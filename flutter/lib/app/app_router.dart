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
import '../features/incidents/pages/incident_map_page.dart';
import '../features/incidents/pages/osha_determination_page.dart';
import '../features/investigations/pages/investigation_list_page.dart';
import '../features/investigations/pages/investigation_detail_page.dart';
import '../features/investigations/pages/investigation_form_page.dart';
import '../features/capas/pages/capa_dashboard_page.dart';
import '../features/capas/pages/capa_detail_page.dart';
import '../features/capas/pages/capa_form_page.dart';
import '../features/admin/pages/admin_settings_page.dart';
import '../features/admin/pages/factor_types_page.dart';
import '../features/admin/pages/osha_export_page.dart';
import '../features/audit_log/pages/audit_log_page.dart';
import '../features/notifications/pages/notification_preferences_page.dart';
import '../features/search/pages/search_results_page.dart';
import '../features/training/pages/training_list_page.dart';
import '../features/training/pages/training_detail_page.dart';
import '../features/activity/pages/activity_page.dart';

/// Builds the [GoRouter] with auth redirect and shell routing.
///
/// Requires an [AuthService] so the redirect logic can check login state
/// without a BuildContext dependency.
///
/// Auth redirect rules:
/// - Unauthenticated → /login
/// - Authenticated on /login, Field Reporter → /incidents
/// - Authenticated on /login, all other roles → /dashboard
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

      // Authenticated on /login: send to role-appropriate landing page.
      // Field Reporter lands on /incidents (their primary workflow).
      // All other roles land on /dashboard.
      // Edge case (TASK-044): if role is null (JWT deserialization failed),
      // redirect to /login to force re-authentication.
      if (loggedIn && location == '/login') {
        if (role == null) {
          authService.logout(); // clear stale/malformed token
          return '/login';
        }
        if (role == Role.fieldReporter) {
          return '/incidents';
        }
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

      // Role gate: /training — Safety Coordinator and above
      // Field Reporter cannot access training.
      if (location.startsWith('/training') &&
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
                // TASK-044: pass query parameters for pre-fill support.
                // GoRouter preserves query params through auth redirect by
                // default, so deep-links with params survive login.
                builder: (context, state) =>
                    IncidentFormPage(queryParams: state.uri.queryParameters),
              ),
              GoRoute(
                path: 'map',
                name: 'incidentMap',
                builder: (context, state) => const IncidentMapPage(),
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
                  final params = state.uri.queryParameters;
                  final incidentId = int.tryParse(params['incidentId'] ?? '');
                  // TASK-044: pass leadInvestigator query param for pre-fill.
                  final leadInvestigator = params['leadInvestigator'];
                  return InvestigationFormPage(
                    incidentId: incidentId,
                    leadInvestigator: leadInvestigator,
                  );
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
                  final params = state.uri.queryParameters;
                  final investigationId = int.tryParse(
                    params['investigationId'] ?? '',
                  );
                  // TASK-044: pass type/category/priority/description for
                  // query-param pre-fill.
                  return CAPAFormPage(
                    investigationId: investigationId,
                    queryParams: params,
                  );
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
          // Training routes
          GoRoute(
            path: '/training',
            name: 'training',
            builder: (context, state) => const TrainingListPage(),
            routes: [
              GoRoute(
                path: ':id',
                name: 'trainingDetail',
                builder: (context, state) {
                  final id = int.tryParse(state.pathParameters['id'] ?? '');
                  if (id == null) {
                    return const TrainingListPage();
                  }
                  return TrainingDetailPage(trainingId: id);
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
              GoRoute(
                path: 'osha-export',
                name: 'oshaExport',
                builder: (context, state) => const OshaExportPage(),
              ),
            ],
          ),
          GoRoute(
            path: '/audit-log',
            name: 'auditLog',
            builder: (context, state) => const AuditLogPage(),
          ),
          // Global search route
          GoRoute(
            path: '/search',
            name: 'search',
            builder: (context, state) {
              final q = state.uri.queryParameters['q'] ?? '';
              return SearchResultsPage(initialQuery: q);
            },
          ),
          GoRoute(
            path: '/notification-preferences',
            name: 'notificationPreferences',
            builder: (context, state) => const NotificationPreferencesPage(),
          ),
          GoRoute(
            path: '/activity',
            name: 'activity',
            builder: (context, state) => const ActivityPage(),
          ),
        ],
      ),

      // POC routes removed: /, /drift, /connectivity, /ollama
      // Pages still exist in features/poc/ for reference.
    ],
  );
}
