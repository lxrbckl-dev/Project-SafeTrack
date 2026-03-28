import 'package:flutter/material.dart';

import '../../../app/herzog_theme.dart';
import '../data/dashboard_repository.dart';

/// Horizontal bar chart showing injury counts by body part (last 12 months).
///
/// Replaces the previous body-outline heat-map. Data is sorted descending by
/// count; the top 10 body parts are shown by default with an expandable
/// "View all" row when the dataset exceeds 10 entries.
class BodyMapChart extends StatefulWidget {
  final List<BodyPartCount> data;

  const BodyMapChart({super.key, required this.data});

  @override
  State<BodyMapChart> createState() => _BodyMapChartState();
}

class _BodyMapChartState extends State<BodyMapChart> {
  static const int _defaultMax = 10;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final data = List<BodyPartCount>.from(widget.data)
      ..sort((a, b) => b.count.compareTo(a.count));

    return Card(
      color: HerzogColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: HerzogColors.borderGray),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title ────────────────────────────────────────────────────
            Text('BODY PART INJURIES', style: HerzogText.heading(fontSize: 16)),
            const SizedBox(height: 4),
            // ── Subtitle ─────────────────────────────────────────────────
            Text(
              'Injury count by body part (last 12 months)',
              style: HerzogText.body(fontSize: 12, color: HerzogColors.smoke),
            ),
            const SizedBox(height: 8),
            // ── Summary line ─────────────────────────────────────────────
            if (data.isNotEmpty) _buildSummary(data),
            const SizedBox(height: 12),
            // ── Chart / empty state ───────────────────────────────────────
            data.isEmpty ? _buildEmpty() : _buildChart(data),
          ],
        ),
      ),
    );
  }

  // ── Summary ────────────────────────────────────────────────────────────────

  Widget _buildSummary(List<BodyPartCount> sorted) {
    if (sorted.isEmpty) return const SizedBox.shrink();

    final top1 = sorted[0];
    final hasSecond = sorted.length > 1;
    final top2 = hasSecond ? sorted[1] : null;

    return Text.rich(
      TextSpan(
        style: HerzogText.body(fontSize: 13),
        children: [
          const TextSpan(text: 'Most affected: '),
          TextSpan(
            text: top1.bodyPart,
            style: HerzogText.body(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          TextSpan(text: ' (${top1.count})'),
          if (top2 != null) ...[
            const TextSpan(text: ', '),
            TextSpan(
              text: top2.bodyPart,
              style: HerzogText.body(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            TextSpan(text: ' (${top2.count})'),
          ],
        ],
      ),
    );
  }

  // ── Chart ──────────────────────────────────────────────────────────────────

  Widget _buildChart(List<BodyPartCount> sorted) {
    final maxCount = sorted.first.count;
    final truncated = sorted.length > _defaultMax;
    final visible = (!truncated || _expanded)
        ? sorted
        : sorted.sublist(0, _defaultMax);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...visible.map((entry) => _buildBar(entry, maxCount)),
        if (truncated) _buildViewAll(sorted.length),
      ],
    );
  }

  Widget _buildBar(BodyPartCount entry, int maxCount) {
    final fraction = maxCount > 0 ? entry.count / maxCount : 0.0;

    // Optional gradient: high-count bars shade toward errorRed.
    final barColor = fraction >= 0.5
        ? Color.lerp(
            HerzogColors.navyBlue,
            HerzogColors.errorRed,
            (fraction - 0.5) * 2,
          )!
        : HerzogColors.navyBlue;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        label:
            '${entry.bodyPart}: ${entry.count} '
            '${entry.count == 1 ? "injury" : "injuries"}',
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Label – fixed width so bars align
            SizedBox(
              width: 100,
              child: Text(
                entry.bodyPart,
                style: HerzogText.body(fontSize: 12),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 8),
            // Bar
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final barWidth = constraints.maxWidth * fraction;
                  return Stack(
                    children: [
                      // Track
                      Container(
                        height: 14,
                        decoration: BoxDecoration(
                          color: HerzogColors.borderGray,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      // Fill
                      Container(
                        height: 14,
                        width: barWidth.clamp(2.0, constraints.maxWidth),
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            // Count
            SizedBox(
              width: 28,
              child: Text(
                '${entry.count}',
                textAlign: TextAlign.right,
                style: HerzogText.body(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: HerzogColors.richBlack,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewAll(int total) {
    return TextButton(
      onPressed: () => setState(() => _expanded = !_expanded),
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        _expanded ? 'Show less' : 'View all $total body parts',
        style: HerzogText.body(
          fontSize: 12,
          color: HerzogColors.navyBlue,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────

  Widget _buildEmpty() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(
          'No injury data recorded',
          style: TextStyle(color: HerzogColors.smoke, fontSize: 14),
        ),
      ),
    );
  }
}
