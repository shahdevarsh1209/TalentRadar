import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/tr_colors.dart';
import '../../core/theme/tr_theme.dart';
import '../../core/theme/tr_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/job.dart';
import '../../state/home_providers.dart';
import '../../widgets/primary_cta.dart';
import '../../widgets/tr_components.dart';

/// Recruiter "Roles" tab: every role I have posted, with interest counts.
class RolesTab extends ConsumerWidget {
  const RolesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(myJobsProvider);
    final open = jobs.valueOrNull?.where((job) => job.isOpen).length ?? 0;

    return RefreshIndicator(
      onRefresh: () => ref.refresh(myJobsProvider.future),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
        children: [
          Row(
            children: [
              Expanded(child: Text('Roles', style: TrType.screenTitle.copyWith(fontSize: 25))),
              PrimaryCta(
                label: 'Post',
                icon: Icons.add_rounded,
                expand: false,
                onPressed: () => context.push(Routes.postJob),
              ),
            ],
          ),
          Text(
            jobs.hasValue ? '${Fmt.plural(open, 'open role')} · candidates who tap interested appear here' : 'Loading your roles…',
            style: TrType.itemMeta,
          ),
          const SizedBox(height: 18),
          AsyncSection<List<Job>>(
            value: jobs,
            onRetry: () => ref.invalidate(myJobsProvider),
            builder: (list) => list.isEmpty
                ? EmptyState(
                    icon: Icons.campaign_outlined,
                    title: 'Post your first role',
                    message: 'Roles and walk-ins you post appear on the radar of candidates near your hiring location.',
                    actionLabel: 'Post a role',
                    onAction: () => context.push(Routes.postJob),
                  )
                : Column(
                    children: [
                      for (final job in list) ...[
                        _RoleCard(job: job),
                        const SizedBox(height: 13),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends ConsumerStatefulWidget {
  const _RoleCard({required this.job});

  final Job job;

  @override
  ConsumerState<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends ConsumerState<_RoleCard> {
  bool _busy = false;

  Future<void> _toggleOpen() async {
    final job = widget.job;
    if (job.isOpen) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: TrColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Text('Close this role?', style: TrType.cardTitle),
          content: Text(
            'It will stop appearing to candidates. Conversations you already have stay open.',
            style: TrType.bodySmall,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Keep open')),
            TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Close role')),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(jobsRepositoryProvider).setStatus(job.jobId, open: !job.isOpen);
      ref.refreshHome();
      if (mounted) showTrSnack(context, job.isOpen ? 'Role closed.' : 'Role reopened.');
    } catch (error) {
      if (mounted) showTrSnack(context, errorText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final when = job.isWalkIn && job.walkIn != null
        ? 'Walk-in ${Fmt.day(job.walkIn!.date)} · ${Fmt.clock(job.walkIn!.startTime)}–${Fmt.clock(job.walkIn!.endTime)}'
        : 'Posted ${Fmt.ago(job.createdAt)}';

    return Opacity(
      opacity: job.isOpen ? 1 : 0.62,
      child: Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(color: TrColors.card, borderRadius: TrRadius.cardR, boxShadow: TrColors.cardShadow),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CompanyBadge(name: job.companyName, size: 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(job.title.name, style: TrType.itemTitle.copyWith(fontSize: 15.5)),
                      Text(when, style: TrType.itemMeta),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                TrPill(label: job.isOpen ? 'Open' : 'Closed', tone: job.isOpen ? PillTone.live : PillTone.neutral),
                if (job.walkInToday && job.isOpen) const TrPill(label: 'Walk-in today', tone: PillTone.alert),
                TrPill(label: Fmt.plural(job.openings, 'opening')),
                TrPill(label: '${Fmt.plural(job.interestCount, 'candidate')} interested', tone: PillTone.plum),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: PrimaryCta(
                    label: job.isOpen ? 'Close' : 'Reopen',
                    variant: CtaVariant.outline,
                    isLoading: _busy,
                    onPressed: _toggleOpen,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PrimaryCta(
                    label: 'Interested',
                    onPressed: () => context.push(Routes.jobInterests(job.jobId)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
