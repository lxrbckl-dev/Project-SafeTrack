import 'package:go_router/go_router.dart';
import '../features/auth/data/auth_service.dart';
import '../features/shell/pages/not_found_page.dart';
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
import '../features/admin/pages/agent_sessions_page.dart';
import '../features/admin/pages/factor_types_page.dart';
import '../features/admin/pages/api_keys_page.dart';
import '../features/admin/pages/osha_export_page.dart';
import '../features/audit_log/pages/audit_log_page.dart';
import '../features/notifications/pages/notification_preferences_page.dart';
import '../features/search/pages/search_results_page.dart';
import '../features/training/pages/training_list_page.dart';
import '../features/training/pages/training_detail_page.dart';
import '../features/activity/pages/activity_page.dart';
import '../features/help/pages/help_page.dart';

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
    errorBuilder: (context, state) => const NotFoundPage(),
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

      // Root path: redirect to dashboard (or incidents for Field Reporter)
      if (loggedIn && location == '/') {
        if (role == Role.fieldReporter) return '/incidents';
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
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SafetyDashboardPage(),
            ),
            routes: [
              GoRoute(
                path: 'hours-worked',
                name: 'hoursWorked',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: HoursWorkedPage(),
                ),
              ),
            ],
          ),

          // Incident routes
          GoRoute(
            path: '/incidents',
            name: 'incidents',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: IncidentListPage(),
            ),
            routes: [
              GoRoute(
                path: 'new',
                name: 'incidentNew',
                // TASK-044: pass query parameters for pre-fill support.
                // GoRouter preserves query params through auth redirect by
                // default, so deep-links with params survive login.
                pageBuilder: (context, state) => NoTransitionPage(
                  child: IncidentFormPage(
                      queryParams: state.uri.queryParameters),
                ),
              ),
              GoRoute(
                path: 'map',
                name: 'incidentMap',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: IncidentMapPage(),
                ),
              ),
              GoRoute(
                path: 'clusters',
                name: 'incidentClusters',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: IncidentClusterPage(),
                ),
              ),
              GoRoute(
                path: ':id',
                name: 'incidentDetail',
                pageBuilder: (context, state) {
                  final id = int.tryParse(state.pathParameters['id'] ?? '');
                  if (id == null) {
                    return const NoTransitionPage(
                      child: IncidentListPage(),
                    );
                  }
                  return NoTransitionPage(
                    child: IncidentDetailPage(incidentId: id),
                  );
                },
                routes: [
                  GoRoute(
                    path: 'edit',
                    name: 'incidentEdit',
                    pageBuilder: (context, state) {
                      final id =
                          int.tryParse(state.pathParameters['id'] ?? '');
                      return NoTransitionPage(
                        child: IncidentFormPage(incidentId: id),
                      );
                    },
                  ),
                  GoRoute(
                    path: 'osha',
                    name: 'incidentOsha',
                    pageBuilder: (context, state) {
                      final id =
                          int.tryParse(state.pathParameters['id'] ?? '');
                      if (id == null) {
                        return const NoTransitionPage(
                          child: IncidentListPage(),
                        );
                      }
                      return NoTransitionPage(
                        child: OshaDeterminationPage(incidentId: id),
                      );
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
            pageBuilder: (context, state) => const NoTransitionPage(
              child: InvestigationListPage(),
            ),
            routes: [
              GoRoute(
                path: 'new',
                name: 'investigationNew',
                pageBuilder: (context, state) {
                  final params = state.uri.queryParameters;
                  final incidentId = int.tryParse(params['incidentId'] ?? '');
                  // TASK-044: pass leadInvestigator query param for pre-fill.
                  final leadInvestigator = params['leadInvestigator'];
                  return NoTransitionPage(
                    child: InvestigationFormPage(
                      incidentId: incidentId,
                      leadInvestigator: leadInvestigator,
                    ),
                  );
                },
              ),
              GoRoute(
                path: ':id',
                name: 'investigationDetail',
                pageBuilder: (context, state) {
                  final id = int.tryParse(state.pathParameters['id'] ?? '');
                  if (id == null) {
                    return const NoTransitionPage(
                      child: InvestigationListPage(),
                    );
                  }
                  return NoTransitionPage(
                    child: InvestigationDetailPage(investigationId: id),
                  );
                },
              ),
            ],
          ),
          // CAPA routes
          GoRoute(
            path: '/capas',
            name: 'capas',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: CAPADashboardPage(),
            ),
            routes: [
              GoRoute(
                path: 'new',
                name: 'capaNew',
                pageBuilder: (context, state) {
                  final params = state.uri.queryParameters;
                  final investigationId = int.tryParse(
                    params['investigationId'] ?? '',
                  );
                  // TASK-044: pass type/category/priority/description for
                  // query-param pre-fill.
                  return NoTransitionPage(
                    child: CAPAFormPage(
                      investigationId: investigationId,
                      queryParams: params,
                    ),
                  );
                },
              ),
              GoRoute(
                path: ':id',
                name: 'capaDetail',
                pageBuilder: (context, state) {
                  final id = int.tryParse(state.pathParameters['id'] ?? '');
                  if (id == null) {
                    return const NoTransitionPage(
                      child: CAPADashboardPage(),
                    );
                  }
                  return NoTransitionPage(
                    child: CAPADetailPage(capaId: id),
                  );
                },
              ),
            ],
          ),
          // Training routes
          GoRoute(
            path: '/training',
            name: 'training',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: TrainingListPage(),
            ),
            routes: [
              GoRoute(
                path: ':id',
                name: 'trainingDetail',
                pageBuilder: (context, state) {
                  final id = int.tryParse(state.pathParameters['id'] ?? '');
                  if (id == null) {
                    return const NoTransitionPage(
                      child: TrainingListPage(),
                    );
                  }
                  return NoTransitionPage(
                    child: TrainingDetailPage(trainingId: id),
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: '/admin',
            name: 'admin',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AdminSettingsPage(),
            ),
            routes: [
              GoRoute(
                path: 'factor-types',
                name: 'factorTypes',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: FactorTypesPage(),
                ),
              ),
              GoRoute(
                path: 'osha-export',
                name: 'oshaExport',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: OshaExportPage(),
                ),
              ),
              GoRoute(
                path: 'api-keys',
                name: 'apiKeys',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: ApiKeysPage(),
                ),
              ),
              GoRoute(
                path: 'agents',
                name: 'agentSessions',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: AgentSessionsPage(),
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/audit-log',
            name: 'auditLog',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AuditLogPage(),
            ),
          ),
          // Global search route
          GoRoute(
            path: '/search',
            name: 'search',
            pageBuilder: (context, state) {
              final q = state.uri.queryParameters['q'] ?? '';
              return NoTransitionPage(
                child: SearchResultsPage(initialQuery: q),
              );
            },
          ),
          GoRoute(
            path: '/notification-preferences',
            name: 'notificationPreferences',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: NotificationPreferencesPage(),
            ),
          ),
          GoRoute(
            path: '/activity',
            name: 'activity',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ActivityPage(),
            ),
          ),
          GoRoute(
            path: '/help',
            name: 'help',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HelpPage(),
            ),
          ),
        ],
      ),

      // POC routes removed: /, /drift, /connectivity, /ollama
      // Pages still exist in features/poc/ for reference.
    ],
  );
}
