import '../../core/network/api_client.dart';
import '../models/registration_draft.dart';
import '../models/session.dart';

/// Result of a registration call: the new session plus the OTP challenge.
class RegistrationResult {
  const RegistrationResult({required this.session, required this.challenge});

  final Session session;
  final VerificationChallenge challenge;
}

class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;

  Future<RegistrationResult> registerCandidate(CandidateDraft draft) async {
    final data = await _api.post('/auth/register/candidate', body: draft.toRequest());
    return _toRegistration(data);
  }

  Future<RegistrationResult> registerRecruiter(RecruiterDraft draft) async {
    final data = await _api.post('/auth/register/recruiter', body: draft.toRequest());
    return _toRegistration(data);
  }

  /// Checks an address before submission so a duplicate is caught while the
  /// user is still on the field rather than after they press the CTA.
  Future<({bool available, String? existingRole, bool isOfficialDomain})> checkEmail(
    String email,
  ) async {
    final data = await _api.post('/auth/check-email', body: {'email': email});
    return (
      available: data['available'] == true,
      existingRole: data['existingRole'] as String?,
      isOfficialDomain: data['isOfficialDomain'] == true,
    );
  }

  Future<Session> verifyEmail({required String userId, required String code}) async {
    final data = await _api.post('/auth/verify-email', body: {'userId': userId, 'code': code});
    return Session.fromJson(data);
  }

  Future<VerificationChallenge> resendCode(String userId) async {
    final data = await _api.post('/auth/resend-code', body: {'userId': userId});
    return VerificationChallenge.fromJson(data['verification'] as Map<String, dynamic>?);
  }

  Future<Session> login({
    required String email,
    required String password,
    String? role,
  }) async {
    final data = await _api.post('/auth/login', body: {
      'email': email,
      'password': password,
      if (role != null) 'role': role,
    });
    return Session.fromJson(data);
  }

  /// Re-reads the signed-in user; used to restore a session on cold start.
  Future<Session> me(String token) async {
    _api.setAuthToken(token);
    final data = await _api.get('/auth/me');
    return Session.fromJson(data, fallbackToken: token);
  }

  RegistrationResult _toRegistration(Map<String, dynamic> data) {
    final session = Session.fromJson(data);
    if (session.token != null) _api.setAuthToken(session.token);
    return RegistrationResult(
      session: session,
      challenge: VerificationChallenge.fromJson(data['verification'] as Map<String, dynamic>?),
    );
  }
}
