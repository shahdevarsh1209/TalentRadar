import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talentradar/core/network/api_client.dart';
import 'package:talentradar/data/models/chat.dart';
import 'package:talentradar/data/models/job.dart';
import 'package:talentradar/data/models/people.dart';
import 'package:talentradar/data/models/session.dart';
import 'package:talentradar/data/repositories/social_repository.dart';
import 'package:talentradar/state/home_providers.dart';
import 'package:talentradar/state/session_controller.dart';

export 'package:talentradar/data/models/session.dart' show Session;

/// Shared fixtures for the layout suites.
///
/// Names, titles and companies are deliberately at the long end of plausible —
/// a layout that survives "ABC Technologies and Business Solutions Private
/// Limited" at 1.3× on a 320 px phone will survive real data.

Map<String, dynamic> title(String code, String name) =>
    {'code': code, 'name': name, 'category': 'Support'};

final location = {
  'area': 'HSR Layout',
  'city': 'Bengaluru',
  'label': 'HSR Layout, Bengaluru',
  'isSet': true,
};

final Session candidateSession = Session.fromJson({
  'token': 't',
  'user': {
    'userId': 'c1',
    'email': 'aditi.sharma@example.com',
    'role': 'candidate',
    'isEmailVerified': true,
    'onboardingStage': 'complete',
  },
  'profile': {
    'name': 'Aditi Venkataraman Sharma',
    'email': 'aditi.sharma@example.com',
    'headline': 'Software Support Executive with ERP implementation experience',
    'jobTitles': [
      title('JT_040', 'Software Support Executive'),
      title('JT_049', 'ERP Functional Consultant'),
    ],
    'experienceLevel': '1_2',
    'workModes': ['hybrid', 'onsite', 'remote'],
    'openToWork': 'actively_looking',
    'profileVisibility': 'recruiters_only',
    'stealthMode': false,
    'availableToday': true,
    'skills': ['Zendesk', 'Freshdesk', 'SAP MM', 'Customer support', 'Excel'],
    'location': location,
    'profileCompletion': 75,
  },
});

final Session recruiterSession = Session.fromJson({
  'token': 't',
  'user': {
    'userId': 'r1',
    'email': 'riya@brightdesk.example.com',
    'role': 'recruiter',
    'isEmailVerified': true,
    'onboardingStage': 'complete',
  },
  'profile': {
    'companyName': 'BrightDesk Customer Experience Private Limited',
    'hrName': 'Riya Joshi',
    'email': 'riya@brightdesk.example.com',
    'designation': 'Senior Talent Acquisition Manager',
    'hiringProfiles': [
      title('JT_042', 'Customer Support Executive'),
      title('JT_045', 'Tele-support Associate'),
    ],
    'hiringWorkModes': ['onsite', 'hybrid'],
    'hiringLocations': [location],
    'hiringRadiusKm': 10,
    'profileCompletion': 62,
  },
});

Map<String, dynamic> longJobJson(String id, {bool walkIn = false}) => {
      'jobId': id,
      'recruiterUserId': 'r1',
      'companyName': 'BrightDesk Customer Experience Private Limited',
      'title': title('JT_042', 'Customer Support Executive (Voice & Chat Process)'),
      'workMode': walkIn ? 'onsite' : 'hybrid',
      'experienceLevel': '12_plus',
      'openings': 12,
      'salaryMin': 220000,
      'salaryMax': 2800000,
      'isWalkIn': walkIn,
      'walkIn': walkIn
          ? {
              'date': DateTime.now().toIso8601String(),
              'startTime': '10:00',
              'endTime': '16:30',
              'address': '27th Main Road, HSR Layout Sector 2',
            }
          : null,
      'walkInToday': walkIn,
      'closingSoon': !walkIn,
      'matchesProfile': true,
      'distanceKm': 4.5,
      'location': location,
      'interestCount': 14,
      'createdAt': DateTime.now().toIso8601String(),
    };

Job longJob(String id, {bool walkIn = false}) => Job.fromJson(longJobJson(id, walkIn: walkIn));

Map<String, dynamic> longCandidateJson() => {
      'userId': 'k1',
      'name': 'Priyadarshini Kulkarni',
      'initials': 'PK',
      'headline': 'Customer Support Executive',
      'jobTitles': [title('JT_042', 'Customer Support Executive')],
      'skills': ['Zendesk', 'Freshdesk', 'Voice process'],
      'experienceLevel': '2_3',
      'workModes': ['onsite'],
      'openToWork': 'actively_looking',
      'availableToday': true,
      'area': 'Jayanagar, Bengaluru',
      'distanceKm': 4.5,
      'matchesHiring': true,
      'connectionStatus': 'none',
    };

final PersonSummary recruiterPerson = PersonSummary.fromJson({
  'userId': 'p1',
  'role': 'recruiter',
  'name': 'Riya Joshi-Venkatachalam',
  'initials': 'RJ',
  'headline': 'Senior Talent Acquisition Manager',
  'subtitle': 'Senior Talent Acquisition Manager · BrightDesk Customer Experience',
  'companyId': 'co1',
});

final CandidateCard candidateCard = CandidateCard.fromJson(longCandidateJson());

class FakeSession extends SessionController {
  FakeSession(super.ref, Session session) {
    state = session;
  }
}

/// Serves one conversation with a text message, an invite awaiting an answer,
/// and the system note that followed it — the three shapes chat can render.
class FakeSocial extends SocialRepository {
  FakeSocial() : super(ApiClient());

  static final conversation = ConversationSummary(conversationId: 'x', person: recruiterPerson);

  @override
  Future<({ConversationSummary conversation, List<ChatMessage> messages})> messages(
    String conversationId, {
    String? after,
  }) async {
    if (after != null) return (conversation: conversation, messages: <ChatMessage>[]);
    return (
      conversation: conversation,
      messages: [
        ChatMessage.fromJson({
          'messageId': 'm1',
          'senderId': 'p1',
          'kind': 'text',
          'text': 'Hi Aditi, thanks for connecting. Are you open to a quick chat about the role this week?',
          'createdAt': DateTime.now().toIso8601String(),
        }),
        // A one-word reply: the bubble must hug it, not stretch to the cap.
        ChatMessage.fromJson({
          'messageId': 'm2',
          'senderId': 'c1',
          'kind': 'text',
          'text': 'Hi',
          'createdAt': DateTime.now().toIso8601String(),
        }),
        ChatMessage.fromJson({
          'messageId': 'm3',
          'senderId': 'p1',
          'kind': 'interview_invite',
          'text': '',
          'invite': {
            'title': 'Customer Support Executive (Voice & Chat Process)',
            'round': 'Round 1 — HR and operations',
            'scheduledAt': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
            'mode': 'in_person',
            'location': 'Koramangala office, 3rd floor',
            'status': 'reschedule_requested',
          },
          'createdAt': DateTime.now().toIso8601String(),
        }),
        ChatMessage.fromJson({
          'messageId': 'm4',
          'senderId': 'c1',
          'kind': 'system',
          'text': 'Aditi asked to reschedule the interview.',
          'createdAt': DateTime.now().toIso8601String(),
        }),
      ],
    );
  }
}

/// The overrides every layout test needs: a signed-in session and populated
/// lists, so a screen is measured with content rather than empty states.
List<Override> baseOverrides(Session session) => [
      sessionProvider.overrideWith((ref) => FakeSession(ref, session)),
      socialRepositoryProvider.overrideWithValue(FakeSocial()),
      jobListProvider.overrideWith(
        (ref, query) async => JobList(
          jobs: [longJob('j1', walkIn: true), longJob('j2')],
          meta: JobListMeta(
            total: 2,
            nearbyCount: 2,
            walkInsToday: 1,
            hasLocation: true,
            updatedAt: DateTime.now(),
          ),
        ),
      ),
      jobPreviewProvider.overrideWith((ref, jobId) async => longJob(jobId)),
      myJobsProvider.overrideWith((ref) async => [longJob('j1', walkIn: true), longJob('j2')]),
      nearbyCandidatesProvider.overrideWith(
        (ref, query) async =>
            CandidateList(candidates: [candidateCard], availableToday: 1, hasLocation: true),
      ),
      savedProvider.overrideWith(
        (ref) async => (jobs: [longJob('j1', walkIn: true)], people: [recruiterPerson]),
      ),
      conversationsProvider.overrideWith(
        (ref) async => [
          ConversationSummary(
            conversationId: 'x',
            person: recruiterPerson,
            lastMessageText: 'Interview invite · Customer Support Executive (Voice & Chat Process)',
            lastMessageAt: DateTime.now(),
            unreadCount: 12,
          ),
        ],
      ),
      connectionsProvider.overrideWith(
        (ref) async => ConnectionsOverview(
          incoming: [
            ConnectionItem(
              connectionId: 'q1',
              person: recruiterPerson,
              status: ConnectionStatus.pendingReceived,
              message:
                  'Hi Aditi, we have a UX Researcher role open near you. Would love to chat this week.',
            ),
          ],
          connections: [
            ConnectionItem(
              connectionId: 'q2',
              person: recruiterPerson,
              status: ConnectionStatus.connected,
              at: DateTime.now(),
            ),
          ],
        ),
      ),
      recruitersViewedProvider.overrideWith((ref) async => 7),
      badgesProvider.overrideWith(
        (ref) => Stream.value(const Badges(unreadChats: 12, pendingRequests: 3)),
      ),
    ];

/// Fails with Flutter's own diagnostic, naming the offending widget's file.
///
/// A bare `expect(tester.takeException(), isNull)` says only that something
/// overflowed; this says which widget, which is the part you need.
void expectNoLayoutError(WidgetTester tester, String where) {
  final error = tester.takeException();
  if (error == null) return;
  final detail = error is FlutterError ? error.toStringDeep() : '$error';
  final culprits = RegExp(r'file:///\S+/lib/\S+')
      .allMatches(detail)
      .map((match) => match.group(0)!.split('/lib/').last)
      .toSet();
  // Keep the first lines that actually say something: a FlutterError's own
  // first line is often blank, which used to make this message useless.
  final summary = detail
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty && !line.startsWith('═'))
      .take(6)
      .join(' | ');
  fail('$where: $summary\n  culprits: ${culprits.join(', ')}');
}
