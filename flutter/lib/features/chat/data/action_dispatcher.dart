import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../auth/data/auth_service.dart';
import '../../auth/data/role.dart';
import 'form_fill_service.dart';

/// A structured action parsed from an AI chat response.
///
/// Actions are JSON objects with an "action" key and optional "route" / "fields".
class ChatAction {
  final String action;
  final String? route;
  final Map<String, String>? fields;

  const ChatAction({required this.action, this.route, this.fields});

  /// Parse a [ChatAction] from a decoded JSON map.
  factory ChatAction.fromJson(Map<String, dynamic> json) {
    final fields = json['fields'] != null
        ? (json['fields'] as Map<String, dynamic>).map(
            (k, v) => MapEntry(k, v.toString()),
          )
        : null;

    return ChatAction(
      action: json['action'] as String? ?? '',
      route: json['route'] as String?,
      fields: fields,
    );
  }

  Map<String, dynamic> toJson() => {
    'action': action,
    if (route != null) 'route': route,
    if (fields != null) 'fields': fields,
  };

  /// Human-readable label for action buttons in the chat UI.
  String get buttonLabel {
    switch (action) {
      case 'navigate':
        return 'Go to ${_routeLabel(route ?? '')}';
      case 'fill':
        return 'Fill form fields';
      case 'navigate_and_fill':
        return 'Go to ${_routeLabel(route ?? '')} and fill form';
      default:
        return action;
    }
  }

  /// Converts a route path to a human-readable label.
  static String _routeLabel(String route) {
    // Strip query parameters for display.
    final path = route.split('?').first;
    switch (path) {
      case '/dashboard':
        return 'Dashboard';
      case '/incidents':
        return 'Incidents';
      case '/incidents/new':
        return 'New Incident';
      case '/investigations':
        return 'Investigations';
      case '/investigations/new':
        return 'New Investigation';
      case '/capas':
        return 'CAPAs';
      case '/capas/new':
        return 'New CAPA';
      case '/admin':
        return 'Admin Settings';
      case '/audit-log':
        return 'Audit Log';
      default:
        return path;
    }
  }
}

/// Parses action JSON from chat API responses.
List<ChatAction> parseActionsFromJson(List<dynamic>? actionsJson) {
  if (actionsJson == null || actionsJson.isEmpty) return [];
  return actionsJson
      .map((a) => ChatAction.fromJson(a as Map<String, dynamic>))
      .where((a) => a.action.isNotEmpty)
      .toList();
}

/// Dispatches AI chat actions: navigation and form filling.
///
/// Permission-gated — validates the user has access to the target route before
/// executing. Uses [GoRouter] for navigation and [FormFillService] for form
/// fill queuing.
class ChatActionDispatcher {
  /// Routes that require specific minimum roles.
  static const _routePermissions = <String, Role>{
    '/investigations': Role.safetyCoordinator,
    '/capas': Role.safetyCoordinator,
  };

  /// Routes restricted to specific roles only (not hierarchical).
  static const _restrictedRoutes = <String, List<Role>>{
    '/admin': [Role.admin, Role.safetyManager],
    '/audit-log': [Role.admin, Role.safetyManager],
  };

  /// Check if the current user has permission to access [route].
  static bool _hasPermission(AuthService auth, String route) {
    final role = auth.currentRole;
    if (role == null) return false;

    final path = route.split('?').first;

    // Check restricted routes (exact role match).
    for (final entry in _restrictedRoutes.entries) {
      if (path.startsWith(entry.key)) {
        return entry.value.contains(role);
      }
    }

    // Check hierarchical role gates.
    for (final entry in _routePermissions.entries) {
      if (path.startsWith(entry.key)) {
        return role.isAtLeast(entry.value);
      }
    }

    // All other routes are accessible to any authenticated user.
    return true;
  }

  /// Execute a [ChatAction] in the given [context].
  ///
  /// Returns a user-facing message describing what happened, or an error message
  /// if the action was denied or failed.
  static String execute(BuildContext context, ChatAction action) {
    final auth = context.read<AuthService>();
    final formFillService = context.read<FormFillService>();

    switch (action.action) {
      case 'navigate':
        return _navigate(context, auth, action.route ?? '/dashboard');

      case 'fill':
        return _fill(formFillService, action.fields ?? {});

      case 'navigate_and_fill':
        final navResult = _navigate(
          context,
          auth,
          action.route ?? '/dashboard',
        );
        if (navResult.startsWith('Access denied')) return navResult;
        // Queue the fill — the target form will consume it on init.
        if (action.fields != null && action.fields!.isNotEmpty) {
          formFillService.setPendingFields(action.fields!);
        }
        return navResult;

      default:
        return 'Unknown action: ${action.action}';
    }
  }

  static String _navigate(
    BuildContext context,
    AuthService auth,
    String route,
  ) {
    if (!_hasPermission(auth, route)) {
      return 'Access denied: you do not have permission to access $route';
    }

    context.go(route);
    return 'Navigating to $route';
  }

  static String _fill(
    FormFillService formFillService,
    Map<String, String> fields,
  ) {
    if (fields.isEmpty) return 'No fields to fill.';
    formFillService.setPendingFields(fields);
    return 'Form fields queued for auto-fill.';
  }
}
