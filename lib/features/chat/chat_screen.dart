import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tr_colors.dart';
import '../../core/theme/tr_theme.dart';
import '../../core/theme/tr_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/chat.dart';
import '../../data/models/enums.dart';
import '../../state/home_providers.dart';
import '../../state/session_controller.dart';
import '../../widgets/primary_cta.dart';
import '../../widgets/tr_components.dart';
import '../jobs/job_widgets.dart';
import '../people/hiring_widgets.dart';
import 'invite_composer_sheet.dart';

/// One conversation. New messages arrive by polling every few seconds while the
/// screen is open — no socket to keep alive on a phone in a basement.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversationId, this.openInviteComposer = false});

  final String conversationId;

  /// Opened from a candidate card's "Invite": go straight to the invite form.
  final bool openInviteComposer;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  static const Duration _pollEvery = Duration(seconds: 4);

  final TextEditingController _composer = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<ChatMessage> _messages = [];

  ConversationSummary? _conversation;
  Object? _loadError;
  bool _loading = true;
  bool _sending = false;
  Timer? _poller;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _poller?.cancel();
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final result = await ref.read(socialRepositoryProvider).messages(widget.conversationId);
      if (!mounted) return;
      setState(() {
        _conversation = result.conversation;
        _messages
          ..clear()
          ..addAll(result.messages);
        _loading = false;
      });
      _scrollToEnd(jump: true);
      // Opening the chat cleared its unread count; let the list and badge catch up.
      ref.invalidate(conversationsProvider);
      ref.invalidate(badgesProvider);
      _poller = Timer.periodic(_pollEvery, (_) => _poll());
      if (widget.openInviteComposer) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _openInviteComposer());
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loadError = error;
          _loading = false;
        });
      }
    }
  }

  Future<void> _poll() async {
    if (!mounted || _loading) return;
    try {
      final after = _messages.isEmpty ? null : _messages.last.cursor;
      final result = await ref.read(socialRepositoryProvider).messages(widget.conversationId, after: after);
      if (!mounted || result.messages.isEmpty) return;
      _merge(result.messages);
    } catch (_) {
      // A missed poll is retried on the next tick.
    }
  }

  /// Adds messages not already shown (a sent message can also come back in a poll).
  void _merge(List<ChatMessage> incoming) {
    final known = _messages.map((message) => message.messageId).toSet();
    final fresh = incoming.where((message) => !known.contains(message.messageId)).toList();
    if (fresh.isEmpty) return;
    setState(() => _messages.addAll(fresh));
    _scrollToEnd();
    // Keeps the Chats list preview and order in step with this conversation.
    ref.invalidate(conversationsProvider);
  }

  void _replace(ChatMessage updated) {
    final index = _messages.indexWhere((message) => message.messageId == updated.messageId);
    if (index >= 0) setState(() => _messages[index] = updated);
  }

  void _scrollToEnd({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final target = _scroll.position.maxScrollExtent;
      if (jump) {
        _scroll.jumpTo(target);
      } else {
        _scroll.animateTo(target, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final message = await ref.read(socialRepositoryProvider).send(widget.conversationId, text);
      _composer.clear();
      _merge([message]);
    } catch (error) {
      if (mounted) showTrSnack(context, errorText(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _openInviteComposer() async {
    final draft = await showModalBottomSheet<InviteDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: TrColors.canvas,
      builder: (_) => const InviteComposerSheet(),
    );
    if (draft == null || !mounted) return;
    try {
      final message = await ref.read(socialRepositoryProvider).sendInvite(
            widget.conversationId,
            title: draft.title,
            round: draft.round,
            scheduledAt: draft.scheduledAt,
            mode: draft.mode,
            location: draft.location,
          );
      _merge([message]);
      if (mounted) showTrSnack(context, 'Interview invite sent.');
    } catch (error) {
      if (mounted) showTrSnack(context, errorText(error));
    }
  }

  Future<void> _respondToInvite(ChatMessage message, String action) async {
    try {
      final updated = await ref.read(socialRepositoryProvider).respondToInvite(message.messageId, action);
      _replace(updated);
      await _poll(); // Picks up the system note the server just added.
    } catch (error) {
      if (mounted) showTrSnack(context, errorText(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(sessionProvider);
    final myId = me?.user.userId ?? '';
    final isRecruiter = me?.user.role == UserRole.recruiter;
    final person = _conversation?.person;

    return Scaffold(
      backgroundColor: TrColors.canvas,
      appBar: AppBar(
        titleSpacing: 0,
        title: person == null
            ? const Text('Chat')
            : InkWell(
                // Whoever you are talking to, their identity opens their
                // profile: a candidate's quick view, or the recruiter's page.
                onTap: () => openPersonProfile(context, person),
                child: Row(
                  children: [
                    TrAvatar(
                      initials: person.initials,
                      seed: person.name,
                      size: 40,
                      live: person.availableToday,
                      ringColor: TrColors.canvas,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(person.name, style: TrType.itemTitle, overflow: TextOverflow.ellipsis),
                          Text(
                            person.availableToday ? 'Available today' : person.subtitle,
                            overflow: TextOverflow.ellipsis,
                            style: TrType.itemMeta.copyWith(
                              fontSize: 12,
                              color: person.availableToday ? TrColors.limeText : TrColors.bodyMuted,
                              fontWeight: person.availableToday ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
      ),
      body: Column(
        children: [
          // What this conversation is about, when it started from a role.
          if (_conversation?.jobId != null) _JobContextBar(jobId: _conversation!.jobId!),
          Expanded(child: _body(myId)),
          _Composer(
            controller: _composer,
            sending: _sending,
            enabled: _conversation != null,
            onSend: _send,
            onInvite: isRecruiter ? _openInviteComposer : null,
          ),
        ],
      ),
    );
  }

  Widget _body(String myId) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: TrColors.plumInk));
    if (_loadError != null) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Could not open this chat',
        message: errorText(_loadError!),
        actionLabel: 'Try again',
        onAction: _loadInitial,
      );
    }
    if (_messages.isEmpty) {
      return const EmptyState(
        icon: Icons.waving_hand_outlined,
        title: 'Say hello',
        message: 'Introduce yourself — a short, specific first message gets the fastest reply.',
      );
    }

    final children = <Widget>[];
    DateTime? lastDay;
    for (final message in _messages) {
      final day = DateTime(message.createdAt.year, message.createdAt.month, message.createdAt.day);
      if (lastDay != day) {
        children.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Center(
            child: Text(Fmt.day(message.createdAt), style: TrType.itemMeta.copyWith(fontSize: 11.5, fontWeight: FontWeight.w600)),
          ),
        ));
        lastDay = day;
      }
      children.add(_messageWidget(message, message.senderId == myId));
      children.add(const SizedBox(height: 10));
    }

    return ListView(
      controller: _scroll,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
      children: children,
    );
  }

  Widget _messageWidget(ChatMessage message, bool mine) {
    switch (message.kind) {
      case MessageKind.system:
        return Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: TrColors.plumSurface, borderRadius: TrRadius.pillR),
            child: Text(message.text, style: TrType.itemMeta.copyWith(fontSize: 11.5, color: TrColors.plumInk)),
          ),
        );
      case MessageKind.interviewInvite:
        return Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: 0.84,
            child: _InviteCard(
              message: message,
              mine: mine,
              onRespond: (action) => _respondToInvite(message, action),
            ),
          ),
        );
      case MessageKind.text:
        return Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              decoration: BoxDecoration(
                color: mine ? TrColors.plumInk : TrColors.card,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(mine ? 20 : 6),
                  bottomRight: Radius.circular(mine ? 6 : 20),
                ),
                boxShadow: mine ? null : TrColors.cardShadow,
              ),
              child: Column(
                // Sized to the text, not to the 78% cap: a one-word message
                // gets a one-word bubble. An Align here would fill the width.
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SelectableText(
                    message.text,
                    style: TrType.bodyText.copyWith(
                      fontSize: 13.5,
                      height: 1.45,
                      color: mine ? Colors.white : TrColors.plumInk,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    Fmt.time(message.createdAt),
                    style: TrType.itemMeta.copyWith(
                      fontSize: 10.5,
                      color: mine ? Colors.white.withValues(alpha: 0.6) : TrColors.icon,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
    }
  }
}

/// The role this conversation is about, pinned above the messages.
///
/// It reads the live job, so a role closed since the chat started says so here
/// rather than leaving the candidate to find out at the door.
class _JobContextBar extends ConsumerWidget {
  const _JobContextBar({required this.jobId});

  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final job = ref.watch(jobPreviewProvider(jobId));

    return job.maybeWhen(
      data: (data) => Material(
        color: TrColors.plumSurface,
        child: InkWell(
          onTap: () => openJobDetailsById(context, jobId),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 11, 14, 11),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.title.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TrType.itemTitle.copyWith(fontSize: 13.5, color: TrColors.plumInk),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        [
                          data.companyName,
                          if (data.isOpen)
                            Fmt.plural(data.openings, 'opening')
                          else
                            'Closed',
                          if (data.isWalkIn && data.walkIn != null)
                            'Walk-in ${Fmt.day(data.walkIn!.date)}',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TrType.itemMeta.copyWith(fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text('View', style: TrType.chip.copyWith(fontSize: 12)),
                const Icon(Icons.chevron_right_rounded, size: 18, color: TrColors.plumInk),
              ],
            ),
          ),
        ),
      ),
      // Nothing is shown until it loads, so the bar never flashes empty.
      orElse: () => const SizedBox.shrink(),
    );
  }
}

/// The design's interview-invite card.
class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.message, required this.mine, required this.onRespond});

  final ChatMessage message;
  final bool mine;
  final ValueChanged<String> onRespond;

  @override
  Widget build(BuildContext context) {
    final invite = message.invite!;
    final canRespond = !mine &&
        (invite.status == InviteStatus.pending || invite.status == InviteStatus.rescheduleRequested);
    final tone = switch (invite.status) {
      InviteStatus.accepted => PillTone.live,
      InviteStatus.declined => PillTone.neutral,
      InviteStatus.rescheduleRequested => PillTone.alert,
      InviteStatus.pending => PillTone.plum,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: TrColors.card, borderRadius: BorderRadius.circular(20), boxShadow: TrColors.cardShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              const TrPill(label: 'Interview invite', tone: PillTone.live),
              if (!canRespond || invite.status != InviteStatus.pending) TrPill(label: invite.status.label, tone: tone),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            [invite.title, if (invite.round.isNotEmpty) invite.round].join(' · '),
            style: TrType.cardTitle.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            [
              Fmt.day(invite.scheduledAt),
              Fmt.time(invite.scheduledAt),
              if (invite.mode != InterviewMode.inPerson) invite.mode.label,
              if (invite.location.isNotEmpty) invite.location,
            ].join(' · '),
            style: TrType.itemMeta,
          ),
          if (canRespond) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (invite.status == InviteStatus.pending) ...[
                  Expanded(
                    child: PrimaryCta(
                      label: 'Reschedule',
                      variant: CtaVariant.outline,
                      onPressed: () => onRespond('reschedule'),
                    ),
                  ),
                  const SizedBox(width: 9),
                ],
                Expanded(child: PrimaryCta(label: 'Accept', onPressed: () => onRespond('accept'))),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TrTextAction(
                label: 'Decline',
                color: TrColors.bodyMuted,
                onPressed: () => onRespond('decline'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.enabled,
    required this.onSend,
    this.onInvite,
  });

  final TextEditingController controller;
  final bool sending;
  final bool enabled;
  final VoidCallback onSend;
  final VoidCallback? onInvite;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: TrColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (onInvite != null)
              IconButton(
                tooltip: 'Send interview invite',
                onPressed: enabled ? onInvite : null,
                icon: const Icon(Icons.event_available_outlined, color: TrColors.plumInk),
              ),
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                minLines: 1,
                maxLines: 4,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Write a message…',
                  counterText: '',
                  filled: true,
                  fillColor: TrColors.canvas,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  border: OutlineInputBorder(borderRadius: TrRadius.pillR, borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: TrRadius.pillR, borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: TrRadius.pillR,
                    borderSide: const BorderSide(color: TrColors.plumInk),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Semantics(
              button: true,
              label: 'Send message',
              child: InkWell(
                onTap: enabled && !sending ? onSend : null,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(color: TrColors.lime, shape: BoxShape.circle),
                  child: sending
                      ? const Padding(
                          padding: EdgeInsets.all(13),
                          child: CircularProgressIndicator(strokeWidth: 2.2, color: TrColors.plumInk),
                        )
                      : const Icon(Icons.send_rounded, color: TrColors.plumInk, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
