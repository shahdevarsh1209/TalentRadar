import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tr_colors.dart';
import '../../core/theme/tr_theme.dart';
import '../../core/theme/tr_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/hiring.dart';
import '../../state/home_providers.dart';
import '../../widgets/primary_cta.dart';
import '../../widgets/tr_components.dart';
import '../jobs/job_widgets.dart';
import 'hiring_widgets.dart';
import 'people_widgets.dart';
import 'safety_sheet.dart';

/// The recruiter behind a job, a chat or a search result: who they are, what
/// they are actually hiring for right now, and how to reach them.
///
/// Nothing here is the recruiter's own whereabouts — the location shown is the
/// company's hiring area, which is a business address.
class RecruiterProfileScreen extends ConsumerWidget {
  const RecruiterProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(recruiterProfileProvider(userId));

    return Scaffold(
      backgroundColor: TrColors.canvas,
      appBar: AppBar(
        title: const Text('Recruiter'),
        actions: [
          detail.maybeWhen(
            data: (data) => IconButton(
              tooltip: 'More',
              icon: const Icon(Icons.more_horiz_rounded),
              onPressed: () => showSafetySheet(
                context,
                ref,
                userId: userId,
                name: data.card.name,
                subjectKind: 'person',
                onDone: () => ref.invalidate(recruiterProfileProvider(userId)),
              ),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(recruiterProfileProvider(userId).future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 32),
          children: [
            AsyncSection<RecruiterDetail>(
              value: detail,
              onRetry: () => ref.invalidate(recruiterProfileProvider(userId)),
              loading: const LoadingCards(count: 3, height: 90),
              builder: (data) => _Body(
                detail: data,
                onChanged: () => ref.invalidate(recruiterProfileProvider(userId)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.detail, required this.onChanged});

  final RecruiterDetail detail;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = detail.card;
    final live = detail.liveRoles;
    final declaredOnly = detail.roles.where((role) => !role.hiringNow).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TrAvatar(initials: card.initials, seed: card.name, size: 64, ringColor: TrColors.canvas),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(card.name, style: TrType.sectionTitle),
                  const SizedBox(height: 2),
                  Text(card.designation, style: TrType.bodySmall),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: card.companyId.isEmpty
                        ? null
                        : () => openCompanyProfile(context, card.companyId),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            card.companyName,
                            style: TrType.itemTitle.copyWith(
                              fontSize: 14,
                              color: TrColors.plumInk,
                              decoration: TextDecoration.underline,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, size: 18, color: TrColors.icon),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: card.saved ? 'Remove from saved' : 'Save recruiter',
              onPressed: () async {
                await toggleSavePerson(context, ref, card.userId, card.saved);
                onChanged();
              },
              icon: Icon(
                card.saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                color: card.saved ? TrColors.plumInk : TrColors.icon,
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
            HiringPill(hiringNow: detail.card.hiringNow, openings: card.totalOpenings),
            if (card.area.isNotEmpty) AreaLabel(area: card.area),
            if (card.distanceKm != null) Text(Fmt.distance(card.distanceKm), style: TrType.itemMeta),
          ],
        ),

        // ── Actions ─────────────────────────────────────────────────────────
        if (!detail.isSelf) ...[
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: PrimaryCta(
                  label: 'Message',
                  variant: CtaVariant.outline,
                  enabled: detail.canMessage,
                  onPressed: () => messagePerson(context, ref, card.userId),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ConnectionAction(
                  userId: card.userId,
                  name: card.name,
                  status: card.connectionStatus,
                  connectionId: detail.connectionId,
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ],

        // ── Currently hiring ────────────────────────────────────────────────
        const SizedBox(height: 26),
        Row(
          children: [
            Expanded(child: Text('CURRENTLY HIRING FOR', style: TrType.eyebrow)),
            if (detail.openJobCount > 0)
              TrTextAction(
                label: 'View jobs',
                onPressed: () => openRecruiterJobs(context, card.userId, card.name),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (live.isEmpty)
          const InfoNote(
            text: 'No open roles right now. Connect and they can reach you when something opens.',
          )
        else
          for (final role in live) ...[
            HiringRoleTile(role: role, companyName: card.companyName),
            const SizedBox(height: 10),
          ],

        // Declared but not live: honest about what they recruit for in general,
        // without letting it read as an opening that exists today.
        if (declaredOnly.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('ALSO RECRUITS FOR', style: TrType.eyebrow),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final role in declaredOnly)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                  decoration: BoxDecoration(
                    color: TrColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: TrColors.border),
                  ),
                  child: Text(role.name, style: TrType.chip.copyWith(color: TrColors.bodyMuted)),
                ),
            ],
          ),
        ],

        // ── About ───────────────────────────────────────────────────────────
        const SizedBox(height: 26),
        Text('ABOUT', style: TrType.eyebrow),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: TrColors.card, borderRadius: TrRadius.cardR),
          child: Column(
            children: [
              _Fact(label: 'Company', value: card.companyName),
              if (detail.companyIndustry.isNotEmpty)
                _Fact(label: 'Industry', value: detail.companyIndustry),
              if (detail.companySize.isNotEmpty)
                _Fact(label: 'Company size', value: detail.companySize),
              if (card.area.isNotEmpty) _Fact(label: 'Hiring area', value: card.area),
              if (detail.hiringWorkModes.isNotEmpty)
                _Fact(
                  label: 'Hires for',
                  value: detail.hiringWorkModes.map((mode) => mode.label).join(', '),
                ),
              if (detail.memberSince != null)
                _Fact(label: 'On TalentRadar since', value: Fmt.monthYear(detail.memberSince!)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Said plainly: a work-domain address is not an identity check.
        InfoNote(
          text: detail.verifiedEmailDomain
              ? 'Signed up with a ${card.companyName} work email address. TalentRadar has not otherwise verified this company.'
              : 'This recruiter signed up with a personal email address. Ask for details before sharing anything sensitive.',
        ),
        const SizedBox(height: 10),
        const InfoNote(
          text: 'The area shown is the company hiring location, not anyone\'s home address.',
        ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(label, style: TrType.itemMeta.copyWith(fontSize: 12)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(value, style: TrType.itemTitle.copyWith(fontSize: 13.5)),
          ),
        ],
      ),
    );
  }
}

/// "View jobs" — the same search screen, pinned to one recruiter's postings.
void openRecruiterJobs(BuildContext context, String userId, String name) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: TrColors.canvas,
    builder: (_) => _RecruiterJobsSheet(userId: userId, name: name),
  );
}

class _RecruiterJobsSheet extends ConsumerWidget {
  const _RecruiterJobsSheet({required this.userId, required this.name});

  final String userId;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A recruiter-scoped job search: same endpoint, same rounding, same rules.
    final query = SearchQuery(type: 'jobs', recruiterId: userId);
    final results = ref.watch(searchProvider(query));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: TrColors.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text('Roles from $name', style: TrType.sectionTitle),
          const SizedBox(height: 16),
          AsyncSection<SearchResults>(
            value: results,
            onRetry: () => ref.invalidate(searchProvider(query)),
            loading: const LoadingCards(count: 3, height: 72),
            builder: (data) => data.jobs.isEmpty
                ? const EmptyState(
                    icon: Icons.work_off_outlined,
                    title: 'No open roles',
                    message: 'This recruiter has nothing posted right now.',
                  )
                : Column(
                    children: [
                      for (final job in data.jobs) ...[
                        JobCard(job: job),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
