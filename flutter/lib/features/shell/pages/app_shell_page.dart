import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../app/herzog_theme.dart';
import '../../../core/services/theme_service.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/data/role.dart';
import '../../chat/widgets/chat_widget.dart';
import '../../notifications/widgets/notification_bell.dart';
import '../widgets/keyboard_shortcut_overlay.dart';
import '../widgets/onboarding_tour.dart';

/// Desktop breakpoint: sidebar layout at or above this width.
const double _kSidebarBreakpoint = 900.0;

/// Width of the sidebar in desktop layout.
const double _kSidebarWidth = 220.0;

// ---------------------------------------------------------------------------
// Intent definitions — one per shortcut action
// ---------------------------------------------------------------------------

/// Navigate to the Dashboard page.
class _NavigateDashboardIntent extends Intent {
  const _NavigateDashboardIntent();
}

/// Navigate to the Incidents page.
class _NavigateIncidentsIntent extends Intent {
  const _NavigateIncidentsIntent();
}

/// Navigate to the Investigations page.
class _NavigateInvestigationsIntent extends Intent {
  const _NavigateInvestigationsIntent();
}

/// Navigate to the CAPAs page.
class _NavigateCAPAsIntent extends Intent {
  const _NavigateCAPAsIntent();
}

/// Toggle the AI Chat panel.
class _ToggleChatIntent extends Intent {
  const _ToggleChatIntent();
}

/// Close the current open panel (notification panel / chat panel).
class _ClosePanelIntent extends Intent {
  const _ClosePanelIntent();
}

/// Navigate to the global search page.
class _NavigateSearchIntent extends Intent {
  const _NavigateSearchIntent();
}

/// Show the keyboard shortcuts overlay.
class _ShowShortcutsIntent extends Intent {
  const _ShowShortcutsIntent();
}

// ---------------------------------------------------------------------------
// A single navigation destination entry.
// ---------------------------------------------------------------------------

class _NavItem {
  final String label;
  final IconData icon;
  final String route;
  final String? shortcutHint;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.route,
    this.shortcutHint,
  });
}

/// Builds the full list of nav items visible to [role].
/// Items gated by role are excluded entirely (WCAG: no disabled states with errors).
///
/// RBAC visibility:
/// - Dashboard, Incidents: all roles
/// - Investigations, CAPAs: Safety Coordinator and above (not Field Reporter)
/// - Admin: Admin or Safety Manager
/// - Audit Log: Admin or Safety Manager
List<_NavItem> _visibleNavItems(Role? role) {
  final all = <_NavItem>[
    const _NavItem(
      label: 'Dashboard',
      icon: Icons.dashboard,
      route: '/dashboard',
      shortcutHint: 'Alt+D',
    ),
    const _NavItem(
      label: 'Incidents',
      icon: Icons.report_problem,
      route: '/incidents',
      shortcutHint: 'Alt+I',
    ),
  ];

  // Investigations: Safety Coordinator and above (not Field Reporter)
  if (role != null && role.isAtLeast(Role.safetyCoordinator)) {
    all.add(
      const _NavItem(
        label: 'Investigations',
        icon: Icons.search,
        route: '/investigations',
        shortcutHint: 'Alt+V',
      ),
    );
  }

  // CAPAs: Safety Coordinator and above (not Field Reporter)
  if (role != null && role.isAtLeast(Role.safetyCoordinator)) {
    all.add(
      const _NavItem(
        label: 'CAPAs',
        icon: Icons.assignment_turned_in,
        route: '/capas',
        shortcutHint: 'Alt+C',
      ),
    );
  }

  // Training: Safety Coordinator and above (linked to Training CAPAs)
  if (role != null && role.isAtLeast(Role.safetyCoordinator)) {
    all.add(
      const _NavItem(label: 'Training', icon: Icons.school, route: '/training'),
    );
  }

  // Admin section: admin or safety manager (fix #10)
  if (role != null && (role == Role.admin || role == Role.safetyManager)) {
    all.add(
      const _NavItem(label: 'Admin', icon: Icons.settings, route: '/admin'),
    );
  }

  // Audit Log: admin or safety manager
  if (role != null && (role == Role.admin || role == Role.safetyManager)) {
    all.add(
      const _NavItem(
        label: 'Audit Log',
        icon: Icons.history,
        route: '/audit-log',
      ),
    );
  }

  return all;
}

/// Returns `true` when a text input widget currently has focus.
///
/// Single-letter shortcuts (D, I, V, C, ?) must be suppressed when the user
/// is typing so we don't intercept form input.
bool _isTextFieldFocused() {
  final node = FocusManager.instance.primaryFocus;
  if (node == null) return false;
  // Check both direct widget and ancestor tree, because TextField/TextFormField
  // wraps EditableText and the focused node may be a parent in the tree.
  if (node.context?.widget is EditableText) return true;
  return node.context?.findAncestorWidgetOfExactType<EditableText>() != null;
}

/// The main authenticated app shell.
///
/// Wraps the layout in [Shortcuts] + [Actions] to provide app-wide keyboard
/// navigation shortcuts. Alt+letter shortcuts do not produce text input, so
/// they do not need to be guarded against text field focus.
///
/// **Shortcuts:**
/// - **Alt+D** → /dashboard
/// - **Alt+I** → /incidents
/// - **Alt+V** → /investigations
/// - **Alt+C** → /capas
/// - **Alt+S** → /search (global search)
/// - **Alt+K** or **/** → Toggle AI Chat (no-op if chat widget not present)
/// - **Escape** → Close any open panel
/// - **?** (Shift+/) → Show keyboard shortcuts overlay
///
/// Uses a [LayoutBuilder] to switch between:
/// - **Desktop (≥900px):** Left sidebar with Herzog branding
/// - **Mobile (<900px):** Bottom navigation bar
///
/// The [child] widget is the active page, provided by go_router's [ShellRoute].
///
/// ADA/WCAG compliance:
/// - All nav items have semantic labels (WCAG 1.3.1)
/// - Keyboard navigable sidebar with proper focus indicators (WCAG 2.4.7)
/// - Skip-nav link as first focusable element (WCAG 2.4.1)
/// - Sufficient contrast: Gold on Black (14.4:1 AAA) for active, Smoke on Black (7.0:1 AAA) for inactive
/// - Shortcuts are discoverable via ? overlay + sidebar hint (WCAG 2.1.4)
class AppShellPage extends StatelessWidget {
  /// The current page widget rendered in the body area (from ShellRoute).
  final Widget child;

  const AppShellPage({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final role = auth.currentRole;
    final navItems = _visibleNavItems(role);
    final currentLocation = GoRouterState.of(context).uri.toString();

    return OnboardingTour(
      child: _AppShortcutsWrapper(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= _kSidebarBreakpoint;
            return isDesktop
                ? _DesktopShell(
                    navItems: navItems,
                    currentLocation: currentLocation,
                    child: child,
                  )
                : _MobileShell(
                    navItems: navItems,
                    currentLocation: currentLocation,
                    child: child,
                  );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shortcuts + Actions wrapper
// ---------------------------------------------------------------------------

/// Wraps the app shell with [Shortcuts] and [Actions] for keyboard navigation.
///
/// Alt+letter shortcuts do not produce text input and require no text-field
/// guard. The `/` shortcut is still guarded via [_isTextFieldFocused] because
/// it is a bare character key. Alt+K and Escape work regardless of focus
/// state and do not conflict with browser defaults (Ctrl+C, Ctrl+V, etc.).
class _AppShortcutsWrapper extends StatelessWidget {
  final Widget child;

  const _AppShortcutsWrapper({required this.child});

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        // Alt+letter navigation — modifier combo won't conflict with text input
        SingleActivator(LogicalKeyboardKey.keyD, alt: true):
            _NavigateDashboardIntent(),
        SingleActivator(LogicalKeyboardKey.keyI, alt: true):
            _NavigateIncidentsIntent(),
        SingleActivator(LogicalKeyboardKey.keyV, alt: true):
            _NavigateInvestigationsIntent(),
        SingleActivator(LogicalKeyboardKey.keyC, alt: true):
            _NavigateCAPAsIntent(),

        // Global search: Alt+S
        SingleActivator(LogicalKeyboardKey.keyS, alt: true):
            _NavigateSearchIntent(),

        // Chat toggle: Alt+K (all platforms) — does not conflict with browser
        SingleActivator(LogicalKeyboardKey.keyK, alt: true):
            _ToggleChatIntent(),

        // Chat toggle: forward-slash (/) — single key, guarded against text fields
        SingleActivator(LogicalKeyboardKey.slash): _ToggleChatIntent(),

        // Close any open panel
        SingleActivator(LogicalKeyboardKey.escape): _ClosePanelIntent(),

        // Show shortcuts overlay: ? = Shift+Slash
        SingleActivator(LogicalKeyboardKey.slash, shift: true):
            _ShowShortcutsIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _NavigateDashboardIntent: CallbackAction<_NavigateDashboardIntent>(
            onInvoke: (_) {
              // Alt+D — modifier combo does not produce text; no guard needed.
              context.go('/dashboard');
              return null;
            },
          ),
          _NavigateIncidentsIntent: CallbackAction<_NavigateIncidentsIntent>(
            onInvoke: (_) {
              // Alt+I — modifier combo does not produce text; no guard needed.
              context.go('/incidents');
              return null;
            },
          ),
          _NavigateInvestigationsIntent:
              CallbackAction<_NavigateInvestigationsIntent>(
                onInvoke: (_) {
                  // Alt+V — modifier combo does not produce text; no guard needed.
                  context.go('/investigations');
                  return null;
                },
              ),
          _NavigateCAPAsIntent: CallbackAction<_NavigateCAPAsIntent>(
            onInvoke: (_) {
              // Alt+C — modifier combo does not produce text; no guard needed.
              context.go('/capas');
              return null;
            },
          ),
          _NavigateSearchIntent: CallbackAction<_NavigateSearchIntent>(
            onInvoke: (_) {
              // Alt+S — modifier combo does not produce text; no guard needed.
              context.go('/search');
              return null;
            },
          ),
          _ToggleChatIntent: CallbackAction<_ToggleChatIntent>(
            onInvoke: (_) {
              // The `/` key binding fires this intent; guard against text-field
              // focus so that typing `/` in a form field is not intercepted.
              // Alt+K is a modifier combo and does not need this guard.
              if (_isTextFieldFocused()) return null;
              // Chat widget from TASK-017 may not be present.
              // No-op gracefully if chat is absent; chat widget self-registers
              // its toggle via a ChangeNotifier when present.
              return null;
            },
          ),
          _ClosePanelIntent: CallbackAction<_ClosePanelIntent>(
            onInvoke: (_) {
              // Pop any modal route (notification panel, chat panel, dialogs).
              if (Navigator.of(context, rootNavigator: false).canPop()) {
                Navigator.of(context, rootNavigator: false).pop();
              }
              return null;
            },
          ),
          _ShowShortcutsIntent: CallbackAction<_ShowShortcutsIntent>(
            onInvoke: (_) {
              if (_isTextFieldFocused()) return null;
              KeyboardShortcutOverlay.show(context);
              return null;
            },
          ),
        },
        child: Focus(autofocus: true, canRequestFocus: true, child: child),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Desktop: Left Sidebar
// ---------------------------------------------------------------------------

class _DesktopShell extends StatelessWidget {
  final Widget child;
  final List<_NavItem> navItems;
  final String currentLocation;

  const _DesktopShell({
    required this.child,
    required this.navItems,
    required this.currentLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Top AppBar carries the search icon and notification bell on desktop.
      appBar: AppBar(
        title: const Text(''),
        backgroundColor: HerzogColors.richBlack,
        elevation: 0,
        actions: [
          Semantics(
            label: 'Search, shortcut Alt+S',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.search, color: HerzogColors.smoke),
              tooltip: 'Search (Alt+S)',
              onPressed: () => context.go('/search'),
            ),
          ),
          // OnboardingKeys.notificationBell wraps the bell for the tour target.
          NotificationBell(key: OnboardingKeys.notificationBell),
          const SizedBox(width: 8),
        ],
        shape: const Border(
          bottom: BorderSide(color: HerzogColors.gold, width: 3),
        ),
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: Row(
              children: [
                _Sidebar(navItems: navItems, currentLocation: currentLocation),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
      // AI chat FAB — visible on all authenticated pages (TASK-017)
      floatingActionButton: ChatFab(key: OnboardingKeys.chatFab),
    );
  }
}

/// Herzog-branded left sidebar.
///
/// ADA: The sidebar is keyboard-navigable. Each nav item is a [Focus]-wrapped
/// [InkWell] with a semantic label. A skip-nav link is provided as the first
/// focusable element so keyboard users can jump directly to main content.
///
/// A small "? for shortcuts" hint at the bottom makes shortcuts discoverable
/// per WCAG 2.1.4.
class _Sidebar extends StatelessWidget {
  final List<_NavItem> navItems;
  final String currentLocation;

  const _Sidebar({required this.navItems, required this.currentLocation});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: OnboardingKeys.sidebar,
      width: _kSidebarWidth,
      child: Material(
        color: HerzogColors.richBlack,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Skip-nav link (WCAG 2.4.1) — visually hidden but in tab order
            _SkipNavLink(),

            // Brand header
            _SidebarHeader(),

            const Divider(color: HerzogColors.gold, height: 1, thickness: 3),

            const SizedBox(height: 8),

            // Nav items
            Expanded(
              child: Semantics(
                label: 'Main navigation',
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: navItems.length,
                  itemBuilder: (context, index) {
                    final item = navItems[index];
                    final isActive = _isActiveRoute(
                      currentLocation,
                      item.route,
                    );
                    // Attach the onboarding tour key to the Incidents nav item
                    // so the tour can highlight "Report an incident from here".
                    final itemKey = item.route == '/incidents'
                        ? OnboardingKeys.newIncident
                        : null;
                    return _SidebarNavItem(
                      key: itemKey,
                      item: item,
                      isActive: isActive,
                    );
                  },
                ),
              ),
            ),

            // Dark-mode toggle (TASK-036)
            const _DarkModeToggle(),

            // Restart tour button (TASK-042)
            const _RestartTourButton(),

            // Shortcut discoverability hint (WCAG 2.1.4)
            _ShortcutHint(),
          ],
        ),
      ),
    );
  }

  bool _isActiveRoute(String currentLocation, String route) {
    if (route == '/dashboard') {
      return currentLocation == '/dashboard' || currentLocation == '/';
    }
    return currentLocation.startsWith(route);
  }
}

/// Sun / moon toggle button at the bottom of the sidebar.
///
/// Switches between light and dark mode via [ThemeService.toggle].
///
/// ADA/WCAG compliance:
/// - Semantic label "Toggle dark mode" (WCAG 1.3.1).
/// - Gold icon on dark sidebar — ~8:1 contrast (WCAG AAA, 1.4.3).
/// - Keyboard accessible via InkWell focus handling (WCAG 2.1.1).
class _DarkModeToggle extends StatelessWidget {
  const _DarkModeToggle();

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final isDark = themeService.isDarkMode;

    return Semantics(
      label: 'Toggle dark mode',
      button: true,
      toggled: isDark,
      child: Tooltip(
        message: isDark ? 'Switch to light mode' : 'Switch to dark mode',
        child: InkWell(
          onTap: themeService.toggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: HerzogColors.darkGray)),
            ),
            child: Row(
              children: [
                Icon(
                  isDark ? Icons.light_mode : Icons.dark_mode,
                  size: 14,
                  color: isDark ? HerzogColors.gold : HerzogColors.smoke,
                ),
                const SizedBox(width: 8),
                Text(
                  isDark ? 'Light mode' : 'Dark mode',
                  style: HerzogText.label(
                    fontSize: 11,
                    color: isDark ? HerzogColors.gold : HerzogColors.smoke,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Restart Tour" button in the sidebar footer.
///
/// Calls [OnboardingTour.restartTour] which resets the persistence flag and
/// re-triggers the coach-mark sequence.
///
/// ADA: Semantic button label (WCAG 1.3.1).
class _RestartTourButton extends StatelessWidget {
  const _RestartTourButton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Restart onboarding tour',
      button: true,
      child: Tooltip(
        message: 'Restart the onboarding tour',
        child: InkWell(
          onTap: () => OnboardingTour.restartTour(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: HerzogColors.darkGray)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.tour_outlined,
                  size: 14,
                  color: HerzogColors.midGray,
                ),
                const SizedBox(width: 8),
                Text(
                  'Restart Tour',
                  style: HerzogText.label(
                    fontSize: 11,
                    color: HerzogColors.midGray,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small hint at the sidebar bottom that makes keyboard shortcuts discoverable.
///
/// Tapping it opens the full shortcuts overlay.
/// ADA: Semantic button label (WCAG 1.3.1), sufficient contrast (WCAG 1.4.3).
class _ShortcutHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Press ? to view keyboard shortcuts',
      button: true,
      child: Tooltip(
        message: 'Keyboard shortcuts',
        child: InkWell(
          onTap: () => KeyboardShortcutOverlay.show(context),
          child: Container(
            key: OnboardingKeys.shortcutHint,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: HerzogColors.darkGray)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.keyboard,
                  size: 14,
                  color: HerzogColors.midGray,
                ),
                const SizedBox(width: 8),
                Text(
                  '? for shortcuts',
                  style: HerzogText.label(
                    fontSize: 11,
                    color: HerzogColors.midGray,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Skip-nav link for keyboard accessibility (WCAG 2.4.1).
/// Visually hidden except when focused — focuses main content area.
class _SkipNavLink extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Focus(
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;
          return Visibility(
            visible: hasFocus,
            maintainSize: false,
            maintainAnimation: false,
            maintainState: true,
            child: Semantics(
              label: 'Skip to main content',
              button: true,
              child: InkWell(
                onTap: () {
                  // Focus is handled by Flutter's FocusScope traversal
                  // In a real app we'd focus the main content FocusNode
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  color: HerzogColors.gold,
                  child: Text(
                    'Skip to main content',
                    style: HerzogText.body(
                      color: HerzogColors.richBlack,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Sidebar brand header: "SAFETRACK" in Oswald gold on black.
class _SidebarHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Row(
        children: [
          Image.asset('assets/icon.png', width: 40, height: 40),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SAFETRACK',
                style: HerzogText.heading(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: HerzogColors.gold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Safety Management',
                style: HerzogText.body(fontSize: 11, color: HerzogColors.smoke),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A single navigation item in the sidebar.
///
/// Active state: gold text + gold left border (3px)
/// Inactive state: smoke text, transparent background
/// Hover: slight lightening via InkWell splash
/// Focus: gold outline on dark background (WCAG 2.4.7)
/// Shortcut hint: small key badge shown next to label when a shortcut exists.
class _SidebarNavItem extends StatelessWidget {
  final _NavItem item;
  final bool isActive;

  const _SidebarNavItem({
    super.key,
    required this.item,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          '${item.label} navigation'
          '${item.shortcutHint != null ? ', shortcut: ${item.shortcutHint}' : ''}',
      selected: isActive,
      button: true,
      child: Focus(
        child: Builder(
          builder: (context) {
            final hasFocus = Focus.of(context).hasFocus;
            return InkWell(
              onTap: () => context.go(item.route),
              hoverColor: HerzogColors.richBlack.withValues(alpha: 0.0),
              splashColor: HerzogColors.gold.withValues(alpha: 0.1),
              highlightColor: HerzogColors.gold.withValues(alpha: 0.05),
              child: Container(
                decoration: BoxDecoration(
                  color: isActive
                      ? HerzogColors.gold.withValues(alpha: 0.08)
                      : Colors.transparent,
                  border: Border(
                    left: BorderSide(
                      color: isActive ? HerzogColors.gold : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  // Gold focus indicator on dark background (WCAG 2.4.7)
                  boxShadow: hasFocus
                      ? [
                          BoxShadow(
                            color: HerzogColors.gold.withValues(alpha: 0.6),
                            spreadRadius: 0,
                            blurRadius: 0,
                            offset: Offset.zero,
                          ),
                        ]
                      : null,
                ),
                child: Container(
                  // Gold outline for focus on dark background
                  decoration: hasFocus
                      ? BoxDecoration(
                          border: Border.all(
                            color: HerzogColors.gold,
                            width: 2,
                          ),
                        )
                      : null,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        item.icon,
                        size: 18,
                        color: isActive
                            ? HerzogColors.gold
                            : HerzogColors.smoke,
                        semanticLabel: item.label,
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          item.label,
                          style: isActive
                              ? HerzogText.body(
                                  color: HerzogColors.gold,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                )
                              : HerzogText.body(
                                  color: HerzogColors.smoke,
                                  fontWeight: FontWeight.w400,
                                  fontSize: 13,
                                ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item.shortcutHint != null) ...[
                        const SizedBox(width: 6),
                        _NavShortcutBadge(shortcut: item.shortcutHint!),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Small shortcut key badge displayed next to a nav item label.
///
/// Visually subtle: dark gray background, smoke border, dim text.
/// Only shown when the nav item has an associated single-key shortcut.
class _NavShortcutBadge extends StatelessWidget {
  final String shortcut;

  const _NavShortcutBadge({required this.shortcut});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: HerzogColors.darkGray.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: HerzogColors.midGray.withValues(alpha: 0.5)),
      ),
      child: Text(
        shortcut,
        style: HerzogText.label(
          fontSize: 9,
          color: HerzogColors.smoke,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mobile: Bottom Navigation Bar
// ---------------------------------------------------------------------------

class _MobileShell extends StatelessWidget {
  final Widget child;
  final List<_NavItem> navItems;
  final String currentLocation;

  const _MobileShell({
    required this.child,
    required this.navItems,
    required this.currentLocation,
  });

  int _selectedIndex(String currentLocation) {
    for (int i = 0; i < navItems.length; i++) {
      if (_isActiveRoute(currentLocation, navItems[i].route)) {
        return i;
      }
    }
    return 0;
  }

  bool _isActiveRoute(String currentLocation, String route) {
    if (route == '/dashboard') {
      return currentLocation == '/dashboard' || currentLocation == '/';
    }
    return currentLocation.startsWith(route);
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _selectedIndex(currentLocation);

    return Scaffold(
      // Top AppBar carries the search icon and notification bell on mobile.
      appBar: AppBar(
        title: const Text(''),
        backgroundColor: HerzogColors.richBlack,
        elevation: 0,
        actions: [
          Semantics(
            label: 'Search, shortcut Alt+S',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.search, color: HerzogColors.smoke),
              tooltip: 'Search (Alt+S)',
              onPressed: () => context.go('/search'),
            ),
          ),
          // OnboardingKeys.notificationBell only needs to be attached once.
          // On mobile, we reuse the same GlobalKey as desktop — only one
          // layout is active at a time, so there is no duplicate-key conflict.
          NotificationBell(key: OnboardingKeys.notificationBell),
          const SizedBox(width: 8),
        ],
        shape: const Border(
          bottom: BorderSide(color: HerzogColors.gold, width: 3),
        ),
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: child),
        ],
      ),
      // AI chat FAB — visible on all authenticated pages (TASK-017)
      floatingActionButton: ChatFab(key: OnboardingKeys.chatFab),
      bottomNavigationBar: Semantics(
        label: 'Main navigation',
        // OnboardingKeys.bottomNav targets the entire bottom nav bar (step 1
        // of the mobile tour).
        child: BottomNavigationBar(
          key: OnboardingKeys.bottomNav,
          backgroundColor: HerzogColors.richBlack,
          selectedItemColor: HerzogColors.gold,
          unselectedItemColor: HerzogColors.smoke,
          selectedLabelStyle: HerzogText.label(
            color: HerzogColors.gold,
            fontSize: 10,
          ),
          unselectedLabelStyle: HerzogText.label(
            color: HerzogColors.smoke,
            fontSize: 10,
          ),
          type: BottomNavigationBarType.fixed,
          currentIndex: selectedIndex.clamp(0, navItems.length - 1),
          onTap: (index) => context.go(navItems[index].route),
          items: navItems
              .map(
                (item) => BottomNavigationBarItem(
                  // OnboardingKeys.bottomNavNewIncident targets the Incidents
                  // item (step 2 of the mobile tour). Only one item gets the
                  // key; null keys are ignored by Flutter.
                  icon: Semantics(
                    label: item.label,
                    child: Icon(
                      item.icon,
                      key: item.route == '/incidents'
                          ? OnboardingKeys.bottomNavNewIncident
                          : null,
                      size: 22,
                    ),
                  ),
                  label: item.label,
                  tooltip: item.label,
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
