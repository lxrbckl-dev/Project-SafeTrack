import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/api_config.dart';
import 'role.dart';

/// Manages authentication state for the SafeTrack app.
///
/// [login] calls [POST /api/login] with email and password to obtain an
/// HS256 JWT. In production this will be replaced by Firebase Auth; the rest
/// of the app reads [token], [currentRole], etc., which remain the same
/// regardless of auth provider.
///
/// Session data is persisted to [SharedPreferences] so that auth state
/// survives a browser refresh (fix #148).
class AuthService extends ChangeNotifier {
  AuthService(this._prefs);

  final SharedPreferences _prefs;

  // ── Storage keys ──────────────────────────────────────────────────────
  static const _keyToken = 'auth_token';
  static const _keyUserId = 'auth_user_id';
  static const _keyDisplayName = 'auth_display_name';
  static const _keyRole = 'auth_role';

  String? _userId;
  Role? _currentRole;
  String? _displayName;
  String? _token;

  /// The authenticated user's ID (e.g. "1").
  String? get userId => _userId;

  /// The authenticated user's role.
  Role? get currentRole => _currentRole;

  /// The authenticated user's display name.
  String? get displayName => _displayName;

  /// The current JWT bearer token.  Null when not logged in.
  String? get token => _token;

  /// Returns true when a valid token is present.
  bool get isLoggedIn => _token != null;

  /// Returns true when the current role's access level is at least [role].
  /// Always returns false when not logged in.
  bool isAtLeast(Role role) => _currentRole?.isAtLeast(role) ?? false;

  // ── Session persistence (fix #148) ─────────────────────────────────

  /// Persists the current in-memory session to [SharedPreferences].
  void _saveSession() {
    if (_token != null) _prefs.setString(_keyToken, _token!);
    if (_userId != null) _prefs.setString(_keyUserId, _userId!);
    if (_displayName != null) {
      _prefs.setString(_keyDisplayName, _displayName!);
    }
    if (_currentRole != null) {
      _prefs.setString(_keyRole, _currentRole!.apiValue);
    }
  }

  /// Removes all session keys from [SharedPreferences].
  void _clearSession() {
    _prefs.remove(_keyToken);
    _prefs.remove(_keyUserId);
    _prefs.remove(_keyDisplayName);
    _prefs.remove(_keyRole);
  }

  /// Restores a previously persisted session from [SharedPreferences].
  ///
  /// Returns `true` if a valid session was restored, `false` otherwise.
  /// When the stored data is missing or the role value is invalid the
  /// persisted keys are cleared to prevent stale data from lingering.
  ///
  /// Stale-token note: we intentionally do **not** make a network call
  /// here — the existing [ApiClient] 401 interceptor (TASK-094) will
  /// catch expired tokens on the first real API request.
  Future<bool> restoreSession() async {
    final storedToken = _prefs.getString(_keyToken);
    final storedRole = _prefs.getString(_keyRole);

    if (storedToken == null || storedRole == null) {
      _clearSession();
      return false;
    }

    final role = Role.fromApiValue(storedRole);
    if (role == null) {
      _clearSession();
      return false;
    }

    _token = storedToken;
    _userId = _prefs.getString(_keyUserId);
    _displayName = _prefs.getString(_keyDisplayName);
    _currentRole = role;

    notifyListeners();
    return true;
  }

  // ── Login / Logout ────────────────────────────────────────────────────

  /// Calls [POST /api/login] with email and password, stores the returned
  /// credentials, and notifies listeners so the UI can react to the login event.
  Future<void> login(String email, String password) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/login');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode != 200) {
      throw Exception('Invalid email or password');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    _token = data['token'] as String?;
    _userId = data['userId'] as String?;
    _displayName = data['displayName'] as String?;

    final apiValue = data['role'] as String?;
    _currentRole = apiValue != null ? Role.fromApiValue(apiValue) : null;

    _saveSession();
    notifyListeners();
  }

  /// Clears all auth state and notifies listeners.
  void logout() {
    _clearSession();
    _token = null;
    _userId = null;
    _currentRole = null;
    _displayName = null;
    notifyListeners();
  }

  /// Called by [ApiClient] when a 401 Unauthorized response is received.
  ///
  /// Clears persisted session data first to ensure stale tokens are removed,
  /// then delegates to [logout] which clears in-memory state and notifies
  /// listeners. Because GoRouter watches this service via `refreshListenable`,
  /// the redirect guard will automatically navigate the user to `/login`.
  void handleUnauthorized() {
    _clearSession();
    logout();
  }
}
