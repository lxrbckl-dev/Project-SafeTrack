import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/herzog_theme.dart';
import '../data/dashboard_repository.dart';

/// A 24-row (hours) x 7-column (days) heatmap grid showing incident
/// frequency by time of day and day of week.
///
/// Color intensity is based on incident count, from green (zero/low)
/// through amber to red (high).
class TimeHeatmapChart extends StatefulWidget {
  final List<TimeHeatmapCell> data;

  const TimeHeatmapChart({super.key, required this.data});

  @override
  State<TimeHeatmapChart> createState() => _TimeHeatmapChartState();
}

class _TimeHeatmapChartState extends State<TimeHeatmapChart> {
  TimeHeatmapCell? _hoveredCell;

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static const _dayNamesFull = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  Widget build(BuildContext context) {
    final data = widget.data;

    // Build a lookup: grid[hour][dayIndex] = count
    final grid = <int, Map<int, int>>{};
    int maxCount = 0;
    for (int h = 0; h < 24; h++) {
      grid[h] = {};
      for (int d = 0; d < 7; d++) {
        grid[h]![d] = 0;
      }
    }
    for (final cell in data) {
      final dayIdx = _dayNamesFull.indexOf(cell.day);
      if (dayIdx >= 0 && cell.hour >= 0 && cell.hour < 24) {
        grid[cell.hour]![dayIdx] = cell.count;
        maxCount = math.max(maxCount, cell.count);
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'INCIDENT TIME HEATMAP',
              style: HerzogText.heading(fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'Incidents by hour of day and day of week (last 12 months)',
              style: HerzogText.body(fontSize: 12, color: HerzogColors.smoke),
            ),
            if (_hoveredCell != null) ...[
              const SizedBox(height: 4),
              Semantics(
                liveRegion: true,
                child: Text(
                  '${_hoveredCell!.day} at ${_formatHour(_hoveredCell!.hour)}: '
                  '${_hoveredCell!.count} ${_hoveredCell!.count == 1 ? "incident" : "incidents"}',
                  style: HerzogText.body(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _buildGrid(grid, maxCount),
            ),
            const SizedBox(height: 12),
            _buildColorScale(),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(Map<int, Map<int, int>> grid, int maxCount) {
    const cellSize = 22.0;
    const cellSpacing = 2.0;
    const hourLabelWidth = 40.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day headers
        Padding(
          padding: const EdgeInsets.only(left: hourLabelWidth),
          child: Row(
            children: _dayNames.map((day) {
              return SizedBox(
                width: cellSize + cellSpacing,
                child: Center(
                  child: Text(day, style: HerzogText.label(fontSize: 10)),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 4),
        // Hour rows
        ...List.generate(24, (hour) {
          return Padding(
            padding: const EdgeInsets.only(bottom: cellSpacing),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: hourLabelWidth,
                  child: Text(
                    _formatHour(hour),
                    style: HerzogText.body(fontSize: 10),
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 4),
                ...List.generate(7, (dayIdx) {
                  final count = grid[hour]?[dayIdx] ?? 0;
                  final intensity = maxCount > 0 ? count / maxCount : 0.0;
                  final color = count == 0
                      ? HerzogColors.lightGray
                      : _intensityColor(intensity);

                  return Padding(
                    padding: const EdgeInsets.only(right: cellSpacing),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _hoveredCell = TimeHeatmapCell(
                            hour: hour,
                            day: _dayNamesFull[dayIdx],
                            count: count,
                          );
                        });
                      },
                      child: Semantics(
                        label:
                            '${_dayNamesFull[dayIdx]} ${_formatHour(hour)}: '
                            '$count ${count == 1 ? "incident" : "incidents"}',
                        child: Tooltip(
                          message:
                              '${_dayNamesFull[dayIdx]} ${_formatHour(hour)}: $count',
                          child: Container(
                            width: cellSize,
                            height: cellSize,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(
                                color: HerzogColors.borderGray,
                                width: 0.5,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: count > 0
                                ? Text(
                                    '$count',
                                    style: HerzogText.body(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w600,
                                      color: intensity > 0.5
                                          ? HerzogColors.white
                                          : HerzogColors.richBlack,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildColorScale() {
    return Semantics(
      label:
          'Color scale: light indicates few incidents, '
          'dark red indicates many incidents',
      child: Row(
        children: [
          Text('0', style: HerzogText.body(fontSize: 11)),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: 10,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                gradient: const LinearGradient(
                  colors: [
                    HerzogColors.lightGray,
                    HerzogColors.successGreen,
                    HerzogColors.warningAmber,
                    HerzogColors.errorRed,
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text('High', style: HerzogText.body(fontSize: 11)),
        ],
      ),
    );
  }

  static String _formatHour(int hour) {
    if (hour == 0) return '12 AM';
    if (hour < 12) return '$hour AM';
    if (hour == 12) return '12 PM';
    return '${hour - 12} PM';
  }

  static Color _intensityColor(double t) {
    if (t <= 0.5) {
      return Color.lerp(
            HerzogColors.successGreen,
            HerzogColors.warningAmber,
            t * 2,
          ) ??
          HerzogColors.successGreen;
    }
    return Color.lerp(
          HerzogColors.warningAmber,
          HerzogColors.errorRed,
          (t - 0.5) * 2,
        ) ??
        HerzogColors.errorRed;
  }
}
