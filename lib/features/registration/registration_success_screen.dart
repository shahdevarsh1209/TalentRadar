import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/tr_colors.dart';
import '../../core/theme/tr_typography.dart';
import '../../data/models/session.dart';
import '../../state/registration_controller.dart';
import '../../state/session_controller.dart';
import '../../widgets/primary_cta.dart';
import '../../widgets/tr_logo.dart';
import '../../widgets/tr_scaffold.dart';

/// Final onboarding screen for both roles.
///
/// Candidates get "Welcome to TalentRadar 👋"; recruiters get a summary of the
/// hiring profile they just created, so they can spot a mistake before any
/// candidate sees it.
class RegistrationSuccessScreen extends ConsumerStatefulWidget {
  const RegistrationSuccessScreen({super.key});

  @override
  ConsumerState<RegistrationSuccessScreen> createState() =>
      _RegistrationSuccessScreenState();
}

class _RegistrationSuccessScreenState extends ConsumerState<RegistrationSuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..forward();

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  void _openRadar() {
    // The draft has done its job; nothing from it should leak into a later
    // registration on this device.
    ref.read(registrationProvider.notifier).reset();
    context.go(Routes.radar);
  }

  void _completeCompanyProfile() {
    _openRadar();
    context.push(Routes.company);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    if (session == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final bool isCandidate = session.isCandidate;

    return TrScaffold(
      showBack: false,
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrimaryCta(
            label: isCandidate ? 'Open my radar' : 'Explore Nearby Talent',
            icon: Icons.arrow_forward_rounded,
            onPressed: _openRadar,
          ),
          if (!isCandidate) ...[
            const SizedBox(height: 10),
            PrimaryCta(
              label: 'Complete Company Profile',
              variant: CtaVariant.outline,
              onPressed: _completeCompanyProfile,
            ),
          ],
        ],
      ),
      child: FadeTransition(
        opacity: CurvedAnimation(parent: _entrance, curve: Curves.easeOut),
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(
            CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic),
          ),
          child: isCandidate
              ? _CandidateSuccess(session: session)
              : _RecruiterSuccess(session: session),
        ),
      ),
    );
  }
}

class _SuccessBadge extends StatelessWidget {
  const _SuccessBadge();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const TrLogoMark(size: 64),
        Positioned(
          right: -6,
          bottom: -6,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: TrColors.lime,
              shape: BoxShape.circle,
              border: Border.all(color: TrColors.canvas, width: 3),
            ),
            child: const Icon(Icons.check_rounded, size: 15, color: TrColors.plumInk),
          ),
        ),
      ],
    );
  }
}

class _CandidateSuccess extends StatelessWidget {
  const _CandidateSuccess({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final profile = session.candidate!;
    final firstName = profile.name.split(' ').first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        const _SuccessBadge(),
        const SizedBox(height: 26),
        Text('Welcome to TalentRadar 👋', style: TrType.screenTitle),
        const SizedBox(height: 8),
        Text(
          'You are all set, $firstName. Here is how you will appear to recruiters nearby.',
          style: TrType.bodyLarge.copyWith(fontSize: 14.5),
        ),
        const SizedBox(height: 24),
        TrCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Avatar(initials: profile.initials, seed: profile.name, live: !profile.stealthMode),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(profile.name, style: TrType.cardTitle),
                        Text(
                          profile.jobTitles.isEmpty ? '' : profile.jobTitles.first.name,
                          style: TrType.itemMeta,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _Tag(
                    label: profile.stealthMode ? 'Ninja mode on' : profile.openToWork.label,
                    highlighted: !profile.stealthMode,
                  ),
                  _Tag(label: profile.experienceLevel.label),
                  for (final mode in profile.workModes) _Tag(label: mode.label),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              _SummaryRow(
                icon: Icons.place_outlined,
                label: 'Area',
                value: profile.location.isSet ? profile.location.display : 'Not set yet — add it from Me',
              ),
              _SummaryRow(
                icon: Icons.visibility_outlined,
                label: 'Visible to',
                value: profile.profileVisibility.label,
              ),
              _SummaryRow(
                icon: Icons.work_outline_rounded,
                label: 'Open to',
                value: profile.jobTitles.map((title) => title.name).join(', '),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _CompletionNudge(percent: profile.profileCompletion),
      ],
    );
  }
}

class _RecruiterSuccess extends StatelessWidget {
  const _RecruiterSuccess({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final profile = session.recruiter!;
    final location = profile.primaryHiringLocation;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        const _SuccessBadge(),
        const SizedBox(height: 26),
        Text('Your Hiring Profile is Ready', style: TrType.screenTitle),
        const SizedBox(height: 8),
        Text(
          'Candidates near your hiring location can now discover ${profile.companyName}.',
          style: TrType.bodyLarge.copyWith(fontSize: 14.5),
        ),
        const SizedBox(height: 24),
        TrCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: TrColors.plumSurface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _companyCode(profile.companyName),
                      style: TrType.tag.copyWith(fontSize: 12.5),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(profile.companyName, style: TrType.cardTitle),
                        Text(
                          profile.designation.isEmpty
                              ? profile.hrName
                              : '${profile.hrName} · ${profile.designation}',
                          style: TrType.itemMeta,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('HIRING FOR', style: TrType.eyebrow),
              const SizedBox(height: 10),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final title in profile.hiringProfiles) _Tag(label: title.name),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              _SummaryRow(
                icon: Icons.apartment_rounded,
                label: 'Hiring location',
                value: location == null
                    ? 'Not set yet — add it before you search'
                    : '${location.display} · within ${profile.hiringRadiusKm.toInt()} km',
              ),
              _SummaryRow(
                icon: Icons.verified_outlined,
                label: 'Email',
                value: profile.isOfficialEmailDomain
                    ? '${profile.email} · company domain'
                    : profile.email,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _CompletionNudge(
          percent: profile.profileCompletion,
          message: 'Add your logo, industry and company size so candidates trust your openings.',
        ),
      ],
    );
  }

  static String _companyCode(String name) {
    final letters = name.replaceAll(RegExp(r'[^A-Za-z]'), '');
    if (letters.isEmpty) return 'CO';
    return letters.substring(0, letters.length >= 3 ? 3 : letters.length).toUpperCase();
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials, required this.seed, this.live = false});

  final String initials;
  final String seed;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = TrColors.tintFor(seed);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(color: background, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(initials, style: TrType.itemTitle.copyWith(color: foreground)),
        ),
        if (live)
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: 15,
              height: 15,
              decoration: BoxDecoration(
                color: TrColors.lime,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
              ),
            ),
          ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.highlighted = false});

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: highlighted ? TrColors.limeSurface : TrColors.canvas,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TrType.tag.copyWith(
          color: highlighted ? TrColors.limeText : TrColors.bodyMuted,
          fontWeight: highlighted ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: TrColors.icon),
          const SizedBox(width: 11),
          SizedBox(
            width: 96,
            child: Text(label, style: TrType.itemMeta.copyWith(fontSize: 12)),
          ),
          Expanded(
            child: Text(value, style: TrType.bodySmall.copyWith(color: TrColors.plumInk, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _CompletionNudge extends StatelessWidget {
  const _CompletionNudge({
    required this.percent,
    this.message = 'Add skills and a headline so recruiters understand your experience at a glance.',
  });

  final int percent;
  final String message;

  @override
  Widget build(BuildContext context) {
    return TrCard(
      color: TrColors.plumInk,
      borderColor: TrColors.plumInk,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            height: 50,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: percent / 100,
                  strokeWidth: 4.5,
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  valueColor: const AlwaysStoppedAnimation(TrColors.lime),
                ),
                Text('$percent%', style: TrType.tag.copyWith(color: Colors.white)),
              ],
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profile $percent% complete',
                  style: TrType.itemTitle.copyWith(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: TrType.itemMeta.copyWith(color: Colors.white.withValues(alpha: 0.72)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
