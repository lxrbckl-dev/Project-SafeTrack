import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../app/herzog_theme.dart';
import '../data/dashboard_repository.dart';

/// A radar/spider chart comparing divisions across four safety metrics:
/// incident count, TRIR, investigation timeliness, and CAPA closure rate.
///
/// Uses fl_chart's RadarChart. Each division is rendered as a separate
/// data series with a unique color from the Herzog palette.
class DivisionRadarChart extends StatelessWidget {
  final List<DivisionRadarEntry> data;

  const DivisionRadarChart({super.key, required this.data});

  static const _metricLabels = [
    'Incidents',
    'TRIR',
    'Inv. Timeliness',
    'CAPA Closure',
  ];

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DIVISION COMPARISON',
                style: HerzogText.heading(fontSize: 16),
              ),
              const SizedBox(height: 40),
              Center(
                child: Text(
                  'No division data available',
                  style: HerzogText.body(color: HerzogColors.smoke),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      );
    }

    // Normalize each metric to 0-100 scale for radar chart
    final maxIncidents = data.fold<int>(1, (m, e) => math.max(m, e.incidents));
    final maxTRIR = data.fold<double>(0.01, (m, e) => math.max(m, e.trir));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DIVISION COMPARISON',
              style: HerzogText.heading(fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'Multi-metric radar across divisions',
              style: HerzogText.body(fontSize: 12, color: HerzogColors.smoke),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 300,
              child: Semantics(
                label: _buildAccessibilityDescription(),
                child: RadarChart(
                  RadarChartData(
                    radarTouchData: RadarTouchData(enabled: true),
                    dataSets: data.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final div = entry.value;
                      final color = HerzogColors
                          .chartColors[idx % HerzogColors.chartColors.length];

                      // Normalize: incidents and TRIR are scaled to 0-100.
                      // Timeliness and closure rate are already percentages.
                      // For TRIR, invert so lower is better (higher on chart).
                      final normalizedIncidents = maxIncidents > 0
                          ? (div.incidents / maxIncidents) * 100
                          : 0.0;
                      final normalizedTRIR = maxTRIR > 0
                          ? ((maxTRIR - div.trir) / maxTRIR) * 100
                          : 100.0;

                      return RadarDataSet(
                        fillColor: color.withValues(alpha: 0.15),
                        borderColor: color,
                        borderWidth: 2,
                        entryRadius: 3,
                        dataEntries: [
                          RadarEntry(value: normalizedIncidents),
                          RadarEntry(value: normalizedTRIR),
                          RadarEntry(value: div.investigationTimeliness),
                          RadarEntry(value: div.capaClosureRate),
                        ],
                      );
                    }).toList(),
                    radarBackgroundColor: Colors.transparent,
                    borderData: FlBorderData(show: false),
                    radarBorderData: const BorderSide(
                      color: HerzogColors.borderGray,
                    ),
                    titlePositionPercentageOffset: 0.2,
                    titleTextStyle: HerzogText.body(fontSize: 11),
                    getTitle: (index, _) {
                      return RadarChartTitle(text: _metricLabels[index]);
                    },
                    tickCount: 4,
                    ticksTextStyle: HerzogText.body(
                      fontSize: 9,
                      color: HerzogColors.smoke,
                    ),
                    tickBorderData: const BorderSide(
                      color: HerzogColors.borderGray,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Legend
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: data.asMap().entries.map((entry) {
                final idx = entry.key;
                final div = entry.value;
                final color = HerzogColors
                    .chartColors[idx % HerzogColors.chartColors.length];

                return Semantics(
                  label:
                      '${div.division}: ${div.incidents} incidents, '
                      'TRIR ${div.trir.toStringAsFixed(2)}, '
                      'investigation timeliness ${div.investigationTimeliness.toStringAsFixed(0)}%, '
                      'CAPA closure ${div.capaClosureRate.toStringAsFixed(0)}%',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(div.division, style: HerzogText.body(fontSize: 12)),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            // Metric detail table
            _buildMetricTable(),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 20,
        horizontalMargin: 12,
        columns: const [
          DataColumn(label: Text('DIVISION')),
          DataColumn(label: Text('INCIDENTS'), numeric: true),
          DataColumn(label: Text('TRIR'), numeric: true),
          DataColumn(label: Text('INV. TIMELINESS'), numeric: true),
          DataColumn(label: Text('CAPA CLOSURE'), numeric: true),
        ],
        rows: data.map((div) {
          return DataRow(
            cells: [
              DataCell(Text(div.division)),
              DataCell(Text('${div.incidents}')),
              DataCell(Text(div.trir.toStringAsFixed(2))),
              DataCell(
                Text('${div.investigationTimeliness.toStringAsFixed(0)}%'),
              ),
              DataCell(Text('${div.capaClosureRate.toStringAsFixed(0)}%')),
            ],
          );
        }).toList(),
      ),
    );
  }

  String _buildAccessibilityDescription() {
    final buffer = StringBuffer(
      'Radar chart comparing ${data.length} divisions across '
      '4 metrics: incidents, TRIR, investigation timeliness, and CAPA closure rate. ',
    );
    for (final div in data) {
      buffer.write(
        '${div.division}: ${div.incidents} incidents, '
        'TRIR ${div.trir.toStringAsFixed(2)}, '
        'timeliness ${div.investigationTimeliness.toStringAsFixed(0)} percent, '
        'CAPA closure ${div.capaClosureRate.toStringAsFixed(0)} percent. ',
      );
    }
    return buffer.toString();
  }
}
