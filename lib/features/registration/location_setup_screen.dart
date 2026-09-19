import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/tr_colors.dart';
import '../../core/theme/tr_typography.dart';
import '../../data/models/registration_draft.dart';
import '../../data/services/device_location_service.dart';
import '../../state/providers.dart';
import '../../state/registration_controller.dart';
import '../../widgets/error_message.dart';
import '../../widgets/location_picker.dart';
import '../../widgets/primary_cta.dart';
import '../../widgets/tr_scaffold.dart';

/// "Discover Opportunities Near You" — the candidate's location step.
///
/// Precise location is never demanded: denying the permission, or skipping the
/// screen outright, both leave a working app.
class LocationSetupScreen extends ConsumerStatefulWidget {
  const LocationSetupScreen({super.key});

  @override
  ConsumerState<LocationSetupScreen> createState() => _LocationSetupScreenState();
}

class _LocationSetupScreenState extends ConsumerState<LocationSetupScreen> {
  bool _requestingDeviceLocation = false;
  String? _permissionNote;

  Future<void> _useDeviceLocation() async {
    setState(() {
      _requestingDeviceLocation = true;
      _permissionNote = null;
    });

    final result = await ref.read(deviceLocationServiceProvider).requestCurrentArea();
    if (!mounted) return;

    setState(() {
      _requestingDeviceLocation = false;
      _permissionNote = result.isGranted ? null : result.message;
    });

    if (result.isGranted) {
      ref.read(registrationProvider.notifier).chooseLocation(result.choice!);
    } else if (result.outcome != LocationOutcome.granted) {
      // Straight to the manual list — a refusal should cost one tap, not two.
      await _chooseManually();
    }
  }

  Future<void> _chooseManually() async {
    final choice = await showModalBottomSheet<LocationChoice>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: TrColors.canvas,
      builder: (_) => const ManualLocationSheet(),
    );
    if (choice != null && mounted) {
      ref.read(registrationProvider.notifier).chooseLocation(choice);
    }
  }

  Future<void> _continue() async {
    final ok = await ref.read(registrationProvider.notifier).submitLocation();
    if (!mounted || !ok) return;
    context.push(Routes.success);
  }

  void _skip() => context.push(Routes.success);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registrationProvider);
    final choice = state.locationChoice;

    return TrScaffold(
      title: 'Discover Opportunities Near You',
      subtitle:
          'TalentRadar uses your approximate area to show relevant jobs, professionals and events nearby.',
      showBack: false,
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrimaryCta(
            label: choice == null ? 'Choose a location to continue' : 'Continue',
            loadingLabel: 'Saving location...',
            isLoading: state.isSubmitting,
            enabled: choice != null,
            onPressed: _continue,
          ),
          if (choice == null)
            TrTextAction(label: 'Skip for now', onPressed: _skip)
          else
            const SizedBox(height: 6),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.error != null) ...[
            ErrorMessage(
              error: state.error!,
              onRetry: _continue,
              onDismiss: () => ref.read(registrationProvider.notifier).clearError(),
            ),
            const SizedBox(height: 18),
          ],
          LocationPermissionCard(
            title: 'Allow Location',
            body: 'Use my current area to find what is nearby',
            icon: Icons.my_location_rounded,
            isPrimary: true,
            isBusy: _requestingDeviceLocation,
            onTap: _useDeviceLocation,
          ),
          const SizedBox(height: 12),
          LocationPermissionCard(
            title: 'Choose Location Manually',
            body: 'Pick your city, area or PIN code instead',
            icon: Icons.map_outlined,
            onTap: _chooseManually,
          ),
          if (_permissionNote != null) ...[
            const SizedBox(height: 14),
            TrCard(
              color: TrColors.claySurface,
              borderColor: TrColors.claySurface,
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, size: 18, color: TrColors.clayText),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      _permissionNote!,
                      style: TrType.itemMeta.copyWith(
                        color: TrColors.clayText,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (choice != null) ...[
            const SizedBox(height: 18),
            TrCard(
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: TrColors.limeSurface,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded, color: TrColors.limeText),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your area', style: TrType.itemMeta.copyWith(fontSize: 11.5)),
                        const SizedBox(height: 2),
                        Text(choice.display, style: TrType.itemTitle.copyWith(fontSize: 14.5)),
                      ],
                    ),
                  ),
                  TrTextAction(label: 'Change', onPressed: _chooseManually),
                ],
              ),
            ),
          ],
          const SizedBox(height: 26),
          const _PrivacyNote(),
        ],
      ),
    );
  }
}

/// The promise this screen has to make credibly, stated plainly.
class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  static const List<(IconData, String)> _points = [
    (Icons.visibility_off_outlined, 'Your exact location is never publicly displayed.'),
    (Icons.blur_on_rounded, 'Others only ever see an approximate area, not a pin.'),
    (Icons.tune_rounded, 'You can change or remove your area at any time in Privacy.'),
  ];

  @override
  Widget build(BuildContext context) {
    return TrCard(
      color: TrColors.plumSurface,
      borderColor: TrColors.plumSurface,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, size: 18, color: TrColors.plumInk),
              const SizedBox(width: 9),
              Text('How we handle your location', style: TrType.itemTitle.copyWith(fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          for (final (icon, text) in _points)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 16, color: TrColors.plumInk),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      text,
                      style: TrType.itemMeta.copyWith(color: TrColors.plumInk, height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
