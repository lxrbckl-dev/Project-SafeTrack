import 'dart:convert';

import '../../../core/services/api_client.dart';
import '../../../core/services/api_config.dart';
import '../../auth/data/auth_service.dart';

// ---------- Data Model ----------

/// A single chronological event in the incident lifecycle timeline.
///
/// Aggregates audit log entries from the incident itself, its linked
/// investigation, and all related CAPAs.
class TimelineEvent {
  final DateTime timestamp;
  final String action;
  final String userDisplayName;
  final String userRole;
  final String description;
  final String entityType;
  final int entityId;

  const TimelineEvent({
    required this.timestamp,
    required this.action,
    required this.userDisplayName,
    required this.userRole,
    required this.description,
    required this.entityType,
    required this.entityId,
  });

  factory TimelineEvent.fromJson(Map<String, dynamic> json) {
    return TimelineEvent(
      timestamp:
          DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      action: json['action'] as String? ?? '',
      userDisplayName: json['userDisplayName'] as String? ?? '',
      userRole: json['userRole'] as String? ?? '',
      description: json['description'] as String? ?? '',
      entityType: json['entityType'] as String? ?? '',
      entityId: (json['entityId'] as num?)?.toInt() ?? 0,
    );
  }
}

// ---------- Repository ----------

/// API client for the incident timeline endpoint.
class IncidentTimelineRepository {
  final ApiClient _api;

  IncidentTimelineRepository(AuthService auth) : _api = ApiClient(auth);

  String get _base => ApiConfig.baseUrl;

  /// Fetches all timeline events for the incident identified by [incidentId].
  /// Returns events sorted chronologically (oldest first).
  Future<List<TimelineEvent>> getTimeline(int incidentId) async {
    final uri = Uri.parse('$_base/api/incidents/$incidentId/timeline');
    final response = await _api.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to load timeline: ${response.body}');
    }

    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => TimelineEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
