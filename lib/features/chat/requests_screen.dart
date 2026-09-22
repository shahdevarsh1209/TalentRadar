import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/tr_colors.dart';
import '../../core/theme/tr_theme.dart';
import '../../core/theme/tr_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/chat.dart';
import '../../data/models/people.dart';
import '../../state/home_providers.dart';
import '../../widgets/primary_cta.dart';
import '../../widgets/tr_components.dart';
import '../people/hiring_widgets.dart';
import '../people/people_widgets.dart';

/// "Requests" from the design: incoming requests with their note, then recent
/// activity (connections and requests I have sent).
class RequestsScreen extends ConsumerWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(connectionsProvider);

    return Scaffold(
      backgroundColor: TrColors.canvas,
      appBar: AppBar(title: const Text('Requests')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(connectionsProvider.future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
          children: [
            AsyncSection<ConnectionsOverview>(
              value: overview,
              onRetry: () => ref.invalidate(connectionsProvider),
              builder: (data) {
                final recent = [...data.connections, ...data.outgoing]
                  ..sort((a, b) => (b.at ?? DateTime(0)).compareTo(a.at ?? DateTime(0)));
                if (data.incoming.isEmpty && recent.isEmpty) {
                  return const EmptyState(
                    icon: Icons.people_outline_rounded,
                    title: 'No requests yet',
                    message: 'When someone nearby wants to connect, their request and note will appear here.',
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final request in data.incoming) ...[
                      _IncomingRequest(item: request),
                      const SizedBox(height: 14),
                    ],
                    if (recent.isNotEmpty) ...[
                      Text('RECENT ACTIVITY', style: TrType.eyebrow),
                      const SizedBox(height: 12),
                      for (final item in recent) ...[
                        PersonRow(
                          person: item.person,
                          subtitle: item.status == ConnectionStatus.connected
                              ? 'Connected${item.at == null ? '' : ' · ${Fmt.ago(item.at!)}'}'
                              : 'Request sent · pending',
                          // Candidate or recruiter, the row opens their profile.
                          onTap: () => openPersonProfile(context, item.person),
                          trailing: item.status == ConnectionStatus.connected
                              ? InkWell(
                                  onTap: () => messagePerson(context, ref, item.person.userId),
                                  borderRadius: TrRadius.pillR,
                                  child: const TrPill(label: 'Chat', tone: PillTone.live),
                                )
                              : const TrPill(label: 'Pending'),
                        ),
                        const SizedBox(height: 12),
                      ],
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

class _IncomingRequest extends ConsumerStatefulWidget {
  const _IncomingRequest({required this.item});

  final ConnectionItem item;

  @override
  ConsumerState<_IncomingRequest> createState() => _IncomingRequestState();
}

class _IncomingRequestState extends ConsumerState<_IncomingRequest> {
  bool? _busyAccept;

  Future<void> _respond(bool accept) async {
    setState(() => _busyAccept = accept);
    try {
      final conversationId = await ref
          .read(socialRepositoryProvider)
          .respondToConnection(widget.item.connectionId, accept: accept);
      ref.refreshHome();
      if (!mounted) return;
      if (accept && conversationId != null) {
        context.push(Routes.chat(conversationId));
      } else {
        showTrSnack(context, 'Request ignored. They will not be told.');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _busyAccept = null);
        showTrSnack(context, errorText(error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final person = widget.item.person;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: TrColors.card, borderRadius: BorderRadius.circular(24), boxShadow: TrColors.cardShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Who is this? — decide from their profile before accepting.
          InkWell(
            onTap: () => openPersonProfile(context, person),
            borderRadius: BorderRadius.circular(16),
            child: Row(
              children: [
                TrAvatar(initials: person.initials, seed: person.name, size: 48),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(person.name, style: TrType.itemTitle),
                      Text(person.subtitle, style: TrType.itemMeta),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: TrColors.icon, size: 20),
              ],
            ),
          ),
          if (widget.item.message.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: TrColors.canvas, borderRadius: BorderRadius.circular(16)),
              child: Text(
                '“${widget.item.message}”',
                style: TrType.bodySmall.copyWith(color: TrColors.plumInk, height: 1.5),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: PrimaryCta(
                  label: 'Ignore',
                  variant: CtaVariant.outline,
                  isLoading: _busyAccept == false,
                  enabled: _busyAccept == null,
                  onPressed: () => _respond(false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PrimaryCta(
                  label: 'Accept',
                  isLoading: _busyAccept == true,
                  enabled: _busyAccept == null,
                  onPressed: () => _respond(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
