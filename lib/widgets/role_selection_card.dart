import 'package:flutter/material.dart';

import '../core/theme/tr_colors.dart';
import '../core/theme/tr_theme.dart';
import '../core/theme/tr_typography.dart';
import '../data/models/enums.dart';

/// Large role choice on the registration entry screen. The selected card flips
/// to plum so the answer is unmistakable before the CTA is pressed.
class RoleSelectionCard extends StatelessWidget {
  const RoleSelectionCard({
    super.key,
    required this.role,
    required this.selected,
    required this.onTap,
  });

  final UserRole role;
  final bool selected;
  final VoidCallback onTap;

  String get _statement => role == UserRole.candidate
      ? "I'm looking for opportunities"
      : "I'm hiring talent";

  String get _description => role == UserRole.candidate
      ? 'Discover nearby jobs, recruiters, events and professional connections.'
      : 'Discover nearby candidates and connect with professionals.';

  IconData get _icon =>
      role == UserRole.candidate ? Icons.person_outline_rounded : Icons.business_center_outlined;

  @override
  Widget build(BuildContext context) {
    final Color surface = selected ? TrColors.plumInk : TrColors.card;
    final Color primaryText = selected ? Colors.white : TrColors.plumInk;
    final Color secondaryText =
        selected ? Colors.white.withValues(alpha: 0.74) : TrColors.bodyMuted;

    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      label: '${role.label}. $_statement',
      child: InkWell(
        onTap: onTap,
        borderRadius: TrRadius.largeCardR,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 190),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: TrRadius.largeCardR,
            border: Border.all(
              color: selected ? TrColors.plumInk : TrColors.border,
              width: selected ? 2 : 1,
            ),
            boxShadow: selected ? TrColors.raisedShadow : TrColors.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: selected
                          ? TrColors.lime
                          : (role == UserRole.candidate
                              ? TrColors.limeSurface
                              : TrColors.plumSurface),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(_icon, size: 23, color: TrColors.plumInk),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          role.label,
                          style: TrType.cardTitle.copyWith(color: primaryText, fontSize: 18),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _statement,
                          style: TrType.bodySmall.copyWith(color: secondaryText),
                        ),
                      ],
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 190),
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? TrColors.lime : Colors.transparent,
                      border:
                          selected ? null : Border.all(color: TrColors.borderStrong, width: 1.5),
                    ),
                    child: selected
                        ? const Icon(Icons.check_rounded, size: 16, color: TrColors.plumInk)
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                _description,
                style: TrType.bodySmall.copyWith(color: secondaryText, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
