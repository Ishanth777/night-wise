import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../core/errors/app_failure.dart';
import '../../core/models/models.dart';
import '../../core/theme/theme.dart';
import '../../providers/app_providers.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<PlaceResult> _results = const [];
  bool _loading = false;
  String? _error;
  int _requestSeq = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final text = value.trim();
    if (text.length < 2) {
      setState(() {
        _results = const [];
        _error = null;
        _loading = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () => _search(text));
  }

  Future<void> _search(String text) async {
    final seq = ++_requestSeq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await ref.read(routeRepositoryProvider).searchPlaces(
            text,
            near: ref.read(originProvider),
          );
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _loading = false;
        _error = error is AppFailure ? error.message : 'Place search failed.';
      });
    }
  }

  void _select(PlaceResult place) {
    ref.read(destinationProvider.notifier).state = place;
    context.pop();
  }

  Future<void> _enterCoordinates() async {
    final lat = TextEditingController();
    final lng = TextEditingController();
    final done = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enter coordinates'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: lat,
              keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
              decoration: const InputDecoration(labelText: 'Latitude'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: lng,
              keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
              decoration: const InputDecoration(labelText: 'Longitude'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Use point'),
          ),
        ],
      ),
    );
    if (done != true || !mounted) return;
    final latValue = double.tryParse(lat.text.trim());
    final lngValue = double.tryParse(lng.text.trim());
    if (latValue == null || lngValue == null) {
      _showSnack('Enter valid decimal coordinates.');
      return;
    }
    if (!AppConfig.inServiceArea(latValue, lngValue)) {
      _showSnack('That point is outside the Bengaluru service area.');
      return;
    }
    _select(PlaceResult(
      id: 'coords_${latValue}_$lngValue',
      name: 'Dropped pin',
      lat: latValue,
      lng: lngValue,
    ));
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Destination'),
        actions: [
          TextButton.icon(
            onPressed: _enterCoordinates,
            icon: const Icon(Icons.pin_drop_outlined, size: 18),
            label: const Text('Coordinates'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              controller: _query,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
              onSubmitted: (value) {
                final text = value.trim();
                if (text.length >= 2) _search(text);
              },
              decoration: InputDecoration(
                hintText: 'Search a place, street or landmark',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _query.clear();
                          _onChanged('');
                        },
                      ),
              ),
            ),
          ),
          if (_loading)
            const LinearProgressIndicator(minHeight: 2, color: NwColors.primary),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 44, color: NwColors.textMuted),
              const SizedBox(height: 14),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: NwColors.textMuted, height: 1.5),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () {
                  final text = _query.text.trim();
                  if (text.length >= 2) _search(text);
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_query.text.trim().length < 2) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const Text(
            'Popular searches',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 8),
          for (final place in const [
            'MG Road Metro Station, Bengaluru',
            'Koramangala 5th Block, Bengaluru',
            'Indiranagar 100 Feet Road, Bengaluru',
            'Bengaluru City Railway Station',
          ])
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history, color: NwColors.textMuted),
              title: Text(place),
              onTap: () {
                _query.text = place;
                _search(place);
              },
            ),
          const SizedBox(height: 16),
          const Text(
            'Tip: you can tap anywhere on the home map to drop a destination pin.',
            style: TextStyle(color: NwColors.textMuted, fontSize: 12.5, height: 1.5),
          ),
        ],
      );
    }
    if (_results.isEmpty) {
      return const Center(
        child: Text(
          'No places found.\nTry a landmark or use coordinates.',
          textAlign: TextAlign.center,
          style: TextStyle(color: NwColors.textMuted, height: 1.5),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: NwColors.surfaceHigh),
      itemBuilder: (context, index) {
        final place = _results[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.place_outlined, color: NwColors.primary),
          title: Text(place.name, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            '${place.lat.toStringAsFixed(4)}, ${place.lng.toStringAsFixed(4)}'
            '${place.type.isEmpty ? '' : ' · ${place.type}'}',
            style: const TextStyle(color: NwColors.textMuted, fontSize: 12),
          ),
          onTap: () => _select(place),
        );
      },
    );
  }
}
