import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tr_colors.dart';
import '../../core/theme/tr_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/people.dart';
import '../../state/home_providers.dart';
import '../../widgets/tr_components.dart';
import '../people/people_widgets.dart';

final _interestsProvider = FutureProvider.autoDispose
    .family<List<({PersonSummary person, DateTime? at})>, String>((ref, jobId) {
  return ref.watch(jobsRepositoryProvider).interests(jobId);
});

/// Candidates who tapped "I'm interested" on one of my roles.
class JobInterestsScreen extends ConsumerWidget {
  const JobInterestsScreen({super.key, required this.jobId});

  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interests = ref.watch(_interestsProvider(jobId));

    return Scaffold(
      backgroundColor: TrColors.canvas,
      appBar: AppBar(title: const Text('Interested candidates')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(_interestsProvider(jobId).future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
          children: [
            AsyncSection(
              value: interests,
              onRetry: () => ref.invalidate(_interestsProvider(jobId)),
              builder: (list) => list.isEmpty
                  ? const EmptyState(
                      icon: Icons.how_to_reg_outlined,
                      title: 'No one yet',
                      message: 'When a candidate taps "I\'m interested" on this role, they appear here and a chat opens with them.',
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(Fmt.plural(list.length, 'candidate'), style: TrType.itemMeta),
                        const SizedBox(height: 12),
                        for (final item in list) ...[
                          PersonRow(
                            person: item.person,
                            subtitle: [
                              if (item.person.headline.isNotEmpty) item.person.headline,
                              if (item.at != null) 'interested ${Fmt.ago(item.at!)}',
                            ].join(' · '),
                            onTap: () => openQuickProfile(context, item.person.userId),
                            trailing: IconButton(
                              tooltip: 'Message ${item.person.name}',
                              icon: const Icon(Icons.chat_bubble_outline_rounded, color: TrColors.plumInk),
                              onPressed: () => messagePerson(context, ref, item.person.userId),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
