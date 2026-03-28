import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/herzog_theme.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/data/role.dart';
import '../../capas/data/capa_repository.dart';
import '../../investigations/data/investigation_repository.dart';

/// Role-specific color for the badge chip.
Color _roleColor(Role role) {
  switch (role) {
    case Role.fieldReporter:
      return HerzogColors.infoTeal;
    case Role.safetyCoordinator:
      return HerzogColors.successGreen;
    case Role.safetyManager:
      return HerzogColors.navyBlue;
    case Role.pm:
      return HerzogColors.chartPurple;
    case Role.divisionManager:
      return HerzogColors.warningAmber;
    case Role.executive:
      return HerzogColors.darkGray;
    case Role.admin:
      return HerzogColors.errorRed;
  }
}

/// "Welcome back, [Name]" header with role badge and role-specific quick action
/// cards.
///
/// Rendered at the top of [SafetyDashboardPage] (for coordinator / manager /
/// PM / executive / admin) and at the top of [IncidentListPage] (for field
/// reporter).
///
/// Each quick-action card is a [_QuickActionCard] — a tappable Material card
/// with an icon, a title, and an optional numeric badge (fetched from the
/// relevant API).
class WelcomeHeader extends StatefulWidget {
  const WelcomeHeader({super.key});

  @override
  State<WelcomeHeader> createState() => _WelcomeHeaderState();
}

class _WelcomeHeaderState extends State<WelcomeHeader> {
  // Counts used by Safety Manager / Safety Coordinator cards.
  int? _pendingInvestigations;
  int? _overdueCapas;
  int? _openInvestigations;
  int? _openCapas;

  bool _loadingCounts = false;

  @override
  void initState() {
    super.initState();
    _fetchCounts();
  }

  Future<void> _fetchCounts() async {
    final auth = context.read<AuthService>();
    final role = auth.currentRole;

    // Only Safety Coordinator and Safety Manager need remote counts.
    if (role != Role.safetyManager && role != Role.safetyCoordinator) return;

    setState(() => _loadingCounts = true);

    try {
      final capaRepo = CAPARepository(auth);
      final invRepo = InvestigationRepository(auth);

      if (role == Role.safetyManager) {
        // Safety Manager: investigations under review + overdue CAPAs.
        final invFuture = invRepo.listInvestigations(status: 'Under Review');
        final capaDashFuture = capaRepo.getDashboard();

        final invResp = await invFuture;
        final capaDash = await capaDashFuture;

        if (mounted) {
          setState(() {
            _pendingInvestigations = invResp.total;
            _overdueCapas = capaDash.overdueCapas;
          });
        }
      } else {
        // Safety Coordinator: all active investigations + open CAPAs.
        final invFuture = invRepo.listInvestigations();
        final capaDashFuture = capaRepo.getDashboard();

        final invResp = await invFuture;
        final capaDash = await capaDashFuture;

        if (mounted) {
          setState(() {
            _openInvestigations = invResp.total;
            _openCapas = capaDash.openCapas;
          });
        }
      }
    } catch (_) {
      // Non-blocking: cards show without counts on error.
    } finally {
      if (mounted) setState(() => _loadingCounts = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final name = auth.displayName ?? 'there';
    final role = auth.currentRole;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        color: HerzogColors.navyBlue,
        boxShadow: [
          BoxShadow(
            color: HerzogColors.richBlack.withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    'Welcome back, $name',
                    style: HerzogText.heading(
                      fontSize: 22,
                      color: HerzogColors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (role != null) ...[
                const SizedBox(width: 12),
                _RoleBadge(role: role),
              ],
            ],
          ),

          // Quick-action cards
          if (role != null) ...[
            const SizedBox(height: 16),
            _buildActionCards(role),
          ],
        ],
      ),
    );
  }

  Widget _buildActionCards(Role role) {
    switch (role) {
      case Role.fieldReporter:
        return _QuickActionCard(
          icon: Icons.add_circle_outline,
          title: 'Report New Incident',
          onTap: () => context.go('/incidents/new'),
          semanticsLabel: 'Navigate to new incident form',
        );

      case Role.safetyManager:
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _QuickActionCard(
              icon: Icons.manage_search,
              title: _loadingCounts
                  ? 'Investigations Pending Review'
                  : '${_pendingInvestigations ?? 0} Investigations Pending Review',
              onTap: () => context.go('/investigations'),
              isLoading: _loadingCounts,
              semanticsLabel:
                  '${_pendingInvestigations ?? 0} investigations pending review',
            ),
            _QuickActionCard(
              icon: Icons.warning_amber_outlined,
              title: _loadingCounts
                  ? 'Overdue CAPAs'
                  : '${_overdueCapas ?? 0} Overdue CAPAs',
              onTap: () => context.go('/capas'),
              isLoading: _loadingCounts,
              semanticsLabel: '${_overdueCapas ?? 0} overdue CAPAs',
              isAlert: (_overdueCapas ?? 0) > 0,
            ),
          ],
        );

      case Role.safetyCoordinator:
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _QuickActionCard(
              icon: Icons.search,
              title: _loadingCounts
                  ? 'Open Investigations'
                  : '${_openInvestigations ?? 0} Open Investigations',
              onTap: () => context.go('/investigations'),
              isLoading: _loadingCounts,
              semanticsLabel: '${_openInvestigations ?? 0} open investigations',
            ),
            _QuickActionCard(
              icon: Icons.task_alt,
              title: _loadingCounts
                  ? 'Open CAPAs'
                  : '${_openCapas ?? 0} Open CAPAs',
              onTap: () => context.go('/capas'),
              isLoading: _loadingCounts,
              semanticsLabel: '${_openCapas ?? 0} open CAPAs',
            ),
          ],
        );

      case Role.admin:
        return _QuickActionCard(
          icon: Icons.settings,
          title: 'System Settings',
          onTap: () => context.go('/admin'),
          semanticsLabel: 'Navigate to system settings',
        );

      case Role.pm:
      case Role.divisionManager:
      case Role.executive:
        return _QuickActionCard(
          icon: Icons.dashboard_outlined,
          title: 'View Dashboard',
          onTap: () => context.go('/dashboard'),
          semanticsLabel: 'View safety dashboard summary',
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

/// Colored chip displaying the user's role name.
class _RoleBadge extends StatelessWidget {
  final Role role;

  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final color = _roleColor(role);

    return Semantics(
      label: 'Role: ${role.displayName}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.6)),
        ),
        child: Text(
          role.displayName.toUpperCase(),
          style: HerzogText.label(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: HerzogColors.white,
          ),
        ),
      ),
    );
  }
}

/// A single quick-action card used in [WelcomeHeader].
///
/// Tapping navigates to the route via [onTap]. [isAlert] tints the card
/// amber when there are overdue items.
class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isLoading;
  final bool isAlert;
  final String semanticsLabel;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.onTap,
    required this.semanticsLabel,
    this.isLoading = false,
    this.isAlert = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isAlert
        ? HerzogColors.warningLight
        : HerzogColors.white.withValues(alpha: 0.12);
    final fgColor = isAlert ? HerzogColors.warningAmber : HerzogColors.white;
    final borderColor = isAlert
        ? HerzogColors.warningAmber.withValues(alpha: 0.4)
        : HerzogColors.white.withValues(alpha: 0.25);

    return Semantics(
      button: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(fgColor),
                  ),
                )
              else
                Icon(icon, size: 18, color: fgColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: HerzogText.body(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: fgColor,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_forward_ios,
                size: 12,
                color: fgColor.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
