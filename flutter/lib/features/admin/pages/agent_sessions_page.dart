import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/herzog_theme.dart';
import '../../auth/data/auth_service.dart';
import '../data/agent_session_repository.dart';

/// Live view of active agent sessions and recent agent activity.
///
/// Route: /admin/agents
/// Access: Admin only (router + backend enforce this).
///
/// Sessions auto-refresh every 10 seconds. Color-coded by recency:
///   - Green  — last action within 1 minute
///   - Amber  — last action within 5 minutes (still "active")
///   - Smoke  — inactive (should not appear; backend filters these out)
///
/// ADA/WCAG:
///   - Semantic labels on status indicators (WCAG 1.3.1)
///   - Colour is never the only differentiator — text label also shown (WCAG 1.4.1)
///   - Sufficient contrast on all text / background pairs (WCAG 1.4.3)
class AgentSessionsPage extends StatefulWidget {
  const AgentSessionsPage({super.key});

  @override
  State<AgentSessionsPage> createState() => _AgentSessionsPageState();
}

class _AgentSessionsPageState extends State<AgentSessionsPage> {
  final AgentSessionRepository _repo = AgentSessionRepository();

  List<AgentSession> _sessions = [];
  List<AgentActivityItem> _activity = [];

  bool _loadingSessions = true;
  bool _loadingActivity = true;
  String? _sessionsError;
  String? _activityError;

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadAll();
    // Auto-refresh every 10 seconds (TASK-049 spec).
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _loadAll(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadSessions(), _loadActivity()]);
  }

  Future<void> _loadSessions() async {
    final token = context.read<AuthService>().token;
    if (token == null) return;

    try {
      final sessions = await _repo.getSessions(token);
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _sessionsError = null;
        _loadingSessions = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sessionsError = e.toString();
        _loadingSessions = false;
      });
    }
  }

  Future<void> _loadActivity() async {
    final token = context.read<AuthService>().token;
    if (token == null) return;

    try {
      final activity = await _repo.getActivity(token, limit: 50);
      if (!mounted) return;
      setState(() {
        _activity = activity;
        _activityError = null;
        _loadingActivity = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _activityError = e.toString();
        _loadingActivity = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AGENT SESSIONS'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to Admin',
          onPressed: () => context.go('/admin'),
        ),
        actions: [
          Semantics(
            button: true,
            label: 'Refresh agent sessions',
            child: IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: _loadAll,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildActiveSessionsSection(),
              const SizedBox(height: 32),
              _buildAgentActivitySection(),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Active sessions section
  // ---------------------------------------------------------------------------

  Widget _buildActiveSessionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'ACTIVE AGENT SESSIONS',
              style: HerzogText.heading(fontSize: 15),
            ),
            const SizedBox(width: 12),
            if (!_loadingSessions)
              Semantics(
                label: '${_sessions.length} active agent sessions',
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _sessions.isEmpty
                        ? HerzogColors.smoke
                        : HerzogColors.successGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_sessions.length}',
                    style: const TextStyle(
                      color: HerzogColors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Agents with API activity within the last 5 minutes. '
          'Auto-refreshes every 10 seconds.',
          style: HerzogText.body(),
        ),
        const SizedBox(height: 12),
        if (_loadingSessions)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_sessionsError != null)
          _buildSectionError(_sessionsError!, _loadSessions)
        else if (_sessions.isEmpty)
          _buildEmptySessions()
        else
          ...(_sessions.map((s) => _SessionCard(session: s))),
      ],
    );
  }

  Widget _buildEmptySessions() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border.all(color: HerzogColors.borderGray),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.smart_toy_outlined, color: HerzogColors.smoke, size: 32),
          const SizedBox(width: 12),
          Text(
            'No active agent sessions',
            style: HerzogText.body().copyWith(color: HerzogColors.midGray),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Agent activity section
  // ---------------------------------------------------------------------------

  Widget _buildAgentActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('RECENT AGENT ACTIVITY', style: HerzogText.heading(fontSize: 15)),
        const SizedBox(height: 4),
        Text(
          'All actions performed via agent API keys, including rejections and '
          'rollbacks.',
          style: HerzogText.body(),
        ),
        const SizedBox(height: 12),
        if (_loadingActivity)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_activityError != null)
          _buildSectionError(_activityError!, _loadActivity)
        else if (_activity.isEmpty)
          _buildEmptyActivity()
        else
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: Theme.of(context).brightness == Brightness.dark
                    ? HerzogDarkColors.border
                    : HerzogColors.borderGray,
              ),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _activity.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) => _ActivityRow(item: _activity[i]),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyActivity() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border.all(color: HerzogColors.borderGray),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off, color: HerzogColors.smoke, size: 32),
          const SizedBox(width: 12),
          Text(
            'No agent activity yet',
            style: HerzogText.body().copyWith(color: HerzogColors.midGray),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionError(String error, VoidCallback retry) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 40, color: HerzogColors.errorRed),
          const SizedBox(height: 8),
          Text(error, style: const TextStyle(color: HerzogColors.errorRed)),
          const SizedBox(height: 8),
          FilledButton(onPressed: retry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Session card widget
// ---------------------------------------------------------------------------

class _SessionCard extends StatelessWidget {
  final AgentSession session;

  const _SessionCard({required this.session});

  /// Returns (color, label) based on how recently the agent was active.
  (Color, String) _statusIndicator() {
    if (session.lastUsedAt == null) {
      return (HerzogColors.smoke, 'Unknown');
    }
    final age = DateTime.now().difference(session.lastUsedAt!);
    if (age.inSeconds <= 60) {
      return (HerzogColors.successGreen, 'Active now');
    }
    if (age.inMinutes < 5) {
      return (HerzogColors.warningAmber, 'Active recently');
    }
    return (HerzogColors.smoke, 'Inactive');
  }

  String _formatRelative(DateTime? dt) {
    if (dt == null) return 'never';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusLabel) = _statusIndicator();

    return Semantics(
      label:
          'Agent session: ${session.keyName}, user ${session.userName}, '
          'role ${session.userRole}, $statusLabel',
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Status dot — colour + text label (never colour-only, WCAG 1.4.1)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 10,
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),

              // Robot icon
              Icon(
                Icons.smart_toy_outlined,
                color: HerzogColors.navyBlue,
                size: 28,
              ),
              const SizedBox(width: 12),

              // Session details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.keyName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${session.userName} · ${_formatRole(session.userRole)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Key: ${session.keyPrefix}...',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: HerzogColors.midGray,
                      ),
                    ),
                  ],
                ),
              ),

              // Last action time
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Last action',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: HerzogColors.midGray,
                    ),
                  ),
                  Text(
                    _formatRelative(session.lastUsedAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatRole(String role) {
    switch (role) {
      case 'admin':
        return 'Admin';
      case 'safety_manager':
        return 'Safety Manager';
      case 'safety_coordinator':
        return 'Safety Coordinator';
      case 'pm':
        return 'PM';
      case 'division_manager':
        return 'Division Manager';
      case 'field_reporter':
        return 'Field Reporter';
      default:
        return role;
    }
  }
}

// ---------------------------------------------------------------------------
// Activity row widget
// ---------------------------------------------------------------------------

class _ActivityRow extends StatelessWidget {
  final AgentActivityItem item;

  const _ActivityRow({required this.item});

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Color _actionColor() {
    switch (item.action) {
      case 'reject':
      case 'rollback':
        return HerzogColors.errorRed;
      case 'approve':
      case 'verify':
        return HerzogColors.successGreen;
      case 'create':
        return HerzogColors.navyBlue;
      default:
        return HerzogColors.infoTeal;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Agent action: ${item.message}, ${_formatTime(item.timestamp)}',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Robot icon
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                Icons.smart_toy_outlined,
                size: 18,
                color: HerzogColors.smoke,
              ),
            ),
            const SizedBox(width: 10),

            // Message
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.message,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: _actionColor().withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _actionColor().withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          item.action,
                          style: TextStyle(
                            fontSize: 10,
                            color: _actionColor(),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item.userDisplayName,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: HerzogColors.midGray,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Timestamp
            Text(
              _formatTime(item.timestamp),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: HerzogColors.midGray),
            ),
          ],
        ),
      ),
    );
  }
}
