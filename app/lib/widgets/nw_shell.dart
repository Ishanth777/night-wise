import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/theme.dart';
import 'nw_kit.dart';

/// Persistent desktop navigation + a quiet canvas for secondary screens.
/// Compact layouts let each screen own its header so navigation stays
/// platform-appropriate.
class NwAppShell extends StatelessWidget {
  const NwAppShell({
    super.key,
    required this.child,
    required this.current,
    this.maxContentWidth = 1080,
    this.padding = EdgeInsets.zero,
  });

  /// One of: map, community, profile, emergency.
  final String current;
  final Widget child;
  final double maxContentWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    if (!NwBreakpoints.isWide(context)) {
      return Scaffold(
        backgroundColor: NwColors.canvas,
        body: SafeArea(child: child),
      );
    }
    return Scaffold(
      backgroundColor: NwColors.canvas,
      body: Row(
        children: [
          _DesktopRail(current: current),
          Expanded(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: NwColors.line)),
              ),
              child: SingleChildScrollView(
                padding: padding,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxContentWidth),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopRail extends StatelessWidget {
  const _DesktopRail({required this.current});

  final String current;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      color: NwColors.surface,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => context.go('/home'),
            child: const NwLogo(size: 42),
          ),
          const SizedBox(height: 8),
          const NwWordmark(size: 12),
          const SizedBox(height: 30),
          NwRailButton(
            icon: Icons.map_outlined,
            label: 'Map',
            selected: current == 'map',
            onTap: () => context.go('/home'),
          ),
          const SizedBox(height: 10),
          NwRailButton(
            icon: Icons.forum_outlined,
            label: 'Reports',
            selected: current == 'community',
            onTap: () => context.go('/community'),
          ),
          const SizedBox(height: 10),
          NwRailButton(
            icon: Icons.bookmark_border_rounded,
            label: 'Saved',
            selected: current == 'profile',
            onTap: () => context.go('/profile'),
          ),
          const SizedBox(height: 10),
          NwRailButton(
            icon: Icons.sos_outlined,
            label: 'SOS',
            selected: current == 'emergency',
            onTap: () => context.push('/emergency'),
          ),
          const Spacer(),
          NwIconButton(
            icon: Icons.person_outline_rounded,
            tooltip: 'Profile',
            dark: false,
            onPressed: () => context.go('/profile'),
          ),
        ],
      ),
    );
  }
}

/// A compact floating rail used on the map screens at tablet/desktop widths.
class NwFloatingRail extends StatelessWidget {
  const NwFloatingRail({
    super.key,
    required this.current,
    this.onCommunity,
    this.onProfile,
    this.onEmergency,
  });

  final String current;
  final VoidCallback? onCommunity;
  final VoidCallback? onProfile;
  final VoidCallback? onEmergency;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: NwColors.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: NwColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14111410),
            blurRadius: 24,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          NwRailButton(
            icon: Icons.map_outlined,
            label: 'Map',
            selected: current == 'map',
            onTap: () => context.go('/home'),
          ),
          const SizedBox(height: 8),
          NwRailButton(
            icon: Icons.forum_outlined,
            label: 'Reports',
            selected: current == 'community',
            onTap: onCommunity ?? () => context.push('/community'),
          ),
          const SizedBox(height: 8),
          NwRailButton(
            icon: Icons.bookmark_border_rounded,
            label: 'Saved',
            selected: current == 'profile',
            onTap: onProfile ?? () => context.push('/profile'),
          ),
          const SizedBox(height: 8),
          NwRailButton(
            icon: Icons.sos_outlined,
            label: 'SOS',
            selected: current == 'emergency',
            onTap: onEmergency ?? () => context.push('/emergency'),
          ),
        ],
      ),
    );
  }
}