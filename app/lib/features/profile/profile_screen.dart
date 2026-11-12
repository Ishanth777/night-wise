import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/errors/app_failure.dart';
import '../../core/models/models.dart';
import '../../core/theme/theme.dart';
import '../../providers/app_providers.dart';
import '../../widgets/nw_kit.dart';
import '../../widgets/nw_shell.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider).valueOrNull;
    final profileAsync = ref.watch(profileProvider);
    final profile = profileAsync.valueOrNull;
    final email = profile?.email ?? session?.email ?? 'Signed out';
    final displayName = profile?.displayName?.trim();
    final initials = (displayName?.isNotEmpty == true ? displayName! : email)
        .substring(0, 1)
        .toUpperCase();
    final wide = NwBreakpoints.isWide(context);

    final identity = _IdentityCard(
      initials: initials,
      name: displayName?.isNotEmpty == true ? displayName! : email,
      email: email,
      profile: profile,
      signedIn: session != null,
    );
    final settings = profile == null
        ? null
        : _SettingsCard(
            settings: profile.settings,
            onEdit: () => _editSettings(profile.settings),
          );
    final saved = profile == null || profile.savedRoutes.isEmpty
        ? null
        : _SavedRoutesCard(
            routes: profile.savedRoutes,
            onOpen: _openSavedRoute,
            onDelete: _deleteSavedRoute,
          );

    final footer = Column(
      children: [
        _SectionCard(
          title: 'Community & data',
          children: [
            _Tile(
              icon: Icons.forum_outlined,
              title: 'Community reports',
              subtitle: 'Confirm or deny reports near your start point',
              onTap: () => context.push('/community'),
            ),
            _Tile(
              icon: Icons.dataset_outlined,
              title: 'Data sources & scoring',
              subtitle: 'OpenStreetMap, hours and published reports',
              onTap: () => _showDataSources(context),
            ),
            _Tile(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy commitments',
              subtitle: 'What we store — and what we never store',
              onTap: () => _showPrivacy(context),
            ),
            _Tile(
              icon: Icons.info_outline_rounded,
              title: 'About NightWise',
              subtitle: 'Version 1.0 · Bengaluru MVP',
              onTap: () => _showAbout(context),
              last: true,
            ),
          ],
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Account',
          children: [
            _Tile(
              icon: Icons.description_outlined,
              title: 'Open-source licences',
              subtitle: 'Flutter, MapLibre, OpenStreetMap',
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'NightWise',
                applicationVersion: '1.0.0',
              ),
            ),
            _Tile(
              icon: Icons.logout_rounded,
              title: 'Sign out',
              subtitle: null,
              onTap: _busy ? null : _signOut,
              last: true,
            ),
          ],
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: NwColors.danger,
            side: BorderSide(color: NwColors.danger.withValues(alpha: 0.5)),
          ),
          onPressed: _busy ? null : _deleteAccount,
          icon: const Icon(Icons.delete_forever_outlined, size: 18),
          label: const Text('Delete account'),
        ),
        const SizedBox(height: 18),
        const NwDataNote(
          text: 'NightWise safety scores are environmental estimates, not guarantees '
              'of personal safety. Scores reflect available data and may be incomplete.',
          icon: Icons.info_outline_rounded,
        ),
        const SizedBox(height: 18),
      ],
    );

    return NwAppShell(
      current: 'profile',
      child: Padding(
        padding: EdgeInsets.fromLTRB(wide ? 36 : 16, wide ? 28 : 14, wide ? 36 : 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ACCOUNT', style: NwText.eyebrow),
                      const SizedBox(height: 6),
                      Text('Your night profile', style: NwText.h1),
                    ],
                  ),
                ),
                NwIconButton(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Refresh profile',
                  onPressed: () => ref.invalidate(profileProvider),
                  size: 44,
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (profileAsync.hasError) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: NwColors.dangerSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        profileAsync.error is AppFailure
                            ? (profileAsync.error! as AppFailure).message
                            : 'Could not load your profile details.',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          height: 1.4,
                          color: NwColors.danger,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => ref.invalidate(profileProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        identity,
                        const SizedBox(height: 14),
                        if (profile == null) const _ProfileSkeleton(),
                        if (settings != null) settings,
                        if (saved != null) ...[
                          const SizedBox(height: 14),
                          saved,
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(flex: 4, child: footer),
                ],
              )
            else ...[
              identity,
              const SizedBox(height: 14),
              if (profile == null) const _ProfileSkeleton(),
                        if (settings != null) settings,
              if (saved != null) ...[
                const SizedBox(height: 14),
                saved,
              ],
              const SizedBox(height: 14),
              footer,
            ],
          ],
        ),
      ),
    );
  }

  void _openSavedRoute(SavedRoute route) {
    ref.read(originProvider.notifier).state = route.origin;
    ref.read(destinationProvider.notifier).state = PlaceResult(
      id: 'saved_${route.id}',
      name: route.label,
      lat: route.destination.lat,
      lng: route.destination.lng,
    );
    ref.read(modeProvider.notifier).state = route.mode;
    context.go('/home');
  }

  Future<void> _deleteSavedRoute(SavedRoute route) async {
    try {
      await ref.read(profileRepositoryProvider).deleteSavedRoute(route.id);
      ref.invalidate(profileProvider);
    } catch (error) {
      if (!mounted) return;
      _snack(error is AppFailure ? error.message : 'Could not remove the saved route.');
    }
  }

  Future<void> _editSettings(UserSettings current) async {
    final draft = await showDialog<UserSettings>(
      context: context,
      builder: (dialogContext) => _SettingsDialog(initial: current),
    );
    if (draft == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final saved = await ref.read(profileRepositoryProvider).updateSettings(draft);
      if (!mounted) return;
      ref.read(safetySliderProvider.notifier).state = saved.safetyVsTime;
      ref.read(modeProvider.notifier).state = saved.defaultMode;
      if (saved.vehicleType != null) {
        ref.read(vehicleTypeProvider.notifier).state = saved.vehicleType!;
      }
      ref.invalidate(profileProvider);
      _snack('Preference defaults saved.');
    } catch (error) {
      if (!mounted) return;
      _snack(error is AppFailure ? error.message : 'Could not save preferences.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _signOut() async {
    setState(() => _busy = true);
    await ref.read(authControllerProvider.notifier).logout();
    if (!mounted) return;
    setState(() => _busy = false);
    context.go('/auth');
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'This permanently removes your login and profile. Reports you submitted are '
          'anonymized and stay in the community safety dataset. This cannot be undone.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete forever', style: TextStyle(color: NwColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(authControllerProvider.notifier).deleteAccount();
      if (!mounted) return;
      context.go('/auth');
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is AppFailure ? error.message : 'Could not delete the account.',
          ),
        ),
      );
    }
  }

  void _showPrivacy(BuildContext context) {
    _dialog(
      context,
      title: 'Privacy commitments',
      body: '• No location history is stored.\n'
          '• Reports are pseudonymous; only a hashed device fingerprint is saved.\n'
          '• Access tokens are short-lived (15 min) and refresh tokens rotate on use.\n'
          '• Route requests are cached for 10 minutes by rounded coordinates and time '
          'bucket, not tied to your identity.\n'
          '• Route detail links expire after 24 hours.\n'
          '• Deleting your account removes your login, profile, preference defaults and '
          'saved routes; reports are anonymized.',
    );
  }

  void _showDataSources(BuildContext context) {
    _dialog(
      context,
      title: 'Data sources & scoring',
      body: 'Roads, businesses, opening hours and emergency services come from '
          'OpenStreetMap. Route candidates are generated by a self-hosted Valhalla '
          'engine. Lighting is scored only where verified data exists; otherwise the '
          'score is labelled as estimated and confidence is reduced.\n\n'
          'Community reports are moderated before they influence scores. Missing data is '
          'shown as insufficient — we never fill gaps with fabricated values.',
    );
  }

  void _showAbout(BuildContext context) {
    _dialog(
      context,
      title: 'About NightWise',
      body: 'NightWise reorders walking and vehicle routes by environmental safety '
          'signals: lighting, open businesses, footfall, community reports, emergency '
          'access and road quality.\n\n'
          'NightWise safety scores are environmental estimates, not guarantees of '
          'personal safety. Trust your instincts.',
    );
  }

  void _dialog(BuildContext context, {required String title, required String body}) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(body, style: NwText.bodyMuted.copyWith(height: 1.6, fontSize: 13)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- cards

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.initials,
    required this.name,
    required this.email,
    required this.profile,
    required this.signedIn,
  });

  final String initials;
  final String name;
  final String email;
  final UserProfile? profile;
  final bool signedIn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: NwColors.ink,
        borderRadius: BorderRadius.circular(NwRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: NwColors.accent,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  initials,
                  style: const TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: NwColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.4,
                        color: NwColors.onDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      signedIn ? '$email · Bengaluru' : 'Not signed in',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: NwColors.onDarkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  (profile?.role ?? 'user').toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 9.5,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                    color: NwColors.onDarkMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(height: 1, color: Colors.white12),
          const SizedBox(height: 14),
          Row(
            children: [
              _DarkStat(label: 'Reports', value: '${profile?.reportsSubmitted ?? 0}'),
              _DarkStat(label: 'Votes', value: '${profile?.votesCast ?? 0}'),
              _DarkStat(
                label: 'Saved',
                value: profile == null ? '—' : '${profile!.savedRoutes.length}/2',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DarkStat extends StatelessWidget {
  const _DarkStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: NwColors.onDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 10.5,
              color: NwColors.onDarkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.settings, required this.onEdit});

  final UserSettings settings;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final priority = settings.safetyVsTime >= 0.66
        ? 'Prefer safety'
        : settings.safetyVsTime <= 0.34
            ? 'Prefer speed'
            : 'Balanced';
    return NwCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Trip defaults', style: NwText.h3)),
              TextButton(onPressed: onEdit, child: const Text('Edit')),
            ],
          ),
          const SizedBox(height: 4),
          _SettingLine(label: 'Safety vs time', value: priority),
          _SettingLine(
            label: 'Default mode',
            value: settings.defaultMode == 'walk'
                ? 'Walking'
                : 'Driving · ${settings.vehicleType == 'two_wheeler' ? 'two-wheeler' : 'car'}',
          ),
          _SettingLine(label: 'Avoid steps', value: settings.avoidSteps ? 'On' : 'Off'),
        ],
      ),
    );
  }
}

class _SettingLine extends StatelessWidget {
  const _SettingLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: NwText.small)),
          Text(
            value,
            style: NwText.label.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SavedRoutesCard extends StatelessWidget {
  const _SavedRoutesCard({
    required this.routes,
    required this.onOpen,
    required this.onDelete,
  });

  final List<SavedRoute> routes;
  final ValueChanged<SavedRoute> onOpen;
  final ValueChanged<SavedRoute> onDelete;

  @override
  Widget build(BuildContext context) {
    return NwCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Saved routes', style: NwText.h3)),
              Text('MAX 2', style: NwText.eyebrow.copyWith(fontSize: 9)),
            ],
          ),
          const SizedBox(height: 10),
          for (final route in routes)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: NwColors.canvas,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onOpen(route),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                    child: Row(
                      children: [
                        Icon(
                          route.mode == 'walk'
                              ? Icons.directions_walk_rounded
                              : Icons.directions_car_outlined,
                          size: 18,
                          color: NwColors.ink,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                route.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: NwText.label.copyWith(fontSize: 12.5),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Saved ${DateFormat('d MMM').format(route.createdAt.toLocal())} · '
                                '${route.destination.toString()}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: NwText.small.copyWith(fontSize: 10.5),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove saved route',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.delete_outline_rounded, size: 18),
                          onPressed: () => onDelete(route),
                        ),
                      ],
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return NwCard(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 10, bottom: 4),
            child: Text(title, style: NwText.h3),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.last = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: NwColors.canvas,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: NwColors.inkMuted, size: 17),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: NwText.label.copyWith(fontSize: 13)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: NwText.small.copyWith(fontSize: 10.5)),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 19, color: NwColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 2; i++)
          Container(
            height: 96,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: NwColors.panel,
              borderRadius: BorderRadius.circular(NwRadii.card),
              border: Border.all(color: NwColors.line),
            ),
          ),
      ],
    );
  }
}

class _SettingsDialog extends StatefulWidget {
  const _SettingsDialog({required this.initial});

  final UserSettings initial;

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  late double _slider = widget.initial.safetyVsTime;
  late String _mode = widget.initial.defaultMode;
  late String _vehicle = widget.initial.vehicleType ?? 'car';
  late bool _avoidSteps = widget.initial.avoidSteps;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Trip defaults'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Safety vs time', style: NwText.label),
                const Spacer(),
                Text(
                  _slider >= 0.66
                      ? 'Safety'
                      : _slider <= 0.34
                          ? 'Speed'
                          : 'Balanced',
                  style: NwText.small,
                ),
              ],
            ),
            Slider(
              value: _slider,
              min: 0,
              max: 1,
              divisions: 10,
              onChanged: (value) => setState(() => _slider = value),
            ),
            const SizedBox(height: 4),
            const Text('Default mode', style: NwText.label),
            const SizedBox(height: 8),
            NwSegmented(
              value: _mode,
              onChanged: (value) => setState(() => _mode = value),
              compact: true,
              options: const [
                NwSegmentOption('walk', 'Walking'),
                NwSegmentOption('vehicle', 'Driving'),
              ],
            ),
            if (_mode == 'vehicle') ...[
              const SizedBox(height: 10),
              NwSegmented(
                value: _vehicle,
                onChanged: (value) => setState(() => _vehicle = value),
                compact: true,
                options: const [
                  NwSegmentOption('car', 'Car'),
                  NwSegmentOption('two_wheeler', 'Two-wheeler'),
                ],
              ),
            ],
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _avoidSteps,
              onChanged: (value) => setState(() => _avoidSteps = value),
              title: const Text(
                'Avoid steps when walking',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                'Preference only — every route still shows its real geometry.',
                style: TextStyle(fontFamily: 'Inter', fontSize: 11.5),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(
            UserSettings(
              safetyVsTime: _slider,
              defaultMode: _mode,
              vehicleType: _mode == 'vehicle' ? _vehicle : null,
              avoidSteps: _avoidSteps,
            ),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}