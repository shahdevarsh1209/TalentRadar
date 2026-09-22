import 'package:flutter/material.dart';

import '../core/theme/tr_colors.dart';
import '../core/theme/tr_theme.dart';
import '../core/theme/tr_typography.dart';

enum CtaVariant { plum, lime, outline }

/// The one button style in the product. It owns its disabled and loading looks,
/// so no screen has to reimplement "Creating profile…" or guard a second tap.
class PrimaryCta extends StatelessWidget {
  const PrimaryCta({
    super.key,
    required this.label,
    required this.onPressed,
    this.loadingLabel,
    this.isLoading = false,
    this.enabled = true,
    this.variant = CtaVariant.plum,
    this.icon,
    this.expand = true,
  });

  final String label;

  /// Shown while [isLoading]; falls back to the label.
  final String? loadingLabel;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool enabled;
  final CtaVariant variant;
  final IconData? icon;
  final bool expand;

  bool get _interactive => enabled && !isLoading && onPressed != null;

  @override
  Widget build(BuildContext context) {
    final (Color background, Color foreground, Color? borderColor) = switch (variant) {
      CtaVariant.plum => (TrColors.plumInk, Colors.white, null),
      CtaVariant.lime => (TrColors.lime, TrColors.plumInk, null),
      CtaVariant.outline => (Colors.white, TrColors.plumInk, TrColors.borderStrong),
    };

    // Disabled state keeps the shape and dims it, so the CTA never disappears.
    final Color effectiveBackground = _interactive ? background : background.withValues(alpha: 0.38);
    final Color effectiveForeground = _interactive ? foreground : foreground.withValues(alpha: 0.75);

    return Semantics(
      button: true,
      enabled: _interactive,
      label: isLoading ? (loadingLabel ?? label) : label,
      child: SizedBox(
        width: expand ? double.infinity : null,
        child: Material(
          color: effectiveBackground,
          borderRadius: TrRadius.pillR,
          child: InkWell(
            borderRadius: TrRadius.pillR,
            onTap: _interactive ? onPressed : null,
            child: Container(
              constraints: const BoxConstraints(minHeight: 54),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                borderRadius: TrRadius.pillR,
                border: borderColor != null
                    ? Border.all(color: _interactive ? borderColor : TrColors.border)
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLoading) ...[
                    SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation(effectiveForeground),
                      ),
                    ),
                    const SizedBox(width: 11),
                  ],
                  Flexible(
                    child: Text(
                      isLoading ? (loadingLabel ?? label) : label,
                      style: TrType.button.copyWith(color: effectiveForeground),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (icon != null && !isLoading) ...[
                    const SizedBox(width: 9),
                    Icon(icon, size: 18, color: effectiveForeground),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Quiet text action — "Log in", "Change email", "Skip for now".
class TrTextAction extends StatelessWidget {
  const TrTextAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = TrColors.plumInk,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: TrRadius.pillR),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 17), const SizedBox(width: 7)],
          Text(label, style: TrType.chip.copyWith(color: color, fontSize: 13.5)),
        ],
      ),
    );
  }
}
