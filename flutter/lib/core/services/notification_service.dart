import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

/// A single in-app notification returned from GET /api/notifications.
class AppNotification {
  final int id;
  final String userId;
  final String title;
  final String message;

  /// One of: overdue_investigation, overdue_capa, railroad_notification,
  /// review_request
  final String type;

  /// One of: incident, investigation, capa
  final String entityType;

  final int entityId;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    required this.entityType,
    required this.entityId,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as int,
      userId: json['userId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      type: json['type'] as String? ?? '',
      entityType: json['entityType'] as String? ?? '',
      entityId: json['entityId'] as int? ?? 0,
      isRead: json['isRead'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      userId: userId,
      title: title,
      message: message,
      type: type,
      entityType: entityType,
      entityId: entityId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// Polls GET /api/notifications?unread=true on a fixed interval and exposes
/// [unreadCount] plus the full [notifications] list.
///
/// Add this to the MultiProvider in main.dart AFTER AuthService so it can
/// receive the bearer token.
///
/// Usage:
/// ```dart
///   context.watch<NotificationService>().unreadCount
///   context.read<NotificationService>().markRead(id)
/// ```
class NotificationService extends ChangeNotifier {
  NotificationService({Duration pollInterval = const Duration(seconds: 30)})
    : _pollInterval = pollInterval;

  final Duration _pollInterval;

  /// Current authenticated JWT. Set via [setToken] when the user logs in.
  String? _token;

  List<AppNotification> _notifications = [];
  bool _loading = false;
  String? _error;
  Timer? _timer;

  /// All notifications for the current user (ordered newest-first).
  List<AppNotification> get notifications => _notifications;

  /// Number of unread notifications — drives the bell badge.
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  bool get isLoading => _loading;
  String? get error => _error;

  // ---------- lifecycle ----------

  /// Must be called when the user logs in (or out) so this service
  /// uses the correct JWT for API calls.
  void setToken(String? token) {
    _token = token;
    if (token != null) {
      _startPolling();
    } else {
      _stopPolling();
      _notifications = [];
      _error = null;
      notifyListeners();
    }
  }

  void _startPolling() {
    _timer?.cancel();
    // Fetch immediately, then on each tick.
    fetchNotifications();
    _timer = Timer.periodic(_pollInterval, (_) => fetchNotifications());
  }

  void _stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }

  // ---------- API calls ----------

  /// Fetches all notifications for the current user. Called automatically by
  /// the polling timer; can also be called manually to force a refresh.
  Future<void> fetchNotifications() async {
    if (_token == null) return;

    _loading = true;
    notifyListeners();

    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/notifications');
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        _notifications = data
            .map(
              (json) => AppNotification.fromJson(json as Map<String, dynamic>),
            )
            .toList();
        _error = null;
      } else {
        _error = 'Failed to load notifications (${response.statusCode})';
      }
    } catch (e) {
      _error = 'Network error: $e';
    }

    _loading = false;
    notifyListeners();
  }

  /// Calls PUT /api/notifications/{id}/read and optimistically updates local
  /// state so the badge count decrements immediately.
  Future<void> markRead(int notificationId) async {
    if (_token == null) return;

    // Optimistic update.
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1 && !_notifications[index].isRead) {
      _notifications = List.of(_notifications);
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      notifyListeners();
    }

    try {
      await http.put(
        Uri.parse(
          '${ApiConfig.baseUrl}/api/notifications/$notificationId/read',
        ),
        headers: {'Authorization': 'Bearer $_token'},
      );
    } catch (_) {
      // If the server call fails, refresh to re-sync state.
      await fetchNotifications();
    }
  }

  /// Calls POST /api/notifications/check-escalations to trigger the server-side
  /// escalation sweep. Useful for admin/debug usage.
  Future<void> checkEscalations() async {
    if (_token == null) return;
    try {
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/notifications/check-escalations'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      // Refresh after checking so the new notifications appear immediately.
      await fetchNotifications();
    } catch (_) {
      // Non-fatal — the polling cycle will pick up changes.
    }
  }
}
