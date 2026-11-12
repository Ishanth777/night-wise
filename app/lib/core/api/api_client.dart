import 'dart:async';

import 'package:dio/dio.dart';

import '../config.dart';
import '../errors/app_failure.dart';
import '../models/models.dart';
import 'token_store.dart';

/// Thin Dio wrapper: attaches the bearer token, transparently rotates the
/// refresh token once on a 401, and maps every failure to [AppFailure]
/// (plan §12.3 / §15.1). Requests and responses are strongly typed at the
/// repository layer, not here.
class ApiClient {
  ApiClient({String? baseUrl, required TokenStore tokenStore, Dio? dio})
      : baseUrl = _normalize(baseUrl ?? AppConfig.apiBaseUrl),
        _tokenStore = tokenStore,
        _dio = dio ?? Dio() {
    _dio.options = BaseOptions(
      baseUrl: this.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 45),
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );
    _refreshDio.options = BaseOptions(
      baseUrl: this.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (!options.headers.containsKey('Authorization')) {
            final session = await _tokenStore.read();
            if (session != null) {
              options.headers['Authorization'] = 'Bearer ${session.accessToken}';
            }
          }
          handler.next(options);
        },
        onError: (err, handler) async {
          final status = err.response?.statusCode;
          final isAuthPath = err.requestOptions.path.startsWith('/auth/');
          final alreadyRetried = err.requestOptions.extra['nw_retried'] == true;
          if (status == 401 && !isAuthPath && !alreadyRetried) {
            final session = await _refresh();
            if (session != null) {
              final retry = err.requestOptions;
              retry.extra = {...retry.extra, 'nw_retried': true};
              retry.headers['Authorization'] = 'Bearer ${session.accessToken}';
              try {
                final res = await _dio.fetch<dynamic>(retry);
                handler.resolve(res);
                return;
              } on DioException {
                // fall through and surface the original failure
              }
            }
          }
          handler.next(err);
        },
      ),
    );
  }

  final String baseUrl;
  final TokenStore _tokenStore;
  final Dio _dio;
  final Dio _refreshDio = Dio();

  static String _normalize(String value) =>
      value.endsWith('/') ? value.substring(0, value.length - 1) : value;

  Future<Session?>? _refreshing;

  Future<Session?> _refresh() {
    final inFlight = _refreshing;
    if (inFlight != null) return inFlight;
    final future = _doRefresh().whenComplete(() => _refreshing = null);
    _refreshing = future;
    return future;
  }

  Future<Session?> _doRefresh() async {
    final session = await _tokenStore.read();
    if (session == null) return null;
    try {
      final res = await _refreshDio.post<dynamic>(
        '/auth/refresh',
        data: {'refreshToken': session.refreshToken},
      );
      final body = res.data;
      if (body is! Map || body['data'] is! Map) return null;
      final next = Session.fromJson((body['data'] as Map).cast<String, dynamic>());
      if (next.accessToken.isEmpty || next.refreshToken.isEmpty) return null;
      await _tokenStore.write(next);
      return next;
    } catch (_) {
      await _tokenStore.clear();
      return null;
    }
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get<dynamic>(path, queryParameters: query));

  Future<dynamic> post(String path, {Object? data}) =>
      _send(() => _dio.post<dynamic>(path, data: data));

  Future<dynamic> patch(String path, {Object? data}) =>
      _send(() => _dio.patch<dynamic>(path, data: data));

  Future<dynamic> delete(String path) => _send(() => _dio.delete<dynamic>(path));

  Future<dynamic> _send(Future<Response<dynamic>> Function() run) async {
    try {
      final res = await run();
      return _unwrap(res);
    } on DioException catch (err) {
      throw _failure(err);
    }
  }

  dynamic _unwrap(Response<dynamic> res) {
    final body = res.data;
    if (body is Map && body.containsKey('data')) return body['data'];
    return body;
  }

  AppFailure _failure(DioException err) {
    final status = err.response?.statusCode;
    final body = err.response?.data;
    String? code;
    String? message;
    if (body is Map) {
      final error = body['error'];
      if (error is Map) {
        code = error['code']?.toString();
        message = error['message']?.toString();
      }
    }
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return AppFailure(
          FailureKind.network,
          'NightWise is taking too long to respond. Check your connection and retry.',
        );
      case DioExceptionType.connectionError:
        return AppFailure(
          FailureKind.network,
          'Cannot reach NightWise right now. Check your connection.',
        );
      default:
        break;
    }
    return AppFailure.fromStatus(status, code, message);
  }
}
