import 'package:flutter_test/flutter_test.dart';
import 'package:nightwise/core/errors/app_failure.dart';
import 'package:nightwise/core/models/models.dart';
import 'package:nightwise/core/utils/geo.dart';
import 'package:nightwise/data/routes/route_repository.dart';

void main() {
  group('Geo', () {
    test('haversine distance is realistic for Bengaluru landmarks', () {
      // MG Road Metro -> Cubbon Park gate, roughly 1.7 km.
      final distance = Geo.distanceM(12.9756, 77.6040, 12.9763, 77.5925);
      expect(distance, greaterThan(1200));
      expect(distance, lessThan(1500));
    });

    test('remaining distance decreases along a straight polyline', () {
      final line = <List<double>>[
        [77.6000, 12.9700],
        [77.6000, 12.9800],
      ];
      final total = Geo.polylineLengthM(line);
      final fromStart = Geo.remainingAlongM(line, 12.9700, 77.6000);
      final midway = Geo.remainingAlongM(line, 12.9750, 77.6000);
      expect(fromStart, closeTo(total, 5));
      expect(midway, closeTo(total / 2, 120));
    });

    test('compass maps bearings to eight directions', () {
      expect(Geo.compass(0), 'N');
      expect(Geo.compass(90), 'E');
      expect(Geo.compass(225), 'SW');
      expect(Geo.compass(359), 'N');
    });
  });

  group('Recommendation parsing', () {
    final payload = <String, dynamic>{
      'requestId': 'rw_test',
      'mode': 'walk',
      'computedFor': '2026-11-09T16:30:00.000Z',
      'routes': [
        {
          'routeId': 'rt_0_abc',
          'label': 'safest',
          'summary': {
            'distanceM': 1665,
            'durationS': 1322,
            'safetyScore': 30,
            'confidence': 0.31,
            'safetyGrade': 'poor',
            'tradeOff': 'safest option',
          },
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              [77.6040, 12.9756],
              [77.5925, 12.9763],
            ],
          },
          'indicators': {
            'lights': {
              'score': 35,
              'status': 'estimated',
              'basis': 'OSM lit tags + modelled fallback',
              'minLengthScore': 30,
              'avgConfidence': 0.3,
            },
            'shops': {
              'score': 0,
              'status': 'no_data',
              'basis': 'no verified points',
              'minLengthScore': 0,
              'avgConfidence': 0,
            },
          },
          'segments': [
            {
              'segId': 1,
              'startM': 0,
              'endM': 250,
              'score': 26,
              'confidence': 0.2,
              'indicators': <String, dynamic>{},
              'warnings': ['Lighting data is estimated for this stretch'],
            },
          ],
          'warnings': ['Streetlight coverage is not verified'],
          'dataHealth': {
            'streetlightProvenance': 'model_est',
            'notes': 'Lighting is modelled from OSM tags.',
          },
        },
      ],
      'dataHealth': {'streetlightCoverage': 'insufficient verified streetlight data'},
      'disclaimer': 'Environmental estimates only.',
      'meta': {'took': 2031, 'cache': 'MISS', 'version': '1.0'},
    };

    test('maps the backend payload into typed DTOs', () {
      final recommendation = Recommendation.fromJson(payload);
      expect(recommendation.routes, hasLength(1));
      expect(recommendation.tookMs, 2031);
      expect(recommendation.cacheHit, isFalse);
      final route = recommendation.routes.first;
      expect(route.labelTitle, 'Safest');
      expect(route.summary.durationText, '22 min');
      expect(route.summary.distanceText, '1.7 km');
      expect(route.coordinates.first, [77.6040, 12.9756]);
      expect(route.indicators['lights']!.score, 35);
      expect(route.indicators['shops']!.status, 'no_data');
      expect(route.segments.single.lengthM, 250);
      expect(route.hasLimitedLightingData, isTrue);
      expect(recommendation.disclaimer, contains('Environmental'));
    });

    test('missing shop data is not treated as a zero-confidence score', () {
      final route = Recommendation.fromJson(payload).routes.first;
      final shops = route.indicators['shops']!;
      expect(shops.score, 0);
      expect(shops.status, 'no_data');
    });
  });

  group('Request encoding', () {
    test('departure time keeps an explicit UTC offset', () {
      final request = RecommendationRequest(
        origin: const LatLngPoint(12.9756, 77.6040),
        destination: const LatLngPoint(12.9763, 77.5925),
        mode: 'walk',
        departureTime: DateTime(2026, 11, 9, 22, 0),
        safetyVsTime: 0.8,
      );
      final json = request.toJson();
      expect(json['mode'], 'walk');
      expect(json.containsKey('vehicleType'), isFalse);
      expect(json['departureTime'], matches(RegExp(r'[+-]\d{2}:\d{2}$')));
      expect((json['userPrefs'] as Map)['safetyVsTime'], 0.8);
    });

    test('vehicle requests send a vehicle type', () {
      final request = RecommendationRequest(
        origin: const LatLngPoint(12.9756, 77.6040),
        destination: const LatLngPoint(12.9763, 77.5925),
        mode: 'vehicle',
        vehicleType: 'two_wheeler',
        departureTime: DateTime(2026, 11, 9, 22, 0),
      );
      expect(request.toJson()['vehicleType'], 'two_wheeler');
    });
  });

  group('Failure mapping', () {
    test('out-of-area errors keep their copy', () {
      final failure = AppFailure.fromStatus(422, 'OUT_OF_SERVICE_AREA', null);
      expect(failure.kind, FailureKind.outOfArea);
      expect(failure.message, contains('Bengaluru-only'));
    });

    test('unknown 500s do not leak server internals', () {
      final failure = AppFailure.fromStatus(500, 'INTERNAL_ERROR', 'stack trace');
      expect(failure.kind, FailureKind.server);
      expect(failure.message, isNot(contains('stack trace')));
    });
  });
}
