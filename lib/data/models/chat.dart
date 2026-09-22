import 'package:flutter/foundation.dart';

import 'people.dart';

@immutable
class ConversationSummary {
  const ConversationSummary({
    required this.conversationId,
    required this.person,
    this.lastMessageText,
    this.lastMessageFromMe = false,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.jobId,
  });

  final String conversationId;
  final PersonSummary person;
  final String? lastMessageText;
  final bool lastMessageFromMe;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final String? jobId;

  factory ConversationSummary.fromJson(Map<String, dynamic> json) {
    final last = json['lastMessage'] as Map<String, dynamic>?;
    return ConversationSummary(
      conversationId: '${json['conversationId']}',
      person: PersonSummary.fromJson(json['person'] as Map<String, dynamic>?),
      lastMessageText: last?['text'] as String?,
      lastMessageFromMe: last?['fromMe'] == true,
      lastMessageAt: DateTime.tryParse('${last?['at']}')?.toLocal(),
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      jobId: json['jobId'] as String?,
    );
  }
}

enum InviteStatus {
  pending('pending', 'Awaiting reply'),
  accepted('accepted', 'Accepted'),
  rescheduleRequested('reschedule_requested', 'Reschedule requested'),
  declined('declined', 'Declined');

  const InviteStatus(this.wire, this.label);
  final String wire;
  final String label;

  static InviteStatus fromWire(String? value) => InviteStatus.values.firstWhere(
        (status) => status.wire == value,
        orElse: () => InviteStatus.pending,
      );
}

enum InterviewMode {
  inPerson('in_person', 'In person'),
  video('video', 'Video call'),
  phone('phone', 'Phone call');

  const InterviewMode(this.wire, this.label);
  final String wire;
  final String label;

  static InterviewMode fromWire(String? value) => InterviewMode.values.firstWhere(
        (mode) => mode.wire == value,
        orElse: () => InterviewMode.inPerson,
      );
}

@immutable
class InterviewInvite {
  const InterviewInvite({
    required this.title,
    required this.round,
    required this.scheduledAt,
    required this.mode,
    required this.location,
    required this.status,
  });

  final String title;
  final String round;
  final DateTime scheduledAt;
  final InterviewMode mode;
  final String location;
  final InviteStatus status;

  factory InterviewInvite.fromJson(Map<String, dynamic> json) => InterviewInvite(
        title: '${json['title'] ?? ''}',
        round: '${json['round'] ?? ''}',
        scheduledAt: DateTime.tryParse('${json['scheduledAt']}')?.toLocal() ?? DateTime.now(),
        mode: InterviewMode.fromWire(json['mode'] as String?),
        location: '${json['location'] ?? ''}',
        status: InviteStatus.fromWire(json['status'] as String?),
      );
}

enum MessageKind { text, interviewInvite, system }

@immutable
class ChatMessage {
  const ChatMessage({
    required this.messageId,
    required this.senderId,
    required this.kind,
    required this.text,
    required this.createdAt,
    this.invite,
  });

  final String messageId;
  final String senderId;
  final MessageKind kind;
  final String text;
  final InterviewInvite? invite;
  final DateTime createdAt;

  /// The raw server timestamp, used as the polling cursor.
  String get cursor => createdAt.toUtc().toIso8601String();

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        messageId: '${json['messageId']}',
        senderId: '${json['senderId']}',
        kind: switch (json['kind']) {
          'interview_invite' => MessageKind.interviewInvite,
          'system' => MessageKind.system,
          _ => MessageKind.text,
        },
        text: '${json['text'] ?? ''}',
        invite: json['invite'] is Map<String, dynamic>
            ? InterviewInvite.fromJson(json['invite'] as Map<String, dynamic>)
            : null,
        createdAt: DateTime.tryParse('${json['createdAt']}')?.toLocal() ?? DateTime.now(),
      );
}

@immutable
class ConnectionItem {
  const ConnectionItem({
    required this.connectionId,
    required this.person,
    required this.status,
    this.message = '',
    this.at,
  });

  final String connectionId;
  final PersonSummary person;
  final ConnectionStatus status;
  final String message;
  final DateTime? at;

  factory ConnectionItem.fromJson(Map<String, dynamic> json) => ConnectionItem(
        connectionId: '${json['connectionId']}',
        person: PersonSummary.fromJson(json['person'] as Map<String, dynamic>?),
        status: ConnectionStatus.fromWire(json['status'] as String?),
        message: '${json['message'] ?? ''}',
        at: DateTime.tryParse('${json['at']}')?.toLocal(),
      );
}

@immutable
class ConnectionsOverview {
  const ConnectionsOverview({
    this.incoming = const [],
    this.outgoing = const [],
    this.connections = const [],
  });

  final List<ConnectionItem> incoming;
  final List<ConnectionItem> outgoing;
  final List<ConnectionItem> connections;
}

@immutable
class Badges {
  const Badges({this.unreadChats = 0, this.pendingRequests = 0});

  final int unreadChats;
  final int pendingRequests;

  int get chatsTab => unreadChats + pendingRequests;
}
