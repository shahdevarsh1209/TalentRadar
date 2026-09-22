import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talentradar/main.dart';

/// Shared plumbing for the end-to-end suites, which drive the real widgets
/// against a real API rather than mocks. Run the server first:
///
///   cd backend && npm run dev:local
///   cd frontend && flutter test test/e2e --dart-define=TR_E2E=true

const bool e2eEnabled = bool.fromEnvironment('TR_E2E');
const String api = 'http://localhost:4000/api/v1';
const String demoPassword = 'Demo@1234';
const String testPassword = 'StrongPass123';

Future<Map<String, dynamic>> apiPost(
  String path,
  Map<String, dynamic> body, {
  String? token,
}) async {
  final response = await http.post(
    Uri.parse('$api$path'),
    headers: {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    },
    body: jsonEncode(body),
  );
  return jsonDecode(response.body) as Map<String, dynamic>;
}

Future<Map<String, dynamic>> apiPut(String path, Map<String, dynamic> body, String token) async {
  final response = await http.put(
    Uri.parse('$api$path'),
    headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
    body: jsonEncode(body),
  );
  return jsonDecode(response.body) as Map<String, dynamic>;
}

/// A fresh, verified candidate in HSR Layout — next to the demo recruiters.
Future<String> createCandidate(String email, String name) async {
  final registered = await apiPost('/auth/register/candidate', {
    'name': name,
    'email': email,
    'password': testPassword,
    'jobTitleCodes': ['JT_042', 'JT_040'],
    'workModes': ['onsite', 'hybrid'],
    'openToWork': 'actively_looking',
  });
  final data = registered['data'] as Map<String, dynamic>;
  final token = data['token'] as String;
  final userId = (data['user'] as Map<String, dynamic>)['userId'] as String;
  final code = (data['verification'] as Map<String, dynamic>)['devCode'] as String;
  await apiPost('/auth/verify-email', {'userId': userId, 'code': code});
  await apiPut(
    '/candidates/me/location',
    {'source': 'manual', 'area': 'HSR Layout', 'city': 'Bengaluru'},
    token,
  );
  return token;
}

/// Pumps frames, letting real network calls complete, until [finder] matches.
Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 25),
}) async {
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

Future<void> bootAndLogin(
  WidgetTester tester, {
  required String email,
  required bool recruiter,
  String password = testPassword,
}) async {
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
  await tester.enterText(find.widgetWithText(TextField, 'Your password'), password);
  await tapVisible(
    tester,
    find.text(recruiter ? 'Continue as recruiter' : 'Continue as candidate'),
  );
}

/// Tears the app down and lets any in-flight poll finish, so a pending timer
/// does not fail the next test.
Future<void> finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await settle(tester, seconds: 3);
}
