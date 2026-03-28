import 'dart:convert';

import '../../../core/services/api_client.dart';
import '../../../core/services/api_config.dart';
import '../../auth/data/auth_service.dart';

// ---------- Data Models ----------

/// Top-level dashboard data returned by GET /api/dashboard.
class DashboardData {
  final double trir;
  final double trirPrevious;
  final double dartRate;
  final double nearMissRatio;
  final int openInvestigations;
  final int openCapas;
  final int lostTimeIncidentsYtd;
  final List<MonthlyTRIR> trirTrend;
  final double trirBenchmark;
  final List<MonthlyIncidentTrend> incidentTrend;
  final List<DivisionCount> incidentsByDivision;
  final List<SeverityCount> severityDistribution;
  final LeadingIndicators leadingIndicators;
  final List<RecentIncident> recentIncidents;

  const DashboardData({
    required this.trir,
    required this.trirPrevious,
    required this.dartRate,
    required this.nearMissRatio,
    required this.openInvestigations,
    required this.openCapas,
    required this.lostTimeIncidentsYtd,
    required this.trirTrend,
    required this.trirBenchmark,
    required this.incidentTrend,
    required this.incidentsByDivision,
    required this.severityDistribution,
    required this.leadingIndicators,
    required this.recentIncidents,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      trir: (json['trir'] as num?)?.toDouble() ?? 0.0,
      trirPrevious: (json['trirPrevious'] as num?)?.toDouble() ?? 0.0,
      dartRate: (json['dartRate'] as num?)?.toDouble() ?? 0.0,
      nearMissRatio: (json['nearMissRatio'] as num?)?.toDouble() ?? 0.0,
      openInvestigations: json['openInvestigations'] as int? ?? 0,
      openCapas: json['openCapas'] as int? ?? 0,
      lostTimeIncidentsYtd: json['lostTimeIncidentsYtd'] as int? ?? 0,
      trirTrend:
          (json['trirTrend'] as List<dynamic>?)
              ?.map((e) => MonthlyTRIR.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      trirBenchmark: (json['trirBenchmark'] as num?)?.toDouble() ?? 3.0,
      incidentTrend:
          (json['incidentTrend'] as List<dynamic>?)
              ?.map(
                (e) => MonthlyIncidentTrend.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      incidentsByDivision:
          (json['incidentsByDivision'] as List<dynamic>?)
              ?.map((e) => DivisionCount.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      severityDistribution:
          (json['severityDistribution'] as List<dynamic>?)
              ?.map((e) => SeverityCount.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      leadingIndicators: json['leadingIndicators'] != null
          ? LeadingIndicators.fromJson(
              json['leadingIndicators'] as Map<String, dynamic>,
            )
          : const LeadingIndicators(
              nearMissReportingRate: IndicatorMetric(target: 10, actual: 0),
              capaClosureRate: IndicatorMetric(target: 90, actual: 0),
              investigationTimeliness: IndicatorMetric(target: 95, actual: 0),
            ),
      recentIncidents:
          (json['recentIncidents'] as List<dynamic>?)
              ?.map((e) => RecentIncident.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class MonthlyTRIR {
  final String month;
  final double trir;

  const MonthlyTRIR({required this.month, required this.trir});

  factory MonthlyTRIR.fromJson(Map<String, dynamic> json) {
    return MonthlyTRIR(
      month: json['month'] as String? ?? '',
      trir: (json['trir'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class MonthlyIncidentTrend {
  final String month;
  final int injury;
  final int nearMiss;
  final int propertyDamage;
  final int environmental;
  final int vehicle;
  final int fire;
  final int utilityStrike;

  const MonthlyIncidentTrend({
    required this.month,
    this.injury = 0,
    this.nearMiss = 0,
    this.propertyDamage = 0,
    this.environmental = 0,
    this.vehicle = 0,
    this.fire = 0,
    this.utilityStrike = 0,
  });

  int get total =>
      injury +
      nearMiss +
      propertyDamage +
      environmental +
      vehicle +
      fire +
      utilityStrike;

  factory MonthlyIncidentTrend.fromJson(Map<String, dynamic> json) {
    return MonthlyIncidentTrend(
      month: json['month'] as String? ?? '',
      injury: json['injury'] as int? ?? 0,
      nearMiss: json['nearMiss'] as int? ?? 0,
      propertyDamage: json['propertyDamage'] as int? ?? 0,
      environmental: json['environmental'] as int? ?? 0,
      vehicle: json['vehicle'] as int? ?? 0,
      fire: json['fire'] as int? ?? 0,
      utilityStrike: json['utilityStrike'] as int? ?? 0,
    );
  }
}

class DivisionCount {
  final String division;
  final int count;

  const DivisionCount({required this.division, required this.count});

  factory DivisionCount.fromJson(Map<String, dynamic> json) {
    return DivisionCount(
      division: json['division'] as String? ?? '',
      count: json['count'] as int? ?? 0,
    );
  }
}

class SeverityCount {
  final String severity;
  final int count;

  const SeverityCount({required this.severity, required this.count});

  factory SeverityCount.fromJson(Map<String, dynamic> json) {
    return SeverityCount(
      severity: json['severity'] as String? ?? '',
      count: json['count'] as int? ?? 0,
    );
  }
}

class LeadingIndicators {
  final IndicatorMetric nearMissReportingRate;
  final IndicatorMetric capaClosureRate;
  final IndicatorMetric investigationTimeliness;

  const LeadingIndicators({
    required this.nearMissReportingRate,
    required this.capaClosureRate,
    required this.investigationTimeliness,
  });

  factory LeadingIndicators.fromJson(Map<String, dynamic> json) {
    return LeadingIndicators(
      nearMissReportingRate: IndicatorMetric.fromJson(
        json['nearMissReportingRate'] as Map<String, dynamic>? ?? {},
      ),
      capaClosureRate: IndicatorMetric.fromJson(
        json['capaClosureRate'] as Map<String, dynamic>? ?? {},
      ),
      investigationTimeliness: IndicatorMetric.fromJson(
        json['investigationTimeliness'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

class IndicatorMetric {
  final double target;
  final double actual;

  const IndicatorMetric({required this.target, required this.actual});

  factory IndicatorMetric.fromJson(Map<String, dynamic> json) {
    return IndicatorMetric(
      target: (json['target'] as num?)?.toDouble() ?? 0.0,
      actual: (json['actual'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class RecentIncident {
  final int id;
  final String date;
  final String type;
  final String severity;
  final String status;
  final String division;

  const RecentIncident({
    required this.id,
    required this.date,
    required this.type,
    required this.severity,
    required this.status,
    required this.division,
  });

  factory RecentIncident.fromJson(Map<String, dynamic> json) {
    return RecentIncident(
      id: json['id'] as int? ?? 0,
      date: json['date'] as String? ?? '',
      type: json['type'] as String? ?? '',
      severity: json['severity'] as String? ?? '',
      status: json['status'] as String? ?? '',
      division: json['division'] as String? ?? '',
    );
  }
}

// ---------- Advanced Analytics Models ----------

/// Body part injury count for the body map visualization.
class BodyPartCount {
  final String bodyPart;
  final int count;

  const BodyPartCount({required this.bodyPart, required this.count});

  factory BodyPartCount.fromJson(Map<String, dynamic> json) {
    return BodyPartCount(
      bodyPart: json['bodyPart'] as String? ?? '',
      count: json['count'] as int? ?? 0,
    );
  }
}

/// Single cell in the hour x day-of-week heatmap grid.
class TimeHeatmapCell {
  final int hour;
  final String day;
  final int count;

  const TimeHeatmapCell({
    required this.hour,
    required this.day,
    required this.count,
  });

  factory TimeHeatmapCell.fromJson(Map<String, dynamic> json) {
    return TimeHeatmapCell(
      hour: json['hour'] as int? ?? 0,
      day: json['day'] as String? ?? '',
      count: json['count'] as int? ?? 0,
    );
  }
}

/// Multi-metric division data for the radar chart.
class DivisionRadarEntry {
  final String division;
  final int incidents;
  final double trir;
  final double investigationTimeliness;
  final double capaClosureRate;

  const DivisionRadarEntry({
    required this.division,
    required this.incidents,
    required this.trir,
    required this.investigationTimeliness,
    required this.capaClosureRate,
  });

  factory DivisionRadarEntry.fromJson(Map<String, dynamic> json) {
    return DivisionRadarEntry(
      division: json['division'] as String? ?? '',
      incidents: json['incidents'] as int? ?? 0,
      trir: (json['trir'] as num?)?.toDouble() ?? 0.0,
      investigationTimeliness:
          (json['investigationTimeliness'] as num?)?.toDouble() ?? 0.0,
      capaClosureRate: (json['capaClosureRate'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Hours worked entry for TRIR/DART denominator.
class HoursWorked {
  final int? id;
  final DateTime reportingPeriodStart;
  final DateTime reportingPeriodEnd;
  final double totalHours;
  final String division;
  final String enteredByUserId;
  final DateTime? createdAt;

  const HoursWorked({
    this.id,
    required this.reportingPeriodStart,
    required this.reportingPeriodEnd,
    required this.totalHours,
    this.division = '',
    this.enteredByUserId = '',
    this.createdAt,
  });

  factory HoursWorked.fromJson(Map<String, dynamic> json) {
    return HoursWorked(
      id: json['id'] as int?,
      reportingPeriodStart: DateTime.parse(
        json['reportingPeriodStart'] as String,
      ),
      reportingPeriodEnd: DateTime.parse(json['reportingPeriodEnd'] as String),
      totalHours: (json['totalHours'] as num?)?.toDouble() ?? 0.0,
      division: json['division'] as String? ?? '',
      enteredByUserId: json['enteredByUserId'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'reportingPeriodStart': reportingPeriodStart.toUtc().toIso8601String(),
    'reportingPeriodEnd': reportingPeriodEnd.toUtc().toIso8601String(),
    'totalHours': totalHours,
    'division': division,
  };
}

// ---------- Repository ----------

/// API client for the safety dashboard and hours-worked endpoints.
class DashboardRepository {
  final ApiClient _api;

  DashboardRepository(AuthService auth) : _api = ApiClient(auth);

  String get _base => ApiConfig.baseUrl;

  /// Fetches comprehensive dashboard data.
  Future<DashboardData> getDashboard() async {
    final uri = Uri.parse('$_base/api/dashboard');
    final response = await _api.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to load dashboard: ${response.body}');
    }
    return DashboardData.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// Creates a new hours-worked entry.
  Future<HoursWorked> createHoursWorked(HoursWorked entry) async {
    final uri = Uri.parse('$_base/api/hours-worked');
    final response = await _api.post(uri, body: jsonEncode(entry.toJson()));
    if (response.statusCode != 201) {
      throw Exception('Failed to create hours worked: ${response.body}');
    }
    return HoursWorked.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// Lists all hours-worked entries.
  Future<List<HoursWorked>> listHoursWorked() async {
    final uri = Uri.parse('$_base/api/hours-worked');
    final response = await _api.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to load hours worked: ${response.body}');
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => HoursWorked.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetches body part injury counts for the body map visualization.
  /// Requires Safety Coordinator role or above.
  Future<List<BodyPartCount>> getBodyMap() async {
    final uri = Uri.parse('$_base/api/dashboard/body-map');
    final response = await _api.get(uri);
    if (response.statusCode == 403) {
      throw Exception('Insufficient permissions to view body map data');
    }
    if (response.statusCode != 200) {
      throw Exception('Failed to load body map: ${response.body}');
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => BodyPartCount.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetches incident counts by hour-of-day and day-of-week for the heatmap.
  Future<List<TimeHeatmapCell>> getTimeHeatmap() async {
    final uri = Uri.parse('$_base/api/dashboard/time-heatmap');
    final response = await _api.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to load time heatmap: ${response.body}');
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => TimeHeatmapCell.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetches multi-metric division data for the radar chart.
  Future<List<DivisionRadarEntry>> getDivisionRadar() async {
    final uri = Uri.parse('$_base/api/dashboard/division-radar');
    final response = await _api.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to load division radar: ${response.body}');
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => DivisionRadarEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
