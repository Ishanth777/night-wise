import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_failure.dart';
import '../../core/theme/theme.dart';
import '../../providers/app_providers.dart';

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
    final email = session?.email ?? 'Signed out';
    final initials = email.isEmpty
        ? 'N'
        : email.substring(0, 1).toUpperCase();

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [NwColors.primary, Color(0xFF3B82F6)],
                  ),
                ),
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: NwColors.night,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      session == null ? 'Not signed in' : 'Bengaluru · MVP',
                      style: const TextStyle(color: NwColors.textMuted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionCard(
            children: [
              _Tile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy commitments',
                subtitle: 'What we store — and what we never store',
                onTap: () => _showPrivacy(context),
              ),
              _Tile(
                icon: Icons.dataset_outlined,
                title: 'Data sources & scoring',
                subtitle: 'OpenStreetMap, hours, community reports',
                onTap: () => _showDataSources(context),
              ),
              _Tile(
                icon: Icons.info_outline,
                title: 'About NightWise',
                subtitle: 'Version 1.0 · Bengaluru MVP',
                onTap: () => _showAbout(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            children: [
              _Tile(
                icon: Icons.description_outlined,
                title: 'Open-source licences',
                subtitle: null,
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'NightWise',
                  applicationVersion: '1.0.0',
                ),
              ),
              _Tile(
                icon: Icons.logout,
                title: 'Sign out',
                subtitle: null,
                onTap: _busy ? null : _signOut,
              ),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: NwColors.danger,
              side: BorderSide(color: NwColors.danger.withValues(alpha: 0.6)),
            ),
            onPressed: _busy ? null : _deleteAccount,
            icon: const Icon(Icons.delete_forever_outlined, size: 18),
            label: const Text('Delete account'),
          ),
          const SizedBox(height: 18),
          const Text(
            'NightWise safety scores are environmental estimates, not guarantees of personal safety. '
            'Scores reflect available data and may be incomplete.',
            textAlign: TextAlign.center,
            style: TextStyle(color: NwColors.textMuted, fontSize: 11.5, height: 1.5),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    setState(() => _busy = true);
    await ref.read(authControllerProvider.notifier).logout();
    if (!mounted) return;
    setState(() => _busy = false);
    if (mounted) context.go('/auth');
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'This permanently removes your login and profile. Reports you submitted are anonymized and stay in the '
          'community safety dataset. This cannot be undone.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Delete forever',
              style: TextStyle(color: NwColors.danger),
            ),
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
          '• Route requests are cached for 10 minutes by rounded coordinates and time bucket, not tied to your identity.\n'
          '• Deleting your account removes your login and profile; reports are anonymized.',
    );
  }

  void _showDataSources(BuildContext context) {
    _dialog(
      context,
      title: 'Data sources & scoring',
      body: 'Roads, businesses, opening hours and emergency services come from OpenStreetMap. '
          'Route candidates are generated by a self-hosted Valhalla engine. '
          'Lighting is scored only where verified data exists; otherwise the score is labelled as estimated and confidence is reduced.\n\n'
          'Community reports are moderated before they influence scores. Missing data is shown as insufficient — we never fill gaps with fabricated values.',
    );
  }

  void _showAbout(BuildContext context) {
    _dialog(
      context,
      title: 'About NightWise',
      body: 'NightWise reorders walking and vehicle routes by environmental safety signals: lighting, open businesses, footfall, community reports, emergency access and road quality.\n\n'
          'NightWise safety scores are environmental estimates, not guarantees of personal safety. Trust your instincts.',
    );
  }

  void _dialog(BuildContext context, {required String title, required String body}) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(body, style: const TextStyle(height: 1.6, fontSize: 13)),
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: NwColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(children: children),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: NwColors.textMuted, size: 21),
      title: Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: const TextStyle(color: NwColors.textMuted, fontSize: 11.5)),
      trailing: const Icon(Icons.chevron_right, size: 20, color: NwColors.textMuted),
      onTap: onTap,
    );
  }
}
