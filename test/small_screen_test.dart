import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talentradar/core/theme/tr_theme.dart';
import 'package:talentradar/features/onboarding/welcome_screen.dart';
import 'package:talentradar/features/registration/candidate_registration_screen.dart';
import 'package:talentradar/features/registration/recruiter_registration_screen.dart';
import 'package:talentradar/features/registration/role_selection_screen.dart';

/// Layout must hold on the smallest common Android phone (320 x 568 dp) and at
/// the largest text scale the app allows. A RenderFlex overflow fails the test.
void main() {
  const sizes = <String, Size>{
    'small phone 320x568': Size(320, 568),
    'standard phone 412x892': Size(412, 892),
  };
  const scales = [1.0, 1.3];

  final screens = <String, Widget>{
    'welcome': const WelcomeScreen(),
    'role selection': const RoleSelectionScreen(),
    'candidate registration': const CandidateRegistrationScreen(),
    'recruiter registration': const RecruiterRegistrationScreen(),
  };

  for (final size in sizes.entries) {
    for (final scale in scales) {
      for (final screen in screens.entries) {
        testWidgets('${screen.key} fits on ${size.key} at ${scale}x text', (tester) async {
          tester.view.physicalSize = size.value * 3;
          tester.view.devicePixelRatio = 3;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(ProviderScope(
            child: MaterialApp(
              theme: TrTheme.build(),
              home: MediaQuery(
                data: MediaQueryData(
                  size: size.value,
                  textScaler: TextScaler.linear(scale),
                ),
                child: screen.value,
              ),
            ),
          ));
          await tester.pump(const Duration(milliseconds: 600));

          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
