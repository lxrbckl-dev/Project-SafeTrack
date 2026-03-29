import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/herzog_theme.dart';
import '../data/investigation_repository.dart';

/// Review panel visible ONLY to Safety Manager.
///
/// Features:
/// - Shows current review status
/// - If "Under Review": Approve button + Return button
/// - Required comments field for both actions
/// - On Approve: calls review endpoint with decision="approve"
/// - On Return: calls review endpoint with decision="return"
class InvestigationReviewPanel extends StatefulWidget {
  /// The current investigation.
  final Investigation investigation;

  /// Whether the current user is a Safety Manager (or Admin).
  final bool isSafetyManager;

  /// Called to submit the investigation for review.
  final Future<void> Function() onSubmitForReview;

  /// Called to review the investigation with a decision.
  final Future<void> Function({
    required String decision,
    required String comments,
  })
  onReview;

  const InvestigationReviewPanel({
    super.key,
    required this.investigation,
    required this.isSafetyManager,
    required this.onSubmitForReview,
    required this.onReview,
  });

  @override
  State<InvestigationReviewPanel> createState() =>
      _InvestigationReviewPanelState();
}

class _InvestigationReviewPanelState extends State<InvestigationReviewPanel> {
  final _commentsCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _commentsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      await widget.onSubmitForReview();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _review(String decision) async {
    final comments = _commentsCtrl.text.trim();
    if (comments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comments are required for review')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await widget.onReview(decision: decision, comments: comments);
      if (mounted) _commentsCtrl.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Review failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv = widget.investigation;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current review status
            _buildStatusCard(inv),
            const SizedBox(height: 16),

            // Previous review comments if any
            if (inv.reviewComments.isNotEmpty) ...[
              _buildPreviousReview(inv),
              const SizedBox(height: 16),
            ],

            // Submit for review (for investigator when status is Assigned/In
            // Progress/Returned)
            if (!widget.isSafetyManager &&
                (inv.status == 'Assigned' ||
                    inv.status == 'In Progress' ||
                    inv.status == 'Returned'))
              _buildSubmitSection(),

            // Review actions (Safety Manager only, Under Review status)
            if (widget.isSafetyManager && inv.status == 'Under Review')
              _buildReviewSection(),

            // Approved message
            if (inv.status == 'Approved') _buildApprovedSection(inv),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(Investigation inv) {
    final statusColor = _statusColor(inv.status);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(_statusIcon(inv.status), size: 24, color: statusColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Builder(builder: (context) {
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    return Text(
                      'REVIEW STATUS',
                      style: HerzogText.label(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : HerzogColors.midGray,
                      ),
                    );
                  }),
                  const SizedBox(height: 4),
                  Semantics(
                    label: 'Investigation status: ${inv.status}',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        inv.status.toUpperCase(),
                        style: HerzogText.label(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviousReview(Investigation inv) {
    final reviewDate = inv.reviewDate != null
        ? DateFormat('MM/dd/yyyy hh:mm a').format(inv.reviewDate!)
        : '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Builder(builder: (context) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return Text(
                'REVIEW HISTORY',
                style: HerzogText.heading(
                  fontSize: 14,
                  color: isDark ? HerzogColors.gold : HerzogColors.navyBlue,
                ),
              );
            }),
            const SizedBox(height: 8),
            if (inv.reviewedBy.isNotEmpty)
              _infoRow('Reviewed By', inv.reviewedBy),
            if (reviewDate.isNotEmpty) _infoRow('Review Date', reviewDate),
            const SizedBox(height: 8),
            Builder(builder: (context) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return Text(
                inv.reviewComments,
                style: HerzogText.body(
                  fontSize: 13,
                  color: isDark ? Colors.white : HerzogColors.richBlack,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Builder(builder: (context) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return Text(
                'SUBMIT FOR REVIEW',
                style: HerzogText.heading(
                  fontSize: 14,
                  color: isDark ? HerzogColors.gold : HerzogColors.navyBlue,
                ),
              );
            }),
            const SizedBox(height: 8),
            Builder(builder: (context) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return Text(
                'When your investigation is complete, submit it for Safety '
                'Manager review. Ensure you have at least 3 Why levels and '
                'one primary contributing factor.',
                style: HerzogText.body(
                  fontSize: 13,
                  color: isDark ? Colors.white : HerzogColors.midGray,
                ),
              );
            }),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loading ? null : _submit,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: HerzogColors.white,
                      ),
                    )
                  : const Icon(Icons.send, size: 16),
              label: const Text('Submit for Review'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Builder(builder: (context) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return Text(
                'REVIEW INVESTIGATION',
                style: HerzogText.heading(
                  fontSize: 14,
                  color: isDark ? HerzogColors.gold : HerzogColors.navyBlue,
                ),
              );
            }),
            const SizedBox(height: 12),
            Semantics(
              label: 'Review comments',
              textField: true,
              child: TextField(
                controller: _commentsCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Comments (required)',
                  hintText: 'Enter your review comments...',
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : () => _review('approve'),
                    icon: const Icon(Icons.check_circle, size: 16),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HerzogColors.successGreen,
                      foregroundColor: HerzogColors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : () => _review('return'),
                    icon: const Icon(Icons.undo, size: 16),
                    label: const Text('Return'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HerzogColors.warningAmber,
                      foregroundColor: HerzogColors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovedSection(Investigation inv) {
    final dateStr = inv.actualCompletionDate != null
        ? DateFormat('MM/dd/yyyy hh:mm a').format(inv.actualCompletionDate!)
        : '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  size: 24,
                  color: HerzogColors.successGreen,
                ),
                const SizedBox(width: 8),
                Text(
                  'INVESTIGATION APPROVED',
                  style: HerzogText.heading(
                    fontSize: 14,
                    color: HerzogColors.successGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (dateStr.isNotEmpty) _infoRow('Completed', dateStr),
            if (inv.reviewedBy.isNotEmpty)
              _infoRow('Approved By', inv.reviewedBy),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: HerzogText.label(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : HerzogColors.midGray,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: HerzogText.body(
                fontSize: 13,
                color: isDark ? Colors.white : HerzogColors.richBlack,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Assigned':
        return HerzogColors.infoTeal;
      case 'In Progress':
        return HerzogColors.warningAmber;
      case 'Under Review':
        return HerzogColors.navyBlue;
      case 'Approved':
        return HerzogColors.successGreen;
      case 'Returned':
        return HerzogColors.errorRed;
      default:
        return HerzogColors.midGray;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'Assigned':
        return Icons.assignment;
      case 'In Progress':
        return Icons.pending;
      case 'Under Review':
        return Icons.rate_review;
      case 'Approved':
        return Icons.check_circle;
      case 'Returned':
        return Icons.undo;
      default:
        return Icons.info;
    }
  }
}
