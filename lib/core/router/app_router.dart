import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/login_screen.dart';
import '../../features/onboarding/splash_screen.dart';
import '../../features/onboarding/welcome_screen.dart';
import '../../features/radar/radar_screen.dart';
import '../../features/registration/candidate_registration_screen.dart';
import '../../features/registration/email_verification_screen.dart';
import '../../features/registration/hiring_location_screen.dart';
import '../../features/registration/location_setup_screen.dart';
import '../../features/registration/registration_success_screen.dart';
import '../../features/registration/recruiter_registration_screen.dart';
import '../../features/registration/role_selection_screen.dart';
import '../../state/session_controller.dart';

abstract final class Routes {
  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String login = '/login';
  static const String chooseRole = '/register';
  static const String candidateRegistration = '/register/candidate';
  static const String recruiterRegistration = '/register/recruiter';
  static const String verifyEmail = '/register/verify';
  static const String candidateLocation = '/register/location';
  static const String hiringLocation = '/register/hiring-location';
  static const String success = '/register/done';
  static const String radar = '/radar';
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.splash,
    // Only the radar is gated. The registration screens deliberately stay
    // reachable while a session exists but onboarding is unfinished, otherwise
    // verification and location would bounce the user straight past them.
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      if (state.matchedLocation == Routes.radar && session == null) {
        return Routes.welcome;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.chooseRole,
        builder: (context, state) => const RoleSelectionScreen(),
      ),
      GoRoute(
        path: Routes.candidateRegistration,
        builder: (context, state) => const CandidateRegistrationScreen(),
      ),
      GoRoute(
        path: Routes.recruiterRegistration,
        builder: (context, state) => const RecruiterRegistrationScreen(),
      ),
      GoRoute(
        path: Routes.verifyEmail,
        builder: (context, state) => const EmailVerificationScreen(),
      ),
      GoRoute(
        path: Routes.candidateLocation,
        builder: (context, state) => const LocationSetupScreen(),
      ),
      GoRoute(
        path: Routes.hiringLocation,
        builder: (context, state) => const HiringLocationScreen(),
      ),
      GoRoute(
        path: Routes.success,
        builder: (context, state) => const RegistrationSuccessScreen(),
      ),
      GoRoute(
        path: Routes.radar,
        builder: (context, state) => const RadarScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('We could not open that screen.'),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go(Routes.welcome),
                child: const Text('Back to start'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
});
