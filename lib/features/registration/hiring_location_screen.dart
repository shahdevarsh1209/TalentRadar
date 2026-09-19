import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/tr_colors.dart';
import '../../core/theme/tr_typography.dart';
import '../../data/models/registration_draft.dart';
import '../../state/providers.dart';
import '../../state/registration_controller.dart';
import '../../widgets/error_message.dart';
import '../../widgets/location_picker.dart';
import '../../widgets/option_selectors.dart';
import '../../widgets/primary_cta.dart';
import '../../widgets/tr_scaffold.dart';

/// "Where Are You Hiring?" — the recruiter's location step.
///
/// This is the company's hiring location, not the recruiter's own whereabouts.
/// The distinction is stated on screen because it changes what gets published:
/// an office address is business information and is shown as given.
class HiringLocationScreen extends ConsumerStatefulWidget {
  const HiringLocationScreen({super.key});

  @override
  ConsumerState<HiringLocationScreen> createState() => _HiringLocationScreenState();
}

class _HiringLocationScreenState extends ConsumerState<HiringLocationScreen> {
  static const List<double> _radiusOptions = [5, 10, 25, 50];

  bool _requestingDeviceLocation = false;
  String? _permissionNote;
  double _radiusKm = 10;

  Future<void> _useCurrentLocation() async {
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
      ref.read(registrationProvider.notifier).chooseLocation(
            LocationChoice(
              source: 'device',
              latitude: result.choice!.latitude,
              longitude: result.choice!.longitude,
              label: 'Current office location',
            ),
          );
    } else {
      await _searchLocation();
    }
  }

  Future<void> _searchLocation() async {
    final choice = await showModalBottomSheet<LocationChoice>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: TrColors.canvas,
      builder: (_) => const ManualLocationSheet(title: 'Where are you hiring?'),
    );
    if (choice != null && mounted) {
      ref.read(registrationProvider.notifier).chooseLocation(choice);
    }
  }

  Future<void> _continue() async {
    final ok = await ref
        .read(registrationProvider.notifier)
        .submitLocation(hiringRadiusKm: _radiusKm);
    if (!mounted || !ok) return;
    context.push(Routes.success);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registrationProvider);
    final choice = state.locationChoice;

    return TrScaffold(
      title: 'Where Are You Hiring?',
      subtitle:
          'Set the office or city you are hiring for. Candidates are matched against this location.',
      showBack: false,
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrimaryCta(
            label: choice == null ? 'Choose a hiring location' : 'Continue',
            loadingLabel: 'Saving location...',
            isLoading: state.isSubmitting,
            enabled: choice != null,
            onPressed: _continue,
          ),
          if (choice == null)
            TrTextAction(
              label: 'Skip for now',
              onPressed: () => context.push(Routes.success),
            )
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
          TrCard(
            color: TrColors.plumSurface,
            borderColor: TrColors.plumSurface,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.apartment_rounded, size: 18, color: TrColors.plumInk),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    'This is your company hiring location. Your personal location is never shown to candidates.',
                    style: TrType.itemMeta.copyWith(color: TrColors.plumInk, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          LocationPermissionCard(
            title: 'Use Current Location',
            body: 'I am at the office I am hiring for',
            icon: Icons.my_location_rounded,
            isPrimary: true,
            isBusy: _requestingDeviceLocation,
            onTap: _useCurrentLocation,
          ),
          const SizedBox(height: 12),
          LocationPermissionCard(
            title: 'Search Location',
            body: 'Find the city or area you are hiring in',
            icon: Icons.search_rounded,
            onTap: _searchLocation,
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
                      style: TrType.itemMeta.copyWith(color: TrColors.clayText, height: 1.45),
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
                    child: const Icon(Icons.business_rounded, color: TrColors.limeText),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hiring location',
                          style: TrType.itemMeta.copyWith(fontSize: 11.5),
                        ),
                        const SizedBox(height: 2),
                        Text(choice.display, style: TrType.itemTitle.copyWith(fontSize: 14.5)),
                      ],
                    ),
                  ),
                  TrTextAction(label: 'Change', onPressed: _searchLocation),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Search candidates within', style: TrType.label),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final radius in _radiusOptions)
                  ChoicePill(
                    label: '${radius.toInt()} km',
                    selected: _radiusKm == radius,
                    onTap: () => setState(() => _radiusKm = radius),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'You can widen this later from your hiring preferences.',
              style: TrType.itemMeta.copyWith(fontSize: 11.5),
            ),
          ],
        ],
      ),
    );
  }
}
