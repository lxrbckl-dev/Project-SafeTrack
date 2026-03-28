import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/services/api_config.dart';

/// Data class representing a user's notification preference.
class NotificationPreference {
  final String userId;
  final String preference;

  const NotificationPreference({
    required this.userId,
    required this.preference,
  });

  factory NotificationPreference.fromJson(Map<String, dynamic> json) {
    return NotificationPreference(
      userId: json['userId'] as String? ?? '',
      preference: json['preference'] as String? ?? 'both',
    );
  }
}

/// Repository for notification preference API calls.
class NotificationPreferencesRepository {
  /// Fetches the current user's notification preference.
  Future<NotificationPreference> getPreference(String token) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/users/me/notification-preferences',
    );
    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return NotificationPreference.fromJson(data);
    }
    throw Exception(
      'Failed to load notification preferences (${response.statusCode})',
    );
  }

  /// Updates a user's notification preference.
  Future<NotificationPreference> updatePreference(
    String token,
    String userId,
    String preference,
  ) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/users/$userId/notification-preferences',
    );
    final response = await http.put(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'preference': preference}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return NotificationPreference.fromJson(data);
    }
    throw Exception(
      'Failed to update notification preferences (${response.statusCode})',
    );
  }
}
