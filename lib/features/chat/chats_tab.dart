import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/tr_colors.dart';
import '../../core/theme/tr_theme.dart';
import '../../core/theme/tr_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/chat.dart';
import '../../state/home_providers.dart';
import '../../state/session_controller.dart';
import '../../widgets/tr_components.dart';
import '../people/hiring_widgets.dart';

class ChatsTab extends ConsumerWidget {
  const ChatsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(conversationsProvider);
    final pending = ref.watch(badgesProvider).valueOrNull?.pendingRequests ?? 0;
    final isCandidate = ref.watch(sessionProvider)?.isCandidate ?? true;

    return RefreshIndicator(
      onRefresh: () {
        ref.invalidate(badgesProvider);
        return ref.refresh(conversationsProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
        children: [
          Text('Chats', style: TrType.screenTitle.copyWith(fontSize: 25)),
          const SizedBox(height: 16),
          _RequestsEntry(pending: pending, onTap: () => context.push(Routes.requests)),
          const SizedBox(height: 18),
          AsyncSection<List<ConversationSummary>>(
            value: conversations,
            onRetry: () => ref.invalidate(conversationsProvider),
            loading: const LoadingCards(count: 4, height: 70),
            builder: (list) => list.isEmpty
                ? EmptyState(
                    icon: Icons.forum_outlined,
                    title: 'No conversations yet',
                    message: isCandidate
                        ? 'Tap "I\'m interested" on a role nearby and your chat with the recruiter starts here.'
                        : 'Message or invite a candidate from your radar and the conversation appears here.',
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('RECENT', style: TrType.eyebrow),
                      const SizedBox(height: 10),
                      for (final conversation in list) ...[
                        _ConversationRow(conversation: conversation),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _RequestsEntry extends StatelessWidget {
  const _RequestsEntry({required this.pending, required this.onTap});

  final int pending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: pending > 0 ? TrColors.plumInk : TrColors.card,
      borderRadius: TrRadius.cardR,
      child: InkWell(
        onTap: onTap,
        borderRadius: TrRadius.cardR,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: pending > 0 ? TrColors.lime : TrColors.plumSurface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.person_add_alt_1_outlined, color: TrColors.plumInk, size: 20),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connection requests',
                      style: TrType.itemTitle.copyWith(
                        fontSize: 14.5,
                        color: pending > 0 ? Colors.white : TrColors.plumInk,
                      ),
                    ),
                    Text(
                      pending > 0 ? '${Fmt.plural(pending, 'new request')} waiting' : 'Requests and your connections',
                      style: TrType.itemMeta.copyWith(
                        color: pending > 0 ? Colors.white.withValues(alpha: 0.72) : TrColors.bodyMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: pending > 0 ? TrColors.lime : TrColors.icon),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({required this.conversation});

  final ConversationSummary conversation;

  @override
  Widget build(BuildContext context) {
    final person = conversation.person;
    final unread = conversation.unreadCount > 0;
    final preview = conversation.lastMessageText == null
        ? 'Say hello'
        : '${conversation.lastMessageFromMe ? 'You: ' : ''}${conversation.lastMessageText}';

    return InkWell(
      onTap: () => context.push(Routes.chat(conversation.conversationId)),
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
            // The row opens the conversation; the avatar opens who it is with.
            InkWell(
              onTap: () => openPersonProfile(context, person),
              customBorder: const CircleBorder(),
              child: TrAvatar(
                initials: person.initials,
                seed: person.name,
                size: 46,
                live: person.availableToday,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          person.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TrType.itemTitle.copyWith(fontSize: 14.5),
                        ),
                      ),
                      if (conversation.lastMessageAt != null)
                        Text(
                          Fmt.chatStamp(conversation.lastMessageAt!),
                          style: TrType.itemMeta.copyWith(
                            fontSize: 11,
                            color: unread ? TrColors.limeText : TrColors.icon,
                            fontWeight: unread ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ),
                    ],
                  ),
                  if (person.subtitle.isNotEmpty)
                    Text(person.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TrType.itemMeta.copyWith(fontSize: 11.5)),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TrType.bodySmall.copyWith(
                            fontSize: 13,
                            color: unread ? TrColors.plumInk : TrColors.bodyMuted,
                            fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (unread)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: TrColors.lime, borderRadius: TrRadius.pillR),
                          child: Text('${conversation.unreadCount}', style: TrType.tag.copyWith(fontSize: 11)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
