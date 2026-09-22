import 'package:flutter/material.dart';

import '../../core/theme/tr_colors.dart';
import '../../core/theme/tr_theme.dart';
import '../../core/theme/tr_typography.dart';
import '../../data/models/enums.dart';
import '../../data/models/hiring.dart';
import '../../data/models/job_title.dart';
import '../../widgets/job_title_selector.dart';
import '../../widgets/primary_cta.dart';
import '../../widgets/tr_components.dart';

/// The filter sheet. Which filters appear depends on what is being searched —
/// "available today" is meaningless for a company, "walk-in" for a person.
///
/// Returns the edited query, or null if dismissed. Nothing is applied until
/// "Show results", so a half-set filter never fires a request.
Future<SearchQuery?> showSearchFilters(BuildContext context, SearchQuery query) {
  return showModalBottomSheet<SearchQuery>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: TrColors.canvas,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (_) => _FiltersSheet(query: query),
  );
}

class _FiltersSheet extends StatefulWidget {
  const _FiltersSheet({required this.query});

  final SearchQuery query;

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late SearchQuery _draft = widget.query;
  final TextEditingController _skill = TextEditingController();

  /// Kept so the field can show the role's name; the query only carries a code.
  JobTitle? _title;

  @override
  void initState() {
    super.initState();
    _skill.text = widget.query.skill ?? '';
  }

  @override
  void dispose() {
    _skill.dispose();
    super.dispose();
  }

  void _set(SearchQuery next) => setState(() => _draft = next);

  bool get _isPeople => _draft.type == 'candidates';
  bool get _isJobs => _draft.type == 'jobs';
  bool get _isOrg => _draft.type == 'companies' || _draft.type == 'recruiters';

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, controller) => Column(
        children: [
          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 12),
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
                Row(
                  children: [
                    Expanded(child: Text('Filters', style: TrType.sectionTitle)),
                    if (_draft.activeFilterCount > 0)
                      TrTextAction(
                        label: 'Clear all',
                        color: TrColors.clayText,
                        onPressed: () => _set(_draft.cleared()),
                      ),
                  ],
                ),
                const SizedBox(height: 18),

                // ── Job title, from the master list rather than free text ──
                Text('ROLE', style: TrType.eyebrow),
                const SizedBox(height: 10),
                _TitlePicker(
                  title: _title,
                  hasCode: _draft.titleCode != null,
                  onPicked: (title) {
                    _title = title;
                    _set(
                      title == null
                          ? _draft.copyWith(clearTitleCode: true)
                          : _draft.copyWith(titleCode: title.code),
                    );
                  },
                ),

                // ── Distance ────────────────────────────────────────────────
                const SizedBox(height: 22),
                Text('DISTANCE', style: TrType.eyebrow),
                const SizedBox(height: 10),
                ChipRow(
                  children: [
                    for (final km in const [2.0, 5.0, 10.0, 25.0, 50.0])
                      TrFilterChip(
                        label: 'Within ${km.toStringAsFixed(0)} km',
                        selected: _draft.maxDistanceKm == km,
                        onTap: () => _set(
                          _draft.maxDistanceKm == km
                              ? _draft.copyWith(clearDistance: true)
                              : _draft.copyWith(maxDistanceKm: km),
                        ),
                      ),
                  ],
                ),

                // ── Experience ──────────────────────────────────────────────
                const SizedBox(height: 22),
                Text('EXPERIENCE', style: TrType.eyebrow),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final level in ExperienceLevel.values)
                      TrFilterChip(
                        label: level.label,
                        selected: _draft.experience == level,
                        onTap: () => _set(
                          _draft.experience == level
                              ? _draft.copyWith(clearExperience: true)
                              : _draft.copyWith(experience: level),
                        ),
                      ),
                  ],
                ),

                // ── Work mode ───────────────────────────────────────────────
                const SizedBox(height: 22),
                Text('WORK MODE', style: TrType.eyebrow),
                const SizedBox(height: 10),
                ChipRow(
                  children: [
                    for (final mode in WorkMode.values)
                      TrFilterChip(
                        label: mode.label,
                        selected: _draft.workMode == mode,
                        onTap: () => _set(
                          _draft.workMode == mode
                              ? _draft.copyWith(clearWorkMode: true)
                              : _draft.copyWith(workMode: mode),
                        ),
                      ),
                  ],
                ),

                // ── Job-only ────────────────────────────────────────────────
                if (_isJobs) ...[
                  const SizedBox(height: 22),
                  Text('THE ROLE ITSELF', style: TrType.eyebrow),
                  const SizedBox(height: 10),
                  ChipRow(
                    children: [
                      TrFilterChip(
                        label: 'Walk-in',
                        selected: _draft.walkIn,
                        onTap: () => _set(_draft.copyWith(walkIn: !_draft.walkIn)),
                      ),
                      TrFilterChip(
                        label: 'Remote',
                        selected: _draft.remote,
                        onTap: () => _set(_draft.copyWith(remote: !_draft.remote)),
                      ),
                      TrFilterChip(
                        label: 'Open to freshers',
                        selected: _draft.openToFreshers,
                        onTap: () => _set(_draft.copyWith(openToFreshers: !_draft.openToFreshers)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('OPENINGS', style: TrType.eyebrow),
                  const SizedBox(height: 10),
                  ChipRow(
                    children: [
                      for (final count in const [2, 5, 10])
                        TrFilterChip(
                          label: '$count or more',
                          selected: _draft.minOpenings == count,
                          onTap: () => _set(
                            _draft.minOpenings == count
                                ? _draft.copyWith(clearMinOpenings: true)
                                : _draft.copyWith(minOpenings: count),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('POSTED', style: TrType.eyebrow),
                  const SizedBox(height: 10),
                  ChipRow(
                    children: [
                      for (final (days, label) in const [
                        (1, 'Today'),
                        (7, 'This week'),
                        (30, 'This month'),
                      ])
                        TrFilterChip(
                          label: label,
                          selected: _draft.postedWithinDays == days,
                          onTap: () => _set(
                            _draft.postedWithinDays == days
                                ? _draft.copyWith(clearPostedWithin: true)
                                : _draft.copyWith(postedWithinDays: days),
                          ),
                        ),
                    ],
                  ),
                ],

                // ── Organisation-only ───────────────────────────────────────
                if (_isOrg) ...[
                  const SizedBox(height: 22),
                  Text('HIRING STATUS', style: TrType.eyebrow),
                  const SizedBox(height: 10),
                  ChipRow(
                    children: [
                      TrFilterChip(
                        label: 'Hiring now only',
                        selected: _draft.hiringNow,
                        onTap: () => _set(_draft.copyWith(hiringNow: !_draft.hiringNow)),
                      ),
                    ],
                  ),
                ],

                // ── Candidate-only ──────────────────────────────────────────
                if (_isPeople) ...[
                  const SizedBox(height: 22),
                  Text('AVAILABILITY', style: TrType.eyebrow),
                  const SizedBox(height: 10),
                  ChipRow(
                    children: [
                      TrFilterChip(
                        label: 'Available today',
                        selected: _draft.availableToday,
                        onTap: () => _set(_draft.copyWith(availableToday: !_draft.availableToday)),
                      ),
                      for (final status in const [
                        OpenToWork.activelyLooking,
                        OpenToWork.openToOpportunities,
                      ])
                        TrFilterChip(
                          label: status.label,
                          selected: _draft.openToWork == status,
                          onTap: () => _set(
                            _draft.openToWork == status
                                ? _draft.copyWith(clearOpenToWork: true)
                                : _draft.copyWith(openToWork: status),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('RECENTLY ACTIVE', style: TrType.eyebrow),
                  const SizedBox(height: 10),
                  ChipRow(
                    children: [
                      for (final (days, label) in const [
                        (7, 'Past week'),
                        (30, 'Past month'),
                      ])
                        TrFilterChip(
                          label: label,
                          selected: _draft.activeWithinDays == days,
                          onTap: () => _set(
                            _draft.activeWithinDays == days
                                ? _draft.copyWith(clearActiveWithin: true)
                                : _draft.copyWith(activeWithinDays: days),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('SKILL', style: TrType.eyebrow),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _skill,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(hintText: 'e.g. Flutter, Zendesk, SAP'),
                    onChanged: (value) => _draft = value.trim().isEmpty
                        ? _draft.copyWith(clearSkill: true)
                        : _draft.copyWith(skill: value.trim()),
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 14),
              child: PrimaryCta(
                label: 'Show results',
                onPressed: () => Navigator.of(context).pop(_draft),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Role filter that uses the job-title master, so it matches what postings and
/// profiles are actually tagged with rather than whatever the user types.
class _TitlePicker extends StatelessWidget {
  const _TitlePicker({required this.title, required this.hasCode, required this.onPicked});

  final JobTitle? title;

  /// True when a role is filtered on — the name may be unknown if the query
  /// arrived with a code already set.
  final bool hasCode;
  final ValueChanged<JobTitle?> onPicked;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showJobTitlePicker(
          context,
          selected: title == null ? const [] : [title!],
          maxSelection: 1,
          title: 'Role',
        );
        if (picked == null) return;
        onPicked(picked.isEmpty ? null : picked.first);
      },
      borderRadius: TrRadius.inputR,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        decoration: BoxDecoration(
          color: TrColors.card,
          borderRadius: TrRadius.inputR,
          border: Border.all(color: hasCode ? TrColors.plumInk : TrColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.work_outline_rounded, size: 18, color: TrColors.plumInk),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title?.name ?? (hasCode ? 'Role selected' : 'Any role'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TrType.bodySmall.copyWith(
                  color: hasCode ? TrColors.plumInk : TrColors.bodyMuted,
                  fontWeight: hasCode ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (hasCode)
              IconButton(
                tooltip: 'Clear role',
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () => onPicked(null),
              ),
          ],
        ),
      ),
    );
  }
}
