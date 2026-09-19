import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/tr_colors.dart';
import '../../core/theme/tr_theme.dart';
import '../../core/theme/tr_typography.dart';
import '../../data/models/session.dart';
import '../../state/session_controller.dart';
import 'radar_preview_data.dart';

/// Home for both roles. Candidates see openings near their area; recruiters see
/// talent near their company hiring location. Neither view ever shows an exact
/// point — the map is area-level by construction.
class RadarScreen extends ConsumerStatefulWidget {
  const RadarScreen({super.key});

  @override
  ConsumerState<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends ConsumerState<RadarScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    if (session == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final body = switch (_tab) {
      0 => session.isCandidate
          ? _CandidateRadar(session: session)
          : _RecruiterRadar(session: session),
      3 => _MeTab(session: session),
      _ => _ComingSoon(tab: _tab, isCandidate: session.isCandidate),
    };

    return Scaffold(
      backgroundColor: TrColors.canvas,
      body: SafeArea(bottom: false, child: body),
      bottomNavigationBar: _BottomNav(
        index: _tab,
        isCandidate: session.isCandidate,
        onSelect: (index) => setState(() => _tab = index),
      ),
    );
  }
}

// ── Candidate ─────────────────────────────────────────────────────────────────

class _CandidateRadar extends StatelessWidget {
  const _CandidateRadar({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final profile = session.candidate!;
    final area = profile.location.isSet ? profile.location.display : 'Set your area';

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
      children: [
        _Header(
          eyebrow: '$area · 5 km radius',
          title: 'Near you today',
          initials: profile.initials,
          seed: profile.name,
          live: !profile.stealthMode,
        ),
        const SizedBox(height: 16),
        const _SearchBar(hint: 'Roles, skills, companies'),
        const SizedBox(height: 16),
        if (profile.stealthMode) ...[
          const _Banner(
            icon: Icons.shield_outlined,
            text: 'Ninja mode is on — recruiters will not see you in their radar.',
          ),
          const SizedBox(height: 14),
        ],
        if (!profile.location.isSet) ...[
          _Banner(
            icon: Icons.place_outlined,
            text: 'Add your area to see what is actually near you.',
            actionLabel: 'Set area',
            onAction: () => context.push(Routes.candidateLocation),
          ),
          const SizedBox(height: 14),
        ],
        const _MapPanel(
          caption: 'MAP — APPROXIMATE LOCATIONS ONLY',
          liveLabel: '12 live now',
          showsPeople: false,
        ),
        const SizedBox(height: 18),
        const _SectionHeader(title: 'Open near you'),
        const SizedBox(height: 12),
        for (final opening in RadarPreviewData.openings) ...[
          _OpeningCard(opening: opening),
          const SizedBox(height: 12),
        ],
        _PlumRow(
          title: 'Matched to your titles',
          subtitle: profile.jobTitles.map((title) => title.name).join(' · '),
        ),
      ],
    );
  }
}

// ── Recruiter ─────────────────────────────────────────────────────────────────

class _RecruiterRadar extends StatelessWidget {
  const _RecruiterRadar({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final profile = session.recruiter!;
    final hiringFor =
        profile.hiringProfiles.isEmpty ? 'your roles' : profile.hiringProfiles.first.name;
    final location = profile.primaryHiringLocation;

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
      children: [
        _Header(
          eyebrow: 'Hiring for ${profile.companyName} · $hiringFor',
          title: 'Talent near you',
          initials: profile.initials,
          seed: profile.hrName,
        ),
        const SizedBox(height: 16),
        const _SearchBar(hint: 'Skills, title, experience'),
        const SizedBox(height: 16),
        if (location == null) ...[
          _Banner(
            icon: Icons.apartment_rounded,
            text: 'Set your company hiring location to search candidates around it.',
            actionLabel: 'Set location',
            onAction: () => context.push(Routes.hiringLocation),
          ),
          const SizedBox(height: 14),
        ],
        const _MapPanel(
          caption: 'MAP — AREA LEVEL, NO EXACT PINS',
          liveLabel: '17 available today',
          showsPeople: true,
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(label: 'Within ${profile.hiringRadiusKm.toInt()} km', active: true),
              for (final mode in profile.hiringWorkModes) _FilterChip(label: mode.label),
              for (final title in profile.hiringProfiles.take(3)) _FilterChip(label: title.name),
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (final candidate in RadarPreviewData.candidates) ...[
          _CandidateCard(candidate: candidate),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

// ── Shared pieces ─────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.eyebrow,
    required this.title,
    required this.initials,
    required this.seed,
    this.live = false,
  });

  final String eyebrow;
  final String title;
  final String initials;
  final String seed;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = TrColors.tintFor(seed);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(eyebrow, style: TrType.itemMeta, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(title, style: TrType.screenTitle.copyWith(fontSize: 25)),
            ],
          ),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: background,
              child: Text(initials, style: TrType.tag.copyWith(color: foreground, fontSize: 13)),
            ),
            if (live)
              Positioned(
                right: -1,
                bottom: -1,
                child: Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: TrColors.lime,
                    shape: BoxShape.circle,
                    border: Border.all(color: TrColors.canvas, width: 2.5),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.hint});

  final String hint;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: TrColors.card,
              borderRadius: TrRadius.pillR,
              border: Border.all(color: TrColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, size: 17, color: TrColors.icon),
                const SizedBox(width: 9),
                Text(hint, style: TrType.bodySmall.copyWith(color: TrColors.icon)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 9),
        Container(
          width: 46,
          height: 46,
          decoration: const BoxDecoration(color: TrColors.plumInk, shape: BoxShape.circle),
          child: const Icon(Icons.tune_rounded, size: 19, color: Colors.white),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text, this.actionLabel, this.onAction});

  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 12, 8, 12),
      decoration: BoxDecoration(
        color: TrColors.plumSurface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: TrColors.plumInk),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TrType.itemMeta.copyWith(color: TrColors.plumInk, height: 1.4)),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel!, style: TrType.chip.copyWith(color: TrColors.plumInk)),
            ),
        ],
      ),
    );
  }
}

class _MapPanel extends StatelessWidget {
  const _MapPanel({required this.caption, required this.liveLabel, required this.showsPeople});

  final String caption;
  final String liveLabel;
  final bool showsPeople;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: TrRadius.largeCardR,
      child: SizedBox(
        height: 240,
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _MapPainter(showsPeople: showsPeople))),
            Positioned(
              top: 14,
              left: 18,
              child: Text(
                caption,
                style: TrType.tag.copyWith(color: TrColors.bodyMuted, fontSize: 10.5, letterSpacing: 0.5),
              ),
            ),
            Positioned(
              bottom: 14,
              left: 18,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: TrRadius.pillR,
                  boxShadow: TrColors.raisedShadow,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(color: TrColors.lime, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 7),
                    Text(liveLabel, style: TrType.tag.copyWith(fontSize: 12)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hatched "map" with area-level markers. Positions are fixed fractions, not
/// coordinates — there is nothing on this canvas that could locate a person.
class _MapPainter extends CustomPainter {
  const _MapPainter({required this.showsPeople});

  final bool showsPeople;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = TrColors.pageCanvas);

    final stripe = Paint()
      ..color = const Color(0xFFE9E2DC)
      ..strokeWidth = 7;
    for (double x = -size.height; x < size.width; x += 20) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), stripe);
    }

    // The viewer, with their privacy radius drawn as a soft halo.
    final me = Offset(size.width * 0.3, size.height * 0.72);
    canvas.drawCircle(me, 30, Paint()..color = TrColors.lime.withValues(alpha: 0.22));
    canvas.drawCircle(me, 10, Paint()..color = Colors.white);
    canvas.drawCircle(me, 7, Paint()..color = TrColors.lime);

    const markers = [(0.22, 0.34), (0.6, 0.22), (0.66, 0.58)];
    for (var i = 0; i < markers.length; i++) {
      final (fx, fy) = markers[i];
      final center = Offset(size.width * fx, size.height * fy);
      final paint = Paint()
        ..color = i == 2 && !showsPeople ? TrColors.clay : TrColors.plumInk;

      if (showsPeople) {
        canvas.drawCircle(center, 22, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: center, width: 44, height: 44),
              const Radius.circular(15)),
          paint,
        );
      }
      canvas.drawCircle(
        center,
        5,
        Paint()..color = TrColors.lime,
      );
    }
  }

  @override
  bool shouldRepaint(_MapPainter oldDelegate) => oldDelegate.showsPeople != showsPeople;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: TrType.cardTitle.copyWith(fontSize: 16)),
        const Spacer(),
        Text('See all', style: TrType.label),
      ],
    );
  }
}

class _OpeningCard extends StatelessWidget {
  const _OpeningCard({required this.opening});

  final NearbyOpening opening;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = TrColors.tintFor(opening.company);
    return Container(
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
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(14)),
                alignment: Alignment.center,
                child: Text(opening.companyCode, style: TrType.tag.copyWith(color: foreground, fontSize: 12)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(opening.title, style: TrType.itemTitle),
                    Text(
                      '${opening.company} · ${opening.distanceKm} km · ${opening.openings} opening${opening.openings == 1 ? '' : 's'}',
                      style: TrType.itemMeta,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.bookmark_border_rounded, color: TrColors.icon),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              if (opening.isWalkIn) const _Pill(label: 'Walk-in today', live: true),
              for (final tag in opening.tags) _Pill(label: tag),
            ],
          ),
        ],
      ),
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({required this.candidate});

  final NearbyCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = TrColors.tintFor(candidate.name);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TrColors.card,
        borderRadius: TrRadius.cardR,
        boxShadow: TrColors.cardShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 23,
                    backgroundColor: background,
                    child: Text(candidate.initials, style: TrType.tag.copyWith(color: foreground, fontSize: 13)),
                  ),
                  if (candidate.availableToday)
                    Positioned(
                      right: -1,
                      bottom: -1,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          color: TrColors.lime,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(candidate.name, style: TrType.itemTitle),
                    Text(
                      '${candidate.title} · ${candidate.years} · ${candidate.distanceKm} km',
                      style: TrType.itemMeta,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    foregroundColor: TrColors.plumInk,
                    side: const BorderSide(color: TrColors.border),
                    shape: RoundedRectangleBorder(borderRadius: TrRadius.pillR),
                    minimumSize: const Size(0, 46),
                  ),
                  child: Text('Message', style: TrType.chip),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () {},
                  style: FilledButton.styleFrom(
                    backgroundColor: TrColors.plumInk,
                    shape: RoundedRectangleBorder(borderRadius: TrRadius.pillR),
                    minimumSize: const Size(0, 46),
                  ),
                  child: Text('Invite', style: TrType.chip.copyWith(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, this.live = false});

  final String label;
  final bool live;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: live ? TrColors.limeSurface : TrColors.canvas,
        borderRadius: TrRadius.pillR,
      ),
      child: Text(label, style: TrType.tag.copyWith(color: live ? TrColors.limeText : TrColors.bodyMuted)),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, this.active = false});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 7),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: active ? TrColors.plumInk : TrColors.card,
        borderRadius: TrRadius.pillR,
        border: active ? null : Border.all(color: TrColors.border),
      ),
      child: Text(
        label,
        style: TrType.tag.copyWith(
          color: active ? Colors.white : TrColors.bodyMuted,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PlumRow extends StatelessWidget {
  const _PlumRow({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: TrColors.plumInk, borderRadius: TrRadius.cardR),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TrType.itemTitle.copyWith(color: Colors.white, fontSize: 14)),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TrType.itemMeta.copyWith(color: Colors.white.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: TrColors.lime),
        ],
      ),
    );
  }
}

class _MeTab extends ConsumerWidget {
  const _MeTab({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final candidate = session.candidate;
    final recruiter = session.recruiter;

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
      children: [
        Text('Me', style: TrType.screenTitle),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: TrColors.card,
            borderRadius: TrRadius.cardR,
            boxShadow: TrColors.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(session.displayName, style: TrType.cardTitle),
              const SizedBox(height: 4),
              Text(session.user.email, style: TrType.itemMeta),
              const SizedBox(height: 14),
              if (candidate != null) ...[
                _MeRow('Visibility', candidate.profileVisibility.label),
                _MeRow('Open to work', candidate.openToWork.label),
                _MeRow('Ninja mode', candidate.stealthMode ? 'On' : 'Off'),
                _MeRow('Area', candidate.location.isSet ? candidate.location.display : 'Not set'),
              ],
              if (recruiter != null) ...[
                _MeRow('Company', recruiter.companyName),
                _MeRow('Hiring for', '${recruiter.hiringProfiles.length} roles'),
                _MeRow(
                  'Hiring location',
                  recruiter.primaryHiringLocation?.display ?? 'Not set',
                ),
              ],
              _MeRow('Email verified', session.user.isEmailVerified ? 'Yes' : 'Pending'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () async {
            await ref.read(sessionProvider.notifier).signOut();
            if (context.mounted) context.go(Routes.welcome);
          },
          icon: const Icon(Icons.logout_rounded, size: 18),
          label: Text('Log out', style: TrType.chip),
          style: OutlinedButton.styleFrom(
            foregroundColor: TrColors.clayText,
            side: const BorderSide(color: TrColors.border),
            shape: RoundedRectangleBorder(borderRadius: TrRadius.pillR),
            minimumSize: const Size.fromHeight(50),
          ),
        ),
      ],
    );
  }
}

class _MeRow extends StatelessWidget {
  const _MeRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, style: TrType.itemMeta)),
          Expanded(child: Text(value, style: TrType.bodySmall.copyWith(color: TrColors.plumInk))),
        ],
      ),
    );
  }
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon({required this.tab, required this.isCandidate});

  final int tab;
  final bool isCandidate;

  @override
  Widget build(BuildContext context) {
    final title = switch (tab) {
      1 => isCandidate ? 'Jobs' : 'Roles',
      _ => 'Chats',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: TrType.sectionTitle),
            const SizedBox(height: 8),
            Text(
              'This section is part of the next release.',
              style: TrType.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.isCandidate, required this.onSelect});

  final int index;
  final bool isCandidate;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.radar_rounded, 'Radar'),
      (Icons.work_outline_rounded, isCandidate ? 'Jobs' : 'Roles'),
      (Icons.chat_bubble_outline_rounded, 'Chats'),
      (Icons.person_outline_rounded, 'Me'),
    ];

    Widget item(int i) {
      final (icon, label) = items[i];
      final active = index == i;
      return Expanded(
        child: InkWell(
          onTap: () => onSelect(i),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 22, color: active ? TrColors.plumInk : TrColors.icon),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TrType.navLabel.copyWith(
                    color: active ? TrColors.plumInk : TrColors.icon,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: TrColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              item(0),
              item(1),
              // Centre action: "go live" for candidates, "post a role" for HR.
              Transform.translate(
                offset: const Offset(0, -14),
                child: Container(
                  width: 56,
                  height: 56,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: TrColors.lime,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: TrColors.lime.withValues(alpha: 0.5),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    isCandidate ? Icons.sensors_rounded : Icons.add_rounded,
                    color: TrColors.plumInk,
                    size: 26,
                  ),
                ),
              ),
              item(2),
              item(3),
            ],
          ),
        ),
      ),
    );
  }
}
