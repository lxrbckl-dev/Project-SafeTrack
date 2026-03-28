import 'package:flutter/material.dart';

import '../../../app/herzog_theme.dart';

/// Dialog shown after a CAPA is verified as ineffective.
///
/// Offers two options:
/// - Create a new CAPA (returns 'new_capa')
/// - Reopen the investigation (returns 'reopen_investigation')
/// - Dismiss (returns null)
class IneffectiveActionDialog extends StatelessWidget {
  final int investigationId;
  final int incidentId;

  const IneffectiveActionDialog({
    super.key,
    required this.investigationId,
    required this.incidentId,
  });

  /// Shows the dialog and returns the chosen action:
  /// 'new_capa', 'reopen_investigation', or null if dismissed.
  static Future<String?> show(
    BuildContext context, {
    required int investigationId,
    required int incidentId,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => IneffectiveActionDialog(
        investigationId: investigationId,
        incidentId: incidentId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.warning_amber, color: HerzogColors.errorRed),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'CAPA Verified Ineffective',
              style: HerzogText.heading(
                fontSize: 18,
                color: HerzogColors.errorRed,
              ),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This CAPA was verified as ineffective. Choose a corrective '
              'action to continue the safety process:',
              style: HerzogText.body(fontSize: 14),
            ),
            const SizedBox(height: 20),
            // Option 1: Create New CAPA
            Semantics(
              label: 'Create a new CAPA for this investigation',
              button: true,
              child: _ActionCard(
                icon: Icons.add_circle_outline,
                title: 'Create New CAPA',
                subtitle: 'Create a replacement CAPA with updated actions',
                color: HerzogColors.navyBlue,
                onTap: () => Navigator.of(context).pop('new_capa'),
              ),
            ),
            const SizedBox(height: 12),
            // Option 2: Reopen Investigation
            Semantics(
              label: 'Reopen the original investigation',
              button: true,
              child: _ActionCard(
                icon: Icons.replay,
                title: 'Reopen Investigation',
                subtitle: 'Return to the investigation for additional analysis',
                color: HerzogColors.warningAmber,
                onTap: () => Navigator.of(context).pop('reopen_investigation'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Dismiss',
            style: HerzogText.body(color: HerzogColors.midGray),
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: HerzogText.body(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: HerzogText.body(
                      fontSize: 12,
                      color: HerzogColors.midGray,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color),
          ],
        ),
      ),
    );
  }
}
