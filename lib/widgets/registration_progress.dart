import 'package:flutter/material.dart';

import '../core/theme/tr_colors.dart';
import '../core/theme/tr_typography.dart';

/// "Step 1 of 1 — Professional Profile" plus its bar.
///
/// The step count covers only the form itself; verification and location are
/// shown as their own screens so registration keeps feeling like one short step.
class RegistrationProgress extends StatelessWidget {
  const RegistrationProgress({
    super.key,
    required this.step,
    required this.totalSteps,
    required this.label,
  });

  final int step;
  final int totalSteps;
  final String label;

  @override
  Widget build(BuildContext context) {
    final double value = totalSteps == 0 ? 1 : step / totalSteps;

    return Semantics(
      label: 'Step $step of $totalSteps, $label',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Step $step of $totalSteps — $label',
            style: TrType.eyebrow,
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value),
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
              builder: (context, animated, _) => LinearProgressIndicator(
                value: animated,
                minHeight: 5,
                backgroundColor: TrColors.border,
                valueColor: const AlwaysStoppedAnimation(TrColors.lime),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
