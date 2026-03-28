import 'package:flutter/material.dart';
import '../../../app/herzog_theme.dart';

/// Color-coded badge for incident statuses.
///
/// Follows the Herzog branding badge pattern:
/// - Active/Complete: green bg, green text
/// - In Progress/Pending: amber bg, amber text
/// - Overdue/Error: red bg, red text
/// - Info: teal bg, teal text
class StatusBadge extends StatelessWidget {
  /// The status text to display.
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final colors = _colorsForStatus(status);
    return Semantics(
      label: 'Status: $status',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          status.toUpperCase(),
          style: HerzogText.label(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: colors.foreground,
          ),
        ),
      ),
    );
  }

  static ({Color background, Color foreground}) _colorsForStatus(
    String status,
  ) {
    switch (status) {
      case 'Draft':
        return (
          background: HerzogColors.lightGray,
          foreground: HerzogColors.midGray,
        );
      case 'Reported':
        return (
          background: HerzogColors.infoLight,
          foreground: HerzogColors.infoTeal,
        );
      case 'Under Investigation':
        return (
          background: HerzogColors.warningLight,
          foreground: HerzogColors.warningAmber,
        );
      case 'Investigation Complete':
        return (
          background: HerzogColors.infoLight,
          foreground: HerzogColors.infoTeal,
        );
      case 'CAPA Assigned':
      case 'CAPA In Progress':
        return (
          background: HerzogColors.warningLight,
          foreground: HerzogColors.warningAmber,
        );
      case 'Closed':
        return (
          background: HerzogColors.successLight,
          foreground: HerzogColors.successGreen,
        );
      case 'Reopened':
        return (
          background: HerzogColors.errorLight,
          foreground: HerzogColors.errorRed,
        );
      default:
        return (
          background: HerzogColors.lightGray,
          foreground: HerzogColors.midGray,
        );
    }
  }
}
