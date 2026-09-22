import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/tr_colors.dart';
import '../../core/theme/tr_typography.dart';
import '../../state/home_providers.dart';
import '../../state/session_controller.dart';
import '../../widgets/primary_cta.dart';
import '../../widgets/tr_components.dart';

/// The candidate's centre button: "I'm available today". Recruiters nearby see
/// a lime dot on this person until midnight, and can filter for it.
class GoLiveSheet extends ConsumerStatefulWidget {
  const GoLiveSheet({super.key});

  @override
  ConsumerState<GoLiveSheet> createState() => _GoLiveSheetState();
}

class _GoLiveSheetState extends ConsumerState<GoLiveSheet> {
  bool _saving = false;

  Future<void> _set(bool available) async {
    setState(() => _saving = true);
    try {
      final session = await ref.read(peopleRepositoryProvider).setAvailability(available: available);
      ref.read(sessionProvider.notifier).update(session);
      ref.refreshHome();
      if (!mounted) return;
      Navigator.of(context).pop();
      showTrSnack(
        context,
        available ? 'You are live until midnight. Recruiters nearby can see you are available.' : 'You are no longer shown as available today.',
      );
    } catch (error) {
      if (mounted) showTrSnack(context, errorText(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(sessionProvider)?.candidate;
    if (profile == null) return const SizedBox.shrink();
    final live = profile.availableToday;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(color: TrColors.borderStrong, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: live ? TrColors.lime : TrColors.limeSurface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.sensors_rounded, color: TrColors.plumInk, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(live ? 'You are live today' : 'Go live today', style: TrType.sectionTitle),
                      Text(
                        live ? 'Shown as available until midnight' : 'Tell recruiters nearby you can meet today',
                        style: TrType.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (profile.stealthMode) ...[
              const InfoNote(
                icon: Icons.shield_outlined,
                text: 'Stealth mode is on, so recruiters cannot see you. Turn it off in Privacy to go live.',
              ),
              const SizedBox(height: 16),
              PrimaryCta(
                label: 'Open privacy settings',
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push(Routes.privacy);
                },
              ),
            ] else ...[
              for (final point in const [
                (Icons.circle, 'A lime dot appears on your profile for recruiters nearby.'),
                (Icons.filter_alt_outlined, 'You show up when recruiters filter for "Available today".'),
                (Icons.nightlight_outlined, 'It switches off by itself at midnight.'),
                (Icons.blur_on_rounded, 'Your exact location is still never shared.'),
              ]) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(point.$1, size: point.$1 == Icons.circle ? 12 : 17, color: point.$1 == Icons.circle ? TrColors.lime : TrColors.plumInk),
                    const SizedBox(width: 11),
                    Expanded(child: Text(point.$2, style: TrType.bodySmall.copyWith(color: TrColors.plumInk))),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 12),
              PrimaryCta(
                label: live ? 'Stop being live' : "I'm available today",
                variant: live ? CtaVariant.outline : CtaVariant.lime,
                isLoading: _saving,
                onPressed: () => _set(!live),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
