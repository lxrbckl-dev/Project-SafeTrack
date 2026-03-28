import 'dart:convert';

import '../../../core/services/api_client.dart';
import '../../../core/services/api_config.dart';
import '../../auth/data/auth_service.dart';

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------

/// A single Why/Answer pair in a 5-Why root cause analysis chain.
class FiveWhy {
  final int? id;
  final int? investigationId;
  final int level;
  final String question;
  final String answer;
  final String evidence;
  final int sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const FiveWhy({
    this.id,
    this.investigationId,
    this.level = 1,
    this.question = '',
    this.answer = '',
    this.evidence = '',
    this.sortOrder = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory FiveWhy.fromJson(Map<String, dynamic> json) {
    return FiveWhy(
      id: json['id'] as int?,
      investigationId: json['investigationId'] as int?,
      level: json['level'] as int? ?? 1,
      question: json['question'] as String? ?? '',
      answer: json['answer'] as String? ?? '',
      evidence: json['evidence'] as String? ?? '',
      sortOrder: json['sortOrder'] as int? ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    if (investigationId != null) 'investigationId': investigationId,
    'level': level,
    'question': question,
    'answer': answer,
    'evidence': evidence,
    'sortOrder': sortOrder,
  };
}

/// A contributing factor classified by a configurable FactorType.
class ContributingFactor {
  final int? id;
  final int? investigationId;
  final String factorType;
  final String factorDescription;
  final bool isPrimary;
  final DateTime? createdAt;

  const ContributingFactor({
    this.id,
    this.investigationId,
    this.factorType = '',
    this.factorDescription = '',
    this.isPrimary = false,
    this.createdAt,
  });

  factory ContributingFactor.fromJson(Map<String, dynamic> json) {
    return ContributingFactor(
      id: json['id'] as int?,
      investigationId: json['investigationId'] as int?,
      factorType: json['factorType'] as String? ?? '',
      factorDescription: json['factorDescription'] as String? ?? '',
      isPrimary: json['isPrimary'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    if (investigationId != null) 'investigationId': investigationId,
    'factorType': factorType,
    'factorDescription': factorDescription,
    'isPrimary': isPrimary,
  };
}

/// A witness statement for an investigation.
class WitnessStatement {
  final int? id;
  final int? investigationId;
  final String witnessName;
  final String witnessTitle;
  final String witnessEmployer;
  final String witnessPhone;
  final String statementText;
  final DateTime? collectionDate;
  final String collectorName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const WitnessStatement({
    this.id,
    this.investigationId,
    this.witnessName = '',
    this.witnessTitle = '',
    this.witnessEmployer = '',
    this.witnessPhone = '',
    this.statementText = '',
    this.collectionDate,
    this.collectorName = '',
    this.createdAt,
    this.updatedAt,
  });

  factory WitnessStatement.fromJson(Map<String, dynamic> json) {
    return WitnessStatement(
      id: json['id'] as int?,
      investigationId: json['investigationId'] as int?,
      witnessName: json['witnessName'] as String? ?? '',
      witnessTitle: json['witnessTitle'] as String? ?? '',
      witnessEmployer: json['witnessEmployer'] as String? ?? '',
      witnessPhone: json['witnessPhone'] as String? ?? '',
      statementText: json['statementText'] as String? ?? '',
      collectionDate: json['collectionDate'] != null
          ? DateTime.tryParse(json['collectionDate'] as String)
          : null,
      collectorName: json['collectorName'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    if (investigationId != null) 'investigationId': investigationId,
    'witnessName': witnessName,
    'witnessTitle': witnessTitle,
    'witnessEmployer': witnessEmployer,
    'witnessPhone': witnessPhone,
    'statementText': statementText,
    if (collectionDate != null)
      'collectionDate': collectionDate!.toUtc().toIso8601String(),
    'collectorName': collectorName,
  };
}

/// Full investigation model with nested child collections.
class Investigation {
  final int? id;
  final int incidentId;
  final String leadInvestigatorId;
  final String teamMembers;
  final DateTime? targetCompletionDate;
  final DateTime? actualCompletionDate;
  final String status;
  final String assignedBy;
  final String reviewedBy;
  final String reviewComments;
  final DateTime? reviewDate;
  final bool isOverdue;
  final int overdueEscalationLevel;
  final List<FiveWhy> fiveWhys;
  final List<ContributingFactor> contributingFactors;
  final List<WitnessStatement> witnessStatements;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Investigation({
    this.id,
    this.incidentId = 0,
    this.leadInvestigatorId = '',
    this.teamMembers = '',
    this.targetCompletionDate,
    this.actualCompletionDate,
    this.status = 'Assigned',
    this.assignedBy = '',
    this.reviewedBy = '',
    this.reviewComments = '',
    this.reviewDate,
    this.isOverdue = false,
    this.overdueEscalationLevel = 0,
    this.fiveWhys = const [],
    this.contributingFactors = const [],
    this.witnessStatements = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory Investigation.fromJson(Map<String, dynamic> json) {
    return Investigation(
      id: json['id'] as int?,
      incidentId: json['incidentId'] as int? ?? 0,
      leadInvestigatorId: json['leadInvestigatorId'] as String? ?? '',
      teamMembers: json['teamMembers'] as String? ?? '',
      targetCompletionDate: json['targetCompletionDate'] != null
          ? DateTime.tryParse(json['targetCompletionDate'] as String)
          : null,
      actualCompletionDate: json['actualCompletionDate'] != null
          ? DateTime.tryParse(json['actualCompletionDate'] as String)
          : null,
      status: json['status'] as String? ?? 'Assigned',
      assignedBy: json['assignedBy'] as String? ?? '',
      reviewedBy: json['reviewedBy'] as String? ?? '',
      reviewComments: json['reviewComments'] as String? ?? '',
      reviewDate: json['reviewDate'] != null
          ? DateTime.tryParse(json['reviewDate'] as String)
          : null,
      isOverdue: json['isOverdue'] as bool? ?? false,
      overdueEscalationLevel: json['overdueEscalationLevel'] as int? ?? 0,
      fiveWhys:
          (json['fiveWhys'] as List<dynamic>?)
              ?.map((e) => FiveWhy.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      contributingFactors:
          (json['contributingFactors'] as List<dynamic>?)
              ?.map(
                (e) => ContributingFactor.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      witnessStatements:
          (json['witnessStatements'] as List<dynamic>?)
              ?.map((e) => WitnessStatement.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }
}

/// Paginated investigation list response from the API.
class InvestigationListResponse {
  final List<Investigation> data;
  final int total;
  final int page;
  final int perPage;

  const InvestigationListResponse({
    required this.data,
    required this.total,
    required this.page,
    required this.perPage,
  });

  factory InvestigationListResponse.fromJson(Map<String, dynamic> json) {
    return InvestigationListResponse(
      data:
          (json['data'] as List<dynamic>?)
              ?.map((e) => Investigation.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      perPage: json['per_page'] as int? ?? 50,
    );
  }
}

// ---------------------------------------------------------------------------
// Repository — API client for all investigation endpoints
// ---------------------------------------------------------------------------

/// API client for all investigation-related endpoints.
///
/// Uses [AuthService] for JWT bearer tokens and [ApiConfig.baseUrl] for the
/// Go backend URL.
class InvestigationRepository {
  final ApiClient _api;

  InvestigationRepository(AuthService auth) : _api = ApiClient(auth);

  String get _base => ApiConfig.baseUrl;

  // ---- CRUD ----

  /// Lists investigations with optional filters and pagination.
  Future<InvestigationListResponse> listInvestigations({
    String? status,
    String? investigatorId,
    int? incidentId,
    bool? overdue,
    int page = 1,
    int perPage = 50,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (investigatorId != null && investigatorId.isNotEmpty) {
      params['investigator_id'] = investigatorId;
    }
    if (incidentId != null) params['incident_id'] = incidentId.toString();
    if (overdue == true) params['overdue'] = 'true';

    final uri = Uri.parse(
      '$_base/api/investigations',
    ).replace(queryParameters: params);
    final response = await _api.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to load investigations: ${response.body}');
    }
    return InvestigationListResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// Gets a single investigation by ID with preloaded child collections.
  Future<Investigation> getInvestigation(int id) async {
    final uri = Uri.parse('$_base/api/investigations/$id');
    final response = await _api.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to load investigation: ${response.body}');
    }
    return Investigation.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// Creates a new investigation. Safety Manager only.
  Future<Investigation> createInvestigation({
    required int incidentId,
    required String leadInvestigatorId,
    String teamMembers = '',
  }) async {
    final uri = Uri.parse('$_base/api/investigations');
    final response = await _api.post(
      uri,
      body: jsonEncode({
        'incidentId': incidentId,
        'leadInvestigatorId': leadInvestigatorId,
        'teamMembers': teamMembers,
      }),
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to create investigation: ${response.body}');
    }
    return Investigation.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// Updates investigation fields.
  Future<Investigation> updateInvestigation(
    int id, {
    String? leadInvestigatorId,
    String? teamMembers,
    String? status,
  }) async {
    final uri = Uri.parse('$_base/api/investigations/$id');
    final body = <String, dynamic>{};
    if (leadInvestigatorId != null) {
      body['leadInvestigatorId'] = leadInvestigatorId;
    }
    if (teamMembers != null) body['teamMembers'] = teamMembers;
    if (status != null) body['status'] = status;

    final response = await _api.put(uri, body: jsonEncode(body));
    if (response.statusCode != 200) {
      throw Exception('Failed to update investigation: ${response.body}');
    }
    return Investigation.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  // ---- Five-Why ----

  /// Creates or updates a five-why entry. If [fiveWhy.id] is non-null,
  /// the existing entry is updated; otherwise a new one is created.
  Future<FiveWhy> addFiveWhy(int investigationId, FiveWhy fiveWhy) async {
    final uri = Uri.parse(
      '$_base/api/investigations/$investigationId/five-whys',
    );
    final response = await _api.post(uri, body: jsonEncode(fiveWhy.toJson()));
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to save five-why: ${response.body}');
    }
    return FiveWhy.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Deletes a five-why entry.
  Future<void> deleteFiveWhy(int investigationId, int whyId) async {
    final uri = Uri.parse(
      '$_base/api/investigations/$investigationId/five-whys/$whyId',
    );
    final response = await _api.delete(uri);
    if (response.statusCode != 204) {
      throw Exception('Failed to delete five-why: ${response.body}');
    }
  }

  // ---- Contributing Factors ----

  /// Creates a new contributing factor.
  Future<ContributingFactor> addFactor(
    int investigationId,
    ContributingFactor factor,
  ) async {
    final uri = Uri.parse('$_base/api/investigations/$investigationId/factors');
    final response = await _api.post(uri, body: jsonEncode(factor.toJson()));
    if (response.statusCode != 201) {
      throw Exception('Failed to create factor: ${response.body}');
    }
    return ContributingFactor.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// Deletes a contributing factor.
  Future<void> deleteFactor(int investigationId, int factorId) async {
    final uri = Uri.parse(
      '$_base/api/investigations/$investigationId/factors/$factorId',
    );
    final response = await _api.delete(uri);
    if (response.statusCode != 204) {
      throw Exception('Failed to delete factor: ${response.body}');
    }
  }

  // ---- Witness Statements ----

  /// Creates a new witness statement.
  Future<WitnessStatement> addWitness(
    int investigationId,
    WitnessStatement statement,
  ) async {
    final uri = Uri.parse(
      '$_base/api/investigations/$investigationId/witnesses',
    );
    final response = await _api.post(uri, body: jsonEncode(statement.toJson()));
    if (response.statusCode != 201) {
      throw Exception('Failed to create witness statement: ${response.body}');
    }
    return WitnessStatement.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// Updates an existing witness statement.
  Future<WitnessStatement> updateWitness(
    int investigationId,
    int witnessId,
    WitnessStatement statement,
  ) async {
    final uri = Uri.parse(
      '$_base/api/investigations/$investigationId/witnesses/$witnessId',
    );
    final response = await _api.put(uri, body: jsonEncode(statement.toJson()));
    if (response.statusCode != 200) {
      throw Exception('Failed to update witness statement: ${response.body}');
    }
    return WitnessStatement.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  // ---- Workflow ----

  /// Submits an investigation for review. Validates min 3 five-whys and
  /// at least 1 primary contributing factor on the backend.
  Future<Investigation> submitForReview(int investigationId) async {
    final uri = Uri.parse(
      '$_base/api/investigations/$investigationId/submit-for-review',
    );
    final response = await _api.post(uri);
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(body['error'] ?? 'Failed to submit for review');
    }
    return Investigation.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// Reviews an investigation (approve or return). Safety Manager only.
  Future<Investigation> reviewInvestigation(
    int investigationId, {
    required String decision,
    required String comments,
  }) async {
    final uri = Uri.parse('$_base/api/investigations/$investigationId/review');
    final response = await _api.post(
      uri,
      body: jsonEncode({'decision': decision, 'comments': comments}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to review investigation: ${response.body}');
    }
    return Investigation.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  // ---- Settings ----

  /// Fetches configurable factor types from admin settings.
  Future<List<String>> getFactorTypes() async {
    final uri = Uri.parse('$_base/api/settings/factor_types');
    final response = await _api.get(uri);
    if (response.statusCode != 200) {
      // Return defaults if settings not available.
      return [
        'People',
        'Equipment',
        'Environmental',
        'Procedural',
        'Management/Organizational',
      ];
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final value = data['value'] as String? ?? '[]';
    final parsed = jsonDecode(value) as List<dynamic>;
    return parsed.map((e) => e.toString()).toList();
  }
}
