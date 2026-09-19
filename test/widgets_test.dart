import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talentradar/core/theme/tr_theme.dart';
import 'package:talentradar/data/models/enums.dart';
import 'package:talentradar/widgets/job_title_chip.dart';
import 'package:talentradar/widgets/option_selectors.dart';
import 'package:talentradar/widgets/otp_input.dart';
import 'package:talentradar/widgets/primary_cta.dart';
import 'package:talentradar/widgets/role_selection_card.dart';

Widget _host(Widget child) => MaterialApp(
      theme: TrTheme.build(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  testWidgets('PrimaryCta shows loading label and ignores taps while loading',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(PrimaryCta(
      label: 'Create Candidate Profile',
      loadingLabel: 'Creating Profile...',
      isLoading: true,
      onPressed: () => taps++,
    )));

    expect(find.text('Creating Profile...'), findsOneWidget);
    await tester.tap(find.text('Creating Profile...'));
    expect(taps, 0);
  });

  testWidgets('PrimaryCta disabled state blocks taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(PrimaryCta(
      label: 'Continue',
      enabled: false,
      onPressed: () => taps++,
    )));
    await tester.tap(find.text('Continue'));
    expect(taps, 0);
  });

  testWidgets('RoleSelectionCard shows role copy and reports taps', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_host(RoleSelectionCard(
      role: UserRole.recruiter,
      selected: false,
      onTap: () => tapped = true,
    )));

    expect(find.text("I'm hiring talent"), findsOneWidget);
    await tester.tap(find.text('HR / Recruiter'));
    expect(tapped, isTrue);
  });

  testWidgets('WorkModeSelector is multi-select and includes Hybrid', (tester) async {
    List<WorkMode> selected = [WorkMode.remote];
    await tester.pumpWidget(_host(StatefulBuilder(
      builder: (context, setState) => WorkModeSelector(
        selected: selected,
        onChanged: (modes) => setState(() => selected = modes),
      ),
    )));

    await tester.tap(find.text('Hybrid'));
    await tester.pump();
    expect(selected, containsAll([WorkMode.remote, WorkMode.hybrid]));

    await tester.tap(find.text('Online / Remote'));
    await tester.pump();
    expect(selected, [WorkMode.hybrid]);
  });

  testWidgets('Open-to-work "not looking" explains ninja mode', (tester) async {
    await tester.pumpWidget(_host(OpenToWorkSelector(
      value: OpenToWork.notLooking,
      onChanged: (_) {},
    )));
    expect(find.textContaining('Ninja mode will be switched on'), findsOneWidget);
  });

  testWidgets('JobTitleChip remove button fires', (tester) async {
    var removed = false;
    await tester.pumpWidget(_host(JobTitleChip(
      label: 'ERP Functional Consultant',
      onRemove: () => removed = true,
    )));
    await tester.tap(find.byIcon(Icons.close_rounded));
    expect(removed, isTrue);
  });

  testWidgets('OtpInput completes after six digits', (tester) async {
    final controller = TextEditingController();
    String? completed;
    await tester.pumpWidget(_host(OtpInput(
      controller: controller,
      onCompleted: (code) => completed = code,
    )));

    await tester.enterText(find.byType(TextField), '482915');
    await tester.pump();
    expect(completed, '482915');
    expect(find.text('4'), findsOneWidget);
  });
}
