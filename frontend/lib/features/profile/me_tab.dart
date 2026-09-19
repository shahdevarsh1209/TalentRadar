import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/tr_colors.dart';
import '../../core/theme/tr_theme.dart';
import '../../core/theme/tr_typography.dart';
import '../../data/models/session.dart';
import '../../state/session_controller.dart';
import '../../widgets/tr_components.dart';

/// "Me": who I am on TalentRadar, and every setting that controls it.
class MeTab extends ConsumerWidget {
  const MeTab({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: TrColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text('Log out?', style: TrType.cardTitle),
        content: Text('You can log back in any time with your email.', style: TrType.bodySmall),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Stay')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Log out')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(sessionProvider.notifier).signOut();
    if (context.mounted) context.go(Routes.welcome);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    if (session == null) return const SizedBox.shrink();

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
      children: [
        Text('Me', style: TrType.screenTitle.copyWith(fontSize: 25)),
        const SizedBox(height: 16),
        if (session.candidate != null)
          _CandidateHeader(profile: session.candidate!, email: session.user.email)
        else if (session.recruiter != null)
          _RecruiterHeader(profile: session.recruiter!, email: session.user.email),
        const SizedBox(height: 22),
        if (session.isCandidate) ..._candidateMenu(context, session.candidate!) else ..._recruiterMenu(context, session.recruiter!),
        const SizedBox(height: 22),
        _MenuGroup(
          children: [
            _MenuItem(
              icon: Icons.logout_rounded,
              title: 'Log out',
              color: TrColors.clayText,
              onTap: () => _signOut(context, ref),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Center(child: Text('TalentRadar · ${session.user.email}', style: TrType.itemMeta.copyWith(fontSize: 11))),
      ],
    );
  }

  List<Widget> _candidateMenu(BuildContext context, CandidateProfile profile) => [
        Text('PROFILE', style: TrType.eyebrow),
        const SizedBox(height: 10),
        _MenuGroup(
          children: [
            _MenuItem(
              icon: Icons.edit_outlined,
              title: 'Edit profile',
              subtitle: 'Titles, skills, experience, work mode',
              onTap: () => context.push(Routes.editProfile),
            ),
            _MenuItem(
              icon: Icons.place_outlined,
              title: 'My area',
              subtitle: profile.location.isSet ? profile.location.display : 'Not set — add it to see nearby roles',
              onTap: () => context.push(Routes.changeLocation(recruiter: false)),
            ),
            _MenuItem(
              icon: Icons.bookmark_border_rounded,
              title: 'Saved',
              subtitle: 'Jobs and walk-ins you kept for later',
              onTap: () => context.push(Routes.saved),
            ),
            _MenuItem(
              icon: Icons.people_outline_rounded,
              title: 'Connections',
              subtitle: 'Requests and people you know',
              onTap: () => context.push(Routes.requests),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Text('PRIVACY', style: TrType.eyebrow),
        const SizedBox(height: 10),
        _MenuGroup(
          children: [
            _MenuItem(
              icon: Icons.shield_outlined,
              title: 'Privacy & stealth mode',
              subtitle: profile.stealthMode
                  ? 'Ninja mode on · hidden from recruiters'
                  : 'Visible to ${profile.profileVisibility.label.toLowerCase()}',
              onTap: () => context.push(Routes.privacy),
            ),
          ],
        ),
      ];

  List<Widget> _recruiterMenu(BuildContext context, RecruiterProfile profile) => [
        Text('HIRING', style: TrType.eyebrow),
        const SizedBox(height: 10),
        _MenuGroup(
          children: [
            _MenuItem(
              icon: Icons.edit_outlined,
              title: 'Edit hiring profile',
              subtitle: 'Your name, designation and the roles you hire for',
              onTap: () => context.push(Routes.editProfile),
            ),
            _MenuItem(
              icon: Icons.apartment_rounded,
              title: 'Company profile',
              subtitle: 'About, industry, size and website',
              onTap: () => context.push(Routes.company),
            ),
            _MenuItem(
              icon: Icons.place_outlined,
              title: 'Hiring location',
              subtitle: profile.primaryHiringLocation == null
                  ? 'Not set — needed to find candidates'
                  : '${profile.primaryHiringLocation!.display} · within ${profile.hiringRadiusKm.round()} km',
              onTap: () => context.push(Routes.changeLocation(recruiter: true)),
            ),
            _MenuItem(
              icon: Icons.bookmark_border_rounded,
              title: 'Saved candidates',
              subtitle: 'People you kept for later',
              onTap: () => context.push(Routes.saved),
            ),
            _MenuItem(
              icon: Icons.people_outline_rounded,
              title: 'Connections',
              subtitle: 'Requests and people you know',
              onTap: () => context.push(Routes.requests),
            ),
          ],
        ),
      ];
}

class _CandidateHeader extends StatelessWidget {
  const _CandidateHeader({required this.profile, required this.email});

  final CandidateProfile profile;
  final String email;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: TrColors.card, borderRadius: TrRadius.largeCardR, boxShadow: TrColors.cardShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TrAvatar(
                initials: profile.initials,
                seed: profile.name,
                size: 62,
                live: profile.availableToday && !profile.stealthMode,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.name, style: TrType.sectionTitle),
                    Text(
                      profile.headline.isNotEmpty ? profile.headline : (profile.jobTitles.isEmpty ? '' : profile.jobTitles.first.name),
                      style: TrType.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              if (profile.stealthMode)
                const TrPill(label: 'Ninja mode on', tone: PillTone.plum, icon: Icons.shield_outlined)
              else if (profile.availableToday)
                const TrPill(label: 'Live today', tone: PillTone.live)
              else
                TrPill(label: profile.openToWork.label, tone: PillTone.live),
              TrPill(label: profile.experienceLevel.label),
              if (profile.location.isSet) TrPill(label: profile.location.display, icon: Icons.place_outlined),
            ],
          ),
          const SizedBox(height: 16),
          _Completion(percent: profile.profileCompletion, hint: 'Add skills and a headline to reach 100%.'),
        ],
      ),
    );
  }
}

class _RecruiterHeader extends StatelessWidget {
  const _RecruiterHeader({required this.profile, required this.email});

  final RecruiterProfile profile;
  final String email;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: TrColors.card, borderRadius: TrRadius.largeCardR, boxShadow: TrColors.cardShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TrAvatar(initials: profile.initials, seed: profile.hrName, size: 62),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.hrName, style: TrType.sectionTitle),
                    Text(
                      [if (profile.designation.isNotEmpty) profile.designation, profile.companyName].join(' · '),
                      style: TrType.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text('HIRING FOR', style: TrType.eyebrow),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [for (final title in profile.hiringProfiles) TrPill(label: title.name, tone: PillTone.plum)],
          ),
          const SizedBox(height: 16),
          _Completion(percent: profile.profileCompletion, hint: 'Complete your company profile so candidates trust your roles.'),
        ],
      ),
    );
  }
}

class _Completion extends StatelessWidget {
  const _Completion({required this.percent, required this.hint});

  final int percent;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: percent / 100,
                strokeWidth: 4,
                backgroundColor: TrColors.border,
                valueColor: const AlwaysStoppedAnimation(TrColors.lime),
              ),
              Text('$percent%', style: TrType.tag.copyWith(fontSize: 10.5)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            percent >= 100 ? 'Your profile is complete.' : hint,
            style: TrType.itemMeta,
          ),
        ),
      ],
    );
  }
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: TrColors.card, borderRadius: TrRadius.cardR, boxShadow: TrColors.cardShadow),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 60, color: TrColors.pageCanvas),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.color = TrColors.plumInk,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: TrRadius.cardR,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: TrColors.plumSurface, borderRadius: BorderRadius.circular(11)),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TrType.itemTitle.copyWith(fontSize: 14, color: color)),
                  if (subtitle != null)
                    Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TrType.itemMeta.copyWith(fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: TrColors.icon),
          ],
        ),
      ),
    );
  }
}
