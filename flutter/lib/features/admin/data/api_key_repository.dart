import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/services/api_config.dart';

/// Data model for an agent API key (as returned by the list endpoint).
class AgentApiKey {
  final int id;
  final int userId;
  final String keyPrefix;
  final String name;
  final bool isActive;
  final DateTime? lastUsedAt;
  final DateTime createdAt;
  final DateTime? revokedAt;

  const AgentApiKey({
    required this.id,
    required this.userId,
    required this.keyPrefix,
    required this.name,
    required this.isActive,
    this.lastUsedAt,
    required this.createdAt,
    this.revokedAt,
  });

  factory AgentApiKey.fromJson(Map<String, dynamic> json) {
    return AgentApiKey(
      id: (json['id'] as num).toInt(),
      userId: (json['userId'] as num).toInt(),
      keyPrefix: json['keyPrefix'] as String? ?? '',
      name: json['name'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
      lastUsedAt: json['lastUsedAt'] != null
          ? DateTime.tryParse(json['lastUsedAt'] as String)
          : null,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      revokedAt: json['revokedAt'] != null
          ? DateTime.tryParse(json['revokedAt'] as String)
          : null,
    );
  }
}

/// Response from creating a new API key — includes the full key shown once.
class CreateKeyResponse {
  final String key;
  final String prefix;
  final int id;
  final int userId;
  final String role;
  final String name;

  const CreateKeyResponse({
    required this.key,
    required this.prefix,
    required this.id,
    required this.userId,
    required this.role,
    required this.name,
  });

  factory CreateKeyResponse.fromJson(Map<String, dynamic> json) {
    return CreateKeyResponse(
      key: json['key'] as String? ?? '',
      prefix: json['prefix'] as String? ?? '',
      id: (json['id'] as num).toInt(),
      userId: (json['userId'] as num).toInt(),
      role: json['role'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }
}

/// Repository wrapping the agent API key management endpoints.
///
/// All methods accept a [token] obtained from [AuthService.token] so this
/// class does not depend on [AuthService] directly (Dependency Inversion).
class ApiKeyRepository {
  final http.Client _client;

  ApiKeyRepository({http.Client? client}) : _client = client ?? http.Client();

  Map<String, String> _headers(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  /// Creates a new API key for the given user. Returns the full key once.
  Future<CreateKeyResponse> createKey(
    String token, {
    required int userId,
    required String name,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/agent/keys');
    final response = await _client.post(
      uri,
      headers: _headers(token),
      body: jsonEncode({'userId': userId, 'name': name}),
    );

    if (response.statusCode == 403) {
      throw Exception('Forbidden: insufficient role');
    }
    if (response.statusCode == 404) {
      throw Exception('User not found');
    }
    if (response.statusCode != 201) {
      throw Exception('Failed to create key: ${response.statusCode}');
    }

    return CreateKeyResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// Lists active API keys. Admins/Safety Managers see all keys.
  Future<List<AgentApiKey>> listKeys(
    String token, {
    bool showRevoked = false,
  }) async {
    var uri = Uri.parse('${ApiConfig.baseUrl}/api/agent/keys');
    if (showRevoked) {
      uri = uri.replace(queryParameters: {'show_revoked': 'true'});
    }

    final response = await _client.get(uri, headers: _headers(token));

    if (response.statusCode == 403) {
      throw Exception('Forbidden: insufficient role');
    }
    if (response.statusCode != 200) {
      throw Exception('Failed to list keys: ${response.statusCode}');
    }

    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => AgentApiKey.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Revokes an API key by ID. Returns true on success.
  Future<void> revokeKey(String token, int keyId) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/agent/keys/$keyId');
    final response = await _client.delete(uri, headers: _headers(token));

    if (response.statusCode == 403) {
      throw Exception('Forbidden: insufficient role');
    }
    if (response.statusCode == 404) {
      throw Exception('Key not found');
    }
    if (response.statusCode == 409) {
      throw Exception('Key already revoked');
    }
    if (response.statusCode != 204) {
      throw Exception('Failed to revoke key: ${response.statusCode}');
    }
  }
}
