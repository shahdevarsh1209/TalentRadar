import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Environment wiring. Override the host at build time:
///   flutter run --dart-define=TR_API_BASE_URL=https://api.talentradar.app/api/v1
abstract final class AppConfig {
  static const String _override = String.fromEnvironment('TR_API_BASE_URL');

  static const Duration requestTimeout = Duration(seconds: 20);

  /// How long the job-title field waits after a keystroke before searching.
  static const Duration searchDebounce = Duration(milliseconds: 280);

  static String get apiBaseUrl {
    if (_override.isNotEmpty) return _override;
    // The Android emulator reaches the host machine on 10.0.2.2, not localhost.
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:4000/api/v1';
    return 'http://localhost:4000/api/v1';
  }

  static const String appName = 'TalentRadar';
  static const String tagline =
      'Discover opportunities. Connect with professionals. Grow locally.';
}
