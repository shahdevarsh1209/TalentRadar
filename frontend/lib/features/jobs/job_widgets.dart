import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/tr_colors.dart';
import '../../core/theme/tr_theme.dart';
import '../../core/theme/tr_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/enums.dart';
import '../../data/models/job.dart';
import '../../state/home_providers.dart';
import '../../widgets/primary_cta.dart';
import '../../widgets/tr_components.dart';

// ── Actions shared by every place a job appears ───────────────────────────────

/// Saves or unsaves, then refreshes every list that shows the job.
Future<void> toggleSaveJob(BuildContext context, WidgetRef ref, Job job) async {
  try {
    await ref
        .read(socialRepositoryProvider)
        .setSaved(kind: 'job', refId: job.jobId, saved: !job.saved);
    ref.refreshHome();
    if (context.mounted) {
      showTrSnack(
        context,
        job.saved
            ? 'Removed from saved.'
            : (job.isWalkIn ? 'Saved. We will remind you 2 hours before the walk-in.' : 'Saved to your list.'),
      );
    }
  } catch (error) {
    if (context.mounted) showTrSnack(context, errorText(error));
  }
}

/// "I'm interested" / "Meet in person": records interest and opens the chat.
Future<void> expressInterest(BuildContext context, WidgetRef ref, Job job) async {
  try {
    final conversationId = await ref.read(jobsRepositoryProvider).expressInterest(job.jobId);
    ref.refreshHome();
    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      context.push(Routes.chat(conversationId));
    }
  } catch (error) {
    if (context.mounted) showTrSnack(context, errorText(error));
  }
}

void openJobDetails(BuildContext context, Job job) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: TrColors.canvas,
    builder: (_) => JobDetailSheet(jobId: job.jobId, preview: job),
  );
}

// ── Cards ────────────────────────────────────────────────────────────────────

String _meta(Job job) => [
      job.companyName,
      if (job.distanceKm != null) Fmt.distance(job.distanceKm) else if (job.location.area.isNotEmpty) job.location.area,
      Fmt.plural(job.openings, 'opening'),
    ].join(' · ');

List<Widget> _pills(Job job) => [
      if (job.walkInToday)
        const TrPill(label: 'Walk-in today', tone: PillTone.live)
      else if (job.isWalkIn && job.walkIn != null)
        TrPill(label: 'Walk-in ${Fmt.day(job.walkIn!.date)}', tone: PillTone.live),
      if (job.closingSoon && !job.walkInToday) const TrPill(label: 'Closing soon', tone: PillTone.alert),
      if (job.matchesProfile) const TrPill(label: 'Matches you', tone: PillTone.plum),
      TrPill(label: job.workMode == WorkMode.remote ? 'Remote' : job.workMode == WorkMode.hybrid ? 'Hybrid' : 'On-site'),
      TrPill(label: job.experienceLevel.label),
      if (Fmt.salary(job.salaryMin, job.salaryMax) != null) TrPill(label: Fmt.salary(job.salaryMin, job.salaryMax)!),
    ];

class _BookmarkButton extends ConsumerWidget {
  const _BookmarkButton({required this.job, this.onDark = false});

  final Job job;
  final bool onDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = onDark ? TrColors.lime : (job.saved ? TrColors.plumInk : TrColors.icon);
    return IconButton(
      tooltip: job.saved ? 'Remove from saved' : 'Save',
      onPressed: () => toggleSaveJob(context, ref, job),
      icon: Icon(job.saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: color),
    );
  }
}

/// Full job card from the "Nearby jobs" screen: tags plus Details / primary action.
class JobCard extends ConsumerWidget {
  const JobCard({super.key, required this.job, this.showActions = true});

  final Job job;
  final bool showActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      container: true,
      label: '${job.title.name} at ${job.companyName}',
      child: InkWell(
        onTap: () => openJobDetails(context, job),
        borderRadius: TrRadius.cardR,
        child: Container(
          padding: const EdgeInsets.fromLTRB(17, 15, 6, 17),
          decoration: BoxDecoration(
            color: TrColors.card,
            borderRadius: TrRadius.cardR,
            boxShadow: TrColors.cardShadow,
          ),
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
                        const SizedBox(height: 2),
                        Text(_meta(job), style: TrType.itemMeta, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  _BookmarkButton(job: job),
                ],
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(right: 11),
                child: Wrap(spacing: 7, runSpacing: 7, children: _pills(job)),
              ),
              if (showActions) ...[
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.only(right: 11),
                  child: Row(
                    children: [
                      Expanded(
                        child: _SmallButton(
                          label: 'Details',
                          outlined: true,
                          onTap: () => openJobDetails(context, job),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SmallButton(
                          label: job.interested
                              ? 'Open chat'
                              : (job.isWalkIn ? 'Meet in person' : "I'm interested"),
                          onTap: () => expressInterest(context, ref, job),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact row from the Search and Saved screens.
class JobRow extends ConsumerWidget {
  const JobRow({super.key, required this.job, this.highlighted = false});

  final Job job;

  /// Plum row with lime badge, used for today's walk-ins as in the design.
  final bool highlighted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitle = [
      job.companyName,
      if (job.distanceKm != null) Fmt.distance(job.distanceKm),
      if (job.walkInToday)
        'walk-in today'
      else if (job.isWalkIn && job.walkIn != null)
        'walk-in ${Fmt.day(job.walkIn!.date)} ${Fmt.clock(job.walkIn!.startTime)}'
      else if (Fmt.salary(job.salaryMin, job.salaryMax) != null)
        Fmt.salary(job.salaryMin, job.salaryMax)!
      else if (job.experienceLevel == ExperienceLevel.fresher)
        'fresher ok',
    ].join(' · ');

    return InkWell(
      onTap: () => openJobDetails(context, job),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(15, 12, 4, 12),
        decoration: BoxDecoration(
          color: highlighted ? TrColors.plumInk : TrColors.card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: highlighted ? null : TrColors.cardShadow,
        ),
        child: Row(
          children: [
            CompanyBadge(name: job.companyName, inverted: highlighted),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.title.name,
                    style: TrType.itemTitle.copyWith(
                      fontSize: 14.5,
                      color: highlighted ? Colors.white : TrColors.plumInk,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TrType.itemMeta.copyWith(
                      fontSize: 12,
                      color: highlighted ? Colors.white.withValues(alpha: 0.72) : TrColors.bodyMuted,
                    ),
                  ),
                ],
              ),
            ),
            _BookmarkButton(job: job, onDark: highlighted),
          ],
        ),
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({required this.label, required this.onTap, this.outlined = false});

  final String label;
  final VoidCallback onTap;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: outlined ? Colors.white : TrColors.plumInk,
      borderRadius: TrRadius.pillR,
      child: InkWell(
        onTap: onTap,
        borderRadius: TrRadius.pillR,
        child: Container(
          constraints: const BoxConstraints(minHeight: 46),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: TrRadius.pillR,
            border: outlined ? Border.all(color: TrColors.border) : null,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TrType.chip.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: outlined ? TrColors.plumInk : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Details sheet (the design's walk-in pin sheet) ───────────────────────────

class JobDetailSheet extends ConsumerStatefulWidget {
  const JobDetailSheet({super.key, required this.jobId, required this.preview});

  final String jobId;

  /// Shown immediately; replaced by the fresh copy once it loads.
  final Job preview;

  @override
  ConsumerState<JobDetailSheet> createState() => _JobDetailSheetState();
}

class _JobDetailSheetState extends ConsumerState<JobDetailSheet> {
  late Job _job = widget.preview;
  String _postedBy = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await ref.read(jobsRepositoryProvider).detail(widget.jobId);
      if (!mounted) return;
      setState(() {
        _job = result.job;
        _postedBy = [result.postedBy.name, result.postedBy.headline]
            .where((part) => part.isNotEmpty)
            .join(' · ');
      });
    } catch (_) {
      // The preview is already on screen; a failed refresh is not worth an error.
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    await toggleSaveJob(context, ref, _job);
    if (mounted) {
      setState(() {
        _job = _job.copyWith(saved: !_job.saved);
        _busy = false;
      });
    }
  }

  Future<void> _interested() async {
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    try {
      final conversationId = await ref.read(jobsRepositoryProvider).expressInterest(_job.jobId);
      ref.refreshHome();
      navigator.pop();
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        context.push(Routes.chat(conversationId));
      }
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        showTrSnack(context, errorText(error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = _job;
    final walkIn = job.walkIn;
    final salary = Fmt.salary(job.salaryMin, job.salaryMax);

    final rows = <(IconData, String)>[
      if (job.isWalkIn && walkIn != null)
        (
          Icons.calendar_today_rounded,
          '${Fmt.dayLong(walkIn.date)} · ${Fmt.clock(walkIn.startTime)} – ${Fmt.clock(walkIn.endTime)}',
        ),
      (
        Icons.place_outlined,
        job.isWalkIn && (walkIn?.address.isNotEmpty ?? false) ? walkIn!.address : job.location.display,
      ),
      (
        Icons.group_add_outlined,
        [
          Fmt.plural(job.openings, 'opening'),
          job.experienceLevel.label,
          if (job.isWalkIn) 'walk-in with resume',
        ].join(' · '),
      ),
      if (salary != null) (Icons.payments_outlined, '$salary per month'),
      (
        Icons.work_outline_rounded,
        switch (job.workMode) {
          WorkMode.remote => 'Remote — work from anywhere',
          WorkMode.hybrid => 'Hybrid — part office, part remote',
          WorkMode.onsite => 'On-site at the office',
        },
      ),
    ];

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) => Column(
        children: [
          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
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
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: job.isWalkIn && walkIn != null
                      ? TrPill(
                          label: 'Walk-in · ${Fmt.day(walkIn.date).toLowerCase()}',
                          tone: PillTone.alert,
                          icon: Icons.schedule_rounded,
                        )
                      : TrPill(
                          label: job.isOpen ? 'Hiring now' : 'Closed',
                          tone: job.isOpen ? PillTone.live : PillTone.neutral,
                        ),
                ),
                const SizedBox(height: 16),
                Text(job.title.name, style: TrType.sectionTitle.copyWith(fontSize: 22)),
                const SizedBox(height: 6),
                Text(
                  [
                    job.companyName,
                    if (job.location.area.isNotEmpty) job.location.area else if (job.location.city.isNotEmpty) job.location.city,
                    if (job.distanceKm != null) '${Fmt.distance(job.distanceKm)} away',
                  ].join(' · '),
                  style: TrType.bodySmall,
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: TrColors.card, borderRadius: BorderRadius.circular(20)),
                  child: Column(
                    children: [
                      for (var i = 0; i < rows.length; i++) ...[
                        if (i > 0) const SizedBox(height: 13),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(rows[i].$1, size: 17, color: TrColors.icon),
                            const SizedBox(width: 11),
                            Expanded(child: Text(rows[i].$2, style: TrType.bodySmall.copyWith(color: TrColors.plumInk))),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (job.description.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text('ABOUT THE ROLE', style: TrType.eyebrow),
                  const SizedBox(height: 8),
                  Text(job.description, style: TrType.bodySmall.copyWith(color: TrColors.plumInk, height: 1.55)),
                ],
                if (_postedBy.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text('POSTED BY', style: TrType.eyebrow),
                  const SizedBox(height: 8),
                  Text(_postedBy, style: TrType.bodySmall.copyWith(color: TrColors.plumInk)),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Row(
                children: [
                  Expanded(
                    child: PrimaryCta(
                      label: job.saved ? 'Saved' : 'Save',
                      icon: job.saved ? Icons.bookmark_rounded : null,
                      variant: CtaVariant.outline,
                      enabled: !_busy,
                      onPressed: _save,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PrimaryCta(
                      label: job.interested ? 'Open chat' : "I'm interested",
                      isLoading: _busy,
                      enabled: job.isOpen,
                      onPressed: _interested,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
