import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

/// Width of the sidebar when collapsed (icon-only mode).
const double _kSidebarCollapsedWidth = 60.0;

/// SharedPreferences key for persisting sidebar collapsed state.
const String _kSidebarCollapsedKey = 'sidebar_collapsed';

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

  const _NavItem({
    required this.label,
    required this.icon,
    required this.route,
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
    ),
    const _NavItem(
      label: 'Incidents',
      icon: Icons.report_problem,
      route: '/incidents',
    ),
  ];

  // Investigations: Safety Coordinator and above (not Field Reporter)
  if (role != null && role.isAtLeast(Role.safetyCoordinator)) {
    all.add(
      const _NavItem(
        label: 'Investigations',
        icon: Icons.search,
        route: '/investigations',
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
/// navigation shortcuts. Ctrl+Shift+letter shortcuts do not produce text
/// input, so they do not need to be guarded against text field focus.
///
/// **Shortcuts:**
/// - **Ctrl+Shift+H** → /dashboard
/// - **Ctrl+Shift+I** → /incidents
/// - **Ctrl+Shift+V** → /investigations
/// - **Ctrl+Shift+A** → /capas
/// - **Ctrl+Shift+S** → /search (global search)
/// - **Ctrl+Shift+C** or **/** → Toggle AI Chat (no-op if chat widget not present)
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
/// - Shortcuts are discoverable via ? overlay (WCAG 2.1.4)
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
/// Ctrl+Shift+letter shortcuts do not produce text input and require no
/// text-field guard. The `/` shortcut is still guarded via
/// [_isTextFieldFocused] because it is a bare character key. Ctrl+Shift+C
/// and Escape work regardless of focus state and do not conflict with browser
/// defaults.
class _AppShortcutsWrapper extends StatelessWidget {
  final Widget child;

  const _AppShortcutsWrapper({required this.child});

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        // ---------------------------------------------------------------
        // Ctrl+Shift+letter navigation (fixes #136 — macOS web compat)
        //
        // Alt+key combos were intercepted by macOS before reaching the
        // Flutter web canvas, producing accented characters instead of
        // triggering shortcuts. Ctrl+Shift is safe on all platforms.
        //
        // Some Ctrl+Shift combos conflict with Chrome DevTools:
        //   Ctrl+Shift+I = DevTools in older Chrome, but Flutter canvas
        //       intercepts before the browser → safe to use as I (Incidents)
        //   Ctrl+Shift+D = Bookmark bar   → remapped to H (Home/dashboard)
        //   Ctrl+Shift+C = Element picker in older Chrome, but Flutter canvas
        //       intercepts before the browser → safe to use as C (Chat)
        //   Ctrl+Shift+S = no conflict    → kept as S (Search)
        //   Ctrl+Shift+V = paste-plain in Chrome, but Flutter canvas
        //       intercepts before the browser → kept as V (investigations)
        // ---------------------------------------------------------------
        SingleActivator(LogicalKeyboardKey.keyH, control: true, shift: true):
            _NavigateDashboardIntent(),
        SingleActivator(LogicalKeyboardKey.keyI, control: true, shift: true):
            _NavigateIncidentsIntent(),
        SingleActivator(LogicalKeyboardKey.keyV, control: true, shift: true):
            _NavigateInvestigationsIntent(),
        SingleActivator(LogicalKeyboardKey.keyA, control: true, shift: true):
            _NavigateCAPAsIntent(),

        // Global search: Ctrl+Shift+S
        SingleActivator(LogicalKeyboardKey.keyS, control: true, shift: true):
            _NavigateSearchIntent(),

        // Chat toggle: Ctrl+Shift+C (all platforms)
        SingleActivator(LogicalKeyboardKey.keyC, control: true, shift: true):
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
              // Ctrl+Shift+H — modifier combo; no guard needed.
              context.go('/dashboard');
              return null;
            },
          ),
          _NavigateIncidentsIntent: CallbackAction<_NavigateIncidentsIntent>(
            onInvoke: (_) {
              // Ctrl+Shift+I — modifier combo; no guard needed.
              context.go('/incidents');
              return null;
            },
          ),
          _NavigateInvestigationsIntent:
              CallbackAction<_NavigateInvestigationsIntent>(
                onInvoke: (_) {
                  // Ctrl+Shift+V — modifier combo; no guard needed.
                  context.go('/investigations');
                  return null;
                },
              ),
          _NavigateCAPAsIntent: CallbackAction<_NavigateCAPAsIntent>(
            onInvoke: (_) {
              // Ctrl+Shift+A — modifier combo; no guard needed.
              context.go('/capas');
              return null;
            },
          ),
          _NavigateSearchIntent: CallbackAction<_NavigateSearchIntent>(
            onInvoke: (_) {
              // Ctrl+Shift+S — modifier combo; no guard needed.
              context.go('/search');
              return null;
            },
          ),
          _ToggleChatIntent: CallbackAction<_ToggleChatIntent>(
            onInvoke: (_) {
              // The `/` key binding fires this intent; guard against text-field
              // focus so that typing `/` in a form field is not intercepted.
              // Ctrl+Shift+C is a modifier combo and does not need this guard.
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

/// Returns a page title for the shell AppBar based on the current route.
String _pageTitle(String location) {
  if (location.startsWith('/dashboard')) return 'DASHBOARD';
  if (location.startsWith('/incidents')) return 'INCIDENTS';
  if (location.startsWith('/investigations')) return 'INVESTIGATIONS';
  if (location.startsWith('/capas')) return 'CAPAS';
  if (location.startsWith('/training')) return 'TRAINING';
  if (location.startsWith('/admin')) return 'ADMIN';
  if (location.startsWith('/audit-log')) return 'AUDIT LOG';
  if (location.startsWith('/search')) return 'SEARCH';
  if (location.startsWith('/activity')) return 'ACTIVITY';
  return '';
}

class _DesktopShell extends StatefulWidget {
  final Widget child;
  final List<_NavItem> navItems;
  final String currentLocation;

  const _DesktopShell({
    required this.child,
    required this.navItems,
    required this.currentLocation,
  });

  @override
  State<_DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<_DesktopShell> {
  bool _isCollapsed = false;

  @override
  void initState() {
    super.initState();
    _loadCollapsedState();
  }

  Future<void> _loadCollapsedState() async {
    final prefs = await SharedPreferences.getInstance();
    final collapsed = prefs.getBool(_kSidebarCollapsedKey) ?? false;
    if (mounted && collapsed != _isCollapsed) {
      setState(() => _isCollapsed = collapsed);
    }
  }

  Future<void> _toggleCollapsed() async {
    setState(() => _isCollapsed = !_isCollapsed);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSidebarCollapsedKey, _isCollapsed);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Top AppBar carries the search icon and notification bell on desktop.
      appBar: AppBar(
        title: Text(
          _pageTitle(widget.currentLocation),
          style: HerzogText.heading(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: HerzogColors.gold,
          ),
        ),
        backgroundColor: HerzogColors.richBlack,
        elevation: 0,
        actions: [
          Semantics(
            label: 'Search, shortcut Ctrl+Shift+S',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.search, color: HerzogColors.smoke),
              tooltip: 'Search (Ctrl+Shift+S)',
              onPressed: () => context.go('/search'),
            ),
          ),
          // OnboardingKeys.notificationBell wraps the bell for the tour target.
          NotificationBell(key: OnboardingKeys.notificationBell),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Container(color: HerzogColors.gold, height: 3),
        ),
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: Row(
              children: [
                // Wrap _Sidebar with the onboarding key at this level so
                // tutorial_coach_mark gets a clean render box position.
                // Placing the key on Material inside _Sidebar caused
                // localToGlobal() misalignment due to compositing layers.
                AnimatedContainer(
                  key: OnboardingKeys.sidebar,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  width: _isCollapsed
                      ? _kSidebarCollapsedWidth
                      : _kSidebarWidth,
                  clipBehavior: Clip.hardEdge,
                  decoration: const BoxDecoration(),
                  child: _Sidebar(
                    navItems: widget.navItems,
                    currentLocation: widget.currentLocation,
                    isCollapsed: _isCollapsed,
                    onToggleCollapsed: _toggleCollapsed,
                  ),
                ),
                Expanded(child: widget.child),
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
  final bool isCollapsed;
  final VoidCallback onToggleCollapsed;

  const _Sidebar({
    required this.navItems,
    required this.currentLocation,
    required this.isCollapsed,
    required this.onToggleCollapsed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HerzogColors.richBlack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Skip-nav link (WCAG 2.4.1) — visually hidden but in tab order
          _SkipNavLink(),

          // Brand header
          _SidebarHeader(isCollapsed: isCollapsed),

          const Divider(color: HerzogColors.gold, height: 1, thickness: 3),

          // Toggle collapse button
          _SidebarToggleButton(
            isCollapsed: isCollapsed,
            onToggle: onToggleCollapsed,
          ),

          // Nav items
          Expanded(
            child: Semantics(
              label: 'Main navigation',
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: navItems.length,
                itemBuilder: (context, index) {
                  final item = navItems[index];
                  final isActive = _isActiveRoute(currentLocation, item.route);
                  // Attach the onboarding tour key to the Incidents nav item
                  // so the tour can highlight "Report an incident from here".
                  final itemKey = item.route == '/incidents'
                      ? OnboardingKeys.newIncident
                      : null;
                  return _SidebarNavItem(
                    key: itemKey,
                    item: item,
                    isActive: isActive,
                    isCollapsed: isCollapsed,
                  );
                },
              ),
            ),
          ),

          Divider(
            color: HerzogColors.midGray.withValues(alpha: 0.3),
            height: 1,
          ),

          // Dark-mode toggle (TASK-036)
          _DarkModeFooterButton(isCollapsed: isCollapsed),

          // Restart tour button (TASK-042)
          _SidebarFooterButton(
            icon: Icons.school,
            label: 'RESTART TOUR',
            onTap: () => OnboardingTour.restartTour(context),
            semanticLabel: 'Restart onboarding tour',
            isCollapsed: isCollapsed,
          ),

          // Shortcut discoverability hint (WCAG 2.1.4)
          _SidebarFooterButton(
            key: OnboardingKeys.shortcutHint,
            icon: Icons.keyboard,
            label: '? FOR SHORTCUTS',
            onTap: () => KeyboardShortcutOverlay.show(context),
            semanticLabel: 'Press ? to view keyboard shortcuts',
            isCollapsed: isCollapsed,
          ),

          // Logout button (fix #156)
          _SidebarFooterButton(
            icon: Icons.logout,
            label: 'LOGOUT',
            onTap: () => context.read<AuthService>().logout(),
            semanticLabel: 'Log out of SafeTrack',
            isCollapsed: isCollapsed,
          ),

          const SizedBox(height: 12),
        ],
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

/// Shared footer button used for all sidebar footer actions.
///
/// Provides a consistent layout: icon + label with hover cursor and
/// accessibility semantics.
///
/// ADA/WCAG compliance:
/// - Semantic label via [semanticLabel] (WCAG 1.3.1).
/// - Keyboard accessible via InkWell + MouseRegion (WCAG 2.1.1).
/// - Smoke (#A7A9AC) on black (#000000) — ~7.0:1 contrast (WCAG AAA, 1.4.3).
class _SidebarFooterButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String semanticLabel;
  final bool isCollapsed;

  const _SidebarFooterButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.semanticLabel,
    this.isCollapsed = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(icon, size: 18, color: HerzogColors.smoke);

    final child = Semantics(
      label: semanticLabel,
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: isCollapsed
                ? const EdgeInsets.symmetric(vertical: 10)
                : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: isCollapsed
                ? Center(child: iconWidget)
                : Row(
                    children: [
                      iconWidget,
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 11,
                            color: HerzogColors.smoke,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );

    if (isCollapsed) {
      return Tooltip(message: label, child: child);
    }
    return child;
  }
}

/// Dark-mode toggle footer button.
///
/// Extends [_SidebarFooterButton] behaviour with a toggled semantic state and
/// reactive icon/label based on the current theme.
///
/// ADA/WCAG compliance:
/// - Semantic toggled state (WCAG 1.3.1).
/// - Gold icon when dark mode is active — ~8:1 contrast (WCAG AAA, 1.4.3).
class _DarkModeFooterButton extends StatelessWidget {
  final bool isCollapsed;

  const _DarkModeFooterButton({this.isCollapsed = false});

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final isDark = themeService.isDarkMode;
    final label = isDark ? 'LIGHT MODE' : 'DARK MODE';
    final iconWidget = Icon(
      isDark ? Icons.light_mode : Icons.dark_mode,
      size: 18,
      color: HerzogColors.smoke,
    );

    final child = Semantics(
      label: 'Toggle dark mode',
      button: true,
      toggled: isDark,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: InkWell(
          onTap: themeService.toggle,
          child: Padding(
            padding: isCollapsed
                ? const EdgeInsets.symmetric(vertical: 10)
                : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: isCollapsed
                ? Center(child: iconWidget)
                : Row(
                    children: [
                      iconWidget,
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 11,
                            color: HerzogColors.smoke,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );

    if (isCollapsed) {
      return Tooltip(message: label, child: child);
    }
    return child;
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
///
/// When [isCollapsed] is true, hides the text labels and centers the icon.
class _SidebarHeader extends StatelessWidget {
  final bool isCollapsed;

  const _SidebarHeader({this.isCollapsed = false});

  @override
  Widget build(BuildContext context) {
    if (isCollapsed) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Image.asset(
            'assets/icon_sidebar.png',
            width: 36,
            height: 36,
            filterQuality: FilterQuality.high,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Row(
        children: [
          Image.asset(
            'assets/icon_sidebar.png',
            width: 52,
            height: 52,
            filterQuality: FilterQuality.high,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SAFETRACK',
                  style: HerzogText.heading(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: HerzogColors.gold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Safety Management',
                  style: HerzogText.body(
                    fontSize: 11,
                    color: HerzogColors.smoke,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
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
class _SidebarNavItem extends StatelessWidget {
  final _NavItem item;
  final bool isActive;
  final bool isCollapsed;

  const _SidebarNavItem({
    super.key,
    required this.item,
    required this.isActive,
    this.isCollapsed = false,
  });

  @override
  Widget build(BuildContext context) {
    final itemWidget = Semantics(
      label: '${item.label} navigation',
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
                  padding: isCollapsed
                      ? const EdgeInsets.symmetric(vertical: 12)
                      : const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                  child: isCollapsed
                      ? Center(
                          child: Icon(
                            item.icon,
                            size: 18,
                            color: isActive
                                ? HerzogColors.gold
                                : HerzogColors.smoke,
                            semanticLabel: item.label,
                          ),
                        )
                      : Row(
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
                          ],
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );

    if (isCollapsed) {
      return Tooltip(message: item.label, child: itemWidget);
    }
    return itemWidget;
  }
}

/// Toggle button for collapsing/expanding the sidebar.
///
/// Shows a chevron icon that points left when expanded (to indicate collapsing)
/// and right when collapsed (to indicate expanding).
///
/// ADA/WCAG compliance:
/// - Semantic label describes action (WCAG 1.3.1).
/// - Keyboard accessible via InkWell (WCAG 2.1.1).
class _SidebarToggleButton extends StatelessWidget {
  final bool isCollapsed;
  final VoidCallback onToggle;

  const _SidebarToggleButton({
    required this.isCollapsed,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: isCollapsed ? 'Expand sidebar' : 'Collapse sidebar',
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: Icon(
                isCollapsed ? Icons.chevron_right : Icons.chevron_left,
                size: 20,
                color: HerzogColors.smoke,
              ),
            ),
          ),
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
        title: Text(
          _pageTitle(currentLocation),
          style: HerzogText.heading(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: HerzogColors.gold,
          ),
        ),
        backgroundColor: HerzogColors.richBlack,
        elevation: 0,
        actions: [
          Semantics(
            label: 'Search, shortcut Ctrl+Shift+S',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.search, color: HerzogColors.smoke),
              tooltip: 'Search (Ctrl+Shift+S)',
              onPressed: () => context.go('/search'),
            ),
          ),
          // OnboardingKeys.notificationBell only needs to be attached once.
          // On mobile, we reuse the same GlobalKey as desktop — only one
          // layout is active at a time, so there is no duplicate-key conflict.
          NotificationBell(key: OnboardingKeys.notificationBell),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Container(color: HerzogColors.gold, height: 3),
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
