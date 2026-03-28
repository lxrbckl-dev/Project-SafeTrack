import 'package:flutter/material.dart';

import '../../../app/herzog_theme.dart';

/// Visual stepper showing the 6 CAPA lifecycle stages.
///
/// Stages: Open -> In Progress -> Completed -> Verification Pending
///         -> Verified Effective / Verified Ineffective
///
/// The current [status] determines which step is highlighted.
class CAPALifecycleStepper extends StatelessWidget {
  final String status;

  const CAPALifecycleStepper({super.key, required this.status});

  static const _stages = [
    'Open',
    'In Progress',
    'Completed',
    'Verification Pending',
    'Verified Effective',
    'Verified Ineffective',
  ];

  int get _currentIndex {
    final idx = _stages.indexOf(status);
    return idx >= 0 ? idx : 0;
  }

  @override
  Widget build(BuildContext context) {
    final currentIdx = _currentIndex;
    final isIneffective = status == 'Verified Ineffective';

    // We display only 5 stages in the stepper, with the last stage being
    // either "Verified Effective" or "Verified Ineffective" depending on
    // the actual status.
    final displayStages = [
      'Open',
      'In Progress',
      'Completed',
      'Verification Pending',
      if (isIneffective) 'Verified Ineffective' else 'Verified Effective',
    ];

    return Semantics(
      label: 'CAPA lifecycle progress. Current status: $status',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < displayStages.length; i++) ...[
              if (i > 0) _buildConnector(i <= currentIdx),
              _buildStep(
                displayStages[i],
                index: i,
                isCurrent: displayStages[i] == status,
                isCompleted: i < currentIdx,
                isIneffective:
                    displayStages[i] == 'Verified Ineffective' && isIneffective,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStep(
    String label, {
    required int index,
    required bool isCurrent,
    required bool isCompleted,
    bool isIneffective = false,
  }) {
    final Color bgColor;
    final Color fgColor;
    final IconData icon;

    if (isIneffective) {
      bgColor = HerzogColors.errorRed;
      fgColor = HerzogColors.white;
      icon = Icons.close;
    } else if (isCurrent) {
      bgColor = HerzogColors.navyBlue;
      fgColor = HerzogColors.white;
      icon = Icons.radio_button_checked;
    } else if (isCompleted) {
      bgColor = HerzogColors.successGreen;
      fgColor = HerzogColors.white;
      icon = Icons.check;
    } else {
      bgColor = HerzogColors.accentGray;
      fgColor = HerzogColors.midGray;
      icon = Icons.radio_button_unchecked;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
          child: Icon(icon, color: fgColor, size: 18),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 90,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: HerzogText.label(
              fontSize: 10,
              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
              color: isCurrent ? HerzogColors.navyBlue : HerzogColors.midGray,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnector(bool active) {
    return Container(
      width: 32,
      height: 2,
      margin: const EdgeInsets.only(bottom: 22),
      color: active ? HerzogColors.successGreen : HerzogColors.accentGray,
    );
  }
}
