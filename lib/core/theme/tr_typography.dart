import 'package:flutter/material.dart';

import 'tr_colors.dart';

/// Type scale from the design: Sora for titles, wordmark and numbers;
/// Work Sans for everything a person reads as a sentence.
///
/// Both faces are bundled as variable fonts, so each style sets the weight twice
/// — `fontWeight` for layout and hit-testing, `fontVariations` so the renderer
/// actually moves along the wght axis.
abstract final class TrType {
  static const String display = 'Sora';
  static const String body = 'WorkSans';

  static TextStyle _sora(double size, int weight, {double? height, double? spacing, Color? color}) {
    return TextStyle(
      fontFamily: display,
      fontSize: size,
      height: height,
      letterSpacing: spacing,
      color: color ?? TrColors.plumInk,
      fontWeight: FontWeight.values[(weight ~/ 100) - 1],
      fontVariations: [FontVariation('wght', weight.toDouble())],
    );
  }

  static TextStyle _work(double size, int weight, {double? height, double? spacing, Color? color}) {
    return TextStyle(
      fontFamily: body,
      fontSize: size,
      height: height,
      letterSpacing: spacing,
      color: color ?? TrColors.plumInk,
      fontWeight: FontWeight.values[(weight ~/ 100) - 1],
      fontVariations: [FontVariation('wght', weight.toDouble())],
    );
  }

  // Titles — Sora
  static TextStyle get hero => _sora(31, 700, height: 1.15, spacing: -0.6);
  static TextStyle get screenTitle => _sora(26, 700, height: 1.2, spacing: -0.5);
  static TextStyle get sectionTitle => _sora(20, 700, height: 1.25, spacing: -0.3);
  static TextStyle get cardTitle => _sora(17, 600, height: 1.3);
  static TextStyle get wordmark => _sora(19, 700, spacing: -0.2);
  static TextStyle get stat => _sora(17, 700, height: 1);

  // Body — Work Sans
  static TextStyle get bodyLarge => _work(15.5, 400, height: 1.55, color: TrColors.bodyMuted);
  static TextStyle get bodyText => _work(15, 400, height: 1.5);
  static TextStyle get bodySmall => _work(13.5, 400, height: 1.45, color: TrColors.bodyMuted);
  static TextStyle get itemTitle => _work(15, 700, height: 1.3);
  static TextStyle get itemMeta => _work(12.5, 400, height: 1.4, color: TrColors.bodyMuted);

  // Labels & controls
  static TextStyle get label => _work(12.5, 600, color: TrColors.bodyMuted);
  static TextStyle get button => _work(15, 700, color: Colors.white);
  static TextStyle get chip => _work(12.5, 600);
  static TextStyle get tag => _work(11.5, 700);
  static TextStyle get navLabel => _work(10.5, 600);

  /// Uppercase eyebrow above a group of fields.
  static TextStyle get eyebrow => _work(11.5, 700, spacing: 0.7, color: TrColors.icon);

  static TextTheme get textTheme => TextTheme(
        displayLarge: hero,
        headlineLarge: screenTitle,
        headlineMedium: sectionTitle,
        titleLarge: cardTitle,
        titleMedium: itemTitle,
        bodyLarge: bodyText,
        bodyMedium: bodySmall,
        labelLarge: button,
        labelMedium: label,
        labelSmall: tag,
      );
}
