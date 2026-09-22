import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/tr_colors.dart';
import '../../core/theme/tr_typography.dart';
import '../../widgets/primary_cta.dart';
import '../../widgets/tr_logo.dart';

/// The first screen a new person sees: what the product does, and the two ways
/// in. Deliberately short — the real decision is the role, one screen later.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TrColors.plumInk,
      body: SafeArea(
        // Scrolls on short phones and at large text sizes; on taller screens the
        // min-height keeps the copy and CTA anchored to the bottom as designed.
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(26, 22, 26, 26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const TrWordmark(onDark: true, markSize: 32),
                      const Spacer(),
                      // Illustration yields space first when the screen is short.
                      _RadarIllustration(
                        maxHeight: constraints.maxHeight * 0.32,
                      ),
                      const SizedBox(height: 34),
                      Text(
                        'Work happens\nclose to home.',
                        style: TrType.hero.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'See who is hiring, who is available and what is happening within walking distance of you.',
                        style: TrType.bodyLarge.copyWith(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(height: 30),
                      PrimaryCta(
                        label: 'Get started',
                        variant: CtaVariant.lime,
                        icon: Icons.arrow_forward_rounded,
                        onPressed: () => context.push(Routes.chooseRole),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Already here?',
                              style: TrType.bodySmall.copyWith(
                                color: Colors.white.withValues(alpha: 0.72),
                              ),
                            ),
                            TrTextAction(
                              label: 'Log in',
                              color: TrColors.lime,
                              onPressed: () => context.push(Routes.login),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Stand-in hero: concentric radar rings with people nearby. Drawn rather than
/// shipped as an asset so it scales cleanly on every screen size.
class _RadarIllustration extends StatelessWidget {
  const _RadarIllustration({required this.maxHeight});

  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: AspectRatio(
        aspectRatio: 1.25,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(28),
          ),
          child: CustomPaint(painter: _RadarScenePainter()),
        ),
      ),
    );
  }
}

class _RadarScenePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.shortestSide * 0.44;

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = Colors.white.withValues(alpha: 0.16);

    for (int i = 3; i >= 1; i--) {
      canvas.drawCircle(center, maxRadius * (i / 3), ring);
    }

    // The user, centred and lime — everything else is measured against them.
    canvas.drawCircle(center, 7, Paint()..color = TrColors.lime);
    canvas.drawCircle(
      center,
      15,
      Paint()..color = TrColors.lime.withValues(alpha: 0.22),
    );

    // Nearby people and openings at plausible bearings.
    const contacts = <(double angle, double distance, bool isOpening)>[
      (-0.6, 0.62, true),
      (2.1, 0.78, false),
      (3.6, 0.5, false),
      (5.1, 0.85, true),
      (1.2, 0.34, false),
    ];

    for (final (angle, distance, isOpening) in contacts) {
      final radius = maxRadius * distance;
      final offset =
          center + Offset(radius * math.cos(angle), radius * math.sin(angle));

      if (isOpening) {
        final rect = RRect.fromRectAndRadius(
          Rect.fromCenter(center: offset, width: 26, height: 26),
          const Radius.circular(9),
        );
        canvas.drawRRect(
          rect,
          Paint()..color = Colors.white.withValues(alpha: 0.9),
        );
      } else {
        canvas.drawCircle(
          offset,
          11,
          Paint()..color = Colors.white.withValues(alpha: 0.32),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RadarScenePainter oldDelegate) => false;
}
