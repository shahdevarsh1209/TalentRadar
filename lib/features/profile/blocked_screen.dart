import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tr_colors.dart';
import '../../data/models/people.dart';
import '../../state/home_providers.dart';
import '../../widgets/primary_cta.dart';
import '../../widgets/tr_components.dart';
import '../people/people_widgets.dart';

/// Blocked accounts, and the way back. A block is only fair if it can be undone
/// from somewhere obvious — this is that somewhere.
class BlockedScreen extends ConsumerStatefulWidget {
  const BlockedScreen({super.key});

  @override
  ConsumerState<BlockedScreen> createState() => _BlockedScreenState();
}

class _BlockedScreenState extends ConsumerState<BlockedScreen> {
  String? _busyId;

  Future<void> _unblock(PersonSummary person) async {
    setState(() => _busyId = person.userId);
    try {
      await ref.read(searchRepositoryProvider).setBlocked(person.userId, blocked: false);
      ref.invalidate(blockedPeopleProvider);
      ref.refreshHome();
      if (mounted) showTrSnack(context, '${person.name} is unblocked.');
    } catch (error) {
      if (mounted) showTrSnack(context, errorText(error));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocked = ref.watch(blockedPeopleProvider);

    return Scaffold(
      backgroundColor: TrColors.canvas,
      appBar: AppBar(title: const Text('Blocked accounts')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(blockedPeopleProvider.future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
          children: [
            AsyncSection<List<Map<String, dynamic>>>(
              value: blocked,
              onRetry: () => ref.invalidate(blockedPeopleProvider),
              loading: const LoadingCards(count: 2, height: 72),
              builder: (rows) {
                if (rows.isEmpty) {
                  return const EmptyState(
                    icon: Icons.block_rounded,
                    title: 'No blocked accounts',
                    message:
                        'If you block someone, they appear here and you can undo it at any time.',
                  );
                }
                return Column(
                  children: [
                    const InfoNote(
                      text:
                          'Blocked people cannot see you and you cannot see them — in search, on the radar or in chat.',
                    ),
                    const SizedBox(height: 14),
                    for (final row in rows) ...[
                      Builder(
                        builder: (context) {
                          final person = PersonSummary.fromJson(row);
                          return PersonRow(
                            person: person,
                            subtitle: 'Blocked',
                            // A text action rather than a button: the row is
                            // tight on a small phone at large text.
                            trailing: TrTextAction(
                              label: _busyId == person.userId ? 'Unblocking…' : 'Unblock',
                              onPressed: _busyId == null ? () => _unblock(person) : null,
                            ),
                          );
                        },
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
    );
  }
}
