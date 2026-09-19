import 'package:flutter/material.dart';

import '../core/theme/tr_colors.dart';
import '../core/theme/tr_typography.dart';

/// The radar mark: two concentric rings and a contact dot off-centre, drawn on a
/// rounded plum tile. Rings read as "scanning", the dot as "someone is nearby" —
/// the same idea the lime signal colour carries through the rest of the app.
class TrLogoMark extends StatelessWidget {
  const TrLogoMark({
    super.key,
    this.size = 30,
    this.background = TrColors.plumInk,
    this.foreground = TrColors.lime,
    this.showContact = true,
  });

  final double size;
  final Color background;
  final Color foreground;

  /// The lime dot. Hidden for the smallest sizes where it would blur.
  final bool showContact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'TalentRadar',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(size / 3),
        ),
        child: Center(
          child: CustomPaint(
            size: Size.square(size * 0.6),
            painter: _RadarPainter(
              color: foreground,
              showContact: showContact && size >= 24,
            ),
          ),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  const _RadarPainter({required this.color, required this.showContact});

  final Color color;
  final bool showContact;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final stroke = size.width * 0.115;

    final ring = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius - stroke / 2, ring);
    canvas.drawCircle(center, radius * 0.44, ring);

    if (showContact) {
      canvas.drawCircle(
        center + Offset(radius * 0.72, -radius * 0.72),
        stroke * 1.15,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_RadarPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.showContact != showContact;
}

/// Mark plus wordmark, as used on the splash and the auth screens.
class TrWordmark extends StatelessWidget {
  const TrWordmark({
    super.key,
    this.onDark = false,
    this.markSize = 30,
    this.textStyle,
  });

  final bool onDark;
  final double markSize;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TrLogoMark(
          size: markSize,
          background: onDark ? TrColors.lime : TrColors.plumInk,
          foreground: onDark ? TrColors.plumInk : TrColors.lime,
        ),
        const SizedBox(width: 9),
        Flexible(
          child: Text(
            'TalentRadar',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (textStyle ?? TrType.wordmark).copyWith(
              color: onDark ? Colors.white : TrColors.plumInk,
            ),
          ),
        ),
      ],
    );
  }
}
