import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/services/api_config.dart';
import '../../auth/data/auth_service.dart';

/// All five valid similarity types for incident linking.
const List<String> kSimilarityTypes = [
  'Same Location',
  'Same Type',
  'Same Root Cause',
  'Same Equipment',
  'Same Person',
];

/// Summary of the "other" incident in a link — returned by the links endpoint.
class LinkedIncidentSummary {
  final int id;
  final String type;
  final String location;
  final String status;
  final String severity;
  final String division;

  const LinkedIncidentSummary({
    required this.id,
    required this.type,
    required this.location,
    required this.status,
    required this.severity,
    required this.division,
  });

  factory LinkedIncidentSummary.fromJson(Map<String, dynamic> json) {
    return LinkedIncidentSummary(
      id: json['id'] as int? ?? 0,
      type: json['type'] as String? ?? '',
      location: json['location'] as String? ?? '',
      status: json['status'] as String? ?? '',
      severity: json['severity'] as String? ?? '',
      division: json['division'] as String? ?? '',
    );
  }
}

/// A single incident link record enriched with the linked incident summary.
class IncidentLink {
  final int id;
  final int incidentId1;
  final int incidentId2;
  final String similarityType;
  final String notes;
  final String linkedByUserId;
  final DateTime createdAt;
  final LinkedIncidentSummary linkedIncident;

  const IncidentLink({
    required this.id,
    required this.incidentId1,
    required this.incidentId2,
    required this.similarityType,
    required this.notes,
    required this.linkedByUserId,
    required this.createdAt,
    required this.linkedIncident,
  });

  factory IncidentLink.fromJson(Map<String, dynamic> json) {
    return IncidentLink(
      id: json['id'] as int? ?? 0,
      incidentId1: json['incidentId1'] as int? ?? 0,
      incidentId2: json['incidentId2'] as int? ?? 0,
      similarityType: json['similarityType'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      linkedByUserId: json['linkedByUserId'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      linkedIncident: json['linkedIncident'] != null
          ? LinkedIncidentSummary.fromJson(
              json['linkedIncident'] as Map<String, dynamic>,
            )
          : const LinkedIncidentSummary(
              id: 0,
              type: '',
              location: '',
              status: '',
              severity: '',
              division: '',
            ),
    );
  }
}

/// An incident cluster returned by GET /api/incident-clusters.
class IncidentCluster {
  final int clusterId;
  final List<ClusterIncident> incidents;
  final List<CommonThread> commonThreads;

  const IncidentCluster({
    required this.clusterId,
    required this.incidents,
    required this.commonThreads,
  });

  factory IncidentCluster.fromJson(Map<String, dynamic> json) {
    return IncidentCluster(
      clusterId: json['clusterId'] as int? ?? 0,
      incidents:
          (json['incidents'] as List<dynamic>?)
              ?.map((e) => ClusterIncident.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      commonThreads:
          (json['commonThreads'] as List<dynamic>?)
              ?.map((e) => CommonThread.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Minimal incident record returned inside a cluster.
class ClusterIncident {
  final int id;
  final String type;
  final String location;
  final String status;
  final String severity;
  final String division;

  const ClusterIncident({
    required this.id,
    required this.type,
    required this.location,
    required this.status,
    required this.severity,
    required this.division,
  });

  factory ClusterIncident.fromJson(Map<String, dynamic> json) {
    return ClusterIncident(
      id: json['id'] as int? ?? 0,
      type: json['type'] as String? ?? '',
      location: json['location'] as String? ?? '',
      status: json['status'] as String? ?? '',
      severity: json['severity'] as String? ?? '',
      division: json['division'] as String? ?? '',
    );
  }
}

/// A similarity-type thread with its occurrence count across a cluster.
class CommonThread {
  final String similarityType;
  final int count;

  const CommonThread({required this.similarityType, required this.count});

  factory CommonThread.fromJson(Map<String, dynamic> json) {
    return CommonThread(
      similarityType: json['similarityType'] as String? ?? '',
      count: json['count'] as int? ?? 0,
    );
  }
}

/// A recurrence suggestion returned by POST /api/incidents/{id}/check-recurrence.
class RecurrenceMatch {
  final int incidentId;
  final String type;
  final DateTime date;
  final String location;
  final String similarityType;
  final int score;
  final String description;
  final List<String> matchCriteria;

  const RecurrenceMatch({
    required this.incidentId,
    required this.type,
    required this.date,
    required this.location,
    required this.similarityType,
    required this.score,
    required this.description,
    required this.matchCriteria,
  });

  factory RecurrenceMatch.fromJson(Map<String, dynamic> json) {
    return RecurrenceMatch(
      incidentId: json['incidentId'] as int? ?? 0,
      type: json['type'] as String? ?? '',
      date: json['date'] != null
          ? DateTime.parse(json['date'] as String)
          : DateTime.now(),
      location: json['location'] as String? ?? '',
      similarityType: json['similarityType'] as String? ?? '',
      score: json['score'] as int? ?? 0,
      description: json['description'] as String? ?? '',
      matchCriteria:
          (json['matchCriteria'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }
}

/// API client for all incident-link endpoints.
class IncidentLinkRepository {
  final AuthService _auth;

  IncidentLinkRepository(this._auth);

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_auth.token != null) 'Authorization': 'Bearer ${_auth.token}',
  };

  String get _base => ApiConfig.baseUrl;

  /// Returns all links for [incidentId], enriched with linked incident summaries.
  Future<List<IncidentLink>> getLinksForIncident(int incidentId) async {
    final uri = Uri.parse('$_base/api/incidents/$incidentId/links');
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to load incident links: ${response.body}');
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => IncidentLink.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Creates a link between two incidents.
  Future<IncidentLink> createLink({
    required int incidentId1,
    required int incidentId2,
    required String similarityType,
    String notes = '',
  }) async {
    final uri = Uri.parse('$_base/api/incident-links');
    final response = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode({
        'incidentId1': incidentId1,
        'incidentId2': incidentId2,
        'similarityType': similarityType,
        'notes': notes,
      }),
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to create incident link: ${response.body}');
    }
    // The create endpoint returns the raw IncidentLink without enrichment.
    // Re-fetch links to get the enriched version via the list endpoint.
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return IncidentLink(
      id: json['id'] as int? ?? 0,
      incidentId1: json['incidentId1'] as int? ?? 0,
      incidentId2: json['incidentId2'] as int? ?? 0,
      similarityType: json['similarityType'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      linkedByUserId: json['linkedByUserId'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      linkedIncident: const LinkedIncidentSummary(
        id: 0,
        type: '',
        location: '',
        status: '',
        severity: '',
        division: '',
      ),
    );
  }

  /// Deletes a link by its ID.
  Future<void> deleteLink(int linkId) async {
    final uri = Uri.parse('$_base/api/incident-links/$linkId');
    final response = await http.delete(uri, headers: _headers);
    if (response.statusCode != 204) {
      throw Exception('Failed to delete incident link: ${response.body}');
    }
  }

  /// Checks for similar incidents (recurrence detection).
  /// Returns a ranked list of matches sorted by score descending.
  Future<List<RecurrenceMatch>> checkRecurrence(int incidentId) async {
    final uri = Uri.parse('$_base/api/incidents/$incidentId/check-recurrence');
    final response = await http.post(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to check recurrence: ${response.body}');
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => RecurrenceMatch.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Dismisses a recurrence suggestion so it is not shown again.
  Future<void> dismissSuggestion({
    required int incidentId,
    required int suggestedIncidentId,
  }) async {
    final uri = Uri.parse(
      '$_base/api/incidents/$incidentId/dismiss-suggestion',
    );
    final response = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode({'suggestedIncidentId': suggestedIncidentId}),
    );
    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception('Failed to dismiss suggestion: ${response.body}');
    }
  }

  /// Returns all incident clusters.
  Future<List<IncidentCluster>> getClusters() async {
    final uri = Uri.parse('$_base/api/incident-clusters');
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to load incident clusters: ${response.body}');
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => IncidentCluster.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
