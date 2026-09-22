import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../data/models/enums.dart';
import '../data/models/registration_draft.dart';
import '../data/models/session.dart';
import 'providers.dart';
import 'session_controller.dart';

enum SubmitStatus { idle, submitting, success }

/// Everything the registration flow needs, held above the screens so back
/// navigation and role switching never lose what has been typed.
@immutable
class RegistrationState {
  const RegistrationState({
    this.role,
    this.candidate = const CandidateDraft(),
    this.recruiter = const RecruiterDraft(),
    this.status = SubmitStatus.idle,
    this.error,
    this.challenge,
    this.pendingUserId,
    this.locationChoice,
  });

  final UserRole? role;
  final CandidateDraft candidate;
  final RecruiterDraft recruiter;
  final SubmitStatus status;

  /// Last failure, kept so a screen can show it inline and retry.
  final ApiException? error;

  /// Outstanding email verification, if registration has been submitted.
  final VerificationChallenge? challenge;
  final String? pendingUserId;
  final LocationChoice? locationChoice;

  bool get isSubmitting => status == SubmitStatus.submitting;

  bool get hasDraftContent => switch (role) {
        UserRole.candidate => candidate.hasContent,
        UserRole.recruiter => recruiter.hasContent,
        null => false,
      };

  RegistrationState copyWith({
    UserRole? role,
    CandidateDraft? candidate,
    RecruiterDraft? recruiter,
    SubmitStatus? status,
    ApiException? error,
    bool clearError = false,
    VerificationChallenge? challenge,
    String? pendingUserId,
    LocationChoice? locationChoice,
  }) =>
      RegistrationState(
        role: role ?? this.role,
        candidate: candidate ?? this.candidate,
        recruiter: recruiter ?? this.recruiter,
        status: status ?? this.status,
        error: clearError ? null : (error ?? this.error),
        challenge: challenge ?? this.challenge,
        pendingUserId: pendingUserId ?? this.pendingUserId,
        locationChoice: locationChoice ?? this.locationChoice,
      );
}

class RegistrationController extends StateNotifier<RegistrationState> {
  RegistrationController(this._ref) : super(const RegistrationState());

  final Ref _ref;

  // ── Role & drafts ─────────────────────────────────────────────────────────

  void selectRole(UserRole role) {
    state = state.copyWith(role: role, clearError: true);
  }

  /// True when moving to [role] would discard work already entered, so the
  /// screen knows whether it must warn first.
  bool switchingRoleLosesWork(UserRole role) =>
      state.role != null && state.role != role && state.hasDraftContent;

  /// Clears the draft the user is leaving behind; the other role's draft stays.
  void discardDraftFor(UserRole role) {
    state = switch (role) {
      UserRole.candidate => state.copyWith(candidate: const CandidateDraft()),
      UserRole.recruiter => state.copyWith(recruiter: const RecruiterDraft()),
    };
  }

  void updateCandidate(CandidateDraft draft) {
    state = state.copyWith(candidate: draft, clearError: true);
  }

  void updateRecruiter(RecruiterDraft draft) {
    state = state.copyWith(recruiter: draft, clearError: true);
  }

  void clearError() => state = state.copyWith(clearError: true);

  // ── Submission ────────────────────────────────────────────────────────────

  /// Registers the candidate. Returns true on success; on failure the error is
  /// on the state so the form can show it inline.
  Future<bool> submitCandidate() async {
    if (state.isSubmitting) return false; // Guards against a double tap.
    state = state.copyWith(status: SubmitStatus.submitting, clearError: true);

    try {
      final result = await _ref.read(authRepositoryProvider).registerCandidate(state.candidate);
      await _ref.read(sessionProvider.notifier).adopt(result.session);
      state = state.copyWith(
        status: SubmitStatus.success,
        challenge: result.challenge,
        pendingUserId: result.session.user.userId,
      );
      return true;
    } on ApiException catch (error) {
      state = state.copyWith(status: SubmitStatus.idle, error: error);
      return false;
    } catch (_) {
      state = state.copyWith(status: SubmitStatus.idle, error: ApiException.unexpected());
      return false;
    }
  }

  Future<bool> submitRecruiter() async {
    if (state.isSubmitting) return false;
    state = state.copyWith(status: SubmitStatus.submitting, clearError: true);

    try {
      final result = await _ref.read(authRepositoryProvider).registerRecruiter(state.recruiter);
      await _ref.read(sessionProvider.notifier).adopt(result.session);
      state = state.copyWith(
        status: SubmitStatus.success,
        challenge: result.challenge,
        pendingUserId: result.session.user.userId,
      );
      return true;
    } on ApiException catch (error) {
      state = state.copyWith(status: SubmitStatus.idle, error: error);
      return false;
    } catch (_) {
      state = state.copyWith(status: SubmitStatus.idle, error: ApiException.unexpected());
      return false;
    }
  }

  // ── Email verification ────────────────────────────────────────────────────

  Future<bool> verifyEmail(String code) async {
    final userId = state.pendingUserId;
    if (userId == null || state.isSubmitting) return false;

    state = state.copyWith(status: SubmitStatus.submitting, clearError: true);
    try {
      final session = await _ref
          .read(authRepositoryProvider)
          .verifyEmail(userId: userId, code: code);
      _ref.read(sessionProvider.notifier).update(session);
      state = state.copyWith(status: SubmitStatus.success);
      return true;
    } on ApiException catch (error) {
      state = state.copyWith(status: SubmitStatus.idle, error: error);
      return false;
    } catch (_) {
      state = state.copyWith(status: SubmitStatus.idle, error: ApiException.unexpected());
      return false;
    }
  }

  Future<bool> resendCode() async {
    final userId = state.pendingUserId;
    if (userId == null) return false;

    try {
      final challenge = await _ref.read(authRepositoryProvider).resendCode(userId);
      state = state.copyWith(challenge: challenge, clearError: true);
      return true;
    } on ApiException catch (error) {
      state = state.copyWith(error: error);
      return false;
    }
  }

  /// Returns to the email field without losing the rest of the form.
  void changeEmail() {
    state = state.copyWith(status: SubmitStatus.idle, clearError: true);
  }

  // ── Location ──────────────────────────────────────────────────────────────

  void chooseLocation(LocationChoice choice) {
    state = state.copyWith(locationChoice: choice, clearError: true);
  }

  Future<bool> submitLocation({double? hiringRadiusKm}) async {
    final choice = state.locationChoice;
    if (choice == null || state.isSubmitting) return false;

    state = state.copyWith(status: SubmitStatus.submitting, clearError: true);
    try {
      final repository = _ref.read(locationRepositoryProvider);
      // The signed-in role decides the endpoint: the registration role is
      // cleared once onboarding ends, but location can be changed later.
      final role = _ref.read(sessionProvider)?.user.role ?? state.role;
      final session = role == UserRole.recruiter
          ? await repository.setHiringLocation(choice, radiusKm: hiringRadiusKm)
          : await repository.setCandidateLocation(choice);
      _ref.read(sessionProvider.notifier).update(session);
      state = state.copyWith(status: SubmitStatus.success);
      return true;
    } on ApiException catch (error) {
      state = state.copyWith(status: SubmitStatus.idle, error: error);
      return false;
    } catch (_) {
      state = state.copyWith(status: SubmitStatus.idle, error: ApiException.unexpected());
      return false;
    }
  }

  /// Wipes the flow once the user lands on the radar.
  void reset() => state = const RegistrationState();
}

final registrationProvider =
    StateNotifierProvider<RegistrationController, RegistrationState>(
  (ref) => RegistrationController(ref),
);
