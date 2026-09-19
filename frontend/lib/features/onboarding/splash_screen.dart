import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/tr_colors.dart';
import '../../core/theme/tr_typography.dart';
import '../../state/session_controller.dart';
import '../../widgets/tr_logo.dart';

/// Brand moment while a stored session is restored. Whatever the outcome, the
/// user lands somewhere useful — the radar if signed in, the welcome otherwise.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    // Hold the logo long enough to read, while the session restores behind it.
    await Future.wait([
      ref.read(sessionProvider.notifier).restore(),
      Future<void>.delayed(const Duration(milliseconds: 900)),
    ]);
    if (!mounted) return;

    final session = ref.read(sessionProvider);
    context.go(session == null ? Routes.welcome : Routes.radar);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TrColors.plumInk,
      body: Center(
        child: FadeTransition(
          opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOut),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: Tween<double>(begin: 0.82, end: 1).animate(
                  CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
                ),
                child: const TrLogoMark(
                  size: 84,
                  background: TrColors.lime,
                  foreground: TrColors.plumInk,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'TalentRadar',
                style: TrType.screenTitle.copyWith(color: Colors.white, fontSize: 27),
              ),
              const SizedBox(height: 8),
              Text(
                'Work happens close to home.',
                style: TrType.bodySmall.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
