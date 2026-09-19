import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/session.dart';
import 'providers.dart';

/// The signed-in session, or null. The router watches this, so signing in or
/// out moves the app without any screen pushing routes itself.
class SessionController extends StateNotifier<Session?> {
  SessionController(this._ref) : super(null);

  final Ref _ref;

  bool _restoreAttempted = false;
  bool get restoreAttempted => _restoreAttempted;

  /// Called once at startup: re-reads a stored token and refreshes the profile.
  /// Any failure simply means "not signed in" — never a blocking error.
  Future<void> restore() async {
    if (_restoreAttempted) return;
    _restoreAttempted = true;

    final store = _ref.read(sessionStoreProvider);
    final token = await store.readToken();
    if (token == null || token.isEmpty) return;

    try {
      final session = await _ref.read(authRepositoryProvider).me(token);
      state = session.copyWith(token: token);
    } catch (_) {
      await store.clear();
      _ref.read(apiClientProvider).setAuthToken(null);
    }
  }

  /// Adopts a session and persists its token.
  Future<void> adopt(Session session) async {
    final token = session.token ?? state?.token;
    state = session.copyWith(token: token);
    if (token != null) {
      _ref.read(apiClientProvider).setAuthToken(token);
      await _ref.read(sessionStoreProvider).save(token: token, role: session.user.role.wire);
    }
  }

  /// Replaces profile data while keeping the current token (used after the
  /// location step, which returns a session without a fresh token).
  void update(Session session) {
    state = session.copyWith(token: session.token ?? state?.token);
  }

  Future<void> signOut() async {
    state = null;
    _ref.read(apiClientProvider).setAuthToken(null);
    _ref.read(jobTitleRepositoryProvider).clearCache();
    await _ref.read(sessionStoreProvider).clear();
  }
}

final sessionProvider = StateNotifierProvider<SessionController, Session?>(
  (ref) => SessionController(ref),
);
