import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talentradar/core/theme/tr_theme.dart';
import 'package:talentradar/data/models/hiring.dart';
import 'package:talentradar/features/jobs/search_screen.dart';
import 'package:talentradar/features/people/company_view_screen.dart';
import 'package:talentradar/features/people/recruiter_profile_screen.dart';
import 'package:talentradar/features/profile/blocked_screen.dart';
import 'package:talentradar/features/profile/help_screen.dart';
import 'package:talentradar/state/home_providers.dart';

import 'support/fakes.dart';

/// The discovery screens — recruiter profile, company profile, search — must
/// hold on the smallest common phone at the largest allowed text scale, with
/// the longest plausible company and role names. A RenderFlex overflow fails.

const _recruiterId = 'r9';
const _companyId = 'co9';

Map<String, dynamic> _role(String code, String name, {bool hiring = true, int openings = 3}) => {
      'code': code,
      'name': name,
      'category': 'Technology',
      'hiringNow': hiring,
      'openings': hiring ? openings : 0,
      'jobId': hiring ? 'j-$code' : null,
      'isWalkIn': code == 'JT_003',
      'area': 'Prahlad Nagar, Ahmedabad',
    };

final _recruiterDetail = RecruiterDetail.fromJson({
  'recruiter': {
    'userId': _recruiterId,
    'role': 'recruiter',
    'name': 'Rahulkumar Venkataraman Sharma',
    'initials': 'RS',
    'designation': 'Senior Manager — Talent Acquisition & Campus Hiring',
    'companyId': _companyId,
    'companyName': 'ABC Technologies and Business Solutions Private Limited',
    'companyIndustry': 'Information Technology & Services',
    'companySize': '201-500 employees',
    'verifiedEmailDomain': true,
    'companyVerification': 'unverified',
    'area': 'Prahlad Nagar, Ahmedabad',
    'city': 'Ahmedabad',
    'distanceKm': 4.2,
    'hiringWorkModes': ['onsite', 'hybrid'],
    'hiringRadiusKm': 15,
    'memberSince': DateTime(2024, 3, 2).toIso8601String(),
    'saved': true,
    'isSelf': false,
  },
  'hiringNow': true,
  'totalOpenings': 11,
  'openJobCount': 4,
  'roles': [
    _role('JT_001', 'Senior Flutter Application Developer (Android & iOS)'),
    _role('JT_003', 'Enterprise Resource Planning Functional Consultant', openings: 2),
    _role('JT_009', 'Quality Assurance Automation Engineer', hiring: false),
  ],
  'connectionStatus': 'none',
  'connectionId': null,
  'canMessage': true,
});

final _companyProfile = CompanyProfile.fromJson({
  'company': {
    'companyId': _companyId,
    'name': 'ABC Technologies and Business Solutions Private Limited',
    'initials': 'AT',
    'description':
        'We build enterprise software for logistics and retail across India, with delivery centres in '
            'Ahmedabad, Bengaluru and Pune, and a support desk operating around the clock.',
    'industry': 'Information Technology & Services',
    'size': '201-500 employees',
    'website': 'https://www.abc-technologies-and-business-solutions.example.com/careers',
    'linkedinUrl': 'https://www.linkedin.com/company/abc-technologies-business-solutions',
    'verificationStatus': 'unverified',
    'area': 'Prahlad Nagar, Ahmedabad',
    'city': 'Ahmedabad',
    'distanceKm': 4.2,
  },
  'hiringNow': true,
  'totalOpenings': 11,
  'roles': [
    _role('JT_001', 'Senior Flutter Application Developer (Android & iOS)'),
    _role('JT_003', 'Enterprise Resource Planning Functional Consultant', openings: 2),
  ],
  'jobs': [longJob('j1', walkIn: true), longJob('j2')],
  'recruiters': [
    {
      'userId': _recruiterId,
      'role': 'recruiter',
      'name': 'Rahulkumar Venkataraman Sharma',
      'initials': 'RS',
      'designation': 'Senior Manager — Talent Acquisition',
      'companyId': _companyId,
      'companyName': 'ABC Technologies and Business Solutions Private Limited',
      'subtitle': 'Senior Manager — Talent Acquisition · ABC Technologies and Business Solutions',
    },
  ],
});

SearchResults _results(String type) => SearchResults.fromJson({
      'results': {
        'jobs': [longJobJson('j1', walkIn: true), longJobJson('j2')],
        'companies': [
          {
            'companyId': _companyId,
            'name': 'ABC Technologies and Business Solutions Private Limited',
            'initials': 'AT',
            'industry': 'Information Technology & Services',
            'size': '201-500 employees',
            'area': 'Prahlad Nagar, Ahmedabad',
            'distanceKm': 4.2,
            'hiringNow': true,
            'totalOpenings': 11,
            'openRoles': [
              _role('JT_001', 'Senior Flutter Application Developer (Android & iOS)'),
              _role('JT_003', 'Enterprise Resource Planning Functional Consultant'),
            ],
          },
        ],
        'recruiters': [
          {
            'userId': _recruiterId,
            'name': 'Rahulkumar Venkataraman Sharma',
            'initials': 'RS',
            'designation': 'Senior Manager — Talent Acquisition & Campus Hiring',
            'companyId': _companyId,
            'companyName': 'ABC Technologies and Business Solutions Private Limited',
            'area': 'Prahlad Nagar, Ahmedabad',
            'distanceKm': 4.2,
            'hiringNow': true,
            'totalOpenings': 11,
            'openRoles': [
              _role('JT_001', 'Senior Flutter Application Developer (Android & iOS)'),
            ],
            'saved': false,
            'connectionStatus': 'pending_sent',
          },
        ],
        'candidates': [longCandidateJson()],
      },
      'counts': {'jobs': 2, 'companies': 1, 'recruiters': 1, 'candidates': 1},
      'meta': {'hasLocation': true, 'areaLabel': 'Prahlad Nagar, Ahmedabad', 'radiusKm': 10},
    });

List<Override> _overrides(Session session) => [
      ...baseOverrides(session),
      recruiterProfileProvider.overrideWith((ref, userId) async => _recruiterDetail),
      companyProfileProvider.overrideWith((ref, companyId) async => _companyProfile),
      searchProvider.overrideWith((ref, query) async => _results(query.type)),
      blockedPeopleProvider.overrideWith((ref) async => [
            {
              'userId': 'b1',
              'role': 'recruiter',
              'name': 'Someone With A Very Long Blocked Name Indeed',
              'initials': 'SB',
              'subtitle': 'Recruiter · A Company With A Long Name Limited',
            },
          ]),
    ];

Future<void> _render(WidgetTester tester, Size size, double scale, Session session, Widget screen) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    // A fresh key per render, so a screen rendered twice in one test does not
    // reuse the previous State (and with it the previous role's tabs).
    key: UniqueKey(),
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

void main() {
  const sizes = {'320x568': Size(320, 568), '412x892': Size(412, 892)};
  const scales = [1.0, 1.3];

  for (final size in sizes.entries) {
    for (final scale in scales) {
      final label = '${size.key} @ ${scale}x';

      testWidgets('recruiter and company profiles fit on $label', (tester) async {
        await _render(tester, size.value, scale, candidateSession, const RecruiterProfileScreen(userId: _recruiterId));
        expectNoLayoutError(tester, 'RecruiterProfileScreen');

        await _render(tester, size.value, scale, candidateSession, const CompanyViewScreen(companyId: _companyId));
        expectNoLayoutError(tester, 'CompanyViewScreen');
      });

      testWidgets('candidate search tabs fit on $label', (tester) async {
        await _render(tester, size.value, scale, candidateSession, const SearchScreen());
        expectNoLayoutError(tester, 'SearchScreen jobs');

        for (final tab in ['Companies', 'Recruiters']) {
          await tester.tap(find.textContaining(tab).first);
          await tester.pump(const Duration(milliseconds: 400));
          expectNoLayoutError(tester, 'SearchScreen $tab');
        }
      });

      testWidgets('recruiter search fits on $label', (tester) async {
        await _render(tester, size.value, scale, recruiterSession, const SearchScreen());
        expectNoLayoutError(tester, 'SearchScreen candidates');
      });

      testWidgets('blocked and help fit on $label', (tester) async {
        await _render(tester, size.value, scale, candidateSession, const BlockedScreen());
        expectNoLayoutError(tester, 'BlockedScreen');

        await _render(tester, size.value, scale, candidateSession, const HelpScreen());
        // Open every answer: a collapsed panel proves nothing about its text.
        // Questions are re-found each time, because expanding rebuilds the list.
        // On a small screen the later questions are not built until scrolled to.
        for (final question in ['Who can see my profile?', 'What is a walk-in?']) {
          await tester.scrollUntilVisible(find.text(question), 120, maxScrolls: 20);
          await tester.tap(find.text(question));
          await tester.pump(const Duration(milliseconds: 150));
          expectNoLayoutError(tester, 'HelpScreen — "$question"');
        }
      });
    }
  }

  testWidgets('search tabs differ by role', (tester) async {
    await _render(tester, const Size(412, 892), 1.0, candidateSession, const SearchScreen());
    expect(find.textContaining('Companies'), findsOneWidget);
    expect(find.textContaining('Recruiters'), findsOneWidget);
    expect(find.textContaining('Candidates'), findsNothing);

    await _render(tester, const Size(412, 892), 1.0, recruiterSession, const SearchScreen());
    expect(find.textContaining('Candidates'), findsOneWidget);
    // A recruiter has no business browsing other recruiters' profiles here.
    expect(find.textContaining('Recruiters'), findsNothing);
  });

  testWidgets('a role with no openings is not shown as hiring', (tester) async {
    await _render(
      tester,
      const Size(412, 892),
      1.0,
      candidateSession,
      const RecruiterProfileScreen(userId: _recruiterId),
    );
    // The two live roles are listed under "currently hiring"...
    expect(find.text('Senior Flutter Application Developer (Android & iOS)'), findsOneWidget);
    // ...and the closed one is only under "also recruits for".
    expect(find.text('ALSO RECRUITS FOR'), findsOneWidget);
    expect(find.text('Quality Assurance Automation Engineer'), findsOneWidget);
  });
}
