import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/services/api_config.dart';
import '../../auth/data/auth_service.dart';

// ---------- Data Models ----------

/// A single audit log entry returned by GET /api/audit-logs.
class AuditLogEntry {
  final int id;
  final DateTime timestamp;
  final String userId;
  final String userRole;
  final String action;
  final String entityType;
  final int entityId;
  final String before;
  final String after;
  final String notes;

  const AuditLogEntry({
    required this.id,
    required this.timestamp,
    required this.userId,
    required this.userRole,
    required this.action,
    required this.entityType,
    required this.entityId,
    this.before = '',
    this.after = '',
    this.notes = '',
  });

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) {
    return AuditLogEntry(
      id: (json['id'] as num?)?.toInt() ?? 0,
      timestamp:
          DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      userId: json['userId'] as String? ?? '',
      userRole: json['userRole'] as String? ?? '',
      action: json['action'] as String? ?? '',
      entityType: json['entityType'] as String? ?? '',
      entityId: (json['entityId'] as num?)?.toInt() ?? 0,
      before: json['before'] as String? ?? '',
      after: json['after'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
    );
  }

  /// Returns a human-readable display name for the action.
  String get actionDisplay {
    switch (action) {
      case 'create':
        return 'Create';
      case 'update':
        return 'Update';
      case 'status_change':
        return 'Status Change';
      case 'approve':
        return 'Approve';
      case 'reject':
        return 'Reject';
      case 'assign':
        return 'Assign';
      case 'verify':
        return 'Verify';
      default:
        return action;
    }
  }

  /// Returns a human-readable display name for the user role.
  String get roleDisplay {
    switch (userRole) {
      case 'field_reporter':
        return 'Field Reporter';
      case 'safety_coordinator':
        return 'Safety Coordinator';
      case 'safety_manager':
        return 'Safety Manager';
      case 'pm':
        return 'Project Manager';
      case 'division_manager':
        return 'Division Manager';
      case 'executive':
        return 'Executive';
      case 'admin':
        return 'Admin';
      default:
        return userRole;
    }
  }
}

/// Paginated response wrapper for audit logs.
class AuditLogPage {
  final List<AuditLogEntry> data;
  final int total;
  final int page;
  final int perPage;

  const AuditLogPage({
    required this.data,
    required this.total,
    required this.page,
    required this.perPage,
  });

  int get totalPages =>
      (total / perPage).ceil().clamp(1, double.maxFinite.toInt());

  factory AuditLogPage.fromJson(Map<String, dynamic> json) {
    return AuditLogPage(
      data:
          (json['data'] as List<dynamic>?)
              ?.map((e) => AuditLogEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      perPage: (json['per_page'] as num?)?.toInt() ?? 50,
    );
  }
}

/// Filter parameters for the audit log query.
class AuditLogFilter {
  final String? entityType;
  final String? entityId;
  final String? userId;
  final String? action;
  final DateTime? dateStart;
  final DateTime? dateEnd;
  final int page;
  final int perPage;

  const AuditLogFilter({
    this.entityType,
    this.entityId,
    this.userId,
    this.action,
    this.dateStart,
    this.dateEnd,
    this.page = 1,
    this.perPage = 25,
  });

  AuditLogFilter copyWith({
    String? entityType,
    String? entityId,
    String? userId,
    String? action,
    DateTime? dateStart,
    DateTime? dateEnd,
    int? page,
    int? perPage,
    bool clearEntityType = false,
    bool clearEntityId = false,
    bool clearUserId = false,
    bool clearAction = false,
    bool clearDateStart = false,
    bool clearDateEnd = false,
  }) {
    return AuditLogFilter(
      entityType: clearEntityType ? null : (entityType ?? this.entityType),
      entityId: clearEntityId ? null : (entityId ?? this.entityId),
      userId: clearUserId ? null : (userId ?? this.userId),
      action: clearAction ? null : (action ?? this.action),
      dateStart: clearDateStart ? null : (dateStart ?? this.dateStart),
      dateEnd: clearDateEnd ? null : (dateEnd ?? this.dateEnd),
      page: page ?? this.page,
      perPage: perPage ?? this.perPage,
    );
  }

  Map<String, String> toQueryParams() {
    final params = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (entityType != null && entityType!.isNotEmpty) {
      params['entity_type'] = entityType!;
    }
    if (entityId != null && entityId!.isNotEmpty) {
      params['entity_id'] = entityId!;
    }
    if (userId != null && userId!.isNotEmpty) {
      params['user_id'] = userId!;
    }
    if (action != null && action!.isNotEmpty) {
      params['action'] = action!;
    }
    if (dateStart != null) {
      params['date_start'] =
          '${dateStart!.year.toString().padLeft(4, '0')}-${dateStart!.month.toString().padLeft(2, '0')}-${dateStart!.day.toString().padLeft(2, '0')}';
    }
    if (dateEnd != null) {
      params['date_end'] =
          '${dateEnd!.year.toString().padLeft(4, '0')}-${dateEnd!.month.toString().padLeft(2, '0')}-${dateEnd!.day.toString().padLeft(2, '0')}';
    }
    return params;
  }
}

// ---------- Repository ----------

/// API client for the audit log endpoint.
class AuditLogRepository {
  final AuthService _auth;

  AuditLogRepository(this._auth);

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_auth.token != null) 'Authorization': 'Bearer ${_auth.token}',
  };

  String get _base => ApiConfig.baseUrl;

  /// Fetches a page of audit log entries matching the given [filter].
  Future<AuditLogPage> getAuditLogs(AuditLogFilter filter) async {
    final uri = Uri.parse(
      '$_base/api/audit-logs',
    ).replace(queryParameters: filter.toQueryParams());
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 403) {
      throw Exception(
        'Access denied: audit logs restricted to Admin and Safety Manager',
      );
    }
    if (response.statusCode != 200) {
      throw Exception('Failed to load audit logs: ${response.body}');
    }

    return AuditLogPage.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}
