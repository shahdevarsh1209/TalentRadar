// Drives Jobs, Chats, Me and the centre action through the real UI against a
// running API seeded with demo data:
//
//   cd backend && npm run dev:local
//   cd frontend && flutter test test/e2e --dart-define=TR_E2E=true

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talentradar/widgets/tr_components.dart';

import 'support/e2e.dart';

void main() {
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final candidateEmail = 'meera.$stamp@example.com';
  // Unique per run, so repeated runs never pick up an older test candidate.
  final candidateName = 'Meera ${String.fromCharCodes('$stamp'.substring(7).codeUnits.map((unit) => unit + 49))}';

  setUpAll(() async {
    if (!e2eEnabled) return;
    HttpOverrides.global = null;
    await createCandidate(candidateEmail, candidateName);
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
  }, skip: !e2eEnabled);

  testWidgets('recruiter: talent radar → post walk-in → invite candidate', (tester) async {
    await bootAndLogin(tester, email: 'riya.joshi@demo.talentradar.app', recruiter: true, password: demoPassword);

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
  }, skip: !e2eEnabled);

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
  }, skip: !e2eEnabled);
}
