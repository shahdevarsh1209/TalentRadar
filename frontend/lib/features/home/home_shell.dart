import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/tr_colors.dart';
import '../../core/theme/tr_typography.dart';
import '../../state/home_providers.dart';
import '../../state/session_controller.dart';
import '../chat/chats_tab.dart';
import '../jobs/jobs_tab.dart';
import '../live/go_live_sheet.dart';
import '../profile/me_tab.dart';
import '../radar/candidate_radar_tab.dart';
import '../radar/recruiter_radar_tab.dart';
import '../roles/roles_tab.dart';

/// Home for both roles: Radar, Jobs (or Roles), the centre action, Chats, Me.
///
/// The centre button does the one thing each role comes back for — a candidate
/// goes live as available today; a recruiter posts a role or walk-in.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _tab = 0;

  void _select(int index) => setState(() => _tab = index);

  void _centreAction(bool isCandidate) {
    if (isCandidate) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: TrColors.canvas,
        builder: (_) => const GoLiveSheet(),
      );
    } else {
      context.push(Routes.postJob);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    if (session == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final isCandidate = session.isCandidate;
    final badges = ref.watch(badgesProvider).valueOrNull;

    final tabs = <Widget>[
      isCandidate ? CandidateRadarTab(onOpenTab: _select) : RecruiterRadarTab(onOpenTab: _select),
      isCandidate ? const JobsTab() : const RolesTab(),
      const ChatsTab(),
      const MeTab(),
    ];

    return Scaffold(
      backgroundColor: TrColors.canvas,
      body: SafeArea(
        bottom: false,
        // Keeps each tab's scroll position and loaded data when switching.
        child: IndexedStack(index: _tab, children: tabs),
      ),
      bottomNavigationBar: _BottomNav(
        index: _tab,
        isCandidate: isCandidate,
        isLive: session.candidate?.availableToday ?? false,
        chatBadge: badges?.chatsTab ?? 0,
        onSelect: _select,
        onCentre: () => _centreAction(isCandidate),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.index,
    required this.isCandidate,
    required this.isLive,
    required this.chatBadge,
    required this.onSelect,
    required this.onCentre,
  });

  final int index;
  final bool isCandidate;
  final bool isLive;
  final int chatBadge;
  final ValueChanged<int> onSelect;
  final VoidCallback onCentre;

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.radar_rounded, 'Radar', 0),
      (Icons.work_outline_rounded, isCandidate ? 'Jobs' : 'Roles', 0),
      (Icons.chat_bubble_outline_rounded, 'Chats', chatBadge),
      (Icons.person_outline_rounded, 'Me', 0),
    ];

    Widget item(int i) {
      final (icon, label, badge) = items[i];
      final active = index == i;
      final color = active ? TrColors.plumInk : TrColors.icon;
      return Expanded(
        child: Semantics(
          selected: active,
          button: true,
          label: badge > 0 ? '$label, $badge new' : label,
          child: InkWell(
            onTap: () => onSelect(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(icon, size: 22, color: color),
                      if (badge > 0)
                        Positioned(
                          right: -9,
                          top: -5,
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 17),
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: TrColors.clay,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: Text(
                              badge > 9 ? '9+' : '$badge',
                              textAlign: TextAlign.center,
                              style: TrType.tag.copyWith(color: Colors.white, fontSize: 9.5),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TrType.navLabel.copyWith(
                      color: color,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
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
              Semantics(
                button: true,
                label: isCandidate
                    ? (isLive ? 'You are live today. Change availability' : 'Go live as available today')
                    : 'Post a role or walk-in',
                child: Transform.translate(
                  offset: const Offset(0, -14),
                  child: GestureDetector(
                    onTap: onCentre,
                    child: Container(
                      width: 58,
                      height: 58,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: TrColors.lime,
                        shape: BoxShape.circle,
                        border: isLive ? Border.all(color: TrColors.plumInk, width: 2.5) : null,
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
                        size: 27,
                      ),
                    ),
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
