import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/tr_colors.dart';
import '../../core/theme/tr_theme.dart';
import '../../core/theme/tr_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/people.dart';
import '../../state/home_providers.dart';
import '../../widgets/primary_cta.dart';
import '../../widgets/tr_components.dart';
import 'hiring_widgets.dart';

// ── Actions ──────────────────────────────────────────────────────────────────

/// Opens (or creates) the conversation and goes to it. With [invite], the chat
/// opens straight onto the interview-invite composer.
Future<void> messagePerson(
  BuildContext context,
  WidgetRef ref,
  String userId, {
  bool invite = false,
}) async {
  try {
    final conversation = await ref.read(socialRepositoryProvider).startConversation(userId);
    ref.invalidate(conversationsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      context.push(Routes.chat(conversation.conversationId) + (invite ? '?compose=invite' : ''));
    }
  } catch (error) {
    if (context.mounted) showTrSnack(context, errorText(error));
  }
}

Future<void> toggleSavePerson(BuildContext context, WidgetRef ref, String userId, bool saved) async {
  try {
    await ref.read(socialRepositoryProvider).setSaved(kind: 'person', refId: userId, saved: !saved);
    ref.refreshHome();
    if (context.mounted) showTrSnack(context, saved ? 'Removed from saved.' : 'Saved to your list.');
  } catch (error) {
    if (context.mounted) showTrSnack(context, errorText(error));
  }
}

void openQuickProfile(BuildContext context, String userId) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: TrColors.canvas,
    builder: (_) => QuickProfileSheet(userId: userId),
  );
}

// ── Recruiter's candidate card ───────────────────────────────────────────────

class CandidateCardView extends ConsumerWidget {
  const CandidateCardView({super.key, required this.candidate});

  final CandidateCard candidate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meta = [
      if (candidate.headline.isNotEmpty) candidate.headline,
      candidate.experienceLevel.label,
      if (candidate.distanceKm != null) Fmt.distance(candidate.distanceKm) else if (candidate.area.isNotEmpty) candidate.area,
    ].join(' · ');

    return InkWell(
      onTap: () => openQuickProfile(context, candidate.userId),
      borderRadius: TrRadius.cardR,
      child: Container(
        padding: const EdgeInsets.all(16),
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
                TrAvatar(initials: candidate.initials, seed: candidate.name, live: candidate.availableToday),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(candidate.name, style: TrType.itemTitle),
                      const SizedBox(height: 2),
                      Text(meta, style: TrType.itemMeta, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
            if (candidate.availableToday || candidate.matchesHiring) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  if (candidate.availableToday) const TrPill(label: 'Available today', tone: PillTone.live),
                  if (candidate.matchesHiring) const TrPill(label: 'Matches your roles', tone: PillTone.plum),
                ],
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: PrimaryCta(
                    label: 'Message',
                    variant: CtaVariant.outline,
                    onPressed: () => messagePerson(context, ref, candidate.userId),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PrimaryCta(
                    label: 'Invite',
                    onPressed: () => messagePerson(context, ref, candidate.userId, invite: true),
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

// ── Quick profile sheet ──────────────────────────────────────────────────────

final _candidateDetailProvider =
    FutureProvider.autoDispose.family<CandidateDetail, String>((ref, userId) {
  return ref.watch(peopleRepositoryProvider).candidate(userId);
});

class QuickProfileSheet extends ConsumerStatefulWidget {
  const QuickProfileSheet({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<QuickProfileSheet> createState() => _QuickProfileSheetState();
}

class _QuickProfileSheetState extends ConsumerState<QuickProfileSheet> {
  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(_candidateDetailProvider(widget.userId));

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
        child: AsyncSection<CandidateDetail>(
          value: detail,
          onRetry: () => ref.invalidate(_candidateDetailProvider(widget.userId)),
          loading: const Padding(
            padding: EdgeInsets.all(60),
            child: Center(child: CircularProgressIndicator(color: TrColors.plumInk)),
          ),
          builder: (data) => _content(data),
        ),
      ),
    );
  }

  Widget _content(CandidateDetail data) {
    final card = data.card;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(color: TrColors.borderStrong, borderRadius: BorderRadius.circular(2)),
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            TrAvatar(
              initials: card.initials,
              seed: card.name,
              size: 62,
              live: card.availableToday,
              ringColor: TrColors.canvas,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(card.name, style: TrType.sectionTitle),
                  Text(card.headline, style: TrType.bodySmall),
                ],
              ),
            ),
            IconButton(
              tooltip: card.saved ? 'Remove from saved' : 'Save',
              onPressed: () async {
                await toggleSavePerson(context, ref, card.userId, card.saved);
                ref.invalidate(_candidateDetailProvider(widget.userId));
              },
              icon: Icon(
                card.saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                color: card.saved ? TrColors.plumInk : TrColors.icon,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            TrPill(label: card.openToWork.label, tone: PillTone.live),
            if (card.availableToday) const TrPill(label: 'Available today'),
            if (card.matchesHiring) const TrPill(label: 'Matches your roles', tone: PillTone.plum),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            _Stat(value: card.experienceLevel.short, label: 'years exp'),
            const SizedBox(width: 10),
            _Stat(value: card.distanceKm == null ? '—' : card.distanceKm!.toStringAsFixed(1), label: 'km away'),
            const SizedBox(width: 10),
            _Stat(value: '${card.jobTitleNames.length}', label: 'roles open to'),
          ],
        ),
        if (card.jobTitleNames.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('OPEN TO', style: TrType.eyebrow),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [for (final title in card.jobTitleNames) _SkillChip(title)]),
        ],
        if (data.skills.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('SKILLS', style: TrType.eyebrow),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [for (final skill in data.skills) _SkillChip(skill)]),
        ],
        if (card.area.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.shield_outlined, size: 15, color: TrColors.icon),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Around ${card.area} — exact location is never shared.',
                  style: TrType.itemMeta.copyWith(fontSize: 11.5),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: PrimaryCta(
                label: 'Message',
                variant: CtaVariant.outline,
                enabled: data.canMessage,
                onPressed: () {
                  Navigator.of(context).pop();
                  messagePerson(context, ref, card.userId);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              // The same control as the recruiter profile and search results,
              // so a connection reads identically wherever it is shown.
              child: ConnectionAction(
                userId: card.userId,
                name: card.name,
                status: data.connectionStatus,
                connectionId: data.connectionId,
                enabled: data.openToConnect,
                onChanged: () => ref.invalidate(_candidateDetailProvider(widget.userId)),
              ),
            ),
          ],
        ),
        if (!data.canMessage)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'This candidate is not taking messages right now — send a connection request instead.',
              style: TrType.itemMeta.copyWith(fontSize: 11.5),
            ),
          ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(color: TrColors.card, borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Text(value, style: TrType.stat, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text(label, style: TrType.itemMeta.copyWith(fontSize: 11), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _SkillChip extends StatelessWidget {
  const _SkillChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: TrColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TrColors.border),
      ),
      child: Text(label, style: TrType.chip),
    );
  }
}

/// Row for a person in Saved, Requests and interest lists.
class PersonRow extends StatelessWidget {
  const PersonRow({
    super.key,
    required this.person,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final PersonSummary person;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: TrColors.card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: TrColors.cardShadow,
        ),
        child: Row(
          children: [
            TrAvatar(initials: person.initials, seed: person.name, size: 42, live: person.availableToday),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(person.name, style: TrType.itemTitle.copyWith(fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(
                    subtitle ?? person.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TrType.itemMeta.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}
