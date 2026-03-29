import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../../app/herzog_theme.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/data/role.dart';
import '../data/dashboard_repository.dart';
import '../services/dashboard_pdf_service.dart';
import '../widgets/body_map_chart.dart';
import '../widgets/division_radar_chart.dart';
import '../widgets/time_heatmap_chart.dart';
import '../widgets/welcome_header.dart';
import '../../activity/widgets/activity_feed.dart';
import '../../admin/data/agent_session_repository.dart';

/// Uniform gap used throughout the dashboard for consistent spacing.
const double _kDashboardGap = 16;

/// Full safety dashboard replacing the placeholder.
///
/// Shows KPI cards, charts (TRIR trend, incident trend stacked bar,
/// division grouped bar, severity donut), leading indicators,
/// recent-incidents table, and advanced analytics (body map, time heatmap,
/// division radar).
class SafetyDashboardPage extends StatefulWidget {
  const SafetyDashboardPage({super.key});

  @override
  State<SafetyDashboardPage> createState() => _SafetyDashboardPageState();
}

class _SafetyDashboardPageState extends State<SafetyDashboardPage> {
  DashboardData? _data;
  bool _loading = true;
  String? _error;
  bool _generatingPdf = false;

  // Advanced analytics data
  List<BodyPartCount>? _bodyMapData;
  List<TimeHeatmapCell>? _timeHeatmapData;
  List<DivisionRadarEntry>? _divisionRadarData;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthService>();
      final repo = DashboardRepository(auth);

      // Load main dashboard data
      final data = await repo.getDashboard();
      if (mounted) setState(() => _data = data);

      // Load advanced analytics in parallel (non-blocking)
      _loadAnalytics(auth, repo);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Loads advanced analytics data independently. Failures are silently
  /// handled — the sections simply won't render if their data is unavailable.
  Future<void> _loadAnalytics(
    AuthService auth,
    DashboardRepository repo,
  ) async {
    // Time heatmap and division radar are available to all authenticated users
    final heatmapFuture = repo.getTimeHeatmap();
    final radarFuture = repo.getDivisionRadar();

    // Body map requires exactly Safety Coordinator, Safety Manager, or Admin.
    // PM/DivMgr/Executive are higher in the hierarchy but the backend only
    // permits these three roles (aggregate counts, not individual records).
    final role = auth.currentRole;
    final canViewMedical =
        role == Role.safetyCoordinator ||
        role == Role.safetyManager ||
        role == Role.admin;
    final bodyMapFuture = canViewMedical ? repo.getBodyMap() : null;

    try {
      final heatmap = await heatmapFuture;
      if (mounted) setState(() => _timeHeatmapData = heatmap);
    } catch (_) {
      // Silently ignore — section won't render
    }

    try {
      final radar = await radarFuture;
      if (mounted) setState(() => _divisionRadarData = radar);
    } catch (_) {
      // Silently ignore — section won't render
    }

    if (bodyMapFuture != null) {
      try {
        final bodyMap = await bodyMapFuture;
        if (mounted) setState(() => _bodyMapData = bodyMap);
      } catch (_) {
        // Silently ignore — section won't render
      }
    }
  }

  /// Shows a month/year picker, then generates and opens the PDF report.
  Future<void> _exportReport() async {
    final data = _data;
    if (data == null) return;

    // Default to previous month.
    final now = DateTime.now();
    final defaultMonth = DateTime(now.year, now.month - 1);

    // Show month/year picker dialog.
    final selectedMonth = await showDialog<DateTime>(
      context: context,
      builder: (ctx) => _MonthYearPickerDialog(initialDate: defaultMonth),
    );
    if (selectedMonth == null || !mounted) return;

    setState(() => _generatingPdf = true);
    try {
      final pdf = await DashboardPdfService.generateReport(
        data: data,
        reportMonth: selectedMonth,
      );
      if (!mounted) return;

      final monthLabel =
          '${selectedMonth.year}_${selectedMonth.month.toString().padLeft(2, '0')}';
      await Printing.layoutPdf(
        onLayout: (_) => pdf.save(),
        name: 'SafeTrack_Monthly_Report_$monthLabel.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate PDF: $e'),
            backgroundColor: HerzogColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildBody();
  }

  /// Builds the dashboard action buttons (Export, Hours Worked, Refresh).
  Widget _buildActionButtons(AuthService auth) {
    final canManageHours =
        auth.currentRole == Role.safetyManager ||
        auth.currentRole == Role.admin;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: _kDashboardGap,
        vertical: _kDashboardGap / 2,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_data != null)
            _generatingPdf
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: _kDashboardGap),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : OutlinedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf, size: 18),
                    label: const Text('Export Report'),
                    onPressed: _exportReport,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: HerzogColors.navyBlue,
                      side: const BorderSide(color: HerzogColors.navyBlue),
                      padding: const EdgeInsets.symmetric(
                        horizontal: _kDashboardGap,
                      ),
                    ),
                  ),
          const SizedBox(width: _kDashboardGap),
          if (canManageHours)
            IconButton(
              icon: const Icon(Icons.access_time),
              tooltip: 'Hours Worked',
              onPressed: () => context.push('/dashboard/hours-worked'),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Failed to load dashboard',
              style: HerzogText.heading(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(_error!, style: HerzogText.body(color: HerzogColors.errorRed)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    final data = _data;
    if (data == null) return const SizedBox.shrink();

    return RefreshIndicator(
      onRefresh: _load,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          final auth = context.watch<AuthService>();
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Welcome header with role badge and quick-action cards.
                const WelcomeHeader(),
                // Action buttons (Export, Hours Worked, Refresh) — moved from removed AppBar.
                _buildActionButtons(auth),
                Padding(
                  padding: const EdgeInsets.all(_kDashboardGap),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _KPICards(data: data, isWide: isWide),
                      const SizedBox(height: _kDashboardGap),
                      if (isWide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 350,
                                child: _IncidentTrendChart(data: data),
                              ),
                            ),
                            const SizedBox(width: _kDashboardGap),
                            Expanded(
                              child: SizedBox(
                                height: 350,
                                child: _TRIRTrendChart(data: data),
                              ),
                            ),
                          ],
                        )
                      else ...[
                        SizedBox(
                          height: 350,
                          child: _IncidentTrendChart(data: data),
                        ),
                        const SizedBox(height: _kDashboardGap),
                        SizedBox(
                          height: 350,
                          child: _TRIRTrendChart(data: data),
                        ),
                      ],
                      const SizedBox(height: _kDashboardGap),
                      if (isWide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 350,
                                child: _DivisionChart(data: data),
                              ),
                            ),
                            const SizedBox(width: _kDashboardGap),
                            Expanded(
                              child: SizedBox(
                                height: 350,
                                child: _SeverityDonut(data: data),
                              ),
                            ),
                          ],
                        )
                      else ...[
                        SizedBox(
                          height: 350,
                          child: _DivisionChart(data: data),
                        ),
                        const SizedBox(height: _kDashboardGap),
                        SizedBox(
                          height: 350,
                          child: _SeverityDonut(data: data),
                        ),
                      ],
                      const SizedBox(height: _kDashboardGap),
                      _LeadingIndicatorsCard(data: data),
                      const SizedBox(height: _kDashboardGap),
                      _RecentIncidentsTable(data: data),
                      // --- Advanced Analytics ---
                      if (_timeHeatmapData != null ||
                          _bodyMapData != null ||
                          _divisionRadarData != null) ...[
                        const SizedBox(height: _kDashboardGap),
                        Semantics(
                          header: true,
                          child: Text(
                            'ADVANCED ANALYTICS',
                            style: HerzogText.heading(fontSize: 20),
                          ),
                        ),
                        const SizedBox(height: _kDashboardGap),
                      ],
                      // Time heatmap
                      if (_timeHeatmapData != null) ...[
                        TimeHeatmapChart(data: _timeHeatmapData!),
                        const SizedBox(height: _kDashboardGap),
                      ],
                      // Body map and division radar side-by-side on wide screens
                      if (isWide &&
                          _bodyMapData != null &&
                          _divisionRadarData != null)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: BodyMapChart(data: _bodyMapData!)),
                            const SizedBox(width: _kDashboardGap),
                            Expanded(
                              child: DivisionRadarChart(
                                data: _divisionRadarData!,
                              ),
                            ),
                          ],
                        )
                      else ...[
                        if (_bodyMapData != null) ...[
                          BodyMapChart(data: _bodyMapData!),
                          const SizedBox(height: _kDashboardGap),
                        ],
                        if (_divisionRadarData != null)
                          DivisionRadarChart(data: _divisionRadarData!),
                      ],
                      // --- Agent badge (Admin / Safety Manager only) ---
                      if (auth.currentRole == Role.admin ||
                          auth.currentRole == Role.safetyManager) ...[
                        const SizedBox(height: _kDashboardGap),
                        const _AgentBadge(),
                      ],
                      // --- Recent Activity Feed ---
                      const SizedBox(height: _kDashboardGap),
                      const _RecentActivitySection(),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------- Recent Activity Section ----------

class _RecentActivitySection extends StatefulWidget {
  const _RecentActivitySection();

  @override
  State<_RecentActivitySection> createState() => _RecentActivitySectionState();
}

class _RecentActivitySectionState extends State<_RecentActivitySection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'RECENT ACTIVITY',
                    style: HerzogText.heading(fontSize: 20),
                  ),
                ),
                const SizedBox(width: _kDashboardGap),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: isDark
                      ? HerzogDarkColors.textSecondary
                      : HerzogColors.midGray,
                ),
              ],
            ),
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: _kDashboardGap),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: isDark
                    ? HerzogDarkColors.border
                    : HerzogColors.borderGray,
              ),
            ),
            child: const ActivityFeed(compact: true, maxItems: 10),
          ),
        ],
      ],
    );
  }
}

// ---------- KPI Cards ----------

class _KPICards extends StatelessWidget {
  final DashboardData data;
  final bool isWide;

  const _KPICards({required this.data, required this.isWide});

  @override
  Widget build(BuildContext context) {
    final cards = [
      _KPITile(
        label: 'TRIR',
        value: data.trir.toStringAsFixed(2),
        trend: data.trir < data.trirPrevious
            ? _Trend.down
            : data.trir > data.trirPrevious
            ? _Trend.up
            : _Trend.flat,
        semanticLabel:
            'TRIR ${data.trir.toStringAsFixed(2)}, previous ${data.trirPrevious.toStringAsFixed(2)}',
      ),
      _KPITile(
        label: 'DART Rate',
        value: data.dartRate.toStringAsFixed(2),
        semanticLabel: 'DART Rate ${data.dartRate.toStringAsFixed(2)}',
      ),
      _KPITile(
        label: 'Near Miss Ratio',
        value: data.nearMissRatio.toStringAsFixed(2),
        semanticLabel:
            'Near Miss Ratio ${data.nearMissRatio.toStringAsFixed(2)}',
      ),
      _KPITile(
        label: 'Open Investigations',
        value: data.openInvestigations.toString(),
        semanticLabel: '${data.openInvestigations} open investigations',
      ),
      _KPITile(
        label: 'Open CAPAs',
        value: data.openCapas.toString(),
        semanticLabel: '${data.openCapas} open CAPAs',
      ),
      _KPITile(
        label: 'Lost Time Incidents YTD',
        value: data.lostTimeIncidentsYtd.toString(),
        semanticLabel:
            '${data.lostTimeIncidentsYtd} lost time incidents year to date',
      ),
    ];

    // Always use 4 columns so all 6 cards have identical widths.
    // On narrow screens (< 900 px) the Wrap reflows to 2 columns naturally.
    const int kColumns = 4;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth =
            (constraints.maxWidth - _kDashboardGap * (kColumns - 1)) / kColumns;
        return Wrap(
          spacing: _kDashboardGap,
          runSpacing: _kDashboardGap,
          children: cards
              .map((c) => SizedBox(width: cardWidth, height: 110, child: c))
              .toList(),
        );
      },
    );
  }
}

enum _Trend { up, down, flat }

class _KPITile extends StatelessWidget {
  final String label;
  final String value;
  final _Trend? trend;
  final String? semanticLabel;

  const _KPITile({
    required this.label,
    required this.value,
    this.trend,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? HerzogDarkColors.surface : HerzogColors.white;
    final borderColor = isDark
        ? HerzogDarkColors.border
        : HerzogColors.borderGray;

    return Semantics(
      label: semanticLabel ?? '$label: $value',
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          border: Border(
            left: const BorderSide(color: HerzogColors.gold, width: 4),
            top: BorderSide(color: borderColor),
            right: BorderSide(color: borderColor),
            bottom: BorderSide(color: borderColor),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: HerzogText.label(
                color: isDark
                    ? HerzogDarkColors.textMuted
                    : HerzogColors.midGray,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  value,
                  style: HerzogText.heading(
                    fontSize: 28,
                    color: isDark
                        ? HerzogDarkColors.textPrimary
                        : HerzogColors.richBlack,
                  ),
                ),
                if (trend != null) ...[
                  const SizedBox(width: 6),
                  Icon(
                    trend == _Trend.down
                        ? Icons.arrow_downward
                        : trend == _Trend.up
                        ? Icons.arrow_upward
                        : Icons.horizontal_rule,
                    color: trend == _Trend.down
                        ? HerzogColors.successGreen
                        : trend == _Trend.up
                        ? HerzogColors.errorRed
                        : isDark
                        ? HerzogDarkColors.textMuted
                        : HerzogColors.midGray,
                    size: 20,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IncidentTrendChart extends StatelessWidget {
  final DashboardData data;

  const _IncidentTrendChart({required this.data});

  static const _typeColors = [
    HerzogColors.errorRed, // Injury
    HerzogColors.warningAmber, // Near Miss
    HerzogColors.navyBlue, // Property Damage
    HerzogColors.successGreen, // Environmental
    HerzogColors.chartPurple, // Vehicle
    HerzogColors.gold, // Fire
    HerzogColors.chartSlate, // Utility Strike
  ];

  static const _typeLabels = [
    'Injury',
    'Near Miss',
    'Property Damage',
    'Environmental',
    'Vehicle',
    'Fire',
    'Utility Strike',
  ];

  @override
  Widget build(BuildContext context) {
    final trend = data.incidentTrend;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'INCIDENT TREND (12 MONTHS)',
              style: HerzogText.heading(fontSize: 16),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: List.generate(_typeLabels.length, (i) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _typeColors[i],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(_typeLabels[i], style: HerzogText.body(fontSize: 11)),
                  ],
                );
              }),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: trend.isEmpty
                  ? Center(
                      child: Text(
                        'No data',
                        style: HerzogText.body(color: HerzogColors.smoke),
                      ),
                    )
                  : BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        barTouchData: BarTouchData(enabled: true),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28,
                              getTitlesWidget: (v, _) => Text(
                                v.toInt().toString(),
                                style: HerzogText.body(fontSize: 10),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (v, _) {
                                final idx = v.toInt();
                                if (idx < 0 || idx >= trend.length) {
                                  return const SizedBox.shrink();
                                }
                                final label = trend[idx].month;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    label.length >= 7
                                        ? label.substring(5)
                                        : label,
                                    style: HerzogText.body(fontSize: 9),
                                  ),
                                );
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        gridData: const FlGridData(show: true),
                        borderData: FlBorderData(show: false),
                        barGroups: List.generate(trend.length, (i) {
                          final t = trend[i];
                          final values = [
                            t.injury.toDouble(),
                            t.nearMiss.toDouble(),
                            t.propertyDamage.toDouble(),
                            t.environmental.toDouble(),
                            t.vehicle.toDouble(),
                            t.fire.toDouble(),
                            t.utilityStrike.toDouble(),
                          ];
                          return BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: t.total.toDouble(),
                                width: 14,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(2),
                                  topRight: Radius.circular(2),
                                ),
                                rodStackItems: _buildStack(values),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<BarChartRodStackItem> _buildStack(List<double> values) {
    final items = <BarChartRodStackItem>[];
    double from = 0;
    for (int i = 0; i < values.length; i++) {
      if (values[i] > 0) {
        items.add(BarChartRodStackItem(from, from + values[i], _typeColors[i]));
        from += values[i];
      }
    }
    return items;
  }
}

// ---------- TRIR Trend Line Chart ----------

class _TRIRTrendChart extends StatelessWidget {
  final DashboardData data;

  const _TRIRTrendChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final trend = data.trirTrend;
    final benchmark = data.trirBenchmark;

    // Find max Y for chart
    double maxY = benchmark;
    for (final m in trend) {
      if (m.trir > maxY) maxY = m.trir;
    }
    maxY = (maxY * 1.3).ceilToDouble();
    if (maxY < 1) maxY = 5;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('TRIR TREND', style: HerzogText.heading(fontSize: 16)),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(width: 20, height: 2, color: HerzogColors.navyBlue),
                const SizedBox(width: 4),
                Text('TRIR', style: HerzogText.body(fontSize: 11)),
                const SizedBox(width: 16),
                _dashedLine(),
                const SizedBox(width: 4),
                Text(
                  'Benchmark (${benchmark.toStringAsFixed(1)})',
                  style: HerzogText.body(fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: trend.isEmpty
                  ? Center(
                      child: Text(
                        'No data',
                        style: HerzogText.body(color: HerzogColors.smoke),
                      ),
                    )
                  : LineChart(
                      LineChartData(
                        minY: 0,
                        maxY: maxY,
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 32,
                              getTitlesWidget: (v, _) => Text(
                                v.toStringAsFixed(1),
                                style: HerzogText.body(fontSize: 10),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 1,
                              getTitlesWidget: (v, _) {
                                final idx = v.toInt();
                                if (idx < 0 || idx >= trend.length) {
                                  return const SizedBox.shrink();
                                }
                                final label = trend[idx].month;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    label.length >= 7
                                        ? label.substring(5)
                                        : label,
                                    style: HerzogText.body(fontSize: 9),
                                  ),
                                );
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        gridData: const FlGridData(show: true),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          // TRIR line
                          LineChartBarData(
                            spots: List.generate(
                              trend.length,
                              (i) => FlSpot(i.toDouble(), trend[i].trir),
                            ),
                            isCurved: true,
                            color: HerzogColors.navyBlue,
                            barWidth: 3,
                            dotData: const FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              color: HerzogColors.navyBlue.withValues(
                                alpha: 0.08,
                              ),
                            ),
                          ),
                          // Benchmark dashed reference line
                          LineChartBarData(
                            spots: [
                              FlSpot(0, benchmark),
                              FlSpot((trend.length - 1).toDouble(), benchmark),
                            ],
                            isCurved: false,
                            color: HerzogColors.errorRed,
                            barWidth: 1.5,
                            dashArray: [6, 4],
                            dotData: const FlDotData(show: false),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dashedLine() {
    return SizedBox(
      width: 20,
      height: 2,
      child: CustomPaint(painter: _DashedLinePainter()),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = HerzogColors.errorRed
      ..strokeWidth = 2;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset(x + 4, size.height / 2),
        paint,
      );
      x += 6;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------- Division Grouped Bar ----------

class _DivisionChart extends StatelessWidget {
  final DashboardData data;

  const _DivisionChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final divs = data.incidentsByDivision;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'INCIDENTS BY DIVISION',
              style: HerzogText.heading(fontSize: 16),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: divs.isEmpty
                  ? Center(
                      child: Text(
                        'No data',
                        style: HerzogText.body(color: HerzogColors.smoke),
                      ),
                    )
                  : BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipItem: (group, gIdx, rod, rIdx) {
                              return BarTooltipItem(
                                '${divs[group.x.toInt()].division}\n${rod.toY.toInt()}',
                                HerzogText.body(
                                  fontSize: 12,
                                  color: HerzogColors.white,
                                ),
                              );
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28,
                              getTitlesWidget: (v, _) => Text(
                                v.toInt().toString(),
                                style: HerzogText.body(fontSize: 10),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (v, _) {
                                final idx = v.toInt();
                                if (idx < 0 || idx >= divs.length) {
                                  return const SizedBox.shrink();
                                }
                                final label = divs[idx].division;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    label.length > 8
                                        ? '${label.substring(0, 8)}..'
                                        : label,
                                    style: HerzogText.body(fontSize: 9),
                                  ),
                                );
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        gridData: const FlGridData(show: true),
                        borderData: FlBorderData(show: false),
                        barGroups: List.generate(divs.length, (i) {
                          return BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: divs[i].count.toDouble(),
                                width: 18,
                                color:
                                    HerzogColors.chartColors[i %
                                        HerzogColors.chartColors.length],
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(3),
                                  topRight: Radius.circular(3),
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Severity Donut ----------

class _SeverityDonut extends StatelessWidget {
  final DashboardData data;

  const _SeverityDonut({required this.data});

  @override
  Widget build(BuildContext context) {
    final sevs = data.severityDistribution;
    final total = sevs.fold<int>(0, (s, e) => s + e.count);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SEVERITY DISTRIBUTION',
              style: HerzogText.heading(fontSize: 16),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: sevs.isEmpty
                  ? Center(
                      child: Text(
                        'No data',
                        style: HerzogText.body(color: HerzogColors.smoke),
                      ),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 40,
                              sections: List.generate(sevs.length, (i) {
                                final pct = total > 0
                                    ? (sevs[i].count / total) * 100
                                    : 0;
                                return PieChartSectionData(
                                  value: sevs[i].count.toDouble(),
                                  title: '${pct.toStringAsFixed(0)}%',
                                  titleStyle: HerzogText.body(
                                    fontSize: 11,
                                    color: HerzogColors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  color:
                                      HerzogColors.chartColors[i %
                                          HerzogColors.chartColors.length],
                                  radius: 55,
                                );
                              }),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: List.generate(sevs.length, (i) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color:
                                          HerzogColors.chartColors[i %
                                              HerzogColors.chartColors.length],
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${sevs[i].severity} (${sevs[i].count})',
                                    style: HerzogText.body(fontSize: 12),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Leading Indicators ----------

class _LeadingIndicatorsCard extends StatelessWidget {
  final DashboardData data;

  const _LeadingIndicatorsCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final li = data.leadingIndicators;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('LEADING INDICATORS', style: HerzogText.heading(fontSize: 16)),
            const SizedBox(height: 12),
            _IndicatorRow(
              label: 'Near Miss Reporting Rate',
              target: li.nearMissReportingRate.target,
              actual: li.nearMissReportingRate.actual,
              unit: 'ratio',
            ),
            const SizedBox(height: 12),
            _IndicatorRow(
              label: 'CAPA Closure Rate',
              target: li.capaClosureRate.target,
              actual: li.capaClosureRate.actual,
              unit: '%',
            ),
            const SizedBox(height: 12),
            _IndicatorRow(
              label: 'Investigation Timeliness',
              target: li.investigationTimeliness.target,
              actual: li.investigationTimeliness.actual,
              unit: '%',
            ),
          ],
        ),
      ),
    );
  }
}

class _IndicatorRow extends StatelessWidget {
  final String label;
  final double target;
  final double actual;
  final String unit;

  const _IndicatorRow({
    required this.label,
    required this.target,
    required this.actual,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final progress = target > 0 ? (actual / target).clamp(0.0, 1.0) : 0.0;
    final color = progress >= 0.9
        ? HerzogColors.successGreen
        : progress >= 0.6
        ? HerzogColors.warningAmber
        : HerzogColors.errorRed;

    return Semantics(
      label:
          '$label: actual ${actual.toStringAsFixed(1)} $unit, target ${target.toStringAsFixed(1)} $unit',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text(label, style: HerzogText.body())),
              Text(
                '${actual.toStringAsFixed(1)} $unit / ${target.toStringAsFixed(1)} $unit',
                style: HerzogText.body(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: HerzogColors.lightGray,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Recent Incidents Table ----------

class _RecentIncidentsTable extends StatelessWidget {
  final DashboardData data;

  const _RecentIncidentsTable({required this.data});

  @override
  Widget build(BuildContext context) {
    final incidents = data.recentIncidents;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('RECENT INCIDENTS', style: HerzogText.heading(fontSize: 16)),
            const SizedBox(height: 12),
            incidents.isEmpty
                ? Text(
                    'No incidents yet',
                    style: HerzogText.body(color: HerzogColors.smoke),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('DATE')),
                        DataColumn(label: Text('TYPE')),
                        DataColumn(label: Text('SEVERITY')),
                        DataColumn(label: Text('STATUS')),
                        DataColumn(label: Text('DIVISION')),
                      ],
                      rows: incidents.map((inc) {
                        return DataRow(
                          onSelectChanged: (_) {
                            context.push('/incidents/${inc.id}');
                          },
                          cells: [
                            DataCell(Text(inc.date)),
                            DataCell(Text(inc.type)),
                            DataCell(_SeverityChip(severity: inc.severity)),
                            DataCell(Text(inc.status)),
                            DataCell(Text(inc.division)),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _SeverityChip extends StatelessWidget {
  final String severity;

  const _SeverityChip({required this.severity});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (severity.toLowerCase()) {
      case 'fatality':
        bg = HerzogColors.errorLight;
        fg = HerzogColors.errorRed;
      case 'lost time':
        bg = HerzogColors.warningLight;
        fg = HerzogColors.warningAmber;
      case 'medical treatment':
        bg = HerzogColors.infoLight;
        fg = HerzogColors.infoTeal;
      case 'first aid':
      case 'near miss':
        bg = HerzogColors.successLight;
        fg = HerzogColors.successGreen;
      default:
        bg = HerzogColors.lightGray;
        fg = HerzogColors.darkGray;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(severity, style: HerzogText.body(fontSize: 12, color: fg)),
    );
  }
}

// ---------- Month / Year Picker Dialog ----------

/// Dialog that lets the user pick a month and year for the PDF report.
class _MonthYearPickerDialog extends StatefulWidget {
  final DateTime initialDate;

  const _MonthYearPickerDialog({required this.initialDate});

  @override
  State<_MonthYearPickerDialog> createState() => _MonthYearPickerDialogState();
}

class _MonthYearPickerDialogState extends State<_MonthYearPickerDialog> {
  late int _selectedYear;
  late int _selectedMonth;

  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialDate.year;
    _selectedMonth = widget.initialDate.month;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // Allow years from 3 years ago up to current year.
    final years = List.generate(4, (i) => now.year - 3 + i);

    return AlertDialog(
      title: Semantics(
        header: true,
        child: Text(
          'Select Report Month',
          style: HerzogText.heading(fontSize: 18),
        ),
      ),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Year selector
            DropdownButtonFormField<int>(
              initialValue: _selectedYear,
              decoration: const InputDecoration(
                labelText: 'Year',
                border: OutlineInputBorder(),
              ),
              items: years
                  .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedYear = v);
              },
            ),
            const SizedBox(height: 16),
            // Month selector
            DropdownButtonFormField<int>(
              initialValue: _selectedMonth,
              decoration: const InputDecoration(
                labelText: 'Month',
                border: OutlineInputBorder(),
              ),
              items: List.generate(
                12,
                (i) =>
                    DropdownMenuItem(value: i + 1, child: Text(_monthNames[i])),
              ),
              onChanged: (v) {
                if (v != null) setState(() => _selectedMonth = v);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.picture_as_pdf, size: 18),
          label: const Text('Generate PDF'),
          onPressed: () {
            Navigator.of(context).pop(DateTime(_selectedYear, _selectedMonth));
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Agent badge widget (TASK-049)
// ---------------------------------------------------------------------------

/// Compact banner showing the count of currently active agent sessions.
///
/// Visible to Admin and Safety Manager on the dashboard. Tapping navigates
/// to /admin/agents for the full live-session view.
///
/// Color-coded: green if at least one agent is active, navy otherwise.
/// ADA: text label always present alongside the colour (WCAG 1.4.1).
class _AgentBadge extends StatefulWidget {
  const _AgentBadge();

  @override
  State<_AgentBadge> createState() => _AgentBadgeState();
}

class _AgentBadgeState extends State<_AgentBadge> {
  final AgentSessionRepository _repo = AgentSessionRepository();
  int _count = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  Future<void> _loadCount() async {
    final token = context.read<AuthService>().token;
    if (token == null) return;
    try {
      final sessions = await _repo.getSessions(token);
      if (!mounted) return;
      setState(() {
        _count = sessions.length;
        _loaded = true;
      });
    } catch (_) {
      // Badge is best-effort — silently ignore errors.
      if (!mounted) return;
      setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();

    final hasAgents = _count > 0;
    final label = hasAgents
        ? '$_count agent${_count == 1 ? '' : 's'} active'
        : 'No active agents';
    final bgColor = hasAgents
        ? HerzogColors.successLight
        : HerzogColors.lightGray;
    final fgColor = hasAgents
        ? HerzogColors.successGreen
        : HerzogColors.midGray;
    final borderColor = hasAgents
        ? HerzogColors.successGreen
        : HerzogColors.borderGray;

    return Semantics(
      button: true,
      label: 'Agent sessions: $label. Tap to view.',
      child: InkWell(
        onTap: () => context.push('/admin/agents'),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.smart_toy_outlined, color: fgColor, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: fgColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, color: fgColor, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
