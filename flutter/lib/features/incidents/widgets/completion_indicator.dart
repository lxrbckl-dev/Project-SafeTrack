import 'package:flutter/material.dart';
import '../../../app/herzog_theme.dart';

/// A linear progress bar showing form completion percentage.
///
/// Updates in real-time as fields are filled. Uses Herzog semantic
/// colors: gold for progress, navy for the value text.
class CompletionIndicator extends StatelessWidget {
  /// Completion percentage (0-100).
  final int percent;

  const CompletionIndicator({super.key, required this.percent});

  @override
  Widget build(BuildContext context) {
    final clampedPercent = percent.clamp(0, 100);
    final color = clampedPercent < 30
        ? HerzogColors.errorRed
        : clampedPercent < 70
        ? HerzogColors.warningAmber
        : HerzogColors.successGreen;

    return Semantics(
      label: 'Form completion: $clampedPercent percent',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'COMPLETION',
                style: HerzogText.label(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: HerzogColors.midGray,
                ),
              ),
              Text(
                '$clampedPercent%',
                style: HerzogText.body(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: clampedPercent / 100,
              backgroundColor: HerzogColors.borderGray,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}
