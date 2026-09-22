// The discovery ecosystem, driven through the real UI against a running API
// seeded with demo data:
//
//   Candidate → Search → Hiring role → HR → Company → Job → Chat
//
//   cd backend && npm run dev:local
//   cd frontend && flutter test test/e2e/discovery_flow_test.dart --dart-define=TR_E2E=true

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/e2e.dart';

void main() {
  testWidgets('candidate: search a role → who is hiring → HR profile → company → chat',
      (tester) async {
    await bootAndLogin(
      tester,
      email: 'priya.kulkarni@demo.talentradar.app',
      password: demoPassword,
      recruiter: false,
    );
    await pumpUntil(tester, find.text('Near you today'));

    // Search is reached from the radar's search bar.
    await tapVisible(tester, find.text('Roles, skills, companies'));
    await pumpUntil(tester, find.text('Search'));
    await tester.enterText(find.byType(TextField).first, 'support');
    await pumpUntil(tester, find.textContaining('Jobs · '));

    // "Which companies are hiring for this?"
    await tapVisible(tester, find.text('Companies'));
    await pumpUntil(tester, find.textContaining('Hiring now'));

    // "Who is the HR behind it?"
    await tapVisible(tester, find.text('Recruiters'));
    await pumpUntil(tester, find.text('View HR'));
    expect(find.textContaining('Hiring now'), findsWidgets);
    expect(find.text('HIRING FOR'), findsWidgets);

    // Open the recruiter profile.
    await tapVisible(tester, find.text('View HR'));
    await pumpUntil(tester, find.text('CURRENTLY HIRING FOR'));
    expect(find.text('Riya Joshi'), findsWidgets);
    // The roles listed are live ones, with their openings.
    expect(find.textContaining('opening'), findsWidgets);

    // The company behind the recruiter.
    await tapVisible(tester, find.text('BrightDesk Support'));
    await pumpUntil(tester, find.text('OPEN ROLES'));
    expect(find.text('WHO TO TALK TO'), findsOneWidget);
    await tester.pageBack();
    await settle(tester);

    // And a chat with them, from the profile.
    await pumpUntil(tester, find.text('Message'));
    await tapVisible(tester, find.text('Message'));
    await pumpUntil(tester, find.text('Write a message…'));

    // The chat header opens the same recruiter profile — no dead end.
    // Wait for the conversation to load: until it does the title reads "Chat".
    await pumpUntil(tester, find.text('Riya Joshi'));
    await tapVisible(tester, find.text('Riya Joshi'));
    await pumpUntil(tester, find.text('CURRENTLY HIRING FOR'));

    await finish(tester);
  }, skip: !e2eEnabled);

  testWidgets('recruiter: search candidates by skill', (tester) async {
    await bootAndLogin(
      tester,
      email: 'riya.joshi@demo.talentradar.app',
      password: demoPassword,
      recruiter: true,
    );
    await pumpUntil(tester, find.text('Talent near you'));

    await tapVisible(tester, find.byTooltip('Search and filters'));
    await pumpUntil(tester, find.text('Search'));
    expect(find.textContaining('Candidates'), findsWidgets);
    // A recruiter is not offered other recruiters to browse.
    expect(find.textContaining('Recruiters ·'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'support');
    await pumpUntil(tester, find.textContaining('Candidates · '));
    expect(find.text('Message'), findsWidgets);
    expect(find.text('Invite'), findsWidgets);

    await finish(tester);
  }, skip: !e2eEnabled);
}
