import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../../core/services/api_config.dart';
import '../../auth/data/auth_service.dart';

/// Data models for incident API responses.

class InjuredPerson {
  final int? id;
  final int? incidentId;
  final String name;
  final String jobTitle;
  final String division;
  final String injuryType;
  final String bodyPart;
  final String bodyPartSide;
  final String treatmentType;
  final String returnToWorkStatus;

  const InjuredPerson({
    this.id,
    this.incidentId,
    this.name = '',
    this.jobTitle = '',
    this.division = '',
    this.injuryType = '',
    this.bodyPart = '',
    this.bodyPartSide = '',
    this.treatmentType = '',
    this.returnToWorkStatus = '',
  });

  factory InjuredPerson.fromJson(Map<String, dynamic> json) {
    return InjuredPerson(
      id: json['id'] as int?,
      incidentId: json['incidentId'] as int?,
      name: json['name'] as String? ?? '',
      jobTitle: json['jobTitle'] as String? ?? '',
      division: json['division'] as String? ?? '',
      injuryType: json['injuryType'] as String? ?? '',
      bodyPart: json['bodyPart'] as String? ?? '',
      bodyPartSide: json['bodyPartSide'] as String? ?? '',
      treatmentType: json['treatmentType'] as String? ?? '',
      returnToWorkStatus: json['returnToWorkStatus'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    if (incidentId != null) 'incidentId': incidentId,
    'name': name,
    'jobTitle': jobTitle,
    'division': division,
    'injuryType': injuryType,
    'bodyPart': bodyPart,
    'bodyPartSide': bodyPartSide,
    'treatmentType': treatmentType,
    'returnToWorkStatus': returnToWorkStatus,
  };
}

class IncidentPhoto {
  final int id;
  final int incidentId;
  final String fileName;
  final String contentType;
  final String uploadedBy;
  final DateTime createdAt;

  const IncidentPhoto({
    required this.id,
    required this.incidentId,
    required this.fileName,
    required this.contentType,
    required this.uploadedBy,
    required this.createdAt,
  });

  factory IncidentPhoto.fromJson(Map<String, dynamic> json) {
    return IncidentPhoto(
      id: json['id'] as int? ?? 0,
      incidentId: json['incidentId'] as int? ?? 0,
      fileName: json['fileName'] as String? ?? '',
      contentType: json['contentType'] as String? ?? '',
      uploadedBy: json['uploadedBy'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }
}

class Incident {
  final int? id;
  final String type;
  final DateTime? date;
  final String location;
  final double latitude;
  final double longitude;
  final String division;
  final String projectJobSite;
  final String description;
  final String immediateActions;
  final String severity;
  final String potentialSeverity;
  final String shift;
  final String weather;
  final String status;
  final String reporterId;
  final bool isDraft;
  final int completionPercent;
  final bool? isOshaRecordable;
  final bool? isDart;
  final String oshaOverrideJustification;
  final bool isRailroadProperty;
  final String railroadClient;
  final bool railroadNotified;
  final DateTime? railroadNotificationDate;
  final String railroadNotificationMethod;
  final bool railroadNotificationOverdue;
  final List<InjuredPerson> injuredPersons;
  final List<IncidentPhoto> photos;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Incident({
    this.id,
    this.type = '',
    this.date,
    this.location = '',
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.division = '',
    this.projectJobSite = '',
    this.description = '',
    this.immediateActions = '',
    this.severity = '',
    this.potentialSeverity = '',
    this.shift = '',
    this.weather = '',
    this.status = 'Draft',
    this.reporterId = '',
    this.isDraft = true,
    this.completionPercent = 0,
    this.isOshaRecordable,
    this.isDart,
    this.oshaOverrideJustification = '',
    this.isRailroadProperty = false,
    this.railroadClient = '',
    this.railroadNotified = false,
    this.railroadNotificationDate,
    this.railroadNotificationMethod = '',
    this.railroadNotificationOverdue = false,
    this.injuredPersons = const [],
    this.photos = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory Incident.fromJson(Map<String, dynamic> json) {
    return Incident(
      id: json['id'] as int?,
      type: json['type'] as String? ?? '',
      date: json['date'] != null
          ? DateTime.parse(json['date'] as String)
          : null,
      location: json['location'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      division: json['division'] as String? ?? '',
      projectJobSite: json['projectJobSite'] as String? ?? '',
      description: json['description'] as String? ?? '',
      immediateActions: json['immediateActions'] as String? ?? '',
      severity: json['severity'] as String? ?? '',
      potentialSeverity: json['potentialSeverity'] as String? ?? '',
      shift: json['shift'] as String? ?? '',
      weather: json['weather'] as String? ?? '',
      status: json['status'] as String? ?? 'Draft',
      reporterId: json['reporterId'] as String? ?? '',
      isDraft: json['isDraft'] as bool? ?? true,
      completionPercent: json['completionPercent'] as int? ?? 0,
      isOshaRecordable: json['isOshaRecordable'] as bool?,
      isDart: json['isDart'] as bool?,
      oshaOverrideJustification:
          json['oshaOverrideJustification'] as String? ?? '',
      isRailroadProperty: json['isRailroadProperty'] as bool? ?? false,
      railroadClient: json['railroadClient'] as String? ?? '',
      railroadNotified: json['railroadNotified'] as bool? ?? false,
      railroadNotificationDate: json['railroadNotificationDate'] != null
          ? DateTime.parse(json['railroadNotificationDate'] as String)
          : null,
      railroadNotificationMethod:
          json['railroadNotificationMethod'] as String? ?? '',
      railroadNotificationOverdue:
          json['railroadNotificationOverdue'] as bool? ?? false,
      injuredPersons:
          (json['injuredPersons'] as List<dynamic>?)
              ?.map((e) => InjuredPerson.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      photos:
          (json['photos'] as List<dynamic>?)
              ?.map((e) => IncidentPhoto.fromJson(e as Map<String, dynamic>))
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

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'type': type,
    if (date != null) 'date': date!.toUtc().toIso8601String(),
    'location': location,
    'latitude': latitude,
    'longitude': longitude,
    'division': division,
    'projectJobSite': projectJobSite,
    'description': description,
    'immediateActions': immediateActions,
    'severity': severity,
    'potentialSeverity': potentialSeverity,
    'shift': shift,
    'weather': weather,
    'isDraft': isDraft,
    'isRailroadProperty': isRailroadProperty,
    'railroadClient': railroadClient,
    'railroadNotified': railroadNotified,
    if (railroadNotificationDate != null)
      'railroadNotificationDate': railroadNotificationDate!
          .toUtc()
          .toIso8601String(),
    'railroadNotificationMethod': railroadNotificationMethod,
    if (injuredPersons.isNotEmpty)
      'injuredPersons': injuredPersons.map((e) => e.toJson()).toList(),
  };
}

/// Paginated list response from the incidents API.
class IncidentListResponse {
  final List<Incident> data;
  final int total;
  final int page;
  final int perPage;

  const IncidentListResponse({
    required this.data,
    required this.total,
    required this.page,
    required this.perPage,
  });

  factory IncidentListResponse.fromJson(Map<String, dynamic> json) {
    return IncidentListResponse(
      data:
          (json['data'] as List<dynamic>?)
              ?.map((e) => Incident.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      perPage: json['per_page'] as int? ?? 50,
    );
  }
}

/// OSHA determination request.
class OshaDecisionRequest {
  final bool workRelated;
  final bool death;
  final bool daysAway;
  final bool restrictedTransfer;
  final bool medicalTreatment;
  final bool lossOfConsciousness;
  final bool significantDiagnosis;

  const OshaDecisionRequest({
    required this.workRelated,
    required this.death,
    required this.daysAway,
    required this.restrictedTransfer,
    required this.medicalTreatment,
    required this.lossOfConsciousness,
    required this.significantDiagnosis,
  });

  Map<String, dynamic> toJson() => {
    'workRelated': workRelated,
    'death': death,
    'daysAway': daysAway,
    'restrictedTransfer': restrictedTransfer,
    'medicalTreatment': medicalTreatment,
    'lossOfConsciousness': lossOfConsciousness,
    'significantDiagnosis': significantDiagnosis,
  };
}

/// API client for all incident-related endpoints.
///
/// Uses [AuthService] for JWT bearer tokens and [ApiConfig.baseUrl] for the
/// Go backend URL.
class IncidentRepository {
  final AuthService _auth;

  IncidentRepository(this._auth);

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_auth.token != null) 'Authorization': 'Bearer ${_auth.token}',
  };

  String get _base => ApiConfig.baseUrl;

  /// Lists incidents with optional filters and pagination.
  Future<IncidentListResponse> listIncidents({
    String? status,
    String? type,
    String? division,
    int page = 1,
    int perPage = 50,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (type != null && type.isNotEmpty) params['type'] = type;
    if (division != null && division.isNotEmpty) params['division'] = division;

    final uri = Uri.parse(
      '$_base/api/incidents',
    ).replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to load incidents: ${response.body}');
    }
    return IncidentListResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// Gets a single incident by ID with injured persons and photos.
  Future<Incident> getIncident(int id) async {
    final uri = Uri.parse('$_base/api/incidents/$id');
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to load incident: ${response.body}');
    }
    return Incident.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Creates a new incident.
  Future<Incident> createIncident(Incident data) async {
    final uri = Uri.parse('$_base/api/incidents');
    final response = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode(data.toJson()),
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to create incident: ${response.body}');
    }
    return Incident.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Updates an existing incident.
  Future<Incident> updateIncident(int id, Incident data) async {
    final uri = Uri.parse('$_base/api/incidents/$id');
    final response = await http.put(
      uri,
      headers: _headers,
      body: jsonEncode(data.toJson()),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update incident: ${response.body}');
    }
    return Incident.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Uploads a photo for an incident.
  Future<IncidentPhoto> uploadPhoto(int incidentId, XFile file) async {
    final uri = Uri.parse('$_base/api/incidents/$incidentId/photos');
    final request = http.MultipartRequest('POST', uri);
    if (_auth.token != null) {
      request.headers['Authorization'] = 'Bearer ${_auth.token}';
    }

    final bytes = await file.readAsBytes();
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: file.name),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode != 201) {
      throw Exception('Failed to upload photo: ${response.body}');
    }
    return IncidentPhoto.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// Submits OSHA determination answers for an incident.
  Future<Incident> oshaDecision(int id, OshaDecisionRequest answers) async {
    final uri = Uri.parse('$_base/api/incidents/$id/osha-determination');
    final response = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode(answers.toJson()),
    );
    if (response.statusCode != 200) {
      throw Exception('OSHA determination failed: ${response.body}');
    }
    return Incident.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Overrides the OSHA determination for an incident.
  Future<Incident> oshaOverride(
    int id,
    bool isRecordable,
    String justification,
  ) async {
    final uri = Uri.parse('$_base/api/incidents/$id/osha-override');
    final response = await http.put(
      uri,
      headers: _headers,
      body: jsonEncode({
        'isOshaRecordable': isRecordable,
        'justification': justification,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('OSHA override failed: ${response.body}');
    }
    return Incident.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Closes an incident.
  Future<Incident> closeIncident(int id) async {
    final uri = Uri.parse('$_base/api/incidents/$id/close');
    final response = await http.post(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to close incident: ${response.body}');
    }
    return Incident.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Reopens a closed incident.
  Future<Incident> reopenIncident(int id) async {
    final uri = Uri.parse('$_base/api/incidents/$id/reopen');
    final response = await http.post(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to reopen incident: ${response.body}');
    }
    return Incident.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Transitions incident status.
  Future<Incident> transitionStatus(int id, String newStatus) async {
    final uri = Uri.parse('$_base/api/incidents/$id/status');
    final response = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode({'status': newStatus}),
    );
    if (response.statusCode != 200) {
      throw Exception('Status transition failed: ${response.body}');
    }
    return Incident.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}
