import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/herzog_theme.dart';
import '../../../core/services/notification_service.dart';

/// Slide-in notifications panel shown when the bell icon is tapped.
///
/// Renders as a right-edge Drawer displaying all notifications ordered
/// newest-first. Unread items are visually prominent; tapping any item marks
/// it read and navigates to the linked entity.
///
/// ADA/WCAG:
/// - Drawer has an accessible label (WCAG 1.3.1)
/// - Each list tile has a semantic button role with descriptive label
/// - Sufficient contrast on all text (WCAG 1.4.3)
class NotificationPanel extends StatelessWidget {
  const NotificationPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<NotificationService>();
    final notifications = service.notifications;

    return Drawer(
      width: 360,
      backgroundColor: HerzogColors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PanelHeader(onClose: () => Navigator.of(context).pop()),
            const Divider(color: HerzogColors.gold, height: 1, thickness: 3),
            if (service.isLoading && notifications.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (notifications.isEmpty)
              _EmptyState()
            else
              Expanded(
                child: Semantics(
                  label: 'Notifications list',
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: notifications.length,
                    separatorBuilder: (context, i) => const Divider(
                      height: 1,
                      color: HerzogColors.borderGray,
                    ),
                    itemBuilder: (context, index) {
                      return _NotificationTile(
                        notification: notifications[index],
                        onTap: () {
                          context.read<NotificationService>().markRead(
                            notifications[index].id,
                          );
                          Navigator.of(context).pop();
                          _navigateToEntity(
                            context,
                            notifications[index].entityType,
                            notifications[index].entityId,
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Routes the user to the correct entity detail page.
  void _navigateToEntity(
    BuildContext context,
    String entityType,
    int entityId,
  ) {
    switch (entityType) {
      case 'incident':
        context.push('/incidents/$entityId');
      case 'investigation':
        context.push('/investigations/$entityId');
      case 'capa':
        context.push('/capas/$entityId');
    }
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _PanelHeader extends StatelessWidget {
  final VoidCallback onClose;

  const _PanelHeader({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: HerzogColors.richBlack,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Text(
            'NOTIFICATIONS',
            style: HerzogText.heading(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: HerzogColors.gold,
            ),
          ),
          const Spacer(),
          Semantics(
            label: 'Close notifications panel',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.close, color: HerzogColors.smoke),
              onPressed: onClose,
              tooltip: 'Close',
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.notifications_none,
            size: 48,
            color: HerzogColors.smoke,
            semanticLabel: 'No notifications',
          ),
          const SizedBox(height: 12),
          Text(
            'No notifications',
            style: HerzogText.body(fontSize: 14, color: HerzogColors.midGray),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;

    return Semantics(
      label:
          '${notification.title}. ${notification.message}. ${isUnread ? "Unread." : "Read."}',
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          color: isUnread
              ? HerzogColors.warningLight.withValues(alpha: 0.5)
              : HerzogColors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TypeIcon(type: notification.type),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: HerzogText.body(
                              fontSize: 13,
                              fontWeight: isUnread
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: HerzogColors.richBlack,
                            ),
                          ),
                        ),
                        if (isUnread)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: HerzogColors.gold,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: HerzogText.body(
                        fontSize: 12,
                        color: HerzogColors.darkGray,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(notification.createdAt),
                      style: HerzogText.label(
                        fontSize: 10,
                        color: HerzogColors.smoke,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${dt.month}/${dt.day}/${dt.year}';
  }
}

class _TypeIcon extends StatelessWidget {
  final String type;

  const _TypeIcon({required this.type});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (type) {
      'overdue_investigation' => (Icons.search_off, HerzogColors.errorRed),
      'overdue_capa' => (Icons.assignment_late, HerzogColors.warningAmber),
      'railroad_notification' => (Icons.train, HerzogColors.navyBlue),
      'review_request' => (Icons.rate_review, HerzogColors.infoTeal),
      _ => (Icons.notifications, HerzogColors.midGray),
    };

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 18, color: color, semanticLabel: type),
    );
  }
}
