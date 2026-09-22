import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tr_colors.dart';
import '../../core/theme/tr_typography.dart';
import '../../state/home_providers.dart';
import '../../state/session_controller.dart';
import '../../widgets/tr_components.dart';
import '../jobs/job_widgets.dart';
import '../people/hiring_widgets.dart';
import '../people/people_widgets.dart';

/// "Saved" from the design: Jobs and People tabs.
class SavedScreen extends ConsumerStatefulWidget {
  const SavedScreen({super.key});

  @override
  ConsumerState<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends ConsumerState<SavedScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    // Recruiters mostly save people, so open on that tab.
    if (ref.read(sessionProvider)?.isCandidate == false) _tab = 1;
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(savedProvider);
    final jobs = saved.valueOrNull?.jobs.length;
    final people = saved.valueOrNull?.people.length;

    return Scaffold(
      backgroundColor: TrColors.canvas,
      appBar: AppBar(title: const Text('Saved')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: TrColors.border)),
              ),
              // Scrolls rather than overflowing on narrow phones / large text.
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _Tab(
                      label: 'Jobs${jobs == null ? '' : ' · $jobs'}',
                      active: _tab == 0,
                      onTap: () => setState(() => _tab = 0),
                    ),
                    const SizedBox(width: 22),
                    _Tab(
                      label: 'People${people == null ? '' : ' · $people'}',
                      active: _tab == 1,
                      onTap: () => setState(() => _tab = 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(savedProvider.future),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
                children: [
                  AsyncSection(
                    value: saved,
                    onRetry: () => ref.invalidate(savedProvider),
                    loading: const LoadingCards(count: 3, height: 72),
                    builder: (data) {
                      if (_tab == 0) {
                        if (data.jobs.isEmpty) {
                          return const EmptyState(
                            icon: Icons.bookmark_border_rounded,
                            title: 'No saved jobs yet',
                            message:
                                'Tap the bookmark on any role or walk-in to keep it here.',
                          );
                        }
                        return Column(
                          children: [
                            for (final job in data.jobs) ...[
                              JobRow(job: job),
                              const SizedBox(height: 12),
                            ],
                            if (data.jobs.any((job) => job.isWalkIn))
                              const InfoNote(
                                text:
                                    'Saved walk-ins send you a reminder 2 hours before.',
                              ),
                          ],
                        );
                      }
                      if (data.people.isEmpty) {
                        return const EmptyState(
                          icon: Icons.person_outline_rounded,
                          title: 'No saved people yet',
                          message:
                              'Save a profile from its quick view to find it again later.',
                        );
                      }
                      return Column(
                        children: [
                          for (final person in data.people) ...[
                            PersonRow(
                              person: person,
                              // Saved recruiters open their profile too.
                              onTap: () => openPersonProfile(context, person),
                              trailing: IconButton(
                                tooltip: 'Remove from saved',
                                icon: const Icon(
                                  Icons.bookmark_rounded,
                                  color: TrColors.plumInk,
                                ),
                                onPressed: () => toggleSavePerson(
                                  context,
                                  ref,
                                  person.userId,
                                  true,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
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
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(bottom: 11, top: 6),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? TrColors.plumInk : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Text(
          label,
          style: TrType.itemTitle.copyWith(
            fontSize: 14,
            color: active ? TrColors.plumInk : TrColors.icon,
            fontWeight: active ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
