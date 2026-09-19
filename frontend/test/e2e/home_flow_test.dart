// Drives Jobs, Chats, Me and the centre action through the real UI against a
// running API seeded with demo data:
//
//   cd backend && npm run dev:memory
//   cd frontend && flutter test test/e2e/home_flow_test.dart --dart-define=TR_E2E=true

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talentradar/main.dart';
import 'package:talentradar/widgets/tr_components.dart';

const bool _enabled = bool.fromEnvironment('TR_E2E');
const String _api = 'http://localhost:4000/api/v1';
const String _password = 'StrongPass123';

Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body, {String? token}) async {
  final response = await http.post(
    Uri.parse('$_api$path'),
    headers: {'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'},
    body: jsonEncode(body),
  );
  return jsonDecode(response.body) as Map<String, dynamic>;
}

Future<Map<String, dynamic>> _put(String path, Map<String, dynamic> body, String token) async {
  final response = await http.put(
    Uri.parse('$_api$path'),
    headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
    body: jsonEncode(body),
  );
  return jsonDecode(response.body) as Map<String, dynamic>;
}

/// A fresh, verified candidate in HSR Layout — next to the demo recruiters.
Future<String> _createCandidate(String email, String name) async {
  final registered = await _post('/auth/register/candidate', {
    'name': name,
    'email': email,
    'password': _password,
    'jobTitleCodes': ['JT_042', 'JT_040'],
    'workModes': ['onsite', 'hybrid'],
    'openToWork': 'actively_looking',
  });
  final data = registered['data'] as Map<String, dynamic>;
  final token = data['token'] as String;
  final userId = (data['user'] as Map<String, dynamic>)['userId'] as String;
  final code = (data['verification'] as Map<String, dynamic>)['devCode'] as String;
  await _post('/auth/verify-email', {'userId': userId, 'code': code});
  await _put('/candidates/me/location', {'source': 'manual', 'area': 'HSR Layout', 'city': 'Bengaluru'}, token);
  return token;
}

Future<void> pumpUntil(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 25)}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
    await tester.pump(const Duration(milliseconds: 120));
    if (finder.evaluate().isNotEmpty) {
      await tester.pump(const Duration(milliseconds: 600));
      return;
    }
  }
  // Show what was on screen instead, so a failure explains itself.
  final visible = find
      .byType(Text)
      .evaluate()
      .map((element) => (element.widget as Text).data)
      .whereType<String>()
      .take(25)
      .join(' | ');
  throw TestFailure('Timed out waiting for $finder. On screen: $visible');
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.ensureVisible(finder.first);
  await tester.pump(const Duration(seconds: 1));
  await tester.tap(finder.first);
  await tester.pump();
}

/// Lets real network calls complete between frames for [seconds].
Future<void> settle(WidgetTester tester, {int seconds = 2}) async {
  for (var i = 0; i < seconds * 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> bootAndLogin(WidgetTester tester, {required String email, required bool recruiter}) async {
  HttpOverrides.global = null;
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(412 * 2.625, 892 * 2.625);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(ProviderScope(key: UniqueKey(), child: const TalentRadarApp()));
  await pumpUntil(tester, find.text('Get started'));
  await tester.tap(find.text('Log in').first);
  await pumpUntil(tester, find.text('CONTINUE AS'));
  if (recruiter) await tapVisible(tester, find.text('HR / Recruiter'));
  await tester.enterText(find.widgetWithText(TextField, 'you@example.com'), email);
  await tester.enterText(find.widgetWithText(TextField, 'Your password'), recruiter ? 'Demo@1234' : _password);
  await tapVisible(tester, find.text(recruiter ? 'Continue as recruiter' : 'Continue as candidate'));
}

Future<void> finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await settle(tester, seconds: 3);
}

void main() {
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final candidateEmail = 'meera.$stamp@example.com';
  // Unique per run, so repeated runs never pick up an older test candidate.
  final candidateName = 'Meera ${String.fromCharCodes('$stamp'.substring(7).codeUnits.map((unit) => unit + 49))}';

  setUpAll(() async {
    if (!_enabled) return;
    HttpOverrides.global = null;
    await _createCandidate(candidateEmail, candidateName);
  });

  testWidgets('candidate: radar → jobs → save → meet in person → chat → go live → stealth', (tester) async {
    await bootAndLogin(tester, email: candidateEmail, recruiter: false);

    // Radar with real nearby roles from the demo recruiters.
    await pumpUntil(tester, find.text('Near you today'));
    await pumpUntil(tester, find.text('Open near you'));
    expect(find.textContaining('HSR Layout, Bengaluru'), findsWidgets);
    expect(find.text('Customer Support Executive'), findsWidgets);

    // Jobs tab: filter walk-ins.
    await tester.tap(find.text('Jobs').last);
    await pumpUntil(tester, find.textContaining('within 10 km'));
    await tapVisible(tester, find.text('Walk-ins'));
    await pumpUntil(tester, find.textContaining('walk-in'));
    expect(find.text('Meet in person'), findsWidgets);

    // Save the first walk-in.
    await tapVisible(tester, find.byTooltip('Save'));
    await pumpUntil(tester, find.textContaining('remind you 2 hours before'));

    // Meet in person → chat opens with the automatic intro.
    await tapVisible(tester, find.text('Meet in person'));
    await pumpUntil(tester, find.textContaining("I'm interested in the"));
    await tester.enterText(find.widgetWithText(TextField, 'Write a message…'), 'Can I come in at 11 AM?');
    await tapVisible(tester, find.bySemanticsLabel('Send message'));
    await pumpUntil(tester, find.text('Can I come in at 11 AM?'));

    // Back to home → Chats lists the conversation.
    await tester.pageBack();
    await settle(tester);
    await tester.tap(find.text('Chats').last);
    await pumpUntil(tester, find.text('RECENT'));
    expect(find.textContaining('You: Can I come in at 11 AM?'), findsOneWidget);

    // Centre action: go live.
    await tester.tap(find.bySemanticsLabel('Go live as available today'));
    await pumpUntil(tester, find.text("I'm available today"));
    await tapVisible(tester, find.text("I'm available today"));
    await pumpUntil(tester, find.textContaining('You are live until midnight'));

    // Me tab reflects it; saved list holds the walk-in.
    await tester.tap(find.text('Me').last);
    await pumpUntil(tester, find.text('Live today'));
    await tapVisible(tester, find.text('Saved'));
    await pumpUntil(tester, find.text('Jobs · 1'));
    expect(find.textContaining('Saved walk-ins send you a reminder'), findsOneWidget);
    await tester.pageBack();
    await settle(tester);

    // Privacy: stealth mode on → radar shows the ninja banner.
    await tapVisible(tester, find.text('Privacy & stealth mode'));
    await pumpUntil(tester, find.text('Stealth mode'));
    await tester.tap(find.byType(TrToggle).first); // stealth is the first switch
    await pumpUntil(tester, find.textContaining('Stealth mode on.'));
    await tester.pageBack();
    await settle(tester);
    await tester.tap(find.text('Radar').last);
    await pumpUntil(tester, find.textContaining('Ninja mode is on'));

    // Stealth off again so the recruiter test can find this candidate.
    await tester.tap(find.text('Privacy').last);
    await pumpUntil(tester, find.text('Stealth mode'));
    await tester.tap(find.byType(TrToggle).first); // stealth is the first switch
    await pumpUntil(tester, find.textContaining('Stealth mode off.'));

    await finish(tester);
  }, skip: !_enabled);

  testWidgets('recruiter: talent radar → post walk-in → invite candidate', (tester) async {
    await bootAndLogin(tester, email: 'riya.joshi@demo.talentradar.app', recruiter: true);

    await pumpUntil(tester, find.text('Talent near you'));
    await pumpUntil(tester, find.text(candidateName));
    expect(find.textContaining('available today'), findsWidgets);

    // Post a walk-in from the centre button.
    await tester.tap(find.bySemanticsLabel('Post a role or walk-in'));
    await pumpUntil(tester, find.text('Post a role'));
    await tapVisible(tester, find.text('Search the role you are hiring for...'));
    await pumpUntil(tester, find.byType(DraggableScrollableSheet));
    await tester.enterText(find.byType(TextField).last, 'tele');
    final option = find.descendant(of: find.byType(ListView), matching: find.text('Tele-support Associate'));
    await pumpUntil(tester, option);
    await tester.tap(option.first);
    await tester.pump();
    await tester.tap(find.textContaining('Done ·'));
    await settle(tester, seconds: 1);
    await tapVisible(tester, find.bySemanticsLabel('Walk-in interview'));
    await tapVisible(tester, find.text('Post walk-in'));
    await pumpUntil(tester, find.textContaining('Posted. Candidates near your hiring location'));

    // Roles tab lists it.
    await tester.tap(find.text('Roles').last);
    await pumpUntil(tester, find.text('Tele-support Associate'));

    // Invite the candidate from the radar card.
    await tester.tap(find.text('Radar').last);
    await pumpUntil(tester, find.text(candidateName));
    final card = find.ancestor(of: find.text(candidateName), matching: find.byType(InkWell)).first;
    await tapVisible(tester, find.descendant(of: card, matching: find.text('Invite')));
    await pumpUntil(tester, find.text('Interview invite'));
    await tester.enterText(find.widgetWithText(TextField, 'e.g. Customer Support Executive'), 'Customer Support Executive');
    await tapVisible(tester, find.text('Send invite'));
    await pumpUntil(tester, find.text('Interview invite sent.'));
    expect(find.text('Awaiting reply'), findsOneWidget);

    await finish(tester);
  }, skip: !_enabled);

  testWidgets('candidate accepts the interview invite', (tester) async {
    await bootAndLogin(tester, email: candidateEmail, recruiter: false);
    await pumpUntil(tester, find.text('Near you today'));
    await tester.tap(find.text('Chats').last);
    await pumpUntil(tester, find.textContaining('Interview invite · Customer Support Executive'));
    await tapVisible(tester, find.text('Riya Joshi'));
    await pumpUntil(tester, find.text('Accept'));
    await tapVisible(tester, find.text('Accept'));
    await pumpUntil(tester, find.textContaining('accepted the interview invite'));
    expect(find.text('Accepted'), findsOneWidget);
    await finish(tester);
  }, skip: !_enabled);
}
