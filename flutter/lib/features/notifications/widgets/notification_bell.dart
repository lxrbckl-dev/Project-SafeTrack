import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/herzog_theme.dart';
import '../../../core/services/notification_service.dart';
import 'notification_panel.dart';

/// Bell icon button with an unread-count badge for the app shell header.
///
/// Tapping it opens [NotificationPanel] as an end-drawer overlay.
/// The badge is hidden when unreadCount == 0.
///
/// ADA/WCAG:
/// - Semantic label announces unread count (WCAG 1.3.1)
/// - Badge has sufficient contrast: black text on gold background (14.4:1 AAA)
/// - Focus indicator provided by Flutter's default FocusHighlightMode
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final unreadCount = context.watch<NotificationService>().unreadCount;

    final semanticLabel = unreadCount > 0
        ? '$unreadCount unread notification${unreadCount == 1 ? '' : 's'}'
        : 'Notifications — no unread';

    return Semantics(
      label: semanticLabel,
      button: true,
      child: Tooltip(
        message: semanticLabel,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _openPanel(context),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.notifications_outlined,
                  color: HerzogColors.smoke,
                  size: 22,
                ),
                if (unreadCount > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: _Badge(count: unreadCount),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openPanel(BuildContext context) {
    // Show the notification panel as a modal end-drawer.
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss notifications',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
                ),
            child: const NotificationPanel(),
          ),
        );
      },
    );
  }
}

/// Small circular badge displaying the unread count.
///
/// Caps the display at "99+" to avoid overflow.
class _Badge extends StatelessWidget {
  final int count;

  const _Badge({required this.count});

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';

    return Container(
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: HerzogColors.gold,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: HerzogText.label(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: HerzogColors.richBlack,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
