import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/services/api_config.dart';

/// Data model for an admin setting.
class AdminSetting {
  final int id;
  final String category;
  final String key;
  final String value;
  final DateTime updatedAt;
  final String updatedBy;

  const AdminSetting({
    required this.id,
    required this.category,
    required this.key,
    required this.value,
    required this.updatedAt,
    required this.updatedBy,
  });

  factory AdminSetting.fromJson(Map<String, dynamic> json) {
    return AdminSetting(
      id: (json['id'] as num).toInt(),
      category: json['category'] as String? ?? '',
      key: json['key'] as String? ?? '',
      value: json['value'] as String? ?? '',
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedBy: json['updatedBy'] as String? ?? '',
    );
  }
}

/// Repository that wraps the settings API endpoints.
///
/// All methods accept a [token] obtained from [AuthService.token] so this
/// class does not depend on [AuthService] directly (Dependency Inversion).
class AdminRepository {
  final http.Client _client;

  AdminRepository({http.Client? client}) : _client = client ?? http.Client();

  Map<String, String> _headers(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  /// Fetches all settings. Throws on HTTP error.
  Future<List<AdminSetting>> listSettings(String token) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/settings');
    final response = await _client.get(uri, headers: _headers(token));

    if (response.statusCode != 200) {
      throw Exception('Failed to load settings: ${response.statusCode}');
    }

    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => AdminSetting.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetches a single setting by [key]. Throws on HTTP error.
  Future<AdminSetting> getSetting(String token, String key) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/settings/$key');
    final response = await _client.get(uri, headers: _headers(token));

    if (response.statusCode == 404) {
      throw Exception('Setting not found: $key');
    }
    if (response.statusCode != 200) {
      throw Exception('Failed to load setting: ${response.statusCode}');
    }

    return AdminSetting.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// Updates the value of an existing setting. Throws on HTTP error.
  Future<AdminSetting> updateSetting(
    String token,
    String key,
    String value,
  ) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/settings/$key');
    final response = await _client.put(
      uri,
      headers: _headers(token),
      body: jsonEncode({'value': value}),
    );

    if (response.statusCode == 403) {
      throw Exception('Forbidden: insufficient role');
    }
    if (response.statusCode != 200) {
      throw Exception('Failed to update setting: ${response.statusCode}');
    }

    return AdminSetting.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}
