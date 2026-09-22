import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/tr_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Portrait only: every screen in the design is a phone layout.
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const ProviderScope(child: TalentRadarApp()));
}

class TalentRadarApp extends ConsumerWidget {
  const TalentRadarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'TalentRadar',
      debugShowCheckedModeBanner: false,
      theme: TrTheme.build(),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) {
        // Honour the user's text size, but cap it so forms stay usable on
        // small phones at the largest accessibility settings.
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.3),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
