import 'package:flutter/material.dart';

import '../core/network/api_exception.dart';
import '../core/theme/tr_colors.dart';
import '../core/theme/tr_theme.dart';
import '../core/theme/tr_typography.dart';
import 'primary_cta.dart';

/// Inline banner for a failed action.
///
/// It reads the [ApiException] to pick an icon and an action: offline gets a
/// retry, a taken email gets "Log in", a server problem gets a plain apology.
/// Raw backend text never reaches this widget — the API sends presentable copy.
class ErrorMessage extends StatelessWidget {
  const ErrorMessage({
    super.key,
    required this.error,
    this.onRetry,
    this.onLogin,
    this.onDismiss,
  });

  final ApiException error;
  final VoidCallback? onRetry;
  final VoidCallback? onLogin;
  final VoidCallback? onDismiss;

  IconData get _icon {
    if (error.isNetwork) return Icons.wifi_off_rounded;
    if (error.isTimeout) return Icons.hourglass_empty_rounded;
    if (error.isEmailTaken) return Icons.account_circle_outlined;
    if (error.isRateLimited) return Icons.timer_outlined;
    if (error.isServiceDown) return Icons.cloud_off_rounded;
    return Icons.error_outline_rounded;
  }

  bool get _canRetry =>
      onRetry != null && (error.isNetwork || error.isTimeout || error.isServiceDown);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: TrColors.errorSurface,
        borderRadius: TrRadius.inputR,
        border: Border.all(color: TrColors.clay.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_icon, size: 19, color: TrColors.clayText),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  error.message,
                  style: TrType.bodySmall.copyWith(color: TrColors.clayText, height: 1.45),
                ),
              ),
              if (onDismiss != null)
                InkWell(
                  onTap: onDismiss,
                  customBorder: const CircleBorder(),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close_rounded, size: 17, color: TrColors.clayText),
                  ),
                ),
            ],
          ),
          if (_canRetry || (error.isEmailTaken && onLogin != null))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  if (error.isEmailTaken && onLogin != null)
                    TrTextAction(
                      label: 'Log in instead',
                      onPressed: onLogin,
                      color: TrColors.clayText,
                    ),
                  if (_canRetry)
                    TrTextAction(
                      label: 'Try again',
                      onPressed: onRetry,
                      color: TrColors.clayText,
                      icon: Icons.refresh_rounded,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Full-screen version for when a screen has nothing to show at all.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.error_outline_rounded,
    this.onRetry,
    this.retryLabel = 'Try again',
  });

  final String title;
  final String message;
  final IconData icon;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: TrColors.plumSurface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: TrColors.plumInk),
            ),
            const SizedBox(height: 18),
            Text(title, style: TrType.sectionTitle, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message, style: TrType.bodySmall, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 22),
              PrimaryCta(label: retryLabel, onPressed: onRetry, expand: false),
            ],
          ],
        ),
      ),
    );
  }
}
