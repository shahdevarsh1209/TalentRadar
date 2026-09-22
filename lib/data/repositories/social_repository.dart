import '../../core/network/api_client.dart';
import '../models/chat.dart';
import '../models/job.dart';
import '../models/people.dart';

/// Saved items, connection requests, conversations and messages.
class SocialRepository {
  SocialRepository(this._api);

  final ApiClient _api;

  // ── Saved ──────────────────────────────────────────────────────────────────

  Future<({List<Job> jobs, List<PersonSummary> people})> saved() async {
    final data = await _api.get('/saved');
    return (
      jobs: (data['jobs'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(Job.fromJson)
          .toList(),
      people: (data['people'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(PersonSummary.fromJson)
          .toList(),
    );
  }

  Future<void> setSaved({required String kind, required String refId, required bool saved}) async {
    if (saved) {
      await _api.put('/saved', body: {'kind': kind, 'refId': refId});
    } else {
      await _api.delete('/saved/$kind/$refId');
    }
  }

  // ── Connections ────────────────────────────────────────────────────────────

  Future<ConnectionsOverview> connections() async {
    final data = await _api.get('/connections');
    List<ConnectionItem> parse(String key) => (data[key] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(ConnectionItem.fromJson)
        .toList();
    return ConnectionsOverview(
      incoming: parse('incoming'),
      outgoing: parse('outgoing'),
      connections: parse('connections'),
    );
  }

  /// Returns the resulting status, and a conversation id when it connected at once.
  Future<({ConnectionStatus status, String? conversationId})> requestConnection(
    String recipientId, {
    String message = '',
  }) async {
    final data = await _api.post('/connections', body: {
      'recipientId': recipientId,
      if (message.trim().isNotEmpty) 'message': message.trim(),
    });
    return (
      status: ConnectionStatus.fromWire(data['status'] as String?),
      conversationId: data['conversationId'] as String?,
    );
  }

  Future<String?> respondToConnection(String connectionId, {required bool accept}) async {
    final data = await _api.post(
      '/connections/$connectionId/respond',
      body: {'action': accept ? 'accept' : 'ignore'},
    );
    return data['conversationId'] as String?;
  }

  // ── Chat ───────────────────────────────────────────────────────────────────

  Future<List<ConversationSummary>> conversations() async {
    final data = await _api.get('/conversations');
    return (data['conversations'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(ConversationSummary.fromJson)
        .toList();
  }

  Future<ConversationSummary> startConversation(String participantId, {String? jobId}) async {
    final data = await _api.post('/conversations', body: {
      'participantId': participantId,
      'jobId': ?jobId,
    });
    return ConversationSummary.fromJson(data['conversation'] as Map<String, dynamic>);
  }

  /// Messages oldest first. Pass [after] to fetch only what arrived since.
  Future<({ConversationSummary conversation, List<ChatMessage> messages})> messages(
    String conversationId, {
    String? after,
  }) async {
    final data = await _api.get(
      '/conversations/$conversationId/messages',
      query: {'after': ?after},
    );
    return (
      conversation: ConversationSummary.fromJson(data['conversation'] as Map<String, dynamic>),
      messages: (data['messages'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ChatMessage.fromJson)
          .toList(),
    );
  }

  Future<ChatMessage> send(String conversationId, String text) async {
    final data = await _api.post('/conversations/$conversationId/messages', body: {'text': text});
    return ChatMessage.fromJson(data['message'] as Map<String, dynamic>);
  }

  Future<ChatMessage> sendInvite(
    String conversationId, {
    required String title,
    required String round,
    required DateTime scheduledAt,
    required InterviewMode mode,
    required String location,
  }) async {
    final data = await _api.post('/conversations/$conversationId/invites', body: {
      'title': title,
      'round': round,
      'scheduledAt': scheduledAt.toUtc().toIso8601String(),
      'mode': mode.wire,
      'location': location,
    });
    return ChatMessage.fromJson(data['message'] as Map<String, dynamic>);
  }

  /// [action] is 'accept', 'reschedule' or 'decline'.
  Future<ChatMessage> respondToInvite(String messageId, String action) async {
    final data = await _api.post('/messages/$messageId/invite-response', body: {'action': action});
    return ChatMessage.fromJson(data['message'] as Map<String, dynamic>);
  }

  Future<Badges> badges() async {
    final data = await _api.get('/me/badges');
    return Badges(
      unreadChats: (data['unreadChats'] as num?)?.toInt() ?? 0,
      pendingRequests: (data['pendingRequests'] as num?)?.toInt() ?? 0,
    );
  }
}
