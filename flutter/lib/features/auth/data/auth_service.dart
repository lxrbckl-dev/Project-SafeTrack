import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/services/api_config.dart';
import 'role.dart';

/// Manages authentication state for the Highlander app.
///
/// In dev/demo mode, [devLogin] calls [POST /api/dev-login] to obtain a
/// self-signed JWT for the selected role. In production this will be replaced
/// by Firebase Auth; the rest of the app reads [token], [currentRole], etc.,
/// which remain the same regardless of auth provider.
class AuthService extends ChangeNotifier {
  String? _userId;
  Role? _currentRole;
  String? _displayName;
  String? _token;

  /// The authenticated user's ID (e.g. "dev-field_reporter").
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

  /// Calls [POST /api/dev-login], stores the returned credentials, and
  /// notifies listeners so the UI can react to the login event.
  Future<void> devLogin(Role role) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/dev-login');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'role': role.apiValue,
        'displayName': role.displayName,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Dev login failed: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    _token = data['token'] as String?;
    _userId = data['userId'] as String?;
    _displayName = data['displayName'] as String?;

    final apiValue = data['role'] as String?;
    _currentRole = apiValue != null ? Role.fromApiValue(apiValue) : role;

    notifyListeners();
  }

  /// Clears all auth state and notifies listeners.
  void logout() {
    _token = null;
    _userId = null;
    _currentRole = null;
    _displayName = null;
    notifyListeners();
  }
}
