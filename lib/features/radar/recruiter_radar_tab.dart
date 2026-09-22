import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/tr_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/enums.dart';
import '../../data/models/people.dart';
import '../../state/home_providers.dart';
import '../../state/session_controller.dart';
import '../../widgets/tr_components.dart';
import '../people/people_widgets.dart';
import 'radar_widgets.dart';

/// Recruiter home: discoverable talent around the company hiring location.
class RecruiterRadarTab extends ConsumerStatefulWidget {
  const RecruiterRadarTab({super.key, required this.onOpenTab});

  final ValueChanged<int> onOpenTab;

  @override
  ConsumerState<RecruiterRadarTab> createState() => _RecruiterRadarTabState();
}

class _RecruiterRadarTabState extends ConsumerState<RecruiterRadarTab> {
  CandidateQuery _query = const CandidateQuery();
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _pickExperience() async {
    final choice = await showModalBottomSheet<ExperienceLevel?>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            ListTile(
              title: const Text('Any experience'),
              onTap: () => Navigator.of(sheetContext).pop(null),
            ),
            for (final level in ExperienceLevel.values)
              ListTile(
                title: Text(level.label),
                trailing: _query.experience == level ? const Icon(Icons.check_rounded) : null,
                onTap: () => Navigator.of(sheetContext).pop(level),
              ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _query = choice == null
          ? _query.copyWith(clearExperience: true)
          : _query.copyWith(experience: choice);
    });
  }

  void _toggleWorkMode(WorkMode mode) {
    setState(() {
      _query = _query.workMode == mode
          ? _query.copyWith(clearWorkMode: true)
          : _query.copyWith(workMode: mode);
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(sessionProvider)?.recruiter;
    if (profile == null) return const SizedBox.shrink();

    final result = ref.watch(nearbyCandidatesProvider(_query));
    final hiringFor = profile.hiringProfiles.isEmpty ? 'your roles' : profile.hiringProfiles.first.name;
    final location = profile.primaryHiringLocation;

    return RefreshIndicator(
      onRefresh: () => ref.refresh(nearbyCandidatesProvider(_query).future),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
        children: [
          RadarHeader(
            eyebrow: 'Hiring for ${profile.companyName} · $hiringFor',
            title: 'Talent near you',
            initials: profile.initials,
            seed: profile.hrName,
            onAvatarTap: () => widget.onOpenTab(3),
          ),
          const SizedBox(height: 16),
          _SearchField(
            controller: _search,
            onSubmitted: (value) => setState(() => _query = _query.copyWith(q: value)),
            onClear: () {
              _search.clear();
              setState(() => _query = _query.copyWith(q: ''));
            },
            // The inline field narrows the radar; this opens the full search,
            // with skills, availability and the rest of the filters.
            onAdvanced: () => context.push(Routes.search),
          ),
          const SizedBox(height: 16),
          if (location == null) ...[
            RadarBanner(
              icon: Icons.apartment_rounded,
              text: 'Set your company hiring location to see candidates around it.',
              actionLabel: 'Set location',
              onAction: () => context.push(Routes.changeLocation(recruiter: true)),
            ),
            const SizedBox(height: 14),
          ],
          AsyncSection<CandidateList>(
            value: result,
            onRetry: () => ref.invalidate(nearbyCandidatesProvider(_query)),
            loading: const LoadingCards(count: 2, height: 200),
            builder: (list) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RadarMap(
                  height: 230,
                  radiusKm: list.radiusKm,
                  caption: 'MAP — AREA LEVEL, NO EXACT PINS',
                  liveLabel: '${list.availableToday} available today',
                  markers: [
                    for (final candidate in list.candidates)
                      RadarMarker(
                        id: candidate.userId,
                        label: candidate.initials,
                        kind: candidate.availableToday ? MarkerKind.livePerson : MarkerKind.person,
                        distanceKm: candidate.distanceKm,
                      ),
                  ],
                  onMarkerTap: (marker) => openQuickProfile(context, marker.id),
                ),
                const SizedBox(height: 18),
                ChipRow(
                  children: [
                    TrFilterChip(
                      label: _query.experience?.label ?? 'Experience',
                      selected: _query.experience != null,
                      onTap: _pickExperience,
                    ),
                    TrFilterChip(
                      label: 'Within ${list.radiusKm.round()} km',
                      selected: true,
                      onTap: () => context.push(Routes.changeLocation(recruiter: true)),
                    ),
                    TrFilterChip(
                      label: 'Available today',
                      selected: _query.availableToday,
                      onTap: () => setState(
                        () => _query = _query.copyWith(availableToday: !_query.availableToday),
                      ),
                    ),
                    TrFilterChip(
                      label: 'Matches my roles',
                      selected: _query.matchOnly,
                      onTap: () => setState(() => _query = _query.copyWith(matchOnly: !_query.matchOnly)),
                    ),
                    for (final mode in WorkMode.values)
                      TrFilterChip(
                        label: switch (mode) {
                          WorkMode.remote => 'Remote',
                          WorkMode.onsite => 'Onsite',
                          WorkMode.hybrid => 'Hybrid',
                        },
                        selected: _query.workMode == mode,
                        onTap: () => _toggleWorkMode(mode),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                if (list.candidates.isEmpty)
                  EmptyState(
                    icon: Icons.person_search_outlined,
                    title: 'No candidates match yet',
                    message: _query == const CandidateQuery()
                        ? 'Candidates who are open to work near ${location?.display ?? 'you'} will appear here.'
                        : 'Try removing a filter, or widen your hiring radius.',
                    compact: true,
                  )
                else ...[
                  Text(
                    '${Fmt.plural(list.candidates.length, 'candidate')} within ${list.radiusKm.round()} km',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 10),
                  for (final candidate in list.candidates) ...[
                    CandidateCardView(candidate: candidate),
                    const SizedBox(height: 12),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onSubmitted,
    required this.onClear,
    required this.onAdvanced,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  final VoidCallback onAdvanced;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: 'Skills, title, experience',
        prefixIcon: const Icon(Icons.search_rounded, size: 18),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (value.text.isNotEmpty)
                IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: onClear,
                ),
              IconButton(
                tooltip: 'Search and filters',
                icon: const Icon(Icons.tune_rounded, size: 18),
                onPressed: onAdvanced,
              ),
            ],
          ),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(100)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(100),
          borderSide: const BorderSide(color: TrColors.border),
        ),
      ),
    );
  }
}
