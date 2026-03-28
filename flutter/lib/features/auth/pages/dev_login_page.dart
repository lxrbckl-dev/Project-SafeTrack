import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/herzog_theme.dart';
import '../data/auth_service.dart';
import '../data/role.dart';

/// Dev / demo login screen.
///
/// Presents a grid of role cards.  Tapping a card calls [AuthService.devLogin]
/// and then navigates to /dashboard.  This screen is ONLY shown in dev/demo
/// mode — production auth goes through Firebase (Azure AD).
class DevLoginPage extends StatefulWidget {
  const DevLoginPage({super.key});

  @override
  State<DevLoginPage> createState() => _DevLoginPageState();
}

class _DevLoginPageState extends State<DevLoginPage> {
  Role? _loadingRole;

  Future<void> _login(Role role) async {
    setState(() => _loadingRole = role);

    try {
      await context.read<AuthService>().devLogin(role);
      if (mounted) context.go('/dashboard');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed: $e'),
            backgroundColor: HerzogColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingRole = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = _loadingRole != null;

    return Scaffold(
      backgroundColor: HerzogColors.offWhite,
      appBar: AppBar(
        title: const Text('HIGHLANDER'),
        backgroundColor: HerzogColors.richBlack,
        foregroundColor: HerzogColors.gold,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Page heading — Oswald per Herzog brand
                  Semantics(
                    header: true,
                    child: Text(
                      'SELECT YOUR ROLE',
                      style: HerzogText.heading(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose the role you want to demo. No password required.',
                    style: HerzogText.body(fontSize: 15),
                  ),
                  const SizedBox(height: 32),

                  // Role grid — 3 cols on wide, 2 on medium, 1 on narrow
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final crossAxisCount = width >= 700
                          ? 3
                          : (width >= 420 ? 2 : 1);

                      return GridView.count(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.35,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: Role.values
                            .map(
                              (role) => _RoleCard(
                                role: role,
                                isLoading: _loadingRole == role,
                                isDisabled: isLoading && _loadingRole != role,
                                onTap: isLoading ? null : () => _login(role),
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Role card widget
// ---------------------------------------------------------------------------

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.isLoading,
    required this.isDisabled,
    this.onTap,
  });

  final Role role;
  final bool isLoading;
  final bool isDisabled;
  final VoidCallback? onTap;

  static IconData _iconFor(Role role) {
    switch (role) {
      case Role.fieldReporter:
        return Icons.person_outline;
      case Role.safetyCoordinator:
        return Icons.shield_outlined;
      case Role.safetyManager:
        return Icons.security;
      case Role.pm:
        return Icons.assignment_outlined;
      case Role.divisionManager:
        return Icons.business_outlined;
      case Role.executive:
        return Icons.bar_chart;
      case Role.admin:
        return Icons.admin_panel_settings_outlined;
    }
  }

  static String _descriptionFor(Role role) {
    switch (role) {
      case Role.fieldReporter:
        return 'Submit incident reports from the field';
      case Role.safetyCoordinator:
        return 'Manage investigations, CAPAs, link incidents';
      case Role.safetyManager:
        return 'Approve investigations, assign teams, configure safety';
      case Role.pm:
        return 'View project-scoped incidents and data';
      case Role.divisionManager:
        return 'View division-scoped data and metrics';
      case Role.executive:
        return 'Read-only access across all divisions';
      case Role.admin:
        return 'System configuration, audit logs, full access';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNavy = !isDisabled;
    final cardColor = isDisabled ? HerzogColors.lightGray : HerzogColors.white;
    final textColor = isDisabled ? HerzogColors.smoke : HerzogColors.richBlack;
    final subColor = isDisabled ? HerzogColors.smoke : HerzogColors.darkGray;
    final iconColor = isDisabled ? HerzogColors.smoke : HerzogColors.navyBlue;

    return Semantics(
      label: '${role.displayName}: ${_descriptionFor(role)}',
      button: true,
      enabled: !isDisabled,
      child: Focus(
        child: InkWell(
          onTap: isDisabled ? null : onTap,
          borderRadius: BorderRadius.circular(8),
          focusColor: HerzogColors.navyBlue.withValues(alpha: 0.12),
          hoverColor: HerzogColors.navyBlue.withValues(alpha: 0.06),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isNavy
                    ? HerzogColors.borderGray
                    : HerzogColors.accentGray,
              ),
              // Gold left accent for interactive state
              boxShadow: isNavy
                  ? [
                      const BoxShadow(
                        color: Color(0x0F000000),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_iconFor(role), color: iconColor, size: 24),
                    const Spacer(),
                    if (isLoading)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: HerzogColors.navyBlue,
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  role.displayName.toUpperCase(),
                  style: HerzogText.heading(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _descriptionFor(role),
                  style: HerzogText.body(fontSize: 12, color: subColor),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
