import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/tr_colors.dart';
import '../../core/theme/tr_theme.dart';
import '../../core/theme/tr_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/enums.dart';
import '../../data/models/hiring.dart';
import '../../data/models/people.dart';
import '../../state/home_providers.dart';
import '../../widgets/primary_cta.dart';
import '../../widgets/tr_components.dart';
import '../jobs/job_widgets.dart';
import 'people_widgets.dart';

// ── Navigation ───────────────────────────────────────────────────────────────

/// The one way a recruiter is opened, from chat, search, saved, radar or a job.
void openRecruiterProfile(BuildContext context, String userId) =>
    context.push(Routes.recruiter(userId));

void openCompanyProfile(BuildContext context, String companyId) =>
    context.push(Routes.companyProfile(companyId));

/// Opens whichever profile suits the person — so a caller with a mixed list
/// never has to branch on role itself.
void openPersonProfile(BuildContext context, PersonSummary person) {
  if (person.role == UserRole.recruiter) {
    openRecruiterProfile(context, person.userId);
  } else {
    openQuickProfile(context, person.userId);
  }
}

// ── Hiring status ────────────────────────────────────────────────────────────

/// 🟢 Hiring Now / ⚪ Not currently hiring.
///
/// Reads a value the server derived from open jobs; nothing here decides the
/// status, so it cannot disagree with another screen.
class HiringPill extends StatelessWidget {
  const HiringPill({super.key, required this.hiringNow, this.openings = 0, this.compact = false});

  final bool hiringNow;
  final int openings;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!hiringNow) {
      return const TrPill(label: 'Not currently hiring', tone: PillTone.neutral);
    }
    final suffix = compact || openings <= 0 ? '' : ' · ${Fmt.plural(openings, 'opening')}';
    return TrPill(label: 'Hiring now$suffix', tone: PillTone.live);
  }
}

/// Pin icon plus an area name, sized to fit.
///
/// A plain Row here overflows inside a Wrap, because a Wrap hands its child the
/// full width and a Row will not shrink its Text — hence the Flexible.
class AreaLabel extends StatelessWidget {
  const AreaLabel({super.key, required this.area});

  final String area;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.place_outlined, size: 14, color: TrColors.icon),
        const SizedBox(width: 4),
        Flexible(
          child: Text(area, style: TrType.itemMeta, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

/// A single role on a recruiter or company profile. Live roles open the posting.
class HiringRoleTile extends StatelessWidget {
  const HiringRoleTile({super.key, required this.role, this.companyName = ''});

  final HiringRole role;
  final String companyName;

  @override
  Widget build(BuildContext context) {
    final open = role.hiringNow && role.jobId != null;
    return InkWell(
      onTap: open ? () => openJobDetailsById(context, role.jobId!) : null,
      borderRadius: BorderRadius.circular(16),
      child: Opacity(
        opacity: role.hiringNow ? 1 : 0.62,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: TrColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: role.hiringNow ? TrColors.lime : TrColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(role.name, style: TrType.itemTitle.copyWith(fontSize: 14)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 7,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        HiringPill(hiringNow: role.hiringNow, compact: true),
                        if (role.hiringNow && role.openings > 0)
                          Text(role.openingsLabel, style: TrType.itemMeta.copyWith(fontSize: 11.5)),
                        if (role.isWalkIn) const TrPill(label: 'Walk-in', tone: PillTone.plum),
                        if (role.area.isNotEmpty)
                          Text(role.area, style: TrType.itemMeta.copyWith(fontSize: 11.5)),
                      ],
                    ),
                  ],
                ),
              ),
              if (open) const Icon(Icons.chevron_right_rounded, color: TrColors.icon),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Connection ───────────────────────────────────────────────────────────────

/// The connection control, used on every screen that offers one so that a
/// person's state reads the same in search, on a profile, and in chat.
class ConnectionAction extends ConsumerStatefulWidget {
  const ConnectionAction({
    super.key,
    required this.userId,
    required this.name,
    required this.status,
    this.connectionId,
    this.enabled = true,
    this.variant = CtaVariant.plum,
    this.onChanged,
  });

  final String userId;
  final String name;
  final ConnectionStatus status;
  final String? connectionId;
  final bool enabled;
  final CtaVariant variant;
  final VoidCallback? onChanged;

  @override
  ConsumerState<ConnectionAction> createState() => _ConnectionActionState();
}

class _ConnectionActionState extends ConsumerState<ConnectionAction> {
  bool _busy = false;

  /// Connected is the end state: the useful action then is to talk to them.
  Future<void> _act() async {
    switch (widget.status) {
      case ConnectionStatus.connected:
        await messagePerson(context, ref, widget.userId);
      case ConnectionStatus.pendingReceived:
        await _respond('accept');
      case ConnectionStatus.pendingSent:
        break; // Waiting on them; nothing to do.
      case ConnectionStatus.none:
        await _request();
    }
  }

  Future<void> _request() async {
    final note = await askForConnectionNote(context, widget.name.split(' ').first);
    if (note == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(socialRepositoryProvider)
          .requestConnection(widget.userId, message: note);
      widget.onChanged?.call();
      ref.invalidate(connectionsProvider);
      if (mounted) {
        showTrSnack(
          context,
          result.status == ConnectionStatus.connected
              ? 'You are now connected.'
              : 'Request sent. We will let you know when they accept.',
        );
      }
    } catch (error) {
      if (mounted) showTrSnack(context, errorText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _respond(String action) async {
    if (widget.connectionId == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(socialRepositoryProvider).respondToConnection(widget.connectionId!, accept: action == 'accept');
      widget.onChanged?.call();
      ref.refreshHome();
      if (mounted) showTrSnack(context, 'You are now connected.');
    } catch (error) {
      if (mounted) showTrSnack(context, errorText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = switch (widget.status) {
      ConnectionStatus.connected => 'Message',
      ConnectionStatus.pendingSent => 'Request sent',
      ConnectionStatus.pendingReceived => 'Accept request',
      ConnectionStatus.none => 'Connect',
    };
    return PrimaryCta(
      label: label,
      isLoading: _busy,
      // A sent request is shown, not offered again.
      enabled: widget.enabled && widget.status != ConnectionStatus.pendingSent,
      variant: widget.variant,
      onPressed: _act,
    );
  }
}

/// Shared note dialog, so a request reads the same wherever it is sent from.
Future<String?> askForConnectionNote(BuildContext context, String firstName) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: TrColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text('Connect with $firstName', style: TrType.cardTitle),
      content: TextField(
        controller: controller,
        maxLines: 3,
        maxLength: 300,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Add a short note (optional)'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text('Cancel', style: TrType.chip.copyWith(color: TrColors.bodyMuted)),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(controller.text),
          child: Text('Send request', style: TrType.chip),
        ),
      ],
    ),
  );
}

// ── Cards ────────────────────────────────────────────────────────────────────

/// A recruiter in a search result or a list: who they are, what they have open,
/// and the two things you can do about it. Never a dead end.
class RecruiterCardView extends ConsumerWidget {
  const RecruiterCardView({super.key, required this.recruiter, this.onChanged});

  final RecruiterCard recruiter;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => openRecruiterProfile(context, recruiter.userId),
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
                TrAvatar(initials: recruiter.initials, seed: recruiter.name),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(recruiter.name, style: TrType.itemTitle),
                      const SizedBox(height: 2),
                      Text(
                        [recruiter.designation, recruiter.companyName]
                            .where((part) => part.isNotEmpty)
                            .join(' · '),
                        style: TrType.itemMeta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                HiringPill(hiringNow: recruiter.hiringNow, openings: recruiter.totalOpenings),
                if (recruiter.distanceKm != null)
                  Text(Fmt.distance(recruiter.distanceKm), style: TrType.itemMeta)
                else if (recruiter.area.isNotEmpty)
                  Text(recruiter.area, style: TrType.itemMeta),
              ],
            ),
            if (recruiter.openRoles.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('HIRING FOR', style: TrType.eyebrow),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final role in recruiter.openRoles)
                    RoleChip(
                      role: role,
                      onTap: role.jobId == null
                          ? null
                          : () => openJobDetailsById(context, role.jobId!),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: PrimaryCta(
                    label: 'View HR',
                    variant: CtaVariant.outline,
                    onPressed: () => openRecruiterProfile(context, recruiter.userId),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ConnectionAction(
                    userId: recruiter.userId,
                    name: recruiter.name,
                    status: recruiter.connectionStatus,
                    onChanged: onChanged,
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

/// A company in a search result: what they are hiring for, and how many seats.
class CompanyCardView extends StatelessWidget {
  const CompanyCardView({super.key, required this.company});

  final CompanyCard company;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => openCompanyProfile(context, company.companyId),
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
                CompanyBadge(name: company.name),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(company.name, style: TrType.itemTitle),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (company.industry.isNotEmpty) company.industry,
                          if (company.area.isNotEmpty) company.area,
                        ].join(' · '),
                        style: TrType.itemMeta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: TrColors.icon),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                HiringPill(hiringNow: company.hiringNow, openings: company.totalOpenings),
                if (company.distanceKm != null)
                  Text(Fmt.distance(company.distanceKm), style: TrType.itemMeta),
              ],
            ),
            if (company.openRoles.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final role in company.openRoles)
                    RoleChip(
                      role: role,
                      onTap: role.jobId == null
                          ? null
                          : () => openJobDetailsById(context, role.jobId!),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A live role as a tappable chip: "Flutter Developer · 3".
class RoleChip extends StatelessWidget {
  const RoleChip({super.key, required this.role, this.onTap});

  final HiringRole role;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: TrColors.limeSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: TrColors.lime),
        ),
        child: Text(
          role.openings > 1 ? '${role.name} · ${role.openings}' : role.name,
          style: TrType.chip.copyWith(color: TrColors.limeText),
        ),
      ),
    );
  }
}
