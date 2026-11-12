/// API DTOs mirroring the backend contract (plan §11.2). Parsing is defensive:
/// unknown indicator fields flow through as maps so the UI can render new
/// signals without a breaking release.
library;

double _d(dynamic v, [double fallback = 0]) =>
    v is num ? v.toDouble() : double.tryParse('$v') ?? fallback;
int _i(dynamic v, [int fallback = 0]) => v is num ? v.toInt() : int.tryParse('$v') ?? fallback;

class LatLngPoint {
  const LatLngPoint(this.lat, this.lng);
  final double lat;
  final double lng;

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};

  factory LatLngPoint.fromJson(Map<String, dynamic> j) =>
      LatLngPoint(_d(j['lat']), _d(j['lng']));

  @override
  String toString() => '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';

  @override
  bool operator ==(Object other) =>
      other is LatLngPoint && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);
}

class Session {
  const Session({
    required this.userId,
    required this.email,
    required this.role,
    required this.accessToken,
    required this.refreshToken,
  });

  final String userId;
  final String email;
  final String role;
  final String accessToken;
  final String refreshToken;

  factory Session.fromJson(Map<String, dynamic> j) => Session(
        userId: '${j['userId']}',
        email: '${j['email']}',
        role: '${j['role'] ?? 'user'}',
        accessToken: '${j['accessToken']}',
        refreshToken: '${j['refreshToken']}',
      );

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'email': email,
        'role': role,
        'accessToken': accessToken,
        'refreshToken': refreshToken,
      };
}

class PlaceResult {
  const PlaceResult({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    this.type = '',
  });

  final String id;
  final String name;
  final double lat;
  final double lng;
  final String type;

  LatLngPoint get point => LatLngPoint(lat, lng);

  factory PlaceResult.fromJson(Map<String, dynamic> j) => PlaceResult(
        id: '${j['id']}',
        name: '${j['name']}',
        lat: _d(j['lat']),
        lng: _d(j['lng']),
        type: '${j['type'] ?? ''}',
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'lat': lat, 'lng': lng, 'type': type};
}

class IndicatorScore {
  const IndicatorScore({
    required this.key,
    required this.score,
    required this.status,
    required this.basis,
    required this.minLengthScore,
    required this.avgConfidence,
    this.details = const {},
  });

  final String key;
  final int score;
  final String status;
  final String basis;
  final int minLengthScore;
  final double avgConfidence;
  final Map<String, dynamic> details;

  factory IndicatorScore.fromJson(String key, Map<String, dynamic> j) => IndicatorScore(
        key: key,
        score: _i(j['score']),
        status: '${j['status'] ?? 'unknown'}',
        basis: '${j['basis'] ?? ''}',
        minLengthScore: _i(j['minLengthScore'], _i(j['score'])),
        avgConfidence: _d(j['avgConfidence']),
        details: Map<String, dynamic>.from(j)..removeWhere(
            (k, _) => const {'score', 'status', 'basis', 'minLengthScore', 'avgConfidence'}.contains(k)),
      );

  String get label => switch (key) {
        'lights' => 'Street lighting',
        'shops' => 'Open businesses',
        'activity' => 'Footfall',
        'community' => 'Community reports',
        'emergency' => 'Emergency access',
        'road_quality' => 'Road quality',
        _ => key,
      };
}

class SegmentScore {
  const SegmentScore({
    required this.segId,
    required this.startM,
    required this.endM,
    required this.score,
    required this.confidence,
    required this.indicators,
    required this.warnings,
  });

  final int segId;
  final double startM;
  final double endM;
  final int score;
  final double confidence;
  final Map<String, IndicatorScore> indicators;
  final List<String> warnings;

  double get lengthM => endM - startM;

  factory SegmentScore.fromJson(Map<String, dynamic> j) {
    final rawInd = (j['indicators'] as Map?)?.cast<String, dynamic>() ?? const {};
    return SegmentScore(
      segId: _i(j['segId']),
      startM: _d(j['startM']),
      endM: _d(j['endM']),
      score: _i(j['score']),
      confidence: _d(j['confidence']),
      indicators: rawInd.map((k, v) => MapEntry(k, IndicatorScore.fromJson(k, (v as Map).cast<String, dynamic>()))),
      warnings: ((j['warnings'] as List?) ?? const []).map((e) => '$e').toList(),
    );
  }
}

class RouteSummary {
  const RouteSummary({
    required this.distanceM,
    required this.durationS,
    required this.safetyScore,
    required this.confidence,
    required this.safetyGrade,
    required this.tradeOff,
  });

  final int distanceM;
  final int durationS;
  final int safetyScore;
  final double confidence;
  final String safetyGrade;
  final String tradeOff;

  String get durationText {
    final min = durationS ~/ 60;
    if (min < 1) return '<1 min';
    if (min < 60) return '$min min';
    return '${min ~/ 60} h ${min % 60} min';
  }

  String get distanceText =>
      distanceM >= 1000 ? '${(distanceM / 1000).toStringAsFixed(1)} km' : '$distanceM m';

  factory RouteSummary.fromJson(Map<String, dynamic> j) => RouteSummary(
        distanceM: _i(j['distanceM']),
        durationS: _i(j['durationS']),
        safetyScore: _i(j['safetyScore']),
        confidence: _d(j['confidence']),
        safetyGrade: '${j['safetyGrade'] ?? 'poor'}',
        tradeOff: '${j['tradeOff'] ?? ''}',
      );
}

class RouteOption {
  const RouteOption({
    required this.routeId,
    required this.label,
    required this.summary,
    required this.coordinates,
    required this.indicators,
    required this.segments,
    required this.warnings,
    required this.streetlightProvenance,
    required this.dataNotes,
  });

  final String routeId;
  final String label;
  final RouteSummary summary;

  /// GeoJSON order: [lng, lat]
  final List<List<double>> coordinates;
  final Map<String, IndicatorScore> indicators;
  final List<SegmentScore> segments;
  final List<String> warnings;
  final String streetlightProvenance;
  final String dataNotes;

  String get labelTitle => switch (label) {
        'safest' => 'Safest',
        'fastest' => 'Fastest',
        'balanced' => 'Balanced',
        _ => 'Alternative',
      };

  bool get hasLimitedLightingData => streetlightProvenance != 'verified';

  factory RouteOption.fromJson(Map<String, dynamic> j) {
    final geom = (j['geometry'] as Map?)?.cast<String, dynamic>() ?? const {};
    final rawCoords = (geom['coordinates'] as List?) ?? const [];
    final rawInd = (j['indicators'] as Map?)?.cast<String, dynamic>() ?? const {};
    final rawSegs = (j['segments'] as List?) ?? const [];
    final health = (j['dataHealth'] as Map?)?.cast<String, dynamic>() ?? const {};
    return RouteOption(
      routeId: '${j['routeId']}',
      label: '${j['label']}',
      summary: RouteSummary.fromJson((j['summary'] as Map).cast<String, dynamic>()),
      coordinates: rawCoords
          .map((c) => (c as List).map((n) => _d(n)).toList())
          .where((c) => c.length >= 2)
          .toList(),
      indicators: rawInd.map((k, v) =>
          MapEntry(k, IndicatorScore.fromJson(k, (v as Map).cast<String, dynamic>()))),
      segments: rawSegs
          .map((s) => SegmentScore.fromJson((s as Map).cast<String, dynamic>()))
          .toList(),
      warnings: ((j['warnings'] as List?) ?? const []).map((e) => '$e').toList(),
      streetlightProvenance: '${health['streetlightProvenance'] ?? 'model_est'}',
      dataNotes: '${health['notes'] ?? ''}',
    );
  }
}

class Recommendation {
  const Recommendation({
    required this.requestId,
    required this.mode,
    required this.computedFor,
    required this.routes,
    required this.dataHealth,
    required this.disclaimer,
    required this.cacheHit,
    required this.tookMs,
  });

  final String requestId;
  final String mode;
  final DateTime computedFor;
  final List<RouteOption> routes;
  final Map<String, dynamic> dataHealth;
  final String disclaimer;
  final bool cacheHit;
  final int tookMs;

  factory Recommendation.fromJson(Map<String, dynamic> j) {
    final meta = (j['meta'] as Map?)?.cast<String, dynamic>() ?? const {};
    return Recommendation(
      requestId: '${j['requestId']}',
      mode: '${j['mode']}',
      computedFor: DateTime.tryParse('${j['computedFor']}') ?? DateTime.now(),
      routes: ((j['routes'] as List?) ?? const [])
          .map((r) => RouteOption.fromJson((r as Map).cast<String, dynamic>()))
          .toList(),
      dataHealth: (j['dataHealth'] as Map?)?.cast<String, dynamic>() ?? const {},
      disclaimer: '${j['disclaimer'] ?? ''}',
      cacheHit: '${meta['cache']}' == 'HIT',
      tookMs: _i(meta['took']),
    );
  }
}

class EmergencyPlace {
  const EmergencyPlace({
    required this.id,
    required this.type,
    required this.name,
    required this.contact,
    required this.verified,
    required this.distanceM,
    required this.lat,
    required this.lng,
  });

  final int id;
  final String type;
  final String? name;
  final String? contact;
  final bool verified;
  final int distanceM;
  final double lat;
  final double lng;

  String get displayName => name?.trim().isNotEmpty == true
      ? name!
      : type == 'police'
          ? 'Police station'
          : 'Hospital';

  factory EmergencyPlace.fromJson(Map<String, dynamic> j) => EmergencyPlace(
        id: _i(j['id']),
        type: '${j['type']}',
        name: j['name'] as String?,
        contact: j['contact'] as String?,
        verified: j['verified'] == true,
        distanceM: _i(j['distanceM']),
        lat: _d(j['lat']),
        lng: _d(j['lng']),
      );
}

enum ReportKind {
  harassment('harassment', 'Harassment / stalking'),
  poorLighting('poor_lighting', 'Poor lighting'),
  unsafeIsolated('unsafe_isolated', 'Isolated / deserted'),
  noFootpath('no_footpath', 'No footpath'),
  construction('construction', 'Construction / obstruction'),
  crowdSafe('crowd_safe', 'Feels safe / busy'),
  other('other', 'Other');

  const ReportKind(this.apiValue, this.label);
  final String apiValue;
  final String label;

  static ReportKind fromApi(String value) => ReportKind.values.firstWhere(
        (kind) => kind.apiValue == value,
        orElse: () => ReportKind.other,
      );
}

// ------------------------------------------------------- profile & reports

class UserSettings {
  const UserSettings({
    this.safetyVsTime = 0.8,
    this.defaultMode = 'walk',
    this.vehicleType,
    this.avoidSteps = false,
  });

  final double safetyVsTime;
  final String defaultMode;
  final String? vehicleType;
  final bool avoidSteps;

  factory UserSettings.fromJson(Map<String, dynamic>? j) {
    final raw = j ?? const <String, dynamic>{};
    return UserSettings(
      safetyVsTime: _d(raw['safetyVsTime'], 0.8).clamp(0.0, 1.0).toDouble(),
      defaultMode: raw['defaultMode'] == 'vehicle' ? 'vehicle' : 'walk',
      vehicleType: raw['vehicleType'] == 'two_wheeler'
          ? 'two_wheeler'
          : (raw['vehicleType'] == 'car' ? 'car' : null),
      avoidSteps: raw['avoidSteps'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'safetyVsTime': safetyVsTime,
        'defaultMode': defaultMode,
        'vehicleType': vehicleType,
        'avoidSteps': avoidSteps,
      };
}

class SavedRoute {
  const SavedRoute({
    required this.id,
    required this.label,
    required this.mode,
    required this.origin,
    required this.destination,
    required this.createdAt,
  });

  final int id;
  final String label;
  final String mode;
  final LatLngPoint origin;
  final LatLngPoint destination;
  final DateTime createdAt;

  factory SavedRoute.fromJson(Map<String, dynamic> j) => SavedRoute(
        id: _i(j['id']),
        label: '${j['label'] ?? 'Saved route'}',
        mode: '${j['mode'] ?? 'walk'}',
        origin: LatLngPoint.fromJson((j['origin'] as Map).cast<String, dynamic>()),
        destination: LatLngPoint.fromJson((j['destination'] as Map).cast<String, dynamic>()),
        createdAt: DateTime.tryParse('${j['createdAt']}') ?? DateTime.now(),
      );
}

class UserProfile {
  const UserProfile({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.role,
    required this.createdAt,
    required this.settings,
    required this.reportsSubmitted,
    required this.votesCast,
    required this.savedRoutes,
  });

  final String userId;
  final String email;
  final String? displayName;
  final String role;
  final DateTime createdAt;
  final UserSettings settings;
  final int reportsSubmitted;
  final int votesCast;
  final List<SavedRoute> savedRoutes;

  factory UserProfile.fromJson(Map<String, dynamic> j) {
    final stats = (j['stats'] as Map?)?.cast<String, dynamic>() ?? const {};
    return UserProfile(
      userId: '${j['userId']}',
      email: '${j['email']}',
      displayName: j['displayName'] as String?,
      role: '${j['role'] ?? 'user'}',
      createdAt: DateTime.tryParse('${j['createdAt']}') ?? DateTime.now(),
      settings: UserSettings.fromJson((j['settings'] as Map?)?.cast<String, dynamic>()),
      reportsSubmitted: _i(stats['reportsSubmitted']),
      votesCast: _i(stats['votesCast']),
      savedRoutes: ((j['savedRoutes'] as List?) ?? const [])
          .map((r) => SavedRoute.fromJson((r as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}

class CommunityReport {
  const CommunityReport({
    required this.id,
    required this.kind,
    required this.severity,
    required this.note,
    required this.point,
    required this.createdAt,
    required this.confirmations,
    required this.denials,
    required this.myVote,
  });

  final int id;
  final ReportKind kind;
  final int severity;
  final String? note;
  final LatLngPoint point;
  final DateTime createdAt;
  final int confirmations;
  final int denials;
  final String? myVote;

  factory CommunityReport.fromJson(Map<String, dynamic> j) => CommunityReport(
        id: _i(j['id']),
        kind: ReportKind.fromApi('${j['kind']}'),
        severity: _i(j['severity'], 3),
        note: j['note'] as String?,
        point: LatLngPoint(_d(j['lat']), _d(j['lng'])),
        createdAt: DateTime.tryParse('${j['createdAt']}') ?? DateTime.now(),
        confirmations: _i(j['confirmations']),
        denials: _i(j['denials']),
        myVote: j['myVote'] as String?,
      );

  CommunityReport withVote(Map<String, dynamic> result) => CommunityReport(
        id: id,
        kind: kind,
        severity: severity,
        note: note,
        point: point,
        createdAt: createdAt,
        confirmations: _i(result['confirmations'], confirmations),
        denials: _i(result['denials'], denials),
        myVote: '${result['myVote'] ?? myVote}',
      );
}
