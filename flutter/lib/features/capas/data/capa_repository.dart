import 'dart:convert';

import '../../../core/services/api_client.dart';
import '../../../core/services/api_config.dart';
import '../../auth/data/auth_service.dart';

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------

/// Dashboard KPI data from GET /api/capas/dashboard.
class CAPADashboard {
  final int openCapas;
  final int overdueCapas;
  final double avgTimeToCloseDays;
  final double effectivenessRate;

  const CAPADashboard({
    this.openCapas = 0,
    this.overdueCapas = 0,
    this.avgTimeToCloseDays = 0,
    this.effectivenessRate = 0,
  });

  factory CAPADashboard.fromJson(Map<String, dynamic> json) {
    return CAPADashboard(
      openCapas: (json['openCapas'] as num?)?.toInt() ?? 0,
      overdueCapas: (json['overdueCapas'] as num?)?.toInt() ?? 0,
      avgTimeToCloseDays: (json['avgTimeToCloseDays'] as num?)?.toDouble() ?? 0,
      effectivenessRate: (json['effectivenessRate'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// A single CAPA record matching the Go CAPA model.
class CAPA {
  final int? id;
  final int investigationId;
  final int incidentId;
  final String type;
  final String category;
  final String description;
  final String assignedToUserId;
  final String assignedByUserId;
  final DateTime? dueDate;
  final String priority;
  final String verificationMethod;
  final DateTime? verificationDueDate;
  final String status;
  final String completionNotes;
  final String completionEvidence;
  final DateTime? completionDate;
  final String verifiedByUserId;
  final DateTime? verificationDate;
  final String verificationNotes;
  final bool isOverdue;
  final int overdueEscalationLevel;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CAPA({
    this.id,
    this.investigationId = 0,
    this.incidentId = 0,
    this.type = '',
    this.category = '',
    this.description = '',
    this.assignedToUserId = '',
    this.assignedByUserId = '',
    this.dueDate,
    this.priority = 'Medium',
    this.verificationMethod = '',
    this.verificationDueDate,
    this.status = 'Open',
    this.completionNotes = '',
    this.completionEvidence = '',
    this.completionDate,
    this.verifiedByUserId = '',
    this.verificationDate,
    this.verificationNotes = '',
    this.isOverdue = false,
    this.overdueEscalationLevel = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory CAPA.fromJson(Map<String, dynamic> json) {
    return CAPA(
      id: json['id'] as int?,
      investigationId: (json['investigationId'] as num?)?.toInt() ?? 0,
      incidentId: (json['incidentId'] as num?)?.toInt() ?? 0,
      type: json['type'] as String? ?? '',
      category: json['category'] as String? ?? '',
      description: json['description'] as String? ?? '',
      assignedToUserId: json['assignedToUserId'] as String? ?? '',
      assignedByUserId: json['assignedByUserId'] as String? ?? '',
      dueDate: json['dueDate'] != null
          ? DateTime.tryParse(json['dueDate'] as String)
          : null,
      priority: json['priority'] as String? ?? 'Medium',
      verificationMethod: json['verificationMethod'] as String? ?? '',
      verificationDueDate: json['verificationDueDate'] != null
          ? DateTime.tryParse(json['verificationDueDate'] as String)
          : null,
      status: json['status'] as String? ?? 'Open',
      completionNotes: json['completionNotes'] as String? ?? '',
      completionEvidence: json['completionEvidence'] as String? ?? '',
      completionDate: json['completionDate'] != null
          ? DateTime.tryParse(json['completionDate'] as String)
          : null,
      verifiedByUserId: json['verifiedByUserId'] as String? ?? '',
      verificationDate: json['verificationDate'] != null
          ? DateTime.tryParse(json['verificationDate'] as String)
          : null,
      verificationNotes: json['verificationNotes'] as String? ?? '',
      isOverdue: json['isOverdue'] as bool? ?? false,
      overdueEscalationLevel:
          (json['overdueEscalationLevel'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }
}

/// Paginated CAPA list response from the API.
class CAPAListResponse {
  final List<CAPA> data;
  final int total;
  final int page;
  final int perPage;

  const CAPAListResponse({
    required this.data,
    required this.total,
    required this.page,
    required this.perPage,
  });

  factory CAPAListResponse.fromJson(Map<String, dynamic> json) {
    return CAPAListResponse(
      data:
          (json['data'] as List<dynamic>?)
              ?.map((e) => CAPA.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      perPage: (json['per_page'] as num?)?.toInt() ?? 50,
    );
  }
}

/// Response from the verify endpoint, which may include next steps for
/// ineffective CAPAs.
class VerifyResponse {
  final CAPA capa;
  final Map<String, dynamic>? nextSteps;

  const VerifyResponse({required this.capa, this.nextSteps});

  factory VerifyResponse.fromJson(Map<String, dynamic> json) {
    return VerifyResponse(
      capa: CAPA.fromJson(json['capa'] as Map<String, dynamic>),
      nextSteps: json['nextSteps'] as Map<String, dynamic>?,
    );
  }
}

// ---------------------------------------------------------------------------
// Repository -- API client for all CAPA endpoints
// ---------------------------------------------------------------------------

/// API client for all CAPA-related endpoints.
///
/// Uses [AuthService] for JWT bearer tokens and [ApiConfig.baseUrl] for the
/// Go backend URL.
class CAPARepository {
  final ApiClient _api;

  CAPARepository(AuthService auth) : _api = ApiClient(auth);

  String get _base => ApiConfig.baseUrl;

  // ---- Dashboard ----

  /// Fetches aggregated CAPA KPIs.
  Future<CAPADashboard> getDashboard() async {
    final uri = Uri.parse('$_base/api/capas/dashboard');
    final response = await _api.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to load CAPA dashboard: ${response.body}');
    }
    return CAPADashboard.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  // ---- CRUD ----

  /// Lists CAPAs with optional filters and pagination.
  Future<CAPAListResponse> listCAPAs({
    String? status,
    String? assignedTo,
    int? investigationId,
    int? incidentId,
    bool? overdue,
    String? priority,
    int page = 1,
    int perPage = 50,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (assignedTo != null && assignedTo.isNotEmpty) {
      params['assigned_to'] = assignedTo;
    }
    if (investigationId != null) {
      params['investigation_id'] = investigationId.toString();
    }
    if (incidentId != null) {
      params['incident_id'] = incidentId.toString();
    }
    if (overdue == true) params['overdue'] = 'true';
    if (priority != null && priority.isNotEmpty) params['priority'] = priority;

    final uri = Uri.parse('$_base/api/capas').replace(queryParameters: params);
    final response = await _api.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to load CAPAs: ${response.body}');
    }
    return CAPAListResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// Gets a single CAPA by ID.
  Future<CAPA> getCAPA(int id) async {
    final uri = Uri.parse('$_base/api/capas/$id');
    final response = await _api.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to load CAPA: ${response.body}');
    }
    return CAPA.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Creates a new CAPA.
  Future<CAPA> createCAPA({
    required int investigationId,
    required int incidentId,
    required String type,
    required String category,
    required String description,
    required String assignedToUserId,
    required String priority,
    String verificationMethod = '',
  }) async {
    final uri = Uri.parse('$_base/api/capas');
    final response = await _api.post(
      uri,
      body: jsonEncode({
        'investigationId': investigationId,
        'incidentId': incidentId,
        'type': type,
        'category': category,
        'description': description,
        'assignedToUserId': assignedToUserId,
        'priority': priority,
        'verificationMethod': verificationMethod,
      }),
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to create CAPA: ${response.body}');
    }
    return CAPA.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Updates an existing CAPA (partial update).
  Future<CAPA> updateCAPA(
    int id, {
    String? type,
    String? category,
    String? description,
    String? assignedToUserId,
    String? priority,
    String? verificationMethod,
    String? status,
  }) async {
    final uri = Uri.parse('$_base/api/capas/$id');
    final body = <String, dynamic>{};
    if (type != null) body['type'] = type;
    if (category != null) body['category'] = category;
    if (description != null) body['description'] = description;
    if (assignedToUserId != null) body['assignedToUserId'] = assignedToUserId;
    if (priority != null) body['priority'] = priority;
    if (verificationMethod != null) {
      body['verificationMethod'] = verificationMethod;
    }
    if (status != null) body['status'] = status;

    final response = await _api.put(uri, body: jsonEncode(body));
    if (response.statusCode != 200) {
      throw Exception('Failed to update CAPA: ${response.body}');
    }
    return CAPA.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  // ---- Workflow ----

  /// Completes a CAPA (status transitions to Verification Pending).
  Future<CAPA> completeCAPA(
    int id, {
    String notes = '',
    String evidence = '',
  }) async {
    final uri = Uri.parse('$_base/api/capas/$id/complete');
    final response = await _api.post(
      uri,
      body: jsonEncode({'notes': notes, 'evidence': evidence}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to complete CAPA: ${response.body}');
    }
    return CAPA.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Verifies a CAPA. Returns the CAPA and optional next steps if ineffective.
  Future<VerifyResponse> verifyCAPA(
    int id, {
    required bool effective,
    String notes = '',
  }) async {
    final uri = Uri.parse('$_base/api/capas/$id/verify');
    final response = await _api.post(
      uri,
      body: jsonEncode({'effective': effective, 'notes': notes}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to verify CAPA: ${response.body}');
    }
    return VerifyResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}
