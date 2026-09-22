import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/login_screen.dart';
import '../../features/chat/chat_screen.dart';
import '../../features/chat/requests_screen.dart';
import '../../features/home/home_shell.dart';
import '../../features/jobs/search_screen.dart';
import '../../features/onboarding/splash_screen.dart';
import '../../features/people/company_view_screen.dart';
import '../../features/people/recruiter_profile_screen.dart';
import '../../features/onboarding/welcome_screen.dart';
import '../../features/profile/blocked_screen.dart';
import '../../features/profile/company_profile_screen.dart';
import '../../features/profile/help_screen.dart';
import '../../features/profile/edit_profile_screen.dart';
import '../../features/profile/privacy_screen.dart';
import '../../features/profile/saved_screen.dart';
import '../../features/registration/candidate_registration_screen.dart';
import '../../features/registration/email_verification_screen.dart';
import '../../features/registration/hiring_location_screen.dart';
import '../../features/registration/location_setup_screen.dart';
import '../../features/registration/recruiter_registration_screen.dart';
import '../../features/registration/registration_success_screen.dart';
import '../../features/registration/role_selection_screen.dart';
import '../../features/roles/job_interests_screen.dart';
import '../../features/roles/post_job_screen.dart';
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
  static const String search = '/search';
  static const String postJob = '/post-job';
  static const String requests = '/requests';
  static const String saved = '/saved';
  static const String privacy = '/privacy';
  static const String editProfile = '/profile/edit';
  static const String company = '/company';
  static const String blocked = '/privacy/blocked';
  static const String help = '/help';

  static String chat(String conversationId) => '/chat/$conversationId';
  static String jobInterests(String jobId) => '/roles/$jobId/interests';

  /// The recruiter behind a job, chat or search result, and their company.
  static String recruiter(String userId) => '/recruiter/$userId';
  static String companyProfile(String companyId) => '/company/$companyId';

  /// Location screens reused from the Me tab return there instead of
  /// continuing the onboarding flow.
  static String changeLocation({required bool recruiter}) =>
      '${recruiter ? hiringLocation : candidateLocation}?from=profile';
}

/// Routes that need a signed-in session.
const _protected = [
  Routes.radar,
  Routes.search,
  Routes.postJob,
  Routes.requests,
  Routes.saved,
  Routes.privacy,
  Routes.editProfile,
  Routes.company,
  Routes.blocked,
  Routes.help,
  '/chat/',
  '/roles/',
  '/recruiter/',
  '/company/',
];

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.splash,
    // Registration screens stay reachable while onboarding is unfinished;
    // everything inside the app needs a session.
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final path = state.matchedLocation;
      final needsSession = _protected.any((prefix) => path == prefix || path.startsWith(prefix));
      if (needsSession && session == null) return Routes.welcome;
      return null;
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (context, state) => const SplashScreen()),
      GoRoute(path: Routes.welcome, builder: (context, state) => const WelcomeScreen()),
      GoRoute(path: Routes.login, builder: (context, state) => const LoginScreen()),
      GoRoute(path: Routes.chooseRole, builder: (context, state) => const RoleSelectionScreen()),
      GoRoute(
        path: Routes.candidateRegistration,
        builder: (context, state) => const CandidateRegistrationScreen(),
      ),
      GoRoute(
        path: Routes.recruiterRegistration,
        builder: (context, state) => const RecruiterRegistrationScreen(),
      ),
      GoRoute(path: Routes.verifyEmail, builder: (context, state) => const EmailVerificationScreen()),
      GoRoute(
        path: Routes.candidateLocation,
        builder: (context, state) => LocationSetupScreen(
          returnAfterSave: state.uri.queryParameters['from'] == 'profile',
        ),
      ),
      GoRoute(
        path: Routes.hiringLocation,
        builder: (context, state) => HiringLocationScreen(
          returnAfterSave: state.uri.queryParameters['from'] == 'profile',
        ),
      ),
      GoRoute(path: Routes.success, builder: (context, state) => const RegistrationSuccessScreen()),
      GoRoute(path: Routes.radar, builder: (context, state) => const HomeShell()),
      GoRoute(
        path: Routes.search,
        builder: (context, state) => SearchScreen(initialQuery: state.uri.queryParameters['q'] ?? ''),
      ),
      GoRoute(path: Routes.postJob, builder: (context, state) => const PostJobScreen()),
      GoRoute(path: Routes.requests, builder: (context, state) => const RequestsScreen()),
      GoRoute(path: Routes.saved, builder: (context, state) => const SavedScreen()),
      GoRoute(path: Routes.privacy, builder: (context, state) => const PrivacyScreen()),
      GoRoute(path: Routes.editProfile, builder: (context, state) => const EditProfileScreen()),
      GoRoute(path: Routes.company, builder: (context, state) => const CompanyProfileScreen()),
      GoRoute(path: Routes.blocked, builder: (context, state) => const BlockedScreen()),
      GoRoute(path: Routes.help, builder: (context, state) => const HelpScreen()),
      GoRoute(
        path: '/chat/:conversationId',
        builder: (context, state) =>
            ChatScreen(
              conversationId: state.pathParameters['conversationId']!,
              openInviteComposer: state.uri.queryParameters['compose'] == 'invite',
            ),
      ),
      GoRoute(
        path: '/roles/:jobId/interests',
        builder: (context, state) => JobInterestsScreen(jobId: state.pathParameters['jobId']!),
      ),
      GoRoute(
        path: '/recruiter/:userId',
        builder: (context, state) =>
            RecruiterProfileScreen(userId: state.pathParameters['userId']!),
      ),
      GoRoute(
        path: '/company/:companyId',
        builder: (context, state) =>
            CompanyViewScreen(companyId: state.pathParameters['companyId']!),
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
