import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talentradar/core/network/api_client.dart';
import 'package:talentradar/core/theme/tr_theme.dart';
import 'package:talentradar/data/models/chat.dart';
import 'package:talentradar/data/models/job.dart';
import 'package:talentradar/data/models/people.dart';
import 'package:talentradar/data/models/session.dart';
import 'package:talentradar/data/repositories/social_repository.dart';
import 'package:talentradar/features/chat/chat_screen.dart';
import 'package:talentradar/features/chat/requests_screen.dart';
import 'package:talentradar/features/home/home_shell.dart';
import 'package:talentradar/features/live/go_live_sheet.dart';
import 'package:talentradar/features/profile/edit_profile_screen.dart';
import 'package:talentradar/features/profile/privacy_screen.dart';
import 'package:talentradar/features/profile/saved_screen.dart';
import 'package:talentradar/features/roles/post_job_screen.dart';
import 'package:talentradar/state/home_providers.dart';
import 'package:talentradar/state/session_controller.dart';

/// Every home screen must hold on the smallest common phone at the largest
/// allowed text scale. Data is faked; a RenderFlex overflow fails the test.

Map<String, dynamic> _title(String code, String name) => {'code': code, 'name': name, 'category': 'Support'};

final _location = {'area': 'HSR Layout', 'city': 'Bengaluru', 'label': 'HSR Layout, Bengaluru', 'isSet': true};

final Session candidateSession = Session.fromJson({
  'token': 't',
  'user': {'userId': 'c1', 'email': 'aditi.sharma@example.com', 'role': 'candidate', 'isEmailVerified': true, 'onboardingStage': 'complete'},
  'profile': {
    'name': 'Aditi Venkataraman Sharma',
    'email': 'aditi.sharma@example.com',
    'headline': 'Software Support Executive with ERP implementation experience',
    'jobTitles': [_title('JT_040', 'Software Support Executive'), _title('JT_049', 'ERP Functional Consultant')],
    'experienceLevel': '1_2',
    'workModes': ['hybrid', 'onsite', 'remote'],
    'openToWork': 'actively_looking',
    'profileVisibility': 'recruiters_only',
    'stealthMode': false,
    'availableToday': true,
    'skills': ['Zendesk', 'Freshdesk', 'SAP MM', 'Customer support', 'Excel'],
    'location': _location,
    'profileCompletion': 75,
  },
});

final Session recruiterSession = Session.fromJson({
  'token': 't',
  'user': {'userId': 'r1', 'email': 'riya@brightdesk.example.com', 'role': 'recruiter', 'isEmailVerified': true, 'onboardingStage': 'complete'},
  'profile': {
    'companyName': 'BrightDesk Customer Experience Private Limited',
    'hrName': 'Riya Joshi',
    'email': 'riya@brightdesk.example.com',
    'designation': 'Senior Talent Acquisition Manager',
    'hiringProfiles': [_title('JT_042', 'Customer Support Executive'), _title('JT_045', 'Tele-support Associate')],
    'hiringWorkModes': ['onsite', 'hybrid'],
    'hiringLocations': [_location],
    'hiringRadiusKm': 10,
    'profileCompletion': 62,
  },
});

Job _job(String id, {bool walkIn = false}) => Job.fromJson({
      'jobId': id,
      'recruiterUserId': 'r1',
      'companyName': 'BrightDesk Customer Experience Private Limited',
      'title': _title('JT_042', 'Customer Support Executive (Voice & Chat Process)'),
      'workMode': walkIn ? 'onsite' : 'hybrid',
      'experienceLevel': '12_plus',
      'openings': 12,
      'salaryMin': 220000,
      'salaryMax': 2800000,
      'isWalkIn': walkIn,
      'walkIn': walkIn
          ? {'date': DateTime.now().toIso8601String(), 'startTime': '10:00', 'endTime': '16:30', 'address': '27th Main Road, HSR Layout Sector 2'}
          : null,
      'walkInToday': walkIn,
      'closingSoon': !walkIn,
      'matchesProfile': true,
      'distanceKm': 4.5,
      'location': _location,
      'interestCount': 14,
      'createdAt': DateTime.now().toIso8601String(),
    });

final _person = PersonSummary.fromJson({
  'userId': 'p1',
  'role': 'recruiter',
  'name': 'Riya Joshi-Venkatachalam',
  'initials': 'RJ',
  'headline': 'Senior Talent Acquisition Manager',
  'subtitle': 'Senior Talent Acquisition Manager · BrightDesk Customer Experience',
});

final _candidate = CandidateCard.fromJson({
  'userId': 'k1',
  'name': 'Priyadarshini Kulkarni',
  'initials': 'PK',
  'headline': 'Customer Support Executive',
  'jobTitles': [_title('JT_042', 'Customer Support Executive')],
  'experienceLevel': '2_3',
  'workModes': ['onsite'],
  'openToWork': 'actively_looking',
  'availableToday': true,
  'area': 'Jayanagar, Bengaluru',
  'distanceKm': 4.5,
  'matchesHiring': true,
});

class _FakeSession extends SessionController {
  _FakeSession(super.ref, Session session) {
    state = session;
  }
}

class _FakeSocial extends SocialRepository {
  _FakeSocial() : super(ApiClient());

  @override
  Future<({ConversationSummary conversation, List<ChatMessage> messages})> messages(
    String conversationId, {
    String? after,
  }) async {
    if (after != null) return (conversation: _conversation, messages: <ChatMessage>[]);
    return (
      conversation: _conversation,
      messages: [
        ChatMessage.fromJson({
          'messageId': 'm1', 'senderId': 'p1', 'kind': 'text',
          'text': 'Hi Aditi, thanks for connecting. Are you open to a quick chat about the role this week?',
          'createdAt': DateTime.now().toIso8601String(),
        }),
        ChatMessage.fromJson({
          'messageId': 'm2', 'senderId': 'p1', 'kind': 'interview_invite', 'text': '',
          'invite': {
            'title': 'Customer Support Executive (Voice & Chat Process)', 'round': 'Round 1 — HR and operations',
            'scheduledAt': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
            'mode': 'in_person', 'location': 'Koramangala office, 3rd floor', 'status': 'reschedule_requested',
          },
          'createdAt': DateTime.now().toIso8601String(),
        }),
        ChatMessage.fromJson({
          'messageId': 'm3', 'senderId': 'c1', 'kind': 'system', 'text': 'Aditi asked to reschedule the interview.',
          'createdAt': DateTime.now().toIso8601String(),
        }),
      ],
    );
  }

  static final _conversation = ConversationSummary(conversationId: 'x', person: _person);
}

List<Override> _overrides(Session session) => [
      sessionProvider.overrideWith((ref) => _FakeSession(ref, session)),
      socialRepositoryProvider.overrideWithValue(_FakeSocial()),
      jobListProvider.overrideWith(
        (ref, query) async => JobList(
          jobs: [_job('j1', walkIn: true), _job('j2')],
          meta: JobListMeta(total: 2, nearbyCount: 2, walkInsToday: 1, hasLocation: true, updatedAt: DateTime.now()),
        ),
      ),
      myJobsProvider.overrideWith((ref) async => [_job('j1', walkIn: true), _job('j2')]),
      nearbyCandidatesProvider.overrideWith(
        (ref, query) async => CandidateList(candidates: [_candidate], availableToday: 1, hasLocation: true),
      ),
      savedProvider.overrideWith((ref) async => (jobs: [_job('j1', walkIn: true)], people: [_person])),
      conversationsProvider.overrideWith(
        (ref) async => [
          ConversationSummary(
            conversationId: 'x',
            person: _person,
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
              person: _person,
              status: ConnectionStatus.pendingReceived,
              message: 'Hi Aditi, we have a UX Researcher role open near you. Would love to chat this week.',
            ),
          ],
          connections: [ConnectionItem(connectionId: 'q2', person: _person, status: ConnectionStatus.connected, at: DateTime.now())],
        ),
      ),
      recruitersViewedProvider.overrideWith((ref) async => 7),
      badgesProvider.overrideWith((ref) => Stream.value(const Badges(unreadChats: 12, pendingRequests: 3))),
    ];

Future<void> _render(WidgetTester tester, Size size, double scale, Session session, Widget screen) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: _overrides(session),
    child: MaterialApp(
      theme: TrTheme.build(),
      home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: screen,
      ),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

/// Fails with Flutter's diagnostic, naming the offending widget's file and line.
void expectNoLayoutError(WidgetTester tester, String where) {
  final error = tester.takeException();
  if (error == null) return;
  final detail = error is FlutterError ? error.toStringDeep() : '$error';
  final culprits = RegExp(r'file:///\S+/lib/\S+')
      .allMatches(detail)
      .map((match) => match.group(0)!.split('/lib/').last)
      .toSet();
  fail('$where: ${detail.split('\n').first.trim()} at ${culprits.join(', ')}');
}

void main() {
  const sizes = {'320x568': Size(320, 568), '412x892': Size(412, 892)};
  const scales = [1.0, 1.3];

  for (final size in sizes.entries) {
    for (final scale in scales) {
      final label = '${size.key} @ ${scale}x';

      for (final (role, session) in [('candidate', candidateSession), ('recruiter', recruiterSession)]) {
        testWidgets('$role home tabs fit on $label', (tester) async {
          await _render(tester, size.value, scale, session, const HomeShell());
          expectNoLayoutError(tester, 'Radar tab');
          for (final tab in [role == 'candidate' ? 'Jobs' : 'Roles', 'Chats', 'Me']) {
            await tester.tap(find.text(tab).last);
            await tester.pump(const Duration(milliseconds: 400));
            expectNoLayoutError(tester, '$tab tab');
          }
        });

        testWidgets('$role saved, requests, edit profile fit on $label', (tester) async {
          for (final screen in const [SavedScreen(), RequestsScreen(), EditProfileScreen()]) {
            await _render(tester, size.value, scale, session, screen);
            expectNoLayoutError(tester, screen.runtimeType.toString());
          }
        });
      }

      testWidgets('candidate privacy, go-live and chat fit on $label', (tester) async {
        for (final screen in const [
          PrivacyScreen(),
          Scaffold(body: SingleChildScrollView(child: GoLiveSheet())),
          ChatScreen(conversationId: 'x'),
        ]) {
          await _render(tester, size.value, scale, candidateSession, screen);
          expectNoLayoutError(tester, screen.runtimeType.toString());
        }
        // The chat's polling timer must not outlive the test.
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets('recruiter post-a-role and chat fit on $label', (tester) async {
        await _render(tester, size.value, scale, recruiterSession, const PostJobScreen());
        expectNoLayoutError(tester, 'PostJobScreen');
        await tester.ensureVisible(find.text('Walk-in interview'));
        await tester.tap(find.bySemanticsLabel('Walk-in interview').first, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 300));
        expectNoLayoutError(tester, 'PostJobScreen walk-in');

        await _render(tester, size.value, scale, recruiterSession, const ChatScreen(conversationId: 'x'));
        expectNoLayoutError(tester, 'ChatScreen');
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
