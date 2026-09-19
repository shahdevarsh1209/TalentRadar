import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/tr_colors.dart';
import '../../core/theme/tr_typography.dart';
import '../../data/models/enums.dart';
import '../../state/registration_controller.dart';
import '../../widgets/primary_cta.dart';
import '../../widgets/role_selection_card.dart';
import '../../widgets/tr_logo.dart';
import '../../widgets/tr_scaffold.dart';

/// "Join TalentRadar" — the only question asked before role is known.
///
/// Switching to the other role after filling a form warns first, because the
/// two roles collect genuinely different things.
class RoleSelectionScreen extends ConsumerWidget {
  const RoleSelectionScreen({super.key});

  Future<void> _continue(BuildContext context, WidgetRef ref, UserRole role) async {
    final controller = ref.read(registrationProvider.notifier);

    if (controller.switchingRoleLosesWork(role)) {
      final previous = ref.read(registrationProvider).role!;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: TrColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Text('Switch to ${role.label}?', style: TrType.cardTitle),
          content: Text(
            'Switching roles will change the information required for your profile. What you entered as ${previous.label.toLowerCase()} will be cleared.',
            style: TrType.bodySmall.copyWith(height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text('Stay', style: TrType.chip.copyWith(color: TrColors.bodyMuted)),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text('Switch', style: TrType.chip.copyWith(color: TrColors.plumInk)),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
      controller.discardDraftFor(previous);
    }

    controller.selectRole(role);
    if (!context.mounted) return;
    context.push(
      role == UserRole.candidate
          ? Routes.candidateRegistration
          : Routes.recruiterRegistration,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedRole = ref.watch(registrationProvider).role;

    return TrScaffold(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TrLogoMark(size: 44),
          const SizedBox(height: 20),
          Text('Join TalentRadar', style: TrType.screenTitle),
          const SizedBox(height: 8),
          Text(
            AppConfig.tagline,
            style: TrType.bodyLarge.copyWith(fontSize: 14.5),
          ),
          const SizedBox(height: 26),
          Text('I AM HERE TO', style: TrType.eyebrow),
          const SizedBox(height: 14),
          for (final role in UserRole.values) ...[
            RoleSelectionCard(
              role: role,
              selected: selectedRole == role,
              onTap: () => _continue(context, ref, role),
            ),
            const SizedBox(height: 14),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.shield_outlined, size: 17, color: TrColors.icon),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Your exact location is never publicly displayed, whichever role you choose.',
                  style: TrType.itemMeta.copyWith(fontSize: 11.5, height: 1.45),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          if (selectedRole != null)
            PrimaryCta(
              label: 'Continue as ${selectedRole.label}',
              icon: Icons.arrow_forward_rounded,
              onPressed: () => _continue(context, ref, selectedRole),
            ),
          const SizedBox(height: 10),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Already have an account?', style: TrType.bodySmall),
                TrTextAction(
                  label: 'Log in',
                  onPressed: () => context.push(Routes.login),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
