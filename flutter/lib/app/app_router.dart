import 'package:go_router/go_router.dart';
import '../features/auth/data/auth_service.dart';
import '../features/auth/data/role.dart';
import '../features/auth/pages/login_page.dart';
import '../features/shell/pages/app_shell_page.dart';
import '../features/dashboard/pages/safety_dashboard_page.dart';
import '../features/dashboard/pages/hours_worked_page.dart';
import '../features/incidents/pages/incident_list_page.dart';
import '../features/incidents/pages/incident_form_page.dart';
import '../features/incidents/pages/incident_detail_page.dart';
import '../features/incidents/pages/incident_cluster_page.dart';
import '../features/incidents/pages/osha_determination_page.dart';
import '../features/investigations/pages/investigation_list_page.dart';
import '../features/investigations/pages/investigation_detail_page.dart';
import '../features/investigations/pages/investigation_form_page.dart';
import '../features/capas/pages/capa_dashboard_page.dart';
import '../features/capas/pages/capa_detail_page.dart';
import '../features/capas/pages/capa_form_page.dart';
import '../features/admin/pages/admin_settings_page.dart';
import '../features/admin/pages/factor_types_page.dart';
import '../features/audit_log/pages/audit_log_page.dart';
import '../features/notifications/pages/notification_preferences_page.dart';

/// Builds the [GoRouter] with auth redirect and shell routing.
///
/// Requires an [AuthService] so the redirect logic can check login state
/// without a BuildContext dependency.
///
/// Auth redirect rules:
/// - Unauthenticated → /login
/// - Authenticated on /login → /dashboard
/// - /admin: Admin or Safety Manager → else /dashboard (fix #10)
/// - /audit-log: Admin or Safety Manager → else /dashboard
///
/// Shell: all authenticated routes are wrapped in [AppShellPage]
/// (responsive sidebar on desktop ≥900px, bottom nav on mobile <900px).
///
/// POC routes (/, /drift, /connectivity, /ollama) removed from production routing.
GoRouter appRouter(AuthService authService) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: authService,
    redirect: (context, state) {
      final loggedIn = authService.isLoggedIn;
      final role = authService.currentRole;
      final location = state.matchedLocation;

      // Unauthenticated: send to /login (except if already there)
      if (!loggedIn && location != '/login') {
        return '/login';
      }

      // Authenticated on /login: send to dashboard
      if (loggedIn && location == '/login') {
        return '/dashboard';
      }

      // Role gate: /investigations — Safety Coordinator and above
      // Field Reporter cannot access investigations.
      if (location.startsWith('/investigations') &&
          role != null &&
          !role.isAtLeast(Role.safetyCoordinator)) {
        return '/dashboard';
      }

      // Role gate: /capas — Safety Coordinator and above
      // Field Reporter cannot access CAPAs.
      if (location.startsWith('/capas') &&
          role != null &&
          !role.isAtLeast(Role.safetyCoordinator)) {
        return '/dashboard';
      }

      // Role gate: /admin — Admin or Safety Manager (fix #10: was Admin only)
      if (location.startsWith('/admin') &&
          role != null &&
          role != Role.admin &&
          role != Role.safetyManager) {
        return '/dashboard';
      }

      // Role gate: /audit-log — Admin or Safety Manager
      if (location.startsWith('/audit-log') &&
          role != null &&
          role != Role.admin &&
          role != Role.safetyManager) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      // /login — outside the shell (no sidebar on login screen).
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),

      // Authenticated shell — wraps all main app routes with AppShellPage
      // (responsive sidebar on desktop ≥900px, bottom nav on mobile <900px).
      ShellRoute(
        builder: (context, state, child) => AppShellPage(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            name: 'dashboard',
            builder: (context, state) => const SafetyDashboardPage(),
            routes: [
              GoRoute(
                path: 'hours-worked',
                name: 'hoursWorked',
                builder: (context, state) => const HoursWorkedPage(),
              ),
            ],
          ),

          // Incident routes
          GoRoute(
            path: '/incidents',
            name: 'incidents',
            builder: (context, state) => const IncidentListPage(),
            routes: [
              GoRoute(
                path: 'new',
                name: 'incidentNew',
                builder: (context, state) => const IncidentFormPage(),
              ),
              GoRoute(
                path: 'clusters',
                name: 'incidentClusters',
                builder: (context, state) => const IncidentClusterPage(),
              ),
              GoRoute(
                path: ':id',
                name: 'incidentDetail',
                builder: (context, state) {
                  final id = int.tryParse(state.pathParameters['id'] ?? '');
                  if (id == null) {
                    return const IncidentListPage();
                  }
                  return IncidentDetailPage(incidentId: id);
                },
                routes: [
                  GoRoute(
                    path: 'edit',
                    name: 'incidentEdit',
                    builder: (context, state) {
                      final id = int.tryParse(state.pathParameters['id'] ?? '');
                      return IncidentFormPage(incidentId: id);
                    },
                  ),
                  GoRoute(
                    path: 'osha',
                    name: 'incidentOsha',
                    builder: (context, state) {
                      final id = int.tryParse(state.pathParameters['id'] ?? '');
                      if (id == null) {
                        return const IncidentListPage();
                      }
                      return OshaDeterminationPage(incidentId: id);
                    },
                  ),
                ],
              ),
            ],
          ),

          // Investigation routes
          GoRoute(
            path: '/investigations',
            name: 'investigations',
            builder: (context, state) => const InvestigationListPage(),
            routes: [
              GoRoute(
                path: 'new',
                name: 'investigationNew',
                builder: (context, state) {
                  final incidentId = int.tryParse(
                    state.uri.queryParameters['incidentId'] ?? '',
                  );
                  return InvestigationFormPage(incidentId: incidentId);
                },
              ),
              GoRoute(
                path: ':id',
                name: 'investigationDetail',
                builder: (context, state) {
                  final id = int.tryParse(state.pathParameters['id'] ?? '');
                  if (id == null) {
                    return const InvestigationListPage();
                  }
                  return InvestigationDetailPage(investigationId: id);
                },
              ),
            ],
          ),
          // CAPA routes
          GoRoute(
            path: '/capas',
            name: 'capas',
            builder: (context, state) => const CAPADashboardPage(),
            routes: [
              GoRoute(
                path: 'new',
                name: 'capaNew',
                builder: (context, state) {
                  final investigationId = int.tryParse(
                    state.uri.queryParameters['investigationId'] ?? '',
                  );
                  return CAPAFormPage(investigationId: investigationId);
                },
              ),
              GoRoute(
                path: ':id',
                name: 'capaDetail',
                builder: (context, state) {
                  final id = int.tryParse(state.pathParameters['id'] ?? '');
                  if (id == null) {
                    return const CAPADashboardPage();
                  }
                  return CAPADetailPage(capaId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/admin',
            name: 'admin',
            builder: (context, state) => const AdminSettingsPage(),
            routes: [
              GoRoute(
                path: 'factor-types',
                name: 'factorTypes',
                builder: (context, state) => const FactorTypesPage(),
              ),
            ],
          ),
          GoRoute(
            path: '/audit-log',
            name: 'auditLog',
            builder: (context, state) => const AuditLogPage(),
          ),
          GoRoute(
            path: '/notification-preferences',
            name: 'notificationPreferences',
            builder: (context, state) => const NotificationPreferencesPage(),
          ),
        ],
      ),

      // POC routes removed: /, /drift, /connectivity, /ollama
      // Pages still exist in features/poc/ for reference.
    ],
  );
}
