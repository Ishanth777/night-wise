import '../../core/api/api_client.dart';
import '../../core/models/models.dart';

class ReportReceipt {
  const ReportReceipt({
    required this.id,
    required this.status,
    required this.duplicatesNearby,
    required this.moderationNotice,
  });

  final String id;
  final String status;
  final int duplicatesNearby;
  final String moderationNotice;

  factory ReportReceipt.fromJson(Map<String, dynamic> json, String notice) {
    final hint = (json['duplicateHint'] as Map?)?.cast<String, dynamic>() ?? const {};
    return ReportReceipt(
      id: '${json['id']}',
      status: '${json['status']}',
      duplicatesNearby: (hint['nearbySameKind24h'] as num?)?.toInt() ?? 0,
      moderationNotice: notice,
    );
  }
}

class ReportsRepository {
  ReportsRepository(this._api);

  final ApiClient _api;

  Future<ReportReceipt> create({
    required ReportKind kind,
    required int severity,
    required LatLngPoint at,
    String? note,
  }) async {
    final data = (await _api.post('/reports', data: {
      'kind': kind.apiValue,
      'severity': severity,
      'lat': at.lat,
      'lng': at.lng,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    })) as Map;
    const notice =
        'Reports are moderated before publishing. Reports are anonymous; only a hashed device fingerprint is stored.';
    return ReportReceipt.fromJson(data.cast<String, dynamic>(), notice);
  }

  Future<List<Map<String, dynamic>>> nearby({
    required LatLngPoint at,
    int radiusM = 800,
  }) async {
    final data = await _api.get('/reports/nearby', query: {
      'lat': at.lat,
      'lng': at.lng,
      'radiusM': radiusM,
    });
    if (data is! List) return const [];
    return data.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }
}
