import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../core/errors/app_failure.dart';
import '../../core/theme/theme.dart';
import '../../providers/app_providers.dart';
import '../../widgets/nw_kit.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _displayName = TextEditingController();
  bool _registering = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _displayName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    final controller = ref.read(authControllerProvider.notifier);
    final ok = _registering
        ? await controller.register(
            email: _email.text,
            password: _password.text,
            displayName: _displayName.text,
          )
        : await controller.login(email: _email.text, password: _password.text);
    if (!mounted) return;
    if (ok) context.go('/home');
  }

  void _toggleMode() {
    setState(() => _registering = !_registering);
    ref.read(authControllerProvider.notifier).clearError();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final loading = authState.isLoading;
    final error = authState.hasError ? authState.error : null;
    final errorText = error is AppFailure
        ? error.message
        : error == null
            ? null
            : 'Sign-in failed. Please try again.';
    final wide = NwBreakpoints.isWide(context);

    final form = _AuthForm(
      formKey: _formKey,
      email: _email,
      password: _password,
      displayName: _displayName,
      registering: _registering,
      obscure: _obscure,
      loading: loading,
      errorText: errorText,
      onToggleObscure: () => setState(() => _obscure = !_obscure),
      onToggleMode: _toggleMode,
      onSubmit: _submit,
    );

    return Scaffold(
      backgroundColor: NwColors.canvas,
      body: wide
          ? Row(
              children: [
                const Expanded(flex: 11, child: _BrandPanel()),
                Expanded(
                  flex: 10,
                  child: SafeArea(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: form,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const NwLogo(size: 40),
                          const SizedBox(width: 10),
                          const NwWordmark(size: 19),
                          const Spacer(),
                          NwPill(
                            label: 'BENGALURU',
                            icon: Icons.location_on_outlined,
                            color: NwColors.textMuted,
                          ),
                        ],
                      ),
                      const SizedBox(height: 34),
                      form,
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _AuthForm extends StatelessWidget {
  const _AuthForm({
    required this.formKey,
    required this.email,
    required this.password,
    required this.displayName,
    required this.registering,
    required this.obscure,
    required this.loading,
    required this.errorText,
    required this.onToggleObscure,
    required this.onToggleMode,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController email;
  final TextEditingController password;
  final TextEditingController displayName;
  final bool registering;
  final bool obscure;
  final bool loading;
  final String? errorText;
  final VoidCallback onToggleObscure;
  final VoidCallback onToggleMode;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return AutofillGroup(
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('WELCOME TO NIGHTWISE', style: NwText.eyebrow),
            const SizedBox(height: 6),
            Text(
              registering ? 'Plan nights\nwith more confidence.' : 'Good to see\nyou again.',
              style: NwText.h1.copyWith(fontSize: 32),
            ),
            const SizedBox(height: 10),
            Text(
              registering
                  ? 'Create an account to compare safety-ranked routes. No location history is kept.'
                  : 'Sign in to compare routes by lighting, activity and real opening hours.',
              style: NwText.bodyMuted,
            ),
            const SizedBox(height: 22),
            NwSegmented(
              value: registering ? 'register' : 'login',
              onChanged: (value) {
                if ((value == 'register') != registering) onToggleMode();
              },
              compact: true,
              options: const [
                NwSegmentOption('login', 'Sign in'),
                NwSegmentOption('register', 'Create account'),
              ],
            ),
            const SizedBox(height: 18),
            if (registering) ...[
              TextFormField(
                controller: displayName,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                decoration: const InputDecoration(
                  labelText: 'Display name (optional)',
                  prefixIcon: Icon(Icons.person_outline_rounded, size: 19),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.mail_outline_rounded, size: 19),
              ),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return 'Email is required';
                final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text);
                if (!valid) return 'Enter a valid email address';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: password,
              obscureText: obscure,
              textInputAction: TextInputAction.done,
              autofillHints:
                  registering ? const [AutofillHints.newPassword] : const [AutofillHints.password],
              onFieldSubmitted: (_) {
                if (!loading) onSubmit();
              },
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 19),
                helperText: registering ? 'At least 8 characters' : null,
                suffixIcon: IconButton(
                  tooltip: obscure ? 'Show password' : 'Hide password',
                  onPressed: onToggleObscure,
                  icon: Icon(
                    obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 19,
                  ),
                ),
              ),
              validator: (value) {
                final text = value ?? '';
                if (text.isEmpty) return 'Password is required';
                if (registering && text.length < 8) return 'Use at least 8 characters';
                return null;
              },
            ),
            if (errorText != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: NwColors.dangerSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: NwColors.danger, size: 17),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        errorText!,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          color: NwColors.danger,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            NwActionButton(
              label: registering ? 'Create my account' : 'Sign in',
              icon: registering ? Icons.arrow_forward_rounded : Icons.arrow_forward_rounded,
              busy: loading,
              onPressed: loading ? null : onSubmit,
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: loading ? null : onToggleMode,
                child: Text(
                  registering
                      ? 'Already have an account? Sign in'
                      : 'New here? Create an account',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              AppConfig.disclaimer,
              textAlign: TextAlign.center,
              style: NwText.small.copyWith(fontSize: 10.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: NwColors.ink,
      padding: const EdgeInsets.fromLTRB(48, 36, 48, 36),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _RouteArtPainter()),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const NwLogo(size: 40, dark: false),
                  const SizedBox(width: 10),
                  const NwWordmark(size: 19, color: NwColors.onDark),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white24),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Text(
                      'BENGALURU · NIGHT',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        color: NwColors.onDarkMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              const Text(
                'Come home\nwith more\nconfidence.',
                style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 52,
                  height: 0.98,
                  letterSpacing: -2.2,
                  fontWeight: FontWeight.w700,
                  color: NwColors.onDark,
                ),
              ),
              const SizedBox(height: 20),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: const Text(
                  'NightWise ranks walking and driving routes by street lighting, '
                  'open businesses, activity and community reports — not just speed.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    height: 1.55,
                    color: NwColors.onDarkMuted,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  _FeaturePill(icon: Icons.lightbulb_outline, label: 'Lighting-aware'),
                  _FeaturePill(icon: Icons.storefront_outlined, label: 'Real opening hours'),
                  _FeaturePill(icon: Icons.shield_outlined, label: 'Honest confidence'),
                ],
              ),
              const SizedBox(height: 32),
              const Row(
                children: [
                  Icon(Icons.lock_outline_rounded, size: 13, color: NwColors.onDarkMuted),
                  SizedBox(width: 6),
                  Text(
                    'No location history · tokens rotate · Bengaluru-only',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10.5,
                      color: NwColors.onDarkMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: NwColors.accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: NwColors.onDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteArtPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..strokeWidth = 1;
    for (var i = 1; i < 10; i++) {
      final x = size.width * i / 10;
      final y = size.height * i / 10;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final path = Path()
      ..moveTo(size.width * 0.05, size.height * 0.82)
      ..cubicTo(
        size.width * 0.25,
        size.height * 0.7,
        size.width * 0.18,
        size.height * 0.42,
        size.width * 0.46,
        size.height * 0.36,
      )
      ..cubicTo(
        size.width * 0.72,
        size.height * 0.3,
        size.width * 0.62,
        size.height * 0.08,
        size.width * 0.9,
        size.height * 0.06,
      );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.06),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = NwColors.accent.withValues(alpha: 0.75),
    );

    void dot(Offset center, double radius, Color color) {
      canvas.drawCircle(center, radius + 4, Paint()..color = NwColors.ink);
      canvas.drawCircle(center, radius, Paint()..color = color);
    }

    dot(Offset(size.width * 0.05, size.height * 0.82), 5, NwColors.accent);
    dot(Offset(size.width * 0.9, size.height * 0.06), 6, NwColors.onDark);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}