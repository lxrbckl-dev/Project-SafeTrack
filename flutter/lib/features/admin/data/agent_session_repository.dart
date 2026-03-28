import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/services/api_config.dart';

/// A single active agent session, as returned by GET /api/agent/sessions.
class AgentSession {
  final int keyId;
  final String keyPrefix;
  final String keyName;
  final int userId;
  final String userName;
  final String userRole;
  final DateTime? lastUsedAt;

  const AgentSession({
    required this.keyId,
    required this.keyPrefix,
    required this.keyName,
    required this.userId,
    required this.userName,
    required this.userRole,
    this.lastUsedAt,
  });

  factory AgentSession.fromJson(Map<String, dynamic> json) {
    return AgentSession(
      keyId: (json['keyId'] as num).toInt(),
      keyPrefix: json['keyPrefix'] as String? ?? '',
      keyName: json['keyName'] as String? ?? '',
      userId: (json['userId'] as num).toInt(),
      userName: json['userName'] as String? ?? '',
      userRole: json['userRole'] as String? ?? '',
      lastUsedAt: json['lastUsedAt'] != null
          ? DateTime.tryParse(json['lastUsedAt'] as String)?.toLocal()
          : null,
    );
  }
}

/// A single agent activity item, as returned by GET /api/agent/activity.
class AgentActivityItem {
  final int id;
  final DateTime timestamp;
  final String userDisplayName;
  final String userRole;
  final String message;
  final String entityType;
  final int entityId;
  final String action;

  const AgentActivityItem({
    required this.id,
    required this.timestamp,
    required this.userDisplayName,
    required this.userRole,
    required this.message,
    required this.entityType,
    required this.entityId,
    required this.action,
  });

  factory AgentActivityItem.fromJson(Map<String, dynamic> json) {
    return AgentActivityItem(
      id: (json['id'] as num).toInt(),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String).toLocal()
          : DateTime.now(),
      userDisplayName: json['userDisplayName'] as String? ?? '',
      userRole: json['userRole'] as String? ?? '',
      message: json['message'] as String? ?? '',
      entityType: json['entityType'] as String? ?? '',
      entityId: (json['entityId'] as num?)?.toInt() ?? 0,
      action: json['action'] as String? ?? '',
    );
  }
}

/// Repository for agent session and activity endpoints.
///
/// Accepts a [token] per-method (Dependency Inversion — no AuthService dep).
class AgentSessionRepository {
  final http.Client _client;

  AgentSessionRepository({http.Client? client})
    : _client = client ?? http.Client();

  Map<String, String> _headers(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  /// Fetches currently active agent sessions (Admin only).
  /// Active = LastUsedAt within last 5 minutes.
  Future<List<AgentSession>> getSessions(String token) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/agent/sessions');
    final response = await _client.get(uri, headers: _headers(token));

    if (response.statusCode == 403) {
      throw Exception('Forbidden: Admin only');
    }
    if (response.statusCode != 200) {
      throw Exception('Failed to load agent sessions (${response.statusCode})');
    }

    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => AgentSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetches agent-only audit log entries.
  /// [since] provides cursor-based pagination. [limit] defaults to 50.
  Future<List<AgentActivityItem>> getActivity(
    String token, {
    DateTime? since,
    int limit = 50,
  }) async {
    final params = <String, String>{'limit': '$limit'};
    if (since != null) {
      params['since'] = since.toUtc().toIso8601String();
    }

    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/agent/activity',
    ).replace(queryParameters: params);

    final response = await _client.get(uri, headers: _headers(token));

    if (response.statusCode == 403) {
      throw Exception('Forbidden: insufficient role');
    }
    if (response.statusCode != 200) {
      throw Exception('Failed to load agent activity (${response.statusCode})');
    }

    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => AgentActivityItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
