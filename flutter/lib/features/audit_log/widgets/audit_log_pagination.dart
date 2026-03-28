import 'package:flutter/material.dart';

import '../../../app/herzog_theme.dart';

/// Pagination controls: previous / page indicator / next.
///
/// Keyboard navigable and WCAG compliant with proper semantic labels.
class AuditLogPagination extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final int totalRecords;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const AuditLogPagination({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.totalRecords,
    this.onPrevious,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Pagination: page $currentPage of $totalPages, $totalRecords total records',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$totalRecords records',
              style: HerzogText.body(fontSize: 12, color: HerzogColors.midGray),
            ),
            const SizedBox(width: 24),
            Tooltip(
              message: 'Previous page',
              child: IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: currentPage > 1 ? onPrevious : null,
                color: HerzogColors.navyBlue,
                disabledColor: HerzogColors.smoke,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: HerzogColors.offWhite,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: HerzogColors.borderGray),
              ),
              child: Text(
                'Page $currentPage of $totalPages',
                style: HerzogText.body(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Tooltip(
              message: 'Next page',
              child: IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: currentPage < totalPages ? onNext : null,
                color: HerzogColors.navyBlue,
                disabledColor: HerzogColors.smoke,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
