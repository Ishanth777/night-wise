import 'package:flutter/material.dart';

import '../core/theme/theme.dart';

/// Shared building blocks for the NightWise design system.
///
/// Keeping controls here makes spacing, radii, typography and states
/// consistent across every screen.
class NwBreakpoints {
  const NwBreakpoints._();
  static const compact = 700.0;
  static const wide = 1020.0;

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < compact;
  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= wide;
}

class NwLogo extends StatelessWidget {
  const NwLogo({super.key, this.size = 38, this.dark = true});

  final double size;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: dark ? NwColors.ink : NwColors.panel,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(
        Icons.nightlight_round,
        size: size * 0.52,
        color: NwColors.accent,
      ),
    );
  }
}

class NwWordmark extends StatelessWidget {
  const NwWordmark({super.key, this.size = 18, this.color = NwColors.text});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      'NightWise',
      style: TextStyle(
        fontFamily: 'SpaceGrotesk',
        fontWeight: FontWeight.w700,
        fontSize: size,
        letterSpacing: -0.5,
        color: color,
      ),
    );
  }
}

class NwIconButton extends StatelessWidget {
  const NwIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 48,
    this.dark = false,
    this.busy = false,
    this.badge,
    this.filledColor,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final bool dark;
  final bool busy;
  final Widget? badge;
  final Color? filledColor;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? NwColors.onDark : NwColors.ink;
    final bg = filledColor ?? (dark ? NwColors.ink : NwColors.panel);
    final child = Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(size * 0.38),
        side: BorderSide(
          color: dark || filledColor != null ? Colors.transparent : NwColors.line,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(size * 0.38),
        onTap: busy ? null : onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (busy)
                SizedBox(
                  width: size * 0.4,
                  height: size * 0.4,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: dark ? NwColors.accent : NwColors.ink,
                  ),
                )
              else
                Icon(icon, size: size * 0.44, color: fg),
              if (badge != null) Positioned(top: 8, right: 8, child: badge!),
            ],
          ),
        ),
      ),
    );
    if (tooltip == null) return child;
    return Tooltip(message: tooltip!, child: child);
  }
}

/// A dark rounded action used in the map chrome, matching the reference rail.
class NwRailButton extends StatelessWidget {
  const NwRailButton({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Tooltip(
        message: label,
        child: Material(
          color: selected ? NwColors.ink : NwColors.panel,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: 60,
              padding: EdgeInsets.symmetric(vertical: selected ? 10 : 11),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? Colors.transparent : NwColors.line,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 21,
                    color: selected ? NwColors.accent : NwColors.ink,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                      color: selected ? NwColors.onDark : NwColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NwPill extends StatelessWidget {
  const NwPill({
    super.key,
    required this.label,
    this.icon,
    this.color = NwColors.ink,
    this.background = NwColors.panel,
    this.border = true,
    this.onTap,
    this.trailing,
  });

  final String label;
  final IconData? icon;
  final Color color;
  final Color background;
  final bool border;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: EdgeInsets.fromLTRB(icon == null ? 12 : 10, 7, 12, 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(NwRadii.chip),
        border: border ? Border.all(color: NwColors.line) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            trailing!,
          ],
        ],
      ),
    );
    if (onTap == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(NwRadii.chip),
        onTap: onTap,
        child: child,
      ),
    );
  }
}

class NwCard extends StatelessWidget {
  const NwCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color = NwColors.panel,
    this.borderColor = NwColors.line,
    this.radius = NwRadii.card,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class NwSheet extends StatelessWidget {
  const NwSheet({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 10, 20, 18),
    this.showHandle = true,
    this.color = NwColors.surface,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool showHandle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(NwRadii.sheet),
        ),
        border: const Border(top: BorderSide(color: NwColors.line)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A111410),
            blurRadius: 30,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showHandle)
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 2),
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: NwColors.lineStrong,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

class NwSegmented extends StatelessWidget {
  const NwSegmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.compact = false,
  });

  final List<NwSegmentOption> options;
  final String value;
  final ValueChanged<String> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: NwColors.canvasDeep,
        borderRadius: BorderRadius.circular(NwRadii.control),
      ),
      child: Row(
        children: [
          for (final option in options)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(option.value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.symmetric(vertical: compact ? 8 : 11),
                  decoration: BoxDecoration(
                    color: value == option.value
                        ? NwColors.ink
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (option.icon != null) ...[
                        Icon(
                          option.icon,
                          size: 16,
                          color: value == option.value
                              ? NwColors.accent
                              : NwColors.textMuted,
                        ),
                        const SizedBox(width: 7),
                      ],
                      Flexible(
                        child: Text(
                          option.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: compact ? 12 : 13,
                            fontWeight: FontWeight.w600,
                            color: value == option.value
                                ? NwColors.onDark
                                : NwColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class NwSegmentOption {
  const NwSegmentOption(this.value, this.label, {this.icon});
  final String value;
  final String label;
  final IconData? icon;
}

class NwSectionHeading extends StatelessWidget {
  const NwSectionHeading({
    super.key,
    required this.title,
    this.eyebrow,
    this.trailing,
    this.padding = EdgeInsets.zero,
  });

  final String title;
  final String? eyebrow;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null) ...[
                  Text(eyebrow!.toUpperCase(), style: NwText.eyebrow),
                  const SizedBox(height: 5),
                ],
                Text(title, style: NwText.h2),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class NwActionButton extends StatelessWidget {
  const NwActionButton({
    super.key,
    required this.label,
    this.icon = Icons.arrow_forward_rounded,
    this.onPressed,
    this.busy = false,
    this.expand = true,
    this.dark = true,
    this.accentIcon = true,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool busy;
  final bool expand;
  final bool dark;
  final bool accentIcon;

  @override
  Widget build(BuildContext context) {
    final bg = dark ? NwColors.ink : NwColors.panel;
    final fg = dark ? NwColors.onDark : NwColors.ink;
    final button = Material(
      color: onPressed == null ? NwColors.lineStrong : bg,
      borderRadius: BorderRadius.circular(NwRadii.control),
      child: InkWell(
        borderRadius: BorderRadius.circular(NwRadii.control),
        onTap: busy ? null : onPressed,
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: dark ? NwColors.accent : NwColors.ink,
                  ),
                )
              else ...[
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: NwText.button.copyWith(color: fg),
                  ),
                ),
                if (icon != null) ...[
                  const SizedBox(width: 10),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: accentIcon && dark
                          ? NwColors.accent
                          : (dark ? NwColors.onDark : NwColors.ink),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 16,
                      color: dark ? NwColors.ink : NwColors.onDark,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class NwProgressBar extends StatelessWidget {
  const NwProgressBar({
    super.key,
    required this.value,
    this.height = 6,
    this.color = NwColors.accent,
    this.track = NwColors.line,
  });

  final double value;
  final double height;
  final Color color;
  final Color track;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: track),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value.clamp(0.0, 1.0),
              child: ColoredBox(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class NwDataNote extends StatelessWidget {
  const NwDataNote({
    super.key,
    required this.text,
    this.icon = Icons.dataset_outlined,
    this.color = NwColors.textMuted,
    this.background = NwColors.canvas,
    this.onTap,
  });

  final String text;
  final IconData icon;
  final Color color;
  final Color background;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: color,
                    fontSize: 11.5,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NwPageHeader extends StatelessWidget {
  const NwPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.eyebrow,
    this.onBack,
    this.actions = const [],
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 18),
  });

  final String title;
  final String? subtitle;
  final String? eyebrow;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (onBack != null) ...[
                NwIconButton(
                  icon: Icons.arrow_back_rounded,
                  onPressed: onBack,
                  tooltip: 'Back',
                  size: 44,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(child: NwWordmark(size: 17)),
              ...actions,
            ],
          ),
          const SizedBox(height: 22),
          if (eyebrow != null) ...[
            Text(eyebrow!.toUpperCase(), style: NwText.eyebrow),
            const SizedBox(height: 7),
          ],
          Text(title, style: NwText.h1),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle!, style: NwText.bodyMuted),
          ],
        ],
      ),
    );
  }
}

class NwEmptyState extends StatelessWidget {
  const NwEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.actionLabel,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? action;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: NwColors.panel,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: NwColors.ink),
            ),
            const SizedBox(height: 18),
            Text(title, textAlign: TextAlign.center, style: NwText.h2),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: NwText.bodyMuted,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 22),
              SizedBox(
                width: 220,
                child: NwActionButton(label: actionLabel ?? 'Continue', onPressed: action),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class NwErrorState extends StatelessWidget {
  const NwErrorState({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
    this.retryLabel = 'Try again',
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: NwColors.dangerSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_off_rounded, size: 27, color: NwColors.danger),
            ),
            const SizedBox(height: 18),
            Text(title, textAlign: TextAlign.center, style: NwText.h2),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Text(message, textAlign: TextAlign.center, style: NwText.bodyMuted),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: 180,
                child: OutlinedButton(onPressed: onRetry, child: Text(retryLabel)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class NwLoading extends StatelessWidget {
  const NwLoading({super.key, this.label = 'Loading…'});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(strokeWidth: 2.6),
            ),
            const SizedBox(height: 16),
            Text(label, style: NwText.bodyMuted, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// A subtle staggered entrance used for cards and sheets.
class NwFadeIn extends StatelessWidget {
  const NwFadeIn({super.key, required this.child, this.delay = 0});
  final Widget child;
  final int delay;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 330 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class NwAvatar extends StatelessWidget {
  const NwAvatar({super.key, required this.initials, this.size = 48, this.dark = true});
  final String initials;
  final double size;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: dark ? NwColors.ink : NwColors.accent,
        shape: BoxShape.circle,
        border: Border.all(color: NwColors.panel, width: 2),
      ),
      child: Text(
        initials,
        style: TextStyle(
          fontFamily: 'SpaceGrotesk',
          fontWeight: FontWeight.w700,
          fontSize: size * 0.4,
          color: dark ? NwColors.accent : NwColors.ink,
        ),
      ),
    );
  }
}