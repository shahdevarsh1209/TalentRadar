import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/tr_colors.dart';
import '../../core/theme/tr_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/job.dart';
import '../../state/home_providers.dart';
import '../../widgets/tr_components.dart';
import 'job_widgets.dart';

/// Candidate "Jobs" tab: every open role nearby, with walk-in / remote filters.
class JobsTab extends ConsumerStatefulWidget {
  const JobsTab({super.key});

  @override
  ConsumerState<JobsTab> createState() => _JobsTabState();
}

class _JobsTabState extends ConsumerState<JobsTab> {
  String _filter = 'all';

  JobQuery get _query => JobQuery(filter: _filter);

  String _summary(JobList list) {
    final updated = list.meta.updatedAt == null ? '' : ' · updated ${Fmt.ago(list.meta.updatedAt!)}';
    if (!list.meta.hasLocation) return '${Fmt.plural(list.jobs.length, 'open role')}$updated';
    return switch (_filter) {
      'walkins' => '${Fmt.plural(list.jobs.length, 'walk-in')} within ${list.meta.radiusKm.round()} km$updated',
      'remote' => '${Fmt.plural(list.jobs.length, 'remote role')}$updated',
      _ => '${list.meta.nearbyCount} within ${list.meta.radiusKm.round()} km$updated',
    };
  }

  @override
  Widget build(BuildContext context) {
    final jobs = ref.watch(jobListProvider(_query));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Jobs', style: TrType.screenTitle.copyWith(fontSize: 25))),
                  IconButton(
                    tooltip: 'Search jobs',
                    onPressed: () => context.push(Routes.search),
                    icon: const Icon(Icons.search_rounded, color: TrColors.plumInk),
                  ),
                  IconButton(
                    tooltip: 'Saved',
                    onPressed: () => context.push(Routes.saved),
                    icon: const Icon(Icons.bookmark_border_rounded, color: TrColors.plumInk),
                  ),
                ],
              ),
              Text(
                jobs.valueOrNull == null ? 'Finding roles near you…' : _summary(jobs.valueOrNull!),
                style: TrType.itemMeta,
              ),
              const SizedBox(height: 16),
              ChipRow(
                children: [
                  for (final (value, label) in const [('all', 'All'), ('walkins', 'Walk-ins'), ('remote', 'Remote')])
                    TrFilterChip(
                      label: label,
                      selected: _filter == value,
                      onTap: () => setState(() => _filter = value),
                    ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(jobListProvider(_query).future),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 6, 22, 24),
              children: [
                AsyncSection<JobList>(
                  value: jobs,
                  onRetry: () => ref.invalidate(jobListProvider(_query)),
                  builder: (list) {
                    if (list.jobs.isEmpty) {
                      return EmptyState(
                        icon: _filter == 'walkins' ? Icons.event_available_outlined : Icons.work_outline_rounded,
                        title: switch (_filter) {
                          'walkins' => 'No walk-ins nearby right now',
                          'remote' => 'No remote roles yet',
                          _ => 'No open roles nearby yet',
                        },
                        message: list.meta.hasLocation
                            ? 'Check back soon — new roles near you appear here as recruiters post them.'
                            : 'Set your area from the Me tab so we can show roles near you.',
                      );
                    }
                    return Column(
                      children: [
                        for (final job in list.jobs) ...[
                          JobCard(job: job),
                          const SizedBox(height: 13),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
