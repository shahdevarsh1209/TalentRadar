import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talentradar/core/theme/tr_theme.dart';
import 'package:talentradar/features/chat/chat_screen.dart';
import 'package:talentradar/features/chat/requests_screen.dart';
import 'package:talentradar/features/home/home_shell.dart';
import 'package:talentradar/features/live/go_live_sheet.dart';
import 'package:talentradar/features/profile/edit_profile_screen.dart';
import 'package:talentradar/features/profile/privacy_screen.dart';
import 'package:talentradar/features/profile/saved_screen.dart';
import 'package:talentradar/features/roles/post_job_screen.dart';

import 'support/fakes.dart';

/// Every home screen must hold on the smallest common phone at the largest
/// allowed text scale. Data is faked; a RenderFlex overflow fails the test.

Future<void> _render(
  WidgetTester tester,
  Size size,
  double scale,
  Session session,
  Widget screen,
) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    // A fresh key per render, so a screen rendered twice in one test does not
    // reuse the previous State (and with it the previous role's tabs).
    key: UniqueKey(),
    overrides: baseOverrides(session),
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

void main() {
  const sizes = {'320x568': Size(320, 568), '412x892': Size(412, 892)};
  const scales = [1.0, 1.3];

  for (final size in sizes.entries) {
    for (final scale in scales) {
      final label = '${size.key} @ ${scale}x';

      for (final (role, session) in [
        ('candidate', candidateSession),
        ('recruiter', recruiterSession),
      ]) {
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

  testWidgets('a short message gets a bubble its own size', (tester) async {
    await _render(
      tester,
      const Size(412, 892),
      1.0,
      candidateSession,
      const ChatScreen(conversationId: 'x'),
    );
    expectNoLayoutError(tester, 'ChatScreen');

    // The "Hi" bubble must not stretch to the 78%-of-width cap the long
    // message fills — a regression guard for the Align that used to do so.
    final short = tester.getSize(find.ancestor(
      of: find.text('Hi'),
      matching: find.byType(Container),
    ).first);
    expect(short.width, lessThan(412 * 0.4));

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
