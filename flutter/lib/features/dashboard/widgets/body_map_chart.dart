import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/herzog_theme.dart';
import '../data/dashboard_repository.dart';

/// A body outline heat map showing injury counts by body part.
///
/// Uses a positioned layout with a simplified body silhouette drawn via
/// CustomPainter. Body part regions are overlaid as tappable color-coded
/// circles whose color intensity reflects injury count relative to the max.
class BodyMapChart extends StatefulWidget {
  final List<BodyPartCount> data;

  const BodyMapChart({super.key, required this.data});

  @override
  State<BodyMapChart> createState() => _BodyMapChartState();
}

class _BodyMapChartState extends State<BodyMapChart> {
  String? _selectedPart;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;

    if (data.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BODY PART INJURY MAP',
                style: HerzogText.heading(fontSize: 16),
              ),
              const SizedBox(height: 40),
              Center(
                child: Text(
                  'No injury data available',
                  style: HerzogText.body(color: HerzogColors.smoke),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      );
    }

    final maxCount = data.fold<int>(0, (m, e) => math.max(m, e.count));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'BODY PART INJURY MAP',
              style: HerzogText.heading(fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap a region for details',
              style: HerzogText.body(fontSize: 12, color: HerzogColors.smoke),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Body outline with positioned injury indicators
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 340,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          children: [
                            // Body silhouette
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _BodyOutlinePainter(),
                              ),
                            ),
                            // Injury region overlays
                            ..._buildRegionOverlays(
                              constraints,
                              data,
                              maxCount,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Legend / details panel
                Expanded(flex: 2, child: _buildLegend(data, maxCount)),
              ],
            ),
            // Color scale
            const SizedBox(height: 12),
            _buildColorScale(),
          ],
        ),
      ),
    );
  }

  /// Maps body part names to approximate positions on the body outline.
  /// Positions are expressed as fractions (0.0 - 1.0) of the available space.
  static const Map<String, Offset> _bodyPartPositions = {
    'Head': Offset(0.50, 0.06),
    'Neck': Offset(0.50, 0.14),
    'Shoulder': Offset(0.35, 0.20),
    'Chest': Offset(0.50, 0.25),
    'Back': Offset(0.62, 0.30),
    'Upper Arm': Offset(0.25, 0.28),
    'Elbow': Offset(0.22, 0.35),
    'Forearm': Offset(0.20, 0.42),
    'Wrist': Offset(0.18, 0.48),
    'Hand': Offset(0.16, 0.54),
    'Finger': Offset(0.14, 0.58),
    'Abdomen': Offset(0.50, 0.38),
    'Hip': Offset(0.40, 0.46),
    'Upper Leg': Offset(0.42, 0.56),
    'Knee': Offset(0.44, 0.66),
    'Lower Leg': Offset(0.45, 0.76),
    'Ankle': Offset(0.46, 0.85),
    'Foot': Offset(0.47, 0.92),
    'Toe': Offset(0.52, 0.95),
    'Eye': Offset(0.44, 0.05),
    'Face': Offset(0.56, 0.08),
    'Ear': Offset(0.60, 0.06),
    'Teeth': Offset(0.50, 0.10),
    'Multiple': Offset(0.75, 0.45),
  };

  List<Widget> _buildRegionOverlays(
    BoxConstraints constraints,
    List<BodyPartCount> data,
    int maxCount,
  ) {
    final widgets = <Widget>[];
    for (final entry in data) {
      final pos = _bodyPartPositions[entry.bodyPart];
      if (pos == null) {
        // Unknown body part - show in the "other" region
        continue;
      }

      final x = pos.dx * constraints.maxWidth;
      final y = pos.dy * constraints.maxHeight;
      final intensity = maxCount > 0 ? entry.count / maxCount : 0.0;
      final color = _intensityColor(intensity);
      final radius = 10.0 + (intensity * 10.0);
      final isSelected = _selectedPart == entry.bodyPart;

      widgets.add(
        Positioned(
          left: x - radius,
          top: y - radius,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedPart = _selectedPart == entry.bodyPart
                    ? null
                    : entry.bodyPart;
              });
            },
            child: Semantics(
              label:
                  '${entry.bodyPart}: ${entry.count} ${entry.count == 1 ? "injury" : "injuries"}',
              button: true,
              child: Container(
                width: radius * 2,
                height: radius * 2,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(color: HerzogColors.richBlack, width: 2)
                      : null,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.5),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${entry.count}',
                  style: HerzogText.body(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: intensity > 0.5
                        ? HerzogColors.white
                        : HerzogColors.richBlack,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  Widget _buildLegend(List<BodyPartCount> data, int maxCount) {
    // Show all body parts as a scrollable list, with selected one highlighted
    return SizedBox(
      height: 340,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('INJURY COUNTS', style: HerzogText.label()),
            const SizedBox(height: 8),
            ...data.map((entry) {
              final intensity = maxCount > 0 ? entry.count / maxCount : 0.0;
              final isSelected = _selectedPart == entry.bodyPart;
              return Semantics(
                label:
                    '${entry.bodyPart}, ${entry.count} ${entry.count == 1 ? "injury" : "injuries"}',
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedPart = _selectedPart == entry.bodyPart
                          ? null
                          : entry.bodyPart;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 6,
                    ),
                    margin: const EdgeInsets.only(bottom: 2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? HerzogColors.navyBlue.withValues(alpha: 0.1)
                          : null,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _intensityColor(intensity),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            entry.bodyPart,
                            style: HerzogText.body(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        Text(
                          '${entry.count}',
                          style: HerzogText.body(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildColorScale() {
    return Semantics(
      label:
          'Color scale: green indicates low injury count, '
          'yellow indicates medium, red indicates high',
      child: Row(
        children: [
          Text('Low', style: HerzogText.body(fontSize: 11)),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: 10,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                gradient: const LinearGradient(
                  colors: [
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

  /// Returns a color interpolated from green (low) through amber to red (high).
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

/// Draws a simplified body outline silhouette.
class _BodyOutlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = HerzogColors.accentGray.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = HerzogColors.smoke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final cx = size.width * 0.5;

    // Head
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, size.height * 0.06),
        width: size.width * 0.12,
        height: size.height * 0.08,
      ),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, size.height * 0.06),
        width: size.width * 0.12,
        height: size.height * 0.08,
      ),
      strokePaint,
    );

    // Neck
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(cx, size.height * 0.13),
        width: size.width * 0.05,
        height: size.height * 0.04,
      ),
      paint,
    );

    // Torso
    final torsoPath = Path()
      ..moveTo(cx - size.width * 0.14, size.height * 0.15)
      ..lineTo(cx - size.width * 0.16, size.height * 0.30)
      ..lineTo(cx - size.width * 0.12, size.height * 0.48)
      ..lineTo(cx + size.width * 0.12, size.height * 0.48)
      ..lineTo(cx + size.width * 0.16, size.height * 0.30)
      ..lineTo(cx + size.width * 0.14, size.height * 0.15)
      ..close();
    canvas.drawPath(torsoPath, paint);
    canvas.drawPath(torsoPath, strokePaint);

    // Left arm
    final leftArmPath = Path()
      ..moveTo(cx - size.width * 0.14, size.height * 0.16)
      ..lineTo(cx - size.width * 0.28, size.height * 0.35)
      ..lineTo(cx - size.width * 0.22, size.height * 0.55)
      ..lineTo(cx - size.width * 0.18, size.height * 0.55)
      ..lineTo(cx - size.width * 0.24, size.height * 0.35)
      ..lineTo(cx - size.width * 0.12, size.height * 0.18)
      ..close();
    canvas.drawPath(leftArmPath, paint);
    canvas.drawPath(leftArmPath, strokePaint);

    // Right arm
    final rightArmPath = Path()
      ..moveTo(cx + size.width * 0.14, size.height * 0.16)
      ..lineTo(cx + size.width * 0.28, size.height * 0.35)
      ..lineTo(cx + size.width * 0.22, size.height * 0.55)
      ..lineTo(cx + size.width * 0.18, size.height * 0.55)
      ..lineTo(cx + size.width * 0.24, size.height * 0.35)
      ..lineTo(cx + size.width * 0.12, size.height * 0.18)
      ..close();
    canvas.drawPath(rightArmPath, paint);
    canvas.drawPath(rightArmPath, strokePaint);

    // Left leg
    final leftLegPath = Path()
      ..moveTo(cx - size.width * 0.11, size.height * 0.48)
      ..lineTo(cx - size.width * 0.10, size.height * 0.75)
      ..lineTo(cx - size.width * 0.08, size.height * 0.95)
      ..lineTo(cx - size.width * 0.03, size.height * 0.95)
      ..lineTo(cx - size.width * 0.04, size.height * 0.75)
      ..lineTo(cx - size.width * 0.02, size.height * 0.48)
      ..close();
    canvas.drawPath(leftLegPath, paint);
    canvas.drawPath(leftLegPath, strokePaint);

    // Right leg
    final rightLegPath = Path()
      ..moveTo(cx + size.width * 0.02, size.height * 0.48)
      ..lineTo(cx + size.width * 0.04, size.height * 0.75)
      ..lineTo(cx + size.width * 0.03, size.height * 0.95)
      ..lineTo(cx + size.width * 0.08, size.height * 0.95)
      ..lineTo(cx + size.width * 0.10, size.height * 0.75)
      ..lineTo(cx + size.width * 0.11, size.height * 0.48)
      ..close();
    canvas.drawPath(rightLegPath, paint);
    canvas.drawPath(rightLegPath, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
