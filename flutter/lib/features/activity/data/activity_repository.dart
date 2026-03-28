import 'dart:convert';

import '../../../core/services/api_client.dart';
import '../../../core/services/api_config.dart';
import '../../auth/data/auth_service.dart';

/// A single item in the live activity feed, returned from GET /api/activity.
class ActivityFeedItem {
  final int id;
  final DateTime timestamp;
  final String userDisplayName;
  final String userRole;
  final String message;
  final String entityType;
  final int entityId;
  final String action;
  final bool isAgent;

  const ActivityFeedItem({
    required this.id,
    required this.timestamp,
    required this.userDisplayName,
    required this.userRole,
    required this.message,
    required this.entityType,
    required this.entityId,
    required this.action,
    this.isAgent = false,
  });

  factory ActivityFeedItem.fromJson(Map<String, dynamic> json) {
    return ActivityFeedItem(
      id: json['id'] as int? ?? 0,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String).toLocal()
          : DateTime.now(),
      userDisplayName: json['userDisplayName'] as String? ?? '',
      userRole: json['userRole'] as String? ?? '',
      message: json['message'] as String? ?? '',
      entityType: json['entityType'] as String? ?? '',
      entityId: json['entityId'] as int? ?? 0,
      action: json['action'] as String? ?? '',
      isAgent: json['isAgent'] as bool? ?? false,
    );
  }
}

/// Repository for fetching live activity feed data from the Go backend.
class ActivityRepository {
  final ApiClient _api;

  ActivityRepository(AuthService auth) : _api = ApiClient(auth);

  /// Fetches recent activity feed items.
  ///
  /// If [since] is provided, only items after that timestamp are returned.
  /// [limit] controls the maximum number of items (default 50, max 100).
  Future<List<ActivityFeedItem>> getActivity({
    DateTime? since,
    int limit = 50,
  }) async {
    final params = <String, String>{'limit': '$limit'};
    if (since != null) {
      params['since'] = since.toUtc().toIso8601String();
    }

    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/activity',
    ).replace(queryParameters: params);

    final response = await _api.get(uri);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
      return data
          .map(
            (json) => ActivityFeedItem.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } else {
      throw Exception('Failed to load activity feed (${response.statusCode})');
    }
  }
}
