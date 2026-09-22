import 'package:flutter/material.dart';

/// TalentRadar palette (app design v2).
///
/// Plum is the brand ink and every primary action; lime is reserved for the
/// "live / nearby / available" signal and never used as decoration; clay marks
/// urgency such as a closing walk-in. Keeping those three meanings separate is
/// what makes the radar readable at a glance.
abstract final class TrColors {
  // Brand
  static const Color plumInk = Color(0xFF361534);
  static const Color plumDeep = Color(0xFF220C21);
  static const Color plumSurface = Color(0xFFF7EAF5);

  // Live / available signal
  static const Color lime = Color(0xFFA4D854);
  static const Color limeSurface = Color(0xFFE3F7CC);
  static const Color limeText = Color(0xFF3A5800);

  // Urgency / alert
  static const Color clay = Color(0xFFD96A42);
  static const Color claySurface = Color(0xFFFFE6DB);
  static const Color clayText = Color(0xFF842C02);

  // Neutrals
  static const Color canvas = Color(0xFFFBF6F2);
  static const Color pageCanvas = Color(0xFFF1EBE6);
  static const Color card = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE6E0DB);
  static const Color borderStrong = Color(0xFFD6D0CB);
  static const Color bodyMuted = Color(0xFF6A5F69);
  static const Color icon = Color(0xFF8C838A);

  // Feedback
  static const Color error = Color(0xFFC0341A);
  static const Color errorSurface = Color(0xFFFDECE7);
  static const Color success = limeText;

  /// Soft elevation used by every card in the design.
  static List<BoxShadow> get cardShadow => const [
        BoxShadow(
          color: Color(0x0D361534),
          blurRadius: 10,
          offset: Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get raisedShadow => const [
        BoxShadow(
          color: Color(0x1A361534),
          blurRadius: 24,
          offset: Offset(0, 10),
        ),
      ];

  /// Avatar / company-chip tints, picked deterministically from a name so the
  /// same person keeps the same colour between sessions.
  static const List<(Color background, Color foreground)> avatarTints = [
    (plumSurface, plumInk),
    (limeSurface, limeText),
    (claySurface, clayText),
  ];

  static (Color, Color) tintFor(String seed) {
    if (seed.isEmpty) return avatarTints.first;
    final int hash = seed.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
    return avatarTints[hash % avatarTints.length];
  }
}
