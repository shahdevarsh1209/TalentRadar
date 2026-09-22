// Drives the real registration UI against a running API.
//
//   cd backend && npm start
//   cd frontend && flutter test test/e2e --dart-define=TR_E2E=true
//
// Skipped by default so `flutter test` stays hermetic.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talentradar/main.dart';

const bool _enabled = bool.fromEnvironment('TR_E2E');

/// Lets real sockets and timers run, then renders, until [finder] appears.
Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
    await tester.pump(const Duration(milliseconds: 120));
    if (finder.evaluate().isNotEmpty) {
      // Let any route transition finish; routes ignore taps while animating.
      await tester.pump(const Duration(milliseconds: 600));
      return;
    }
  }
  throw TestFailure('Timed out waiting for $finder');
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  // Tapping outside a field closes the keyboard first, as it does on a phone.
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.ensureVisible(finder.first);
  // A focused field animates its caret into view; scroll views ignore taps
  // until that animation ends.
  await tester.pump(const Duration(seconds: 1));
  await tester.tap(finder.first);
  await tester.pump();
}

Future<void> pickTitle(WidgetTester tester, String fieldHint, String query, String title) async {
  await tapVisible(tester, find.text(fieldHint));
  await pumpUntil(tester, find.byType(DraggableScrollableSheet));
  await tester.enterText(find.byType(TextField).last, query);
  await pumpUntil(tester, find.text(title));
  await tester.tap(find.text(title).last);
  await tester.pump();
  await tester.tap(find.textContaining('Done ·'));
  await tester.pumpAndSettle();
}

Future<void> verifyWithDevCode(WidgetTester tester) async {
  final codeFinder = find.textContaining('Development build — your code is');
  await pumpUntil(tester, codeFinder);
  final text = (codeFinder.evaluate().first.widget as Text).data!;
  final code = RegExp(r'(\d{6})').firstMatch(text)!.group(1)!;
  await tester.enterText(find.byType(TextField).first, code);
  await tester.pump();
}

Future<void> chooseManualArea(WidgetTester tester, String cardTitle, String area) async {
  await tapVisible(tester, find.text(cardTitle));
  await pumpUntil(tester, find.byType(DraggableScrollableSheet));
  await tester.enterText(find.byType(TextField).last, area);
  final row = find.descendant(of: find.byType(ListView), matching: find.text(area));
  await pumpUntil(tester, row);
  await tester.tap(row.first);
  await tester.pump();
  // The sheet's CTA reads 'Use <area>, <city>'.
  await tester.tap(find.textContaining(RegExp(r'^Use .+, ')));
  await tester.pumpAndSettle();
}

Future<void> bootApp(WidgetTester tester) async {
  HttpOverrides.global = null; // flutter_test blocks real HTTP by default.
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(412 * 2.625, 892 * 2.625);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(const ProviderScope(child: TalentRadarApp()));
  await pumpUntil(tester, find.text('Get started'));
}

/// Unmounts the app and lets in-flight requests (the badge poller) finish, so
/// no request timeout timer outlives the test.
Future<void> finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump(const Duration(seconds: 1));
  }
}

void main() {
  final stamp = DateTime.now().millisecondsSinceEpoch;

  testWidgets('candidate: role → form → OTP → manual area → radar', (tester) async {
    await bootApp(tester);

    await tester.tap(find.text('Get started'));
    await pumpUntil(tester, find.text('Join TalentRadar'));

    await tester.tap(find.text('Candidate'));
    await pumpUntil(tester, find.text('Create Your Candidate Profile'));
    expect(find.text('Step 1 of 1 — Professional Profile'), findsOneWidget);

    // Required-field gate: CTA stays disabled until the four required answers.
    await tester.enterText(find.widgetWithText(TextField, 'Enter your full name'), 'Aditi Sharma');
    await tester.enterText(
      find.widgetWithText(TextField, 'you@example.com'),
      'aditi.e2e.$stamp@gmail.com',
    );
    // Live availability check against the API marks the address as free.
    await pumpUntil(tester, find.byIcon(Icons.check_circle_rounded));
    await pickTitle(tester, 'Search your job title...', 'software', 'Software Support Executive');
    expect(find.text('Software Support Executive'), findsOneWidget);
    await pickTitle(tester, 'Add another title', 'erp', 'ERP Functional Consultant');
    expect(find.text('ERP Functional Consultant'), findsOneWidget);

    await tapVisible(tester, find.text('Hybrid'));
    await tapVisible(tester, find.text('Actively looking'));

    await tapVisible(tester, find.text('Create Candidate Profile'));
    await pumpUntil(tester, find.text('Verify Your Email'));
    // Gmail dots are stripped server-side so one inbox cannot register twice.
    expect(find.text('aditie2e$stamp@gmail.com'), findsOneWidget);

    await verifyWithDevCode(tester);
    await pumpUntil(tester, find.text('Discover Opportunities Near You'));
    expect(find.text('Your exact location is never publicly displayed.'), findsOneWidget);

    await chooseManualArea(tester, 'Choose Location Manually', 'HSR Layout');
    expect(find.text('HSR Layout, Bengaluru'), findsOneWidget);

    await tapVisible(tester, find.text('Continue'));
    await pumpUntil(tester, find.text('Welcome to TalentRadar 👋'));
    expect(find.textContaining('Actively looking'), findsWidgets);

    await tapVisible(tester, find.text('Open my radar'));
    await pumpUntil(tester, find.text('Near you today'));
    expect(find.textContaining('HSR Layout, Bengaluru'), findsOneWidget);
    await finish(tester);
  }, skip: !_enabled);

  testWidgets('recruiter: form → OTP → hiring location → ready screen', (tester) async {
    await bootApp(tester);

    await tester.tap(find.text('Get started'));
    await pumpUntil(tester, find.text('Join TalentRadar'));
    await tester.tap(find.text('HR / Recruiter'));
    await pumpUntil(tester, find.text('Create Your Hiring Profile'));

    await tester.enterText(find.widgetWithText(TextField, 'Enter company name'), 'ABC Technologies');
    await tester.enterText(find.widgetWithText(TextField, 'Enter your name'), 'Riya Joshi');
    await tester.enterText(
      find.widgetWithText(TextField, 'hr@company.com'),
      'riya.e2e.$stamp@abctechnologies.com',
    );
    await pumpUntil(tester, find.byIcon(Icons.check_circle_rounded));
    await pickTitle(tester, 'Search roles you are hiring for...', 'account', 'Senior Accountant');
    await pickTitle(tester, 'Add another title', 'flutter', 'Flutter Developer');

    await tapVisible(tester, find.text('Create Hiring Profile'));
    await pumpUntil(tester, find.text('Verify Your Email'));

    await verifyWithDevCode(tester);
    await pumpUntil(tester, find.text('Where Are You Hiring?'));
    expect(find.textContaining('Your personal location is never shown'), findsOneWidget);

    await chooseManualArea(tester, 'Search Location', 'Prahlad Nagar');
    await tapVisible(tester, find.text('25 km'));
    await tapVisible(tester, find.text('Continue'));

    await pumpUntil(tester, find.text('Your Hiring Profile is Ready'));
    // An earlier registration created 'ABC Technologies Pvt Ltd'; the same
    // company under a different spelling is joined, not duplicated.
    expect(find.textContaining('ABC Technologies'), findsWidgets);
    expect(find.text('Senior Accountant'), findsOneWidget);
    expect(find.textContaining('Prahlad Nagar, Ahmedabad · within 25 km'), findsOneWidget);
    expect(find.text('Explore Nearby Talent'), findsOneWidget);
    expect(find.text('Complete Company Profile'), findsOneWidget);
    await finish(tester);
  }, skip: !_enabled);

  testWidgets('duplicate email is flagged on the form before submitting', (tester) async {
    await bootApp(tester);

    await tester.tap(find.text('Get started'));
    await pumpUntil(tester, find.text('Join TalentRadar'));
    await tester.tap(find.text('HR / Recruiter'));
    await pumpUntil(tester, find.text('Create Your Hiring Profile'));

    // Registered as a candidate by the first test.
    await tester.enterText(
      find.widgetWithText(TextField, 'hr@company.com'),
      'aditi.e2e.$stamp@gmail.com',
    );
    await pumpUntil(tester, find.textContaining('already registered as a candidate'));
    expect(find.text('Log in'), findsWidgets);
  }, skip: !_enabled);
}
