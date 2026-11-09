/// Engine warnings are stable machine codes; the UI always renders human copy
/// (plan §12.4 — no raw codes or colour-only signals).
String humanizeWarning(String raw) {
  final darkStretch = RegExp(r'^dark_stretch_(\d+)m$').firstMatch(raw);
  if (darkStretch != null) {
    final metres = darkStretch.group(1);
    return 'About $metres m has no verified street lighting.';
  }
  switch (raw) {
    case 'unverified_lighting':
      return 'Lighting data on this route is not field-verified.';
    case 'low_shop_data_confidence':
      return 'Few nearby businesses have known opening hours.';
    case 'low_data_void_stretch':
      return 'Parts of this route have very little available data.';
    case 'low_data_cap_applied':
      return 'The score is capped because data coverage is low.';
    case 'isolated_stretch':
      return 'This stretch has few people or open businesses at night.';
    case 'recent_safety_report':
      return 'A recent community safety report is nearby.';
    case 'poor_road_quality':
      return 'Road or footpath quality is poor here.';
    case 'no_footpath':
      return 'No footpath is mapped along part of this route.';
    default:
      return raw.replaceAll('_', ' ').replaceFirstMapped(
            RegExp(r'^[a-z]'),
            (match) => match.group(0)!.toUpperCase(),
          );
  }
}
