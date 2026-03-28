import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/services/api_config.dart';
import '../../auth/data/auth_service.dart';

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------

/// A training requirement linked to a Training-category CAPA.
class TrainingRequirement {
  final int? id;
  final int capaId;
  final String courseName;
  final String description;
  final String assignedToUserId;
  final String assignedByUserId;
  final DateTime? dueDate;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TrainingRequirement({
    this.id,
    this.capaId = 0,
    this.courseName = '',
    this.description = '',
    this.assignedToUserId = '',
    this.assignedByUserId = '',
    this.dueDate,
    this.status = 'Pending',
    this.createdAt,
    this.updatedAt,
  });

  factory TrainingRequirement.fromJson(Map<String, dynamic> json) {
    return TrainingRequirement(
      id: json['id'] as int?,
      capaId: (json['capaId'] as num?)?.toInt() ?? 0,
      courseName: json['courseName'] as String? ?? '',
      description: json['description'] as String? ?? '',
      assignedToUserId: json['assignedToUserId'] as String? ?? '',
      assignedByUserId: json['assignedByUserId'] as String? ?? '',
      dueDate: json['dueDate'] != null
          ? DateTime.tryParse(json['dueDate'] as String)
          : null,
      status: json['status'] as String? ?? 'Pending',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }
}

/// Completion record for a training requirement.
class TrainingCompletion {
  final int? id;
  final int trainingRequirementId;
  final String completedByUserId;
  final DateTime? completionDate;
  final double durationHours;
  final String instructorName;
  final String notes;
  final String evidence;
  final String verifiedByUserId;
  final DateTime? createdAt;

  const TrainingCompletion({
    this.id,
    this.trainingRequirementId = 0,
    this.completedByUserId = '',
    this.completionDate,
    this.durationHours = 0,
    this.instructorName = '',
    this.notes = '',
    this.evidence = '',
    this.verifiedByUserId = '',
    this.createdAt,
  });

  factory TrainingCompletion.fromJson(Map<String, dynamic> json) {
    return TrainingCompletion(
      id: json['id'] as int?,
      trainingRequirementId:
          (json['trainingRequirementId'] as num?)?.toInt() ?? 0,
      completedByUserId: json['completedByUserId'] as String? ?? '',
      completionDate: json['completionDate'] != null
          ? DateTime.tryParse(json['completionDate'] as String)
          : null,
      durationHours: (json['durationHours'] as num?)?.toDouble() ?? 0,
      instructorName: json['instructorName'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      evidence: json['evidence'] as String? ?? '',
      verifiedByUserId: json['verifiedByUserId'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }
}

/// Detail response including training requirement and optional completion.
class TrainingDetail {
  final TrainingRequirement training;
  final TrainingCompletion? completion;

  const TrainingDetail({required this.training, this.completion});

  factory TrainingDetail.fromJson(Map<String, dynamic> json) {
    return TrainingDetail(
      training: TrainingRequirement.fromJson(
        json['training'] as Map<String, dynamic>,
      ),
      completion: json['completion'] != null
          ? TrainingCompletion.fromJson(
              json['completion'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

/// Paginated training list response from the API.
class TrainingListResponse {
  final List<TrainingRequirement> data;
  final int total;
  final int page;
  final int perPage;

  const TrainingListResponse({
    required this.data,
    required this.total,
    required this.page,
    required this.perPage,
  });

  factory TrainingListResponse.fromJson(Map<String, dynamic> json) {
    return TrainingListResponse(
      data:
          (json['data'] as List<dynamic>?)
              ?.map(
                (e) => TrainingRequirement.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      perPage: (json['per_page'] as num?)?.toInt() ?? 50,
    );
  }
}

// ---------------------------------------------------------------------------
// Repository -- API client for training endpoints
// ---------------------------------------------------------------------------

/// API client for all training-related endpoints.
///
/// Uses [AuthService] for JWT bearer tokens and [ApiConfig.baseUrl] for the
/// Go backend URL.
class TrainingRepository {
  final AuthService _auth;

  TrainingRepository(this._auth);

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_auth.token != null) 'Authorization': 'Bearer ${_auth.token}',
  };

  String get _base => ApiConfig.baseUrl;

  // ---- List ----

  /// Lists training requirements with optional filters and pagination.
  Future<TrainingListResponse> listTraining({
    String? status,
    String? assignedTo,
    int? capaId,
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
    if (capaId != null) params['capa_id'] = capaId.toString();

    final uri = Uri.parse(
      '$_base/api/training',
    ).replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to load training: ${response.body}');
    }
    return TrainingListResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  // ---- Get ----

  /// Gets a single training requirement by ID with its completion record.
  Future<TrainingDetail> getTraining(int id) async {
    final uri = Uri.parse('$_base/api/training/$id');
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to load training: ${response.body}');
    }
    return TrainingDetail.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  // ---- Create ----

  /// Creates a new training requirement linked to a CAPA.
  Future<TrainingRequirement> createTraining({
    required int capaId,
    required String courseName,
    required String assignedToUserId,
    String description = '',
  }) async {
    final uri = Uri.parse('$_base/api/training');
    final response = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode({
        'capaId': capaId,
        'courseName': courseName,
        'description': description,
        'assignedToUserId': assignedToUserId,
      }),
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to create training: ${response.body}');
    }
    return TrainingRequirement.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  // ---- Complete ----

  /// Completes a training requirement. Also auto-completes the linked CAPA.
  Future<TrainingDetail> completeTraining(
    int id, {
    required String completionDate,
    double durationHours = 0,
    String instructorName = '',
    String notes = '',
    String evidence = '',
  }) async {
    final uri = Uri.parse('$_base/api/training/$id/complete');
    final response = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode({
        'completionDate': completionDate,
        'durationHours': durationHours,
        'instructorName': instructorName,
        'notes': notes,
        'evidence': evidence,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to complete training: ${response.body}');
    }
    return TrainingDetail.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  // ---- Get by CAPA ID ----

  /// Gets the training requirement linked to a specific CAPA.
  /// Returns null if no training requirement exists for this CAPA.
  Future<TrainingRequirement?> getTrainingByCapaId(int capaId) async {
    final result = await listTraining(capaId: capaId, perPage: 1);
    if (result.data.isEmpty) return null;
    return result.data.first;
  }
}
