import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tr_colors.dart';
import 'tr_typography.dart';

/// Shape and spacing tokens. The design leans on very round corners — pills for
/// actions and chips, 20-26px for cards, 16px for inputs.
abstract final class TrRadius {
  static const double input = 16;
  static const double card = 22;
  static const double largeCard = 26;
  static const double sheet = 32;
  static const double pill = 100;

  static BorderRadius get inputR => BorderRadius.circular(input);
  static BorderRadius get cardR => BorderRadius.circular(card);
  static BorderRadius get largeCardR => BorderRadius.circular(largeCard);
  static BorderRadius get pillR => BorderRadius.circular(pill);
  static BorderRadius get sheetTop =>
      const BorderRadius.vertical(top: Radius.circular(sheet));
}

abstract final class TrSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 22;
  static const double xxl = 28;

  /// Horizontal padding used by every screen body.
  static const EdgeInsets screen = EdgeInsets.symmetric(horizontal: 22);
}

abstract final class TrTheme {
  static ThemeData build() {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: TrColors.plumInk,
      primary: TrColors.plumInk,
      onPrimary: Colors.white,
      secondary: TrColors.lime,
      onSecondary: TrColors.plumInk,
      surface: TrColors.card,
      onSurface: TrColors.plumInk,
      error: TrColors.error,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: TrColors.canvas,
      fontFamily: TrType.body,
      textTheme: TrType.textTheme,
      splashFactory: InkRipple.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: TrColors.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TrType.sectionTitle,
        iconTheme: const IconThemeData(color: TrColors.plumInk),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      dividerTheme: const DividerThemeData(
        color: TrColors.border,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: TrColors.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        hintStyle: TrType.bodySmall.copyWith(color: TrColors.icon, fontSize: 14.5),
        border: OutlineInputBorder(
          borderRadius: TrRadius.inputR,
          borderSide: const BorderSide(color: TrColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: TrRadius.inputR,
          borderSide: const BorderSide(color: TrColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: TrRadius.inputR,
          borderSide: const BorderSide(color: TrColors.plumInk, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: TrRadius.inputR,
          borderSide: const BorderSide(color: TrColors.error, width: 1.4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: TrRadius.inputR,
          borderSide: const BorderSide(color: TrColors.error, width: 1.8),
        ),
        errorStyle: TrType.bodySmall.copyWith(color: TrColors.error, fontSize: 12.5),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: TrColors.plumInk,
        contentTextStyle: TrType.bodySmall.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: TrRadius.inputR),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: TrColors.canvas,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: TrRadius.sheetTop),
      ),
      // Touch targets stay at or above 48dp everywhere.
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }
}
