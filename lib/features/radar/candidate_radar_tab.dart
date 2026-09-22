import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/job.dart';
import '../../state/home_providers.dart';
import '../../state/session_controller.dart';
import '../../widgets/tr_components.dart';
import '../jobs/job_widgets.dart';
import 'radar_widgets.dart';

/// Candidate home: what is open near me today.
class CandidateRadarTab extends ConsumerWidget {
  const CandidateRadarTab({super.key, required this.onOpenTab});

  /// Switches the home shell to another tab ("See all" → Jobs).
  final ValueChanged<int> onOpenTab;

  static const JobQuery _query = JobQuery();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(sessionProvider)?.candidate;
    if (profile == null) return const SizedBox.shrink();

    final jobs = ref.watch(jobListProvider(_query));
    final viewed = ref.watch(recruitersViewedProvider).valueOrNull ?? 0;
    final radius = jobs.valueOrNull?.meta.radiusKm ?? 10;
    final area = profile.location.isSet ? profile.location.display : 'Set your area';

    return RefreshIndicator(
      onRefresh: () {
        ref.invalidate(recruitersViewedProvider);
        return ref.refresh(jobListProvider(_query).future);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
        children: [
          RadarHeader(
            eyebrow: '$area · ${radius.round()} km radius',
            title: 'Near you today',
            initials: profile.initials,
            seed: profile.name,
            live: profile.availableToday && !profile.stealthMode,
            onAvatarTap: () => onOpenTab(3),
          ),
          const SizedBox(height: 16),
          RadarSearchBar(
            hint: 'Roles, skills, companies',
            onTap: () => context.push(Routes.search),
          ),
          const SizedBox(height: 16),
          if (profile.stealthMode) ...[
            RadarBanner(
              icon: Icons.shield_outlined,
              text: 'Ninja mode is on — recruiters will not see you on their radar.',
              actionLabel: 'Privacy',
              onAction: () => context.push(Routes.privacy),
            ),
            const SizedBox(height: 14),
          ] else if (!profile.location.isSet) ...[
            RadarBanner(
              icon: Icons.place_outlined,
              text: 'Add your area to see what is actually near you.',
              actionLabel: 'Set area',
              onAction: () => context.push(Routes.changeLocation(recruiter: false)),
            ),
            const SizedBox(height: 14),
          ],
          AsyncSection<JobList>(
            value: jobs,
            onRetry: () => ref.invalidate(jobListProvider(_query)),
            loading: const LoadingCards(count: 1, height: 240),
            builder: (list) {
              final nearby = list.jobs.where((job) => job.distanceKm != null).toList();
              final ordered = [
                ...list.jobs.where((job) => job.matchesProfile),
                ...list.jobs.where((job) => !job.matchesProfile),
              ];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RadarMap(
                    radiusKm: list.meta.radiusKm,
                    caption: 'MAP — APPROXIMATE LOCATIONS ONLY',
                    liveLabel: list.meta.walkInsToday > 0
                        ? '${Fmt.plural(list.meta.walkInsToday, 'walk-in')} today'
                        : '${Fmt.plural(nearby.length, 'role')} nearby',
                    markers: [
                      for (final job in nearby)
                        RadarMarker(
                          id: job.jobId,
                          label: '${job.title.name} at ${job.companyName}',
                          kind: job.isWalkIn ? MarkerKind.walkIn : MarkerKind.opening,
                          distanceKm: job.distanceKm,
                        ),
                    ],
                    onMarkerTap: (marker) {
                      final job = list.jobs.firstWhere((item) => item.jobId == marker.id);
                      openJobDetails(context, job);
                    },
                  ),
                  const SizedBox(height: 18),
                  SectionHeader(
                    title: 'Open near you',
                    actionLabel: 'See all',
                    onAction: () => onOpenTab(1),
                  ),
                  const SizedBox(height: 12),
                  if (ordered.isEmpty)
                    const EmptyState(
                      icon: Icons.work_outline_rounded,
                      title: 'Nothing open nearby yet',
                      message: 'New roles and walk-ins near you will show up here as soon as they are posted.',
                      compact: true,
                    )
                  else
                    for (final job in ordered.take(3)) ...[
                      JobCard(job: job, showActions: false),
                      const SizedBox(height: 12),
                    ],
                ],
              );
            },
          ),
          PlumRow(
            title: viewed == 0
                ? 'Get noticed by recruiters'
                : '${Fmt.plural(viewed, 'recruiter')} viewed you',
            subtitle: viewed == 0
                ? 'A complete profile and going live help you appear first.'
                : 'In the last 3 days',
            onTap: () => onOpenTab(3),
          ),
        ],
      ),
    );
  }
}
