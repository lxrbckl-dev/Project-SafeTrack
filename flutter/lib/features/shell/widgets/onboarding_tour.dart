import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../../../app/herzog_theme.dart';
import '../../../core/services/onboarding_service.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/data/role.dart';

// ---------------------------------------------------------------------------
// Global keys — one per tour target widget.
// These are declared here and shared via [OnboardingKeys] so that the shell
// widgets that wrap the target elements can attach the correct key.
// ---------------------------------------------------------------------------

/// Singleton container for all GlobalKeys used by the onboarding tour.
///
/// Shell widgets import this class to wrap their target elements with the
/// correct key so TutorialCoachMark can locate them on screen.
///
/// Desktop-only keys ([sidebar], [newIncident], [shortcutHint]) are attached
/// inside `_Sidebar`, which is only rendered at ≥900 px. Mobile-equivalent
/// keys ([bottomNav], [bottomNavNewIncident]) are attached to the
/// corresponding `BottomNavigationBar` widgets in `_MobileShell`. Only one
/// layout is active at a time, so there is never a duplicate-key conflict.
class OnboardingKeys {
  OnboardingKeys._();

  // ── Desktop (sidebar) keys ────────────────────────────────────────────────

  /// Key for the sidebar / nav area (desktop only).
  static final GlobalKey sidebar = GlobalKey(debugLabel: 'onboarding_sidebar');

  /// Key for the "New Incident" / Incidents item in the sidebar (desktop only).
  static final GlobalKey newIncident = GlobalKey(
    debugLabel: 'onboarding_new_incident',
  );

  /// Key for the keyboard-shortcut hint in the sidebar footer (desktop only).
  static final GlobalKey shortcutHint = GlobalKey(
    debugLabel: 'onboarding_shortcuts',
  );

  // ── Mobile (bottom nav) keys ──────────────────────────────────────────────

  /// Key for the bottom navigation bar (mobile only).
  static final GlobalKey bottomNav = GlobalKey(
    debugLabel: 'onboarding_bottom_nav',
  );

  /// Key for the Incidents item inside the bottom navigation bar (mobile only).
  static final GlobalKey bottomNavNewIncident = GlobalKey(
    debugLabel: 'onboarding_bottom_nav_incidents',
  );

  // ── Shared keys (present in both layouts) ─────────────────────────────────

  /// Key for the notification bell in the AppBar.
  static final GlobalKey notificationBell = GlobalKey(
    debugLabel: 'onboarding_bell',
  );

  /// Key for the AI chat FAB.
  static final GlobalKey chatFab = GlobalKey(debugLabel: 'onboarding_chat');

  /// Key for the Help Guide sidebar button (desktop only).
  static final GlobalKey helpGuide = GlobalKey(debugLabel: 'onboarding_help');
}

// ---------------------------------------------------------------------------
// Tour widget
// ---------------------------------------------------------------------------

/// Wraps the authenticated shell and starts the onboarding coach-mark tour
/// on the first render after login.
///
/// The tour is shown once per device (tracked via [OnboardingService]).
/// Users can restart it at any time via [OnboardingTour.restartTour].
///
/// Usage: wrap the `AppShellPage` child argument (or a page that composes
/// the shell) with this widget.
///
/// Role adaptation:
/// - Field Reporter: step 2 (New Incident) is shown with extra emphasis on
///   incident creation.
/// - Safety Manager and above: step 2 is labeled for "review and approve".
///
/// ADA/WCAG compliance:
/// - Each coach-mark panel is built with sufficient contrast (gold on dark).
/// - Skip button is always visible (WCAG 2.1.1).
/// - Semantic labels are set on the overlay background (WCAG 1.3.1).
/// - Tour can be triggered from keyboard via the "Restart Tour" sidebar button.
class OnboardingTour extends StatefulWidget {
  final Widget child;

  const OnboardingTour({super.key, required this.child});

  /// Trigger the tour programmatically — used by the "Restart Tour" button.
  ///
  /// Resets the persistence flag via [OnboardingService] and calls
  /// [_OnboardingTourState.startTour] on the nearest [OnboardingTour] in
  /// the widget tree.
  static Future<void> restartTour(BuildContext context) async {
    final onboardingService = context.read<OnboardingService>();
    final tourState = context.findAncestorStateOfType<_OnboardingTourState>();
    await onboardingService.resetTour();
    tourState?.startTour();
  }

  @override
  State<OnboardingTour> createState() => _OnboardingTourState();
}

class _OnboardingTourState extends State<OnboardingTour> {
  TutorialCoachMark? _tutorial;

  @override
  void initState() {
    super.initState();
    // Defer until layout is fully settled. A single addPostFrameCallback fires
    // after the first frame, but LayoutBuilder → Scaffold → Row → _Sidebar
    // may not have final positions yet. A short delay ensures all layout
    // passes are complete before tutorial_coach_mark reads render box positions.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 600), _checkAndShowTour);
    });
  }

  Future<void> _checkAndShowTour() async {
    if (!mounted) return;
    final onboardingService = context.read<OnboardingService>();
    if (onboardingService.shouldShowTour()) {
      startTour();
    }
  }

  /// Builds the list of [TargetFocus] steps, adapting content to the current
  /// user role and screen layout.
  ///
  /// [isDesktop] should be `true` when the sidebar layout is active (screen
  /// width ≥ 900 px). On mobile, steps targeting sidebar-only widgets are
  /// replaced by their bottom-nav equivalents so that no `GlobalKey` with a
  /// null `currentContext` is ever passed to TutorialCoachMark.
  List<TargetFocus> _buildTargets(Role? role, {required bool isDesktop}) {
    final isFieldReporter = role == Role.fieldReporter;

    // Step 2 wording depends on role.
    final String incidentStepTitle = isFieldReporter
        ? 'Report an Incident'
        : 'Manage Incidents';
    final String incidentStepBody = isFieldReporter
        ? 'Report a new incident from here. Your submission goes straight to your Safety Coordinator.'
        : 'Review, approve, and investigate incidents reported by your team.';

    if (isDesktop) {
      // ── Desktop tour: 5 steps targeting sidebar widgets ───────────────────
      return [
        // -------------------------------------------------------------------
        // Step 1: Sidebar / nav
        // -------------------------------------------------------------------
        TargetFocus(
          identify: 'sidebar',
          keyTarget: OnboardingKeys.sidebar,
          enableOverlayTab: true,
          shape: ShapeLightFocus.RRect,
          radius: 8,
          color: HerzogColors.navyBlue,
          paddingFocus: 4,
          borderSide: const BorderSide(color: HerzogColors.gold, width: 2),
          contents: [
            TargetContent(
              align: ContentAlign.custom,
              customPosition: CustomTargetContentPosition(top: 100, left: 280),
              padding: const EdgeInsets.all(16),
              child: _TourCard(
                step: '1 of 5',
                title: 'Navigation',
                body:
                    'Navigate between Dashboard, Incidents, Investigations, and CAPAs using this sidebar.',
              ),
            ),
          ],
        ),

        // -------------------------------------------------------------------
        // Step 2: New Incident (role-adaptive)
        // -------------------------------------------------------------------
        TargetFocus(
          identify: 'new_incident',
          keyTarget: OnboardingKeys.newIncident,
          enableOverlayTab: true,
          shape: ShapeLightFocus.RRect,
          radius: 8,
          borderSide: const BorderSide(color: HerzogColors.gold, width: 2),
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              padding: const EdgeInsets.all(16),
              child: _TourCard(
                step: '2 of 5',
                title: incidentStepTitle,
                body: incidentStepBody,
              ),
            ),
          ],
        ),

        // -------------------------------------------------------------------
        // Step 3: Notification bell
        // -------------------------------------------------------------------
        TargetFocus(
          identify: 'notification_bell',
          keyTarget: OnboardingKeys.notificationBell,
          enableOverlayTab: true,
          shape: ShapeLightFocus.Circle,
          borderSide: const BorderSide(color: HerzogColors.gold, width: 2),
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              padding: const EdgeInsets.all(16),
              child: _TourCard(
                step: '3 of 5',
                title: 'Escalation Alerts',
                body:
                    'Escalation alerts and notifications appear here. '
                    'Tap the bell to see all recent alerts.',
              ),
            ),
          ],
        ),

        // -------------------------------------------------------------------
        // Step 4: AI chat FAB
        // -------------------------------------------------------------------
        TargetFocus(
          identify: 'chat_fab',
          keyTarget: OnboardingKeys.chatFab,
          enableOverlayTab: true,
          shape: ShapeLightFocus.Circle,
          borderSide: const BorderSide(color: HerzogColors.gold, width: 2),
          contents: [
            TargetContent(
              align: ContentAlign.top,
              padding: const EdgeInsets.all(16),
              child: _TourCard(
                step: '4 of 6',
                title: 'AI Assistant',
                body:
                    'Ask the AI assistant questions about SafeTrack. '
                    'Press Ctrl+Shift+C to open the chat from anywhere.',
              ),
            ),
          ],
        ),

        // -------------------------------------------------------------------
        // Step 5: Help Guide (sidebar footer)
        // -------------------------------------------------------------------
        TargetFocus(
          identify: 'help_guide',
          keyTarget: OnboardingKeys.helpGuide,
          enableOverlayTab: true,
          shape: ShapeLightFocus.RRect,
          radius: 6,
          borderSide: const BorderSide(color: HerzogColors.gold, width: 2),
          contents: [
            TargetContent(
              align: ContentAlign.top,
              padding: const EdgeInsets.all(16),
              child: _TourCard(
                step: '5 of 6',
                title: 'Help Guide',
                body:
                    'Need help? The Help Guide contains the complete user manual for SafeTrack — all pages, features, data flow, and keyboard shortcuts.',
              ),
            ),
          ],
        ),

        // -------------------------------------------------------------------
        // Step 6: Keyboard shortcuts hint (sidebar footer)
        // -------------------------------------------------------------------
        TargetFocus(
          identify: 'shortcut_hint',
          keyTarget: OnboardingKeys.shortcutHint,
          enableOverlayTab: true,
          shape: ShapeLightFocus.RRect,
          radius: 6,
          borderSide: const BorderSide(color: HerzogColors.gold, width: 2),
          contents: [
            TargetContent(
              align: ContentAlign.top,
              padding: const EdgeInsets.all(16),
              child: _TourCard(
                step: '6 of 6',
                title: 'Keyboard Shortcuts',
                body:
                    'Press ? to see all keyboard shortcuts. '
                    'SafeTrack is fully keyboard accessible.',
              ),
            ),
          ],
        ),
      ];
    } else {
      // ── Mobile tour: 4 steps — sidebar-only widgets omitted, bottom nav
      //    equivalents used for navigation and incidents steps. ──────────────
      return [
        // -------------------------------------------------------------------
        // Step 1: Bottom nav bar (replaces sidebar on mobile)
        // -------------------------------------------------------------------
        TargetFocus(
          identify: 'bottom_nav',
          keyTarget: OnboardingKeys.bottomNav,
          enableOverlayTab: true,
          shape: ShapeLightFocus.RRect,
          radius: 8,
          borderSide: const BorderSide(color: HerzogColors.gold, width: 2),
          contents: [
            TargetContent(
              align: ContentAlign.top,
              padding: const EdgeInsets.all(16),
              child: _TourCard(
                step: '1 of 4',
                title: 'Navigation',
                body:
                    'Navigate between Dashboard, Incidents, Investigations, and CAPAs using the bottom bar.',
              ),
            ),
          ],
        ),

        // -------------------------------------------------------------------
        // Step 2: Incidents item in bottom nav (role-adaptive)
        // -------------------------------------------------------------------
        TargetFocus(
          identify: 'bottom_nav_incidents',
          keyTarget: OnboardingKeys.bottomNavNewIncident,
          enableOverlayTab: true,
          shape: ShapeLightFocus.RRect,
          radius: 8,
          borderSide: const BorderSide(color: HerzogColors.gold, width: 2),
          contents: [
            TargetContent(
              align: ContentAlign.top,
              padding: const EdgeInsets.all(16),
              child: _TourCard(
                step: '2 of 4',
                title: incidentStepTitle,
                body: incidentStepBody,
              ),
            ),
          ],
        ),

        // -------------------------------------------------------------------
        // Step 3: Notification bell
        // -------------------------------------------------------------------
        TargetFocus(
          identify: 'notification_bell',
          keyTarget: OnboardingKeys.notificationBell,
          enableOverlayTab: true,
          shape: ShapeLightFocus.Circle,
          borderSide: const BorderSide(color: HerzogColors.gold, width: 2),
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              padding: const EdgeInsets.all(16),
              child: _TourCard(
                step: '3 of 4',
                title: 'Escalation Alerts',
                body:
                    'Escalation alerts and notifications appear here. '
                    'Tap the bell to see all recent alerts.',
              ),
            ),
          ],
        ),

        // -------------------------------------------------------------------
        // Step 4: AI chat FAB
        // -------------------------------------------------------------------
        TargetFocus(
          identify: 'chat_fab',
          keyTarget: OnboardingKeys.chatFab,
          enableOverlayTab: true,
          shape: ShapeLightFocus.Circle,
          borderSide: const BorderSide(color: HerzogColors.gold, width: 2),
          contents: [
            TargetContent(
              align: ContentAlign.top,
              padding: const EdgeInsets.all(16),
              child: _TourCard(
                step: '4 of 4',
                title: 'AI Assistant',
                body:
                    'Ask the AI assistant questions about SafeTrack. '
                    'Press Ctrl+Shift+C to open the chat from anywhere.',
              ),
            ),
          ],
        ),
      ];
    }
  }

  /// Starts the coach-mark tour. Safe to call multiple times — only one
  /// instance is active at a time.
  ///
  /// Reads the current screen width via [MediaQuery] to decide whether to show
  /// the desktop (sidebar) or mobile (bottom-nav) variant of the tour. This
  /// prevents [NotFoundTargetException] when sidebar GlobalKeys are null on
  /// narrow screens.
  void startTour() {
    if (!mounted) return;
    final role = context.read<AuthService>().currentRole;
    final onboardingService = context.read<OnboardingService>();
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    _tutorial?.removeOverlayEntry();

    _tutorial = TutorialCoachMark(
      targets: _buildTargets(role, isDesktop: isDesktop),
      colorShadow: HerzogColors.richBlack,
      opacityShadow: 0.85,
      textSkip: 'Skip Tour',
      alignSkip: Alignment.bottomRight,
      textStyleSkip: const TextStyle(
        color: HerzogColors.gold,
        fontWeight: FontWeight.w700,
        fontSize: 14,
      ),
      backgroundSemanticLabel:
          'Onboarding tour overlay — tap to advance to the next step',
      paddingFocus: 12,
      focusAnimationDuration: const Duration(milliseconds: 400),
      unFocusAnimationDuration: const Duration(milliseconds: 300),
      onFinish: () {
        onboardingService.completeTour();
      },
      onSkip: () {
        onboardingService.completeTour();
        return true;
      },
    );

    // show() defers to postFrame internally, so it is safe to call here.
    _tutorial!.show(context: context);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// ---------------------------------------------------------------------------
// Coach-mark content card
// ---------------------------------------------------------------------------

/// A single coach-mark content card rendered in the tour overlay.
///
/// Styled per Herzog brand: gold heading on dark background, Roboto body text.
/// ADA: sufficient contrast ratio (WCAG 1.4.3), large tap area.
class _TourCard extends StatelessWidget {
  final String step;
  final String title;
  final String body;

  const _TourCard({
    required this.step,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HerzogColors.richBlack,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: HerzogColors.gold, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Step indicator
          Text(
            step,
            style: HerzogText.label(
              fontSize: 10,
              color: HerzogColors.midGray,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          // Title
          Text(
            title,
            style: HerzogText.heading(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: HerzogColors.gold,
            ),
          ),
          const SizedBox(height: 8),
          // Body
          Text(
            body,
            style: HerzogText.body(fontSize: 13, color: HerzogColors.smoke),
          ),
          const SizedBox(height: 12),
          // Advance hint
          Text(
            'Tap anywhere to continue',
            style: HerzogText.label(fontSize: 11, color: HerzogColors.midGray),
          ),
        ],
      ),
    );
  }
}
