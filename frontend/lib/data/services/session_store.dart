import 'package:shared_preferences/shared_preferences.dart';

/// Persists just enough to restore a signed-in session on a cold start: the
/// token and the last known role. Profile data is always re-fetched, so nothing
/// stale is ever shown.
class SessionStore {
  static const String _tokenKey = 'tr.auth.token';
  static const String _roleKey = 'tr.auth.role';

  Future<void> save({required String token, required String role}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_roleKey, role);
  }

  Future<String?> readToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<String?> readRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roleKey);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_roleKey);
  }
}
