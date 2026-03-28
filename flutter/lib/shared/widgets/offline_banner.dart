import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/herzog_theme.dart';
import '../../core/services/sync_service.dart';

/// Persistent banner displayed at the top of the app shell when the device
/// is offline.
///
/// Shows "You're offline -- changes will sync when connected" in an amber
/// warning bar. Auto-hides when connectivity is restored.
///
/// Also shows a pending sync count badge when there are offline incidents
/// waiting to upload.
///
/// ADA/WCAG compliance:
/// - Uses semantic label for screen readers (WCAG 1.3.1)
/// - Sufficient contrast: dark text on amber/warning background (WCAG 1.4.3)
/// - Auto-announced via [Semantics] liveRegion (WCAG 4.1.3)
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final syncService = context.watch<SyncService>();
    final isOffline = !syncService.isOnline;
    final pendingCount = syncService.pendingCount;
    final isSyncing = syncService.isSyncing;

    // Show banner when offline OR when there are pending items syncing
    if (!isOffline && pendingCount == 0 && !isSyncing) {
      return const SizedBox.shrink();
    }

    // Determine message
    String message;
    Color backgroundColor;
    IconData icon;

    if (isOffline) {
      message = "You're offline -- changes will sync when connected";
      backgroundColor = HerzogColors.warningLight;
      icon = Icons.cloud_off;
    } else if (isSyncing) {
      message =
          'Syncing $pendingCount incident${pendingCount == 1 ? '' : 's'}...';
      backgroundColor = HerzogColors.infoLight;
      icon = Icons.sync;
    } else {
      message =
          '$pendingCount incident${pendingCount == 1 ? '' : 's'} pending sync';
      backgroundColor = HerzogColors.warningLight;
      icon = Icons.cloud_upload_outlined;
    }

    return Semantics(
      label: message,
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: backgroundColor,
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: HerzogColors.warningAmber,
              semanticLabel: isOffline ? 'Offline' : 'Syncing',
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: HerzogText.body(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: HerzogColors.warningAmber,
                ),
              ),
            ),
            if (pendingCount > 0 && !isSyncing)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: HerzogColors.warningAmber,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$pendingCount',
                  style: HerzogText.label(
                    fontSize: 11,
                    color: HerzogColors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (isSyncing)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: HerzogColors.warningAmber,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
