import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'api_config.dart';
import 'notification_service.dart';

// ---------------------------------------------------------------------------
// WebSocket event model
// ---------------------------------------------------------------------------

/// An event received from the server over WebSocket.
class WSEvent {
  final String type;
  final Map<String, dynamic> data;

  const WSEvent({required this.type, required this.data});

  factory WSEvent.fromJson(Map<String, dynamic> json) {
    return WSEvent(
      type: json['type'] as String? ?? '',
      data: json['data'] as Map<String, dynamic>? ?? {},
    );
  }
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// Manages a persistent WebSocket connection to the Go backend for real-time
/// event delivery (notifications, activity feed updates).
///
/// Features:
/// - Auto-reconnect with exponential backoff (1s, 2s, 4s, 8s, max 30s)
/// - Falls back gracefully when WebSocket is unavailable (polling continues)
/// - Pushes notification events to [NotificationService]
/// - Exposes an [activityStream] for the activity feed widget
/// - [isConnected] getter for UI status indicator
///
/// Register in `main.dart` MultiProvider AFTER both AuthService and
/// NotificationService.
class WebSocketService extends ChangeNotifier {
  WebSocketService();

  /// Current JWT for authentication.
  String? _token;

  /// Reference to the notification service for pushing real-time updates.
  NotificationService? _notificationService;

  /// The active WebSocket channel, if connected.
  WebSocketChannel? _channel;

  /// Whether the WebSocket is currently connected.
  bool _connected = false;

  /// Reconnection attempt counter (for exponential backoff).
  int _reconnectAttempts = 0;

  /// Timer for reconnect backoff.
  Timer? _reconnectTimer;

  /// Subscription for the WebSocket stream.
  StreamSubscription<dynamic>? _subscription;

  /// Stream controller for activity events — consumed by the activity feed.
  final StreamController<Map<String, dynamic>> _activityController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Whether the WebSocket connection is currently active.
  bool get isConnected => _connected;

  /// Stream of activity feed events pushed from the server.
  Stream<Map<String, dynamic>> get activityStream => _activityController.stream;

  // ---------- lifecycle ----------

  /// Called when auth state changes. Connects if token is present,
  /// disconnects if token is null (logout).
  void setToken(String? token) {
    _token = token;
    if (token != null) {
      _connect();
    } else {
      _disconnect();
    }
  }

  /// Provides a reference to the notification service for pushing real-time
  /// notification count updates.
  void setNotificationService(NotificationService service) {
    _notificationService = service;
  }

  @override
  void dispose() {
    _disconnect();
    _activityController.close();
    super.dispose();
  }

  // ---------- connection management ----------

  void _connect() {
    _disconnect();

    if (_token == null) return;

    try {
      // Build WebSocket URL from the HTTP base URL.
      final httpBase = ApiConfig.baseUrl;
      final wsBase = httpBase
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://');
      final wsUrl = Uri.parse('$wsBase/api/ws?token=$_token');

      _channel = WebSocketChannel.connect(wsUrl);

      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );

      _connected = true;
      _reconnectAttempts = 0;
      notifyListeners();

      if (kDebugMode) {
        debugPrint('[ws] connected to $wsUrl');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ws] connection failed: $e');
      }
      _connected = false;
      notifyListeners();
      _scheduleReconnect();
    }
  }

  void _disconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;

    if (_connected) {
      _connected = false;
      notifyListeners();
    }
  }

  // ---------- message handling ----------

  void _onMessage(dynamic rawMessage) {
    try {
      final json = jsonDecode(rawMessage as String) as Map<String, dynamic>;
      final event = WSEvent.fromJson(json);

      switch (event.type) {
        case 'notification':
          _handleNotificationEvent(event.data);
          break;
        case 'activity':
          _handleActivityEvent(event.data);
          break;
        default:
          if (kDebugMode) {
            debugPrint('[ws] unknown event type: ${event.type}');
          }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ws] failed to parse message: $e');
      }
    }
  }

  void _handleNotificationEvent(Map<String, dynamic> data) {
    // Tell the notification service to re-fetch so the unread count
    // updates immediately. This is simpler and more reliable than
    // trying to inject a single notification into the local list.
    _notificationService?.fetchNotifications();
  }

  void _handleActivityEvent(Map<String, dynamic> data) {
    // Push the event to the activity stream for any listening widgets.
    if (!_activityController.isClosed) {
      _activityController.add(data);
    }
  }

  // ---------- reconnection ----------

  void _onError(dynamic error) {
    if (kDebugMode) {
      debugPrint('[ws] error: $error');
    }
    _connected = false;
    notifyListeners();
    _scheduleReconnect();
  }

  void _onDone() {
    if (kDebugMode) {
      debugPrint('[ws] connection closed');
    }
    _connected = false;
    notifyListeners();

    // Only reconnect if we still have a token (not a deliberate logout).
    if (_token != null) {
      _scheduleReconnect();
    }
  }

  /// Schedules a reconnection attempt with exponential backoff.
  /// Backoff: 1s, 2s, 4s, 8s, 16s, max 30s.
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();

    final delaySeconds = min(pow(2, _reconnectAttempts).toInt(), 30);
    _reconnectAttempts++;

    if (kDebugMode) {
      debugPrint(
        '[ws] reconnecting in ${delaySeconds}s (attempt $_reconnectAttempts)',
      );
    }

    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (_token != null) {
        _connect();
      }
    });
  }
}
