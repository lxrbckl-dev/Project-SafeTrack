import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/herzog_theme.dart';
import '../../../core/services/websocket_service.dart';
import '../../auth/data/auth_service.dart';
import '../data/activity_repository.dart';

/// A scrollable live activity feed that displays recent audit log entries
/// as human-readable messages with user avatars, action icons, and
/// relative timestamps.
///
/// When a [WebSocketService] is available in the widget tree, it listens
/// for real-time activity events and refreshes immediately instead of
/// waiting for the 30-second polling interval.
///
/// ADA/WCAG:
/// - Semantic labels on all interactive elements (WCAG 1.3.1)
/// - Role-colored avatars with sufficient contrast (WCAG 1.4.3)
/// - Focus indicators on tappable items (WCAG 2.4.7)
class ActivityFeed extends StatefulWidget {
  /// If true, limits display to [maxItems] and shows a "View All" link.
  final bool compact;

  /// Maximum items to display in compact mode.
  final int maxItems;

  const ActivityFeed({super.key, this.compact = false, this.maxItems = 10});

  @override
  State<ActivityFeed> createState() => _ActivityFeedState();
}

class _ActivityFeedState extends State<ActivityFeed> {
  List<ActivityFeedItem> _items = [];
  bool _loading = true;
  String? _error;
  Timer? _timer;
  StreamSubscription<Map<String, dynamic>>? _wsSubscription;

  @override
  void initState() {
    super.initState();
    _fetchActivity();
    // Polling fallback — fires every 30s as before.
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _fetchActivity(),
    );

    // Listen for real-time WebSocket activity events.
    // When an event arrives, refresh the full feed from the API so we get
    // properly RBAC-scoped, human-readable items.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final ws = context.read<WebSocketService>();
        _wsSubscription = ws.activityStream.listen((_) {
          _fetchActivity();
        });
      } catch (_) {
        // WebSocketService not available — polling continues as fallback.
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _wsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchActivity() async {
    final auth = context.read<AuthService>();
    final repo = ActivityRepository(auth);
    try {
      final items = await repo.getActivity(
        limit: widget.compact ? widget.maxItems : 50,
      );
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null && _items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Failed to load activity',
              style: HerzogText.body(
                color: HerzogColors.errorRed,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: _fetchActivity, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No recent activity',
            style: HerzogText.body(
              color: isDark ? Colors.white : HerzogColors.midGray,
            ),
          ),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayItems = widget.compact
        ? _items.take(widget.maxItems).toList()
        : _items;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < displayItems.length; i++) ...[
          _ActivityTile(item: displayItems[i]),
          if (i < displayItems.length - 1)
            const Divider(height: 1, color: HerzogColors.borderGray),
        ],
        if (widget.compact && _items.length > widget.maxItems)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: TextButton(
                onPressed: () => context.push('/activity'),
                child: Text(
                  'View all activity',
                  style: HerzogText.label(
                    color: isDark ? HerzogColors.gold : HerzogColors.navyBlue,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A single activity feed tile with avatar, message, timestamp, and action icon.
class _ActivityTile extends StatelessWidget {
  final ActivityFeedItem item;

  const _ActivityTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      label: '${item.message}, ${_relativeTimestamp(item.timestamp)}',
      button:
          item.entityType == 'incident' ||
          item.entityType == 'investigation' ||
          item.entityType == 'capa',
      child: InkWell(
        onTap: _entityRoute(item) != null
            ? () => context.push(_entityRoute(item)!)
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User initials avatar, colored by role.
              _Avatar(displayName: item.userDisplayName, role: item.userRole),
              const SizedBox(width: 12),
              // Message and timestamp.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            item.message,
                            style: HerzogText.body(
                              fontSize: 13,
                              color: isDark
                                  ? HerzogDarkColors.textPrimary
                                  : HerzogColors.richBlack,
                            ),
                          ),
                        ),
                        if (item.isAgent) ...[
                          const SizedBox(width: 6),
                          Semantics(
                            label: 'via agent',
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: HerzogColors.chartPurple.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: HerzogColors.chartPurple.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                              ),
                              child: Text(
                                'agent',
                                style: HerzogText.label(
                                  fontSize: 10,
                                  color: HerzogColors.chartPurple,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _relativeTimestamp(item.timestamp),
                      style: HerzogText.label(
                        fontSize: 11,
                        color: isDark
                            ? HerzogDarkColors.textMuted
                            : HerzogColors.smoke,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Action-type icon.
              _ActionIcon(action: item.action, entityType: item.entityType),
            ],
          ),
        ),
      ),
    );
  }

  /// Returns the route path for navigating to the entity detail page, or null
  /// if the entity type does not have a detail page.
  static String? _entityRoute(ActivityFeedItem item) {
    switch (item.entityType) {
      case 'incident':
        return '/incidents/${item.entityId}';
      case 'investigation':
        return '/investigations/${item.entityId}';
      case 'capa':
        return '/capas/${item.entityId}';
      default:
        return null;
    }
  }
}

/// Circular avatar with the first letter of the display name, colored by role.
class _Avatar extends StatelessWidget {
  final String displayName;
  final String role;

  const _Avatar({required this.displayName, required this.role});

  @override
  Widget build(BuildContext context) {
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    final bgColor = _roleColor(role);
    // Ensure sufficient contrast for the initial letter.
    final textColor = _textColorForBackground(bgColor);

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: HerzogText.label(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }

  /// Maps roles to distinct colors for visual identification.
  static Color _roleColor(String role) {
    switch (role) {
      case 'field_reporter':
        return HerzogColors.infoTeal;
      case 'safety_coordinator':
        return HerzogColors.successGreen;
      case 'safety_manager':
        return HerzogColors.navyBlue;
      case 'pm':
        return HerzogColors.chartPurple;
      case 'division_manager':
        return HerzogColors.warningAmber;
      case 'executive':
        return HerzogColors.chartSlate;
      case 'admin':
        return HerzogColors.errorRed;
      default:
        return HerzogColors.midGray;
    }
  }

  /// Returns white or black text depending on background luminance.
  static Color _textColorForBackground(Color bg) {
    return bg.computeLuminance() > 0.4
        ? HerzogColors.richBlack
        : HerzogColors.white;
  }
}

/// Small icon representing the action type (create, approve, complete, etc.).
class _ActionIcon extends StatelessWidget {
  final String action;
  final String entityType;

  const _ActionIcon({required this.action, required this.entityType});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark
        ? HerzogDarkColors.textSecondary
        : HerzogColors.midGray;

    IconData icon;
    switch (action) {
      case 'create':
        icon = entityType == 'incident'
            ? Icons.report_outlined
            : entityType == 'link'
            ? Icons.link
            : Icons.add_circle_outline;
        break;
      case 'approve':
        icon = Icons.check_circle_outline;
        break;
      case 'reject':
        icon = Icons.cancel_outlined;
        break;
      case 'complete':
        icon = Icons.task_alt;
        break;
      case 'verify':
        icon = Icons.verified_outlined;
        break;
      case 'assign':
        icon = Icons.person_add_outlined;
        break;
      case 'status_change':
        icon = Icons.swap_horiz;
        break;
      case 'update':
        icon = Icons.edit_outlined;
        break;
      default:
        icon = Icons.history;
    }

    return Icon(icon, size: 18, color: iconColor);
  }
}

/// Formats a [DateTime] as a human-readable relative timestamp.
///
/// Examples: "Just now", "2 minutes ago", "1 hour ago", "Yesterday", "Mar 25"
String _relativeTimestamp(DateTime timestamp) {
  final now = DateTime.now();
  final diff = now.difference(timestamp);

  if (diff.isNegative || diff.inSeconds < 60) {
    return 'Just now';
  } else if (diff.inMinutes < 60) {
    final m = diff.inMinutes;
    return '$m minute${m == 1 ? '' : 's'} ago';
  } else if (diff.inHours < 24) {
    final h = diff.inHours;
    return '$h hour${h == 1 ? '' : 's'} ago';
  } else if (diff.inDays == 1) {
    return 'Yesterday';
  } else if (diff.inDays < 7) {
    final d = diff.inDays;
    return '$d day${d == 1 ? '' : 's'} ago';
  } else {
    // Format as "Mar 25" for older items.
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[timestamp.month - 1]} ${timestamp.day}';
  }
}
