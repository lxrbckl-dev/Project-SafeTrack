import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/herzog_theme.dart';
import '../data/investigation_repository.dart';

/// The six Ishikawa categories for the fishbone diagram.
enum FishboneCategory {
  people('People', Icons.people),
  equipment('Equipment', Icons.build),
  environmental('Environmental', Icons.nature),
  procedural('Procedural', Icons.description),
  managementOrganizational('Management/Organizational', Icons.business),
  other('Other', Icons.more_horiz);

  final String label;
  final IconData icon;

  const FishboneCategory(this.label, this.icon);

  /// Maps a factor type string to the corresponding category.
  static FishboneCategory fromFactorType(String factorType) {
    final normalized = factorType.trim().toLowerCase();
    for (final category in FishboneCategory.values) {
      if (category.label.toLowerCase() == normalized) {
        return category;
      }
    }
    // Partial matching for common variations
    if (normalized.contains('people') || normalized.contains('human')) {
      return FishboneCategory.people;
    }
    if (normalized.contains('equipment') || normalized.contains('machine')) {
      return FishboneCategory.equipment;
    }
    if (normalized.contains('environ')) {
      return FishboneCategory.environmental;
    }
    if (normalized.contains('procedur') || normalized.contains('process')) {
      return FishboneCategory.procedural;
    }
    if (normalized.contains('manage') || normalized.contains('organiz')) {
      return FishboneCategory.managementOrganizational;
    }
    return FishboneCategory.other;
  }
}

/// A contributing factor grouped into its fishbone category.
class _FishboneFactor {
  final ContributingFactor factor;
  final FishboneCategory category;

  const _FishboneFactor({required this.factor, required this.category});
}

/// Interactive Ishikawa (fishbone) diagram for root cause analysis.
///
/// Renders contributing factors on 6 category spines branching from a central
/// backbone. The problem/incident is at the fish head (right side).
///
/// Features:
/// - Pan/zoom via [InteractiveViewer]
/// - Primary factors visually distinguished with bold text and gold indicator
/// - Herzog branding: gold backbone, navy spines, Oswald category labels
/// - ADA: [Semantics] labels on each factor and category, keyboard navigable
class FishboneDiagram extends StatelessWidget {
  /// The contributing factors to display on the diagram.
  final List<ContributingFactor> factors;

  /// Label for the fish head (problem statement).
  final String problemLabel;

  const FishboneDiagram({
    super.key,
    required this.factors,
    this.problemLabel = 'INCIDENT',
  });

  @override
  Widget build(BuildContext context) {
    // Group factors by category
    final grouped = <FishboneCategory, List<_FishboneFactor>>{};
    for (final category in FishboneCategory.values) {
      grouped[category] = [];
    }
    for (final factor in factors) {
      final category = FishboneCategory.fromFactorType(factor.factorType);
      grouped[category]!.add(
        _FishboneFactor(factor: factor, category: category),
      );
    }

    // Calculate diagram dimensions based on content
    final maxFactorsPerSpine = grouped.values.fold<int>(
      0,
      (max, list) => list.length > max ? list.length : max,
    );
    final diagramWidth = math.max(1200.0, 400.0 + maxFactorsPerSpine * 180.0);
    const diagramHeight = 700.0;

    return Semantics(
      label:
          'Fishbone diagram showing ${factors.length} contributing factors '
          'across ${FishboneCategory.values.length} categories',
      child: InteractiveViewer(
        constrained: false,
        boundaryMargin: const EdgeInsets.all(100),
        minScale: 0.3,
        maxScale: 3.0,
        child: SizedBox(
          width: diagramWidth,
          height: diagramHeight,
          child: CustomPaint(
            painter: _FishbonePainter(
              grouped: grouped,
              problemLabel: problemLabel,
            ),
            child: _FishboneOverlay(
              grouped: grouped,
              problemLabel: problemLabel,
              diagramWidth: diagramWidth,
              diagramHeight: diagramHeight,
            ),
          ),
        ),
      ),
    );
  }
}

// Shared constant so painter and overlay always agree on bone length.
const double _kBoneSpacing = 120.0;

/// Paints the fishbone skeleton: backbone, spines, and decorative elements.
class _FishbonePainter extends CustomPainter {
  final Map<FishboneCategory, List<_FishboneFactor>> grouped;
  final String problemLabel;

  _FishbonePainter({required this.grouped, required this.problemLabel});

  @override
  void paint(Canvas canvas, Size size) {
    final backbonePaint = Paint()
      ..color = HerzogColors.gold
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final spinePaint = Paint()
      ..color = HerzogColors.navyBlue
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final bonePaint = Paint()
      ..color = HerzogColors.navyLight
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Layout constants
    final centerY = size.height / 2;
    const leftMargin = 60.0;
    final rightMargin = size.width - 120.0;
    const spineLength = 160.0;

    // Draw backbone (horizontal line)
    canvas.drawLine(
      Offset(leftMargin, centerY),
      Offset(rightMargin, centerY),
      backbonePaint,
    );

    // Draw fish head (arrowhead at right side)
    final headPath = Path()
      ..moveTo(rightMargin, centerY)
      ..lineTo(rightMargin + 40, centerY - 30)
      ..lineTo(rightMargin + 80, centerY)
      ..lineTo(rightMargin + 40, centerY + 30)
      ..close();

    final headFillPaint = Paint()
      ..color = HerzogColors.gold.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawPath(headPath, headFillPaint);
    canvas.drawPath(headPath, backbonePaint);

    // Draw fish tail (at left side)
    final tailPath = Path()
      ..moveTo(leftMargin, centerY)
      ..lineTo(leftMargin - 30, centerY - 40)
      ..moveTo(leftMargin, centerY)
      ..lineTo(leftMargin - 30, centerY + 40);
    canvas.drawPath(tailPath, backbonePaint);

    // Draw category spines
    // Top row: People, Equipment, Environmental (left to right)
    // Bottom row: Procedural, Management/Organizational, Other (left to right)
    final categories = FishboneCategory.values;
    final spineSpacing =
        (rightMargin - leftMargin - 80) / 3; // 3 spines per side

    for (var i = 0; i < categories.length; i++) {
      final category = categories[i];
      final isTop = i < 3;
      final spineIndex = isTop ? i : i - 3;

      final baseX = leftMargin + 80 + spineIndex * spineSpacing;
      final baseY = centerY;
      final endX = baseX + spineLength * 0.5;
      final endY = isTop ? centerY - spineLength : centerY + spineLength;

      // Draw main spine
      canvas.drawLine(Offset(baseX, baseY), Offset(endX, endY), spinePaint);

      // Compute perpendicular direction for bones based on spine angle.
      // The spine vector goes from (baseX, baseY) to (endX, endY).
      // A perpendicular rotated 90° counter-clockwise is (-dy, dx).
      // For upper spines (isTop) we want bones pointing upward, so we flip
      // as needed to ensure the perpendicular component matches orientation.
      final spineDx = endX - baseX;
      final spineDy = endY - baseY;
      final spineLen = math.sqrt(spineDx * spineDx + spineDy * spineDy);
      // Unit perpendicular (-dy, dx) rotated 90° CCW from spine direction.
      final perpUx = -spineDy / spineLen;
      final perpUy = spineDx / spineLen;
      // Ensure bones point away from the backbone centre (up for top spines,
      // down for bottom spines).
      final perpX = isTop
          ? (perpUy < 0 ? perpUx : -perpUx)
          : (perpUy > 0 ? perpUx : -perpUx);
      final perpY = isTop
          ? (perpUy < 0 ? perpUy : -perpUy)
          : (perpUy > 0 ? perpUy : -perpUy);

      // Draw bones for each factor
      final factorsInCategory = grouped[category] ?? [];
      for (var j = 0; j < factorsInCategory.length; j++) {
        final t = (j + 1) / (factorsInCategory.length + 1);
        final boneBaseX = baseX + (endX - baseX) * t;
        final boneBaseY = baseY + (endY - baseY) * t;
        final boneEndX = boneBaseX + perpX * _kBoneSpacing * 0.6;
        final boneEndY = boneBaseY + perpY * _kBoneSpacing * 0.6;

        final factor = factorsInCategory[j];
        final paint = factor.factor.isPrimary
            ? (Paint()
                ..color = HerzogColors.gold
                ..strokeWidth = 2.5
                ..style = PaintingStyle.stroke
                ..strokeCap = StrokeCap.round)
            : bonePaint;

        canvas.drawLine(
          Offset(boneBaseX, boneBaseY),
          Offset(boneEndX, boneEndY),
          paint,
        );

        // Draw dot at bone junction
        final dotPaint = Paint()
          ..color = factor.factor.isPrimary
              ? HerzogColors.gold
              : HerzogColors.navyBlue
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(boneBaseX, boneBaseY), 3.5, dotPaint);
      }

      // Draw a small circle at the spine tip
      final tipPaint = Paint()
        ..color = HerzogColors.navyBlue
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(endX, endY), 5, tipPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FishbonePainter old) {
    if (old.problemLabel != problemLabel) return true;
    if (old.grouped.length != grouped.length) return true;
    for (final key in grouped.keys) {
      if (old.grouped[key]?.length != grouped[key]?.length) return true;
    }
    return false;
  }
}

/// Overlay with positioned text labels for categories and factors.
///
/// This sits on top of the [CustomPaint] canvas so that text is rendered
/// as proper Flutter widgets with full accessibility support.
class _FishboneOverlay extends StatelessWidget {
  final Map<FishboneCategory, List<_FishboneFactor>> grouped;
  final String problemLabel;
  final double diagramWidth;
  final double diagramHeight;

  const _FishboneOverlay({
    required this.grouped,
    required this.problemLabel,
    required this.diagramWidth,
    required this.diagramHeight,
  });

  @override
  Widget build(BuildContext context) {
    final centerY = diagramHeight / 2;
    const leftMargin = 60.0;
    final rightMargin = diagramWidth - 120.0;
    const spineLength = 160.0;

    final spineSpacing = (rightMargin - leftMargin - 80) / 3;

    final children = <Widget>[];

    // Problem label at fish head
    children.add(
      Positioned(
        right: 0,
        top: centerY - 16,
        width: 120,
        child: Semantics(
          label: 'Problem: $problemLabel',
          header: true,
          child: Text(
            problemLabel,
            textAlign: TextAlign.center,
            style: HerzogText.heading(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: HerzogColors.richBlack,
            ),
          ),
        ),
      ),
    );

    // Category labels and factor labels
    final categories = FishboneCategory.values;
    for (var i = 0; i < categories.length; i++) {
      final category = categories[i];
      final isTop = i < 3;
      final spineIndex = isTop ? i : i - 3;

      final baseX = leftMargin + 80 + spineIndex * spineSpacing;
      final baseY = centerY;
      final endX = baseX + spineLength * 0.5;
      final endY = isTop ? centerY - spineLength : centerY + spineLength;

      // Perpendicular direction matching the painter calculation.
      final spineDx = endX - baseX;
      final spineDy = endY - baseY;
      final spineLen = math.sqrt(spineDx * spineDx + spineDy * spineDy);
      final perpUx = -spineDy / spineLen;
      final perpUy = spineDx / spineLen;
      final perpX = isTop
          ? (perpUy < 0 ? perpUx : -perpUx)
          : (perpUy > 0 ? perpUx : -perpUx);
      final perpY = isTop
          ? (perpUy < 0 ? perpUy : -perpUy)
          : (perpUy > 0 ? perpUy : -perpUy);

      // Category label at spine tip
      children.add(
        Positioned(
          left: endX - 70,
          top: isTop ? endY - 40 : endY + 10,
          width: 140,
          child: Semantics(
            label:
                '${category.label} category with '
                '${(grouped[category] ?? []).length} factors',
            header: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  category.icon,
                  size: 18,
                  color: HerzogColors.navyBlue,
                  semanticLabel: category.label,
                ),
                const SizedBox(height: 2),
                Text(
                  category.label.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: HerzogText.heading(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: HerzogColors.navyBlue,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Factor labels on bones
      final factorsInCategory = grouped[category] ?? [];
      for (var j = 0; j < factorsInCategory.length; j++) {
        final t = (j + 1) / (factorsInCategory.length + 1);
        final boneBaseX = baseX + (endX - baseX) * t;
        final boneBaseY = baseY + (endY - baseY) * t;
        final boneEndX = boneBaseX + perpX * _kBoneSpacing * 0.6;
        final boneEndY = boneBaseY + perpY * _kBoneSpacing * 0.6;

        final factor = factorsInCategory[j].factor;
        final isPrimary = factor.isPrimary;

        // Position label at end of bone, offset slightly in perpendicular direction.
        final labelTop = isTop ? boneEndY - 28 : boneEndY + 6;

        children.add(
          Positioned(
            left: boneEndX - 10,
            top: labelTop,
            width: 130,
            child: Semantics(
              label:
                  '${category.label} factor: '
                  '${factor.factorDescription.isNotEmpty ? factor.factorDescription : factor.factorType}'
                  '${isPrimary ? ", primary factor" : ""}',
              child: _FactorLabel(
                text: factor.factorDescription.isNotEmpty
                    ? factor.factorDescription
                    : factor.factorType,
                isPrimary: isPrimary,
              ),
            ),
          ),
        );
      }
    }

    return Stack(clipBehavior: Clip.none, children: children);
  }
}

/// A single factor label widget with visual distinction for primary factors.
class _FactorLabel extends StatelessWidget {
  final String text;
  final bool isPrimary;

  const _FactorLabel({required this.text, required this.isPrimary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: isPrimary
            ? HerzogColors.gold.withValues(alpha: 0.15)
            : HerzogColors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isPrimary ? HerzogColors.gold : HerzogColors.borderGray,
          width: isPrimary ? 2.0 : 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPrimary) ...[
            const Icon(Icons.star, size: 12, color: HerzogColors.gold),
            const SizedBox(width: 3),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: isPrimary
                  ? HerzogText.body(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: HerzogColors.richBlack,
                    )
                  : HerzogText.body(fontSize: 11, color: HerzogColors.darkGray),
            ),
          ),
        ],
      ),
    );
  }
}

/// An empty state widget shown when there are no contributing factors.
class FishboneEmptyState extends StatelessWidget {
  const FishboneEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        label: 'No contributing factors to display in the fishbone diagram',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_tree_outlined,
              size: 64,
              color: HerzogColors.smoke,
              semanticLabel: 'Fishbone diagram icon',
            ),
            const SizedBox(height: 16),
            Text(
              'NO CONTRIBUTING FACTORS',
              style: HerzogText.heading(
                fontSize: 16,
                color: HerzogColors.midGray,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add contributing factors in the Factors tab to see\n'
              'them visualized on the fishbone diagram.',
              textAlign: TextAlign.center,
              style: HerzogText.body(fontSize: 13, color: HerzogColors.smoke),
            ),
          ],
        ),
      ),
    );
  }
}
