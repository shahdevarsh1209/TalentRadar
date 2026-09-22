import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tr_colors.dart';
import '../../core/theme/tr_theme.dart';
import '../../core/theme/tr_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/hiring.dart';
import '../../state/home_providers.dart';
import '../../widgets/tr_components.dart';
import '../jobs/job_widgets.dart';
import 'hiring_widgets.dart';
import 'people_widgets.dart';

/// The public company profile: what they do, every role they have open, and
/// which recruiters you can actually talk to.
///
/// Distinct from `CompanyProfileScreen`, which is the recruiter's own editable
/// form for their company.
class CompanyViewScreen extends ConsumerWidget {
  const CompanyViewScreen({super.key, required this.companyId});

  final String companyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(companyProfileProvider(companyId));

    return Scaffold(
      backgroundColor: TrColors.canvas,
      appBar: AppBar(title: const Text('Company')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(companyProfileProvider(companyId).future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 32),
          children: [
            AsyncSection<CompanyProfile>(
              value: profile,
              onRetry: () => ref.invalidate(companyProfileProvider(companyId)),
              loading: const LoadingCards(count: 3, height: 90),
              builder: (data) => _Body(profile: data),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.profile});

  final CompanyProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = profile.card;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CompanyBadge(name: card.name, size: 62),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(card.name, style: TrType.sectionTitle),
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (card.industry.isNotEmpty) card.industry,
                      if (card.size.isNotEmpty) card.size,
                    ].join(' · '),
                    style: TrType.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            HiringPill(hiringNow: card.hiringNow, openings: card.totalOpenings),
            if (card.area.isNotEmpty) AreaLabel(area: card.area),
            if (card.distanceKm != null) Text(Fmt.distance(card.distanceKm), style: TrType.itemMeta),
          ],
        ),

        if (profile.description.isNotEmpty) ...[
          const SizedBox(height: 22),
          Text('ABOUT', style: TrType.eyebrow),
          const SizedBox(height: 8),
          Text(
            profile.description,
            style: TrType.bodySmall.copyWith(color: TrColors.plumInk, height: 1.55),
          ),
        ],

        if (card.openRoles.isNotEmpty) ...[
          const SizedBox(height: 22),
          Text('HIRING FOR', style: TrType.eyebrow),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final role in card.openRoles)
                RoleChip(
                  role: role,
                  onTap: role.jobId == null ? null : () => openJobDetailsById(context, role.jobId!),
                ),
            ],
          ),
        ],

        const SizedBox(height: 24),
        Text('OPEN ROLES', style: TrType.eyebrow),
        const SizedBox(height: 10),
        if (profile.jobs.isEmpty)
          const EmptyState(
            icon: Icons.work_off_outlined,
            title: 'Nothing open right now',
            message: 'Save this company and check back — new roles show up here first.',
          )
        else
          for (final job in profile.jobs) ...[
            JobRow(job: job, highlighted: job.walkInToday),
            const SizedBox(height: 12),
          ],

        if (profile.recruiters.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('WHO TO TALK TO', style: TrType.eyebrow),
          const SizedBox(height: 10),
          for (final person in profile.recruiters) ...[
            PersonRow(
              person: person,
              // Every recruiter here opens their profile — no dead-end rows.
              onTap: () => openRecruiterProfile(context, person.userId),
              trailing: IconButton(
                tooltip: 'Message',
                icon: const Icon(Icons.chat_bubble_outline_rounded, color: TrColors.plumInk),
                onPressed: () => messagePerson(context, ref, person.userId),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],

        if (profile.website.isNotEmpty || profile.linkedinUrl.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: TrColors.card, borderRadius: TrRadius.cardR),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (profile.website.isNotEmpty)
                  _LinkRow(icon: Icons.language_rounded, value: profile.website),
                if (profile.linkedinUrl.isNotEmpty)
                  _LinkRow(icon: Icons.business_center_outlined, value: profile.linkedinUrl),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        InfoNote(
          text: card.verificationStatus == 'verified'
              ? 'This company has been verified by TalentRadar.'
              : 'TalentRadar has not verified this company yet. Check details before an interview.',
        ),
      ],
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: TrColors.icon),
          const SizedBox(width: 10),
          Expanded(
            child: SelectableText(
              value,
              style: TrType.bodySmall.copyWith(color: TrColors.plumInk),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
