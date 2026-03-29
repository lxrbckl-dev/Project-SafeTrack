import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../app/herzog_theme.dart';
import '../../auth/data/auth_service.dart';
import '../data/audit_log_repository.dart' as repo;
import '../widgets/audit_log_filters.dart';
import '../widgets/audit_log_pagination.dart';
import '../widgets/json_diff_viewer.dart';

/// Full-featured audit log viewer accessible to Admin and Safety Manager.
///
/// Features:
/// - Paginated, filterable data table
/// - Columns: Timestamp, User, Role, Action, Entity Type, Entity ID, Notes
/// - Expandable rows showing Before/After JSON diffs
/// - Filters: entity type dropdown, user text field, date range picker, action type dropdown
/// - Keyboard navigable, responsive at 375px, Herzog branded, WCAG compliant
class AuditLogPage extends StatefulWidget {
  const AuditLogPage({super.key});

  @override
  State<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends State<AuditLogPage> {
  late repo.AuditLogRepository _repo;
  repo.AuditLogFilter _filter = const repo.AuditLogFilter();
  _PageData? _pageData;
  bool _loading = false;
  String? _error;

  /// Tracks which row IDs are expanded to show JSON diffs.
  final Set<int> _expandedRows = {};

  final DateFormat _timestampFormat = DateFormat('MMM d, yyyy HH:mm:ss');

  @override
  void initState() {
    super.initState();
    _repo = repo.AuditLogRepository(context.read<AuthService>());
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _repo.getAuditLogs(_filter);
      if (mounted) {
        setState(() {
          _pageData = _PageData(result);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  void _onFilterChanged(repo.AuditLogFilter newFilter) {
    setState(() {
      _filter = newFilter;
      _expandedRows.clear();
    });
    _loadData();
  }

  void _goToPage(int page) {
    _onFilterChanged(_filter.copyWith(page: page));
  }

  void _toggleExpand(int logId) {
    setState(() {
      if (_expandedRows.contains(logId)) {
        _expandedRows.remove(logId);
      } else {
        _expandedRows.add(logId);
      }
    });
  }

  Color _actionColor(String action) {
    switch (action) {
      case 'create':
        return HerzogColors.successGreen;
      case 'update':
        return HerzogColors.navyBlue;
      case 'status_change':
        return HerzogColors.infoTeal;
      case 'approve':
        return HerzogColors.successGreen;
      case 'reject':
        return HerzogColors.errorRed;
      case 'assign':
        return HerzogColors.warningAmber;
      case 'verify':
        return HerzogColors.chartPurple;
      default:
        return HerzogColors.midGray;
    }
  }

  IconData _actionIcon(String action) {
    switch (action) {
      case 'create':
        return Icons.add_circle_outline;
      case 'update':
        return Icons.edit_outlined;
      case 'status_change':
        return Icons.swap_horiz;
      case 'approve':
        return Icons.check_circle_outline;
      case 'reject':
        return Icons.cancel_outlined;
      case 'assign':
        return Icons.person_add_outlined;
      case 'verify':
        return Icons.verified_outlined;
      default:
        return Icons.article_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Page-specific action buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Tooltip(
                message: 'Refresh audit log',
                child: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loading ? null : _loadData,
                ),
              ),
            ],
          ),
        ),
        // Filters
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: AuditLogFilters(
            filter: _filter,
            onFilterChanged: _onFilterChanged,
          ),
        ),

        // Content
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildContent() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_loading && _pageData == null) {
      return const Center(
        child: CircularProgressIndicator(color: HerzogColors.navyBlue),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: HerzogColors.errorRed),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: HerzogText.body(color: HerzogColors.errorRed),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final data = _pageData;
    if (data == null || data.entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: HerzogColors.smoke),
            const SizedBox(height: 16),
            Text(
              'No audit log entries found',
              style: HerzogText.body(
                color: isDark ? Colors.white : HerzogColors.midGray,
              ),
            ),
            if (_filter != const repo.AuditLogFilter()) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _onFilterChanged(const repo.AuditLogFilter()),
                child: const Text('Clear filters'),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      children: [
        // Loading indicator overlay
        if (_loading)
          const LinearProgressIndicator(
            color: HerzogColors.navyBlue,
            backgroundColor: HerzogColors.lightGray,
          ),

        // Table
        Expanded(child: _buildTable(data)),

        // Pagination
        AuditLogPagination(
          currentPage: data.page,
          totalPages: data.totalPages,
          totalRecords: data.total,
          onPrevious: data.page > 1 ? () => _goToPage(data.page - 1) : null,
          onNext: data.page < data.totalPages
              ? () => _goToPage(data.page + 1)
              : null,
        ),
      ],
    );
  }

  Widget _buildTable(_PageData data) {
    final isNarrow = MediaQuery.of(context).size.width < 700;

    if (isNarrow) {
      return _buildCardList(data);
    }

    return _buildDataTable(data);
  }

  /// Card-based layout for narrow/mobile viewports.
  Widget _buildCardList(_PageData data) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: data.entries.length,
      itemBuilder: (context, index) {
        final entry = data.entries[index];
        final isExpanded = _expandedRows.contains(entry.id);
        final actionColor = _actionColor(entry.action);

        return Semantics(
          label:
              '${entry.actionDisplay} on ${entry.entityType} ${entry.entityId} by ${entry.userId}',
          child: Card(
            child: InkWell(
              onTap: (entry.before.isNotEmpty || entry.after.isNotEmpty)
                  ? () => _toggleExpand(entry.id)
                  : null,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row
                    Row(
                      children: [
                        Icon(
                          _actionIcon(entry.action),
                          size: 18,
                          color: actionColor,
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: actionColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            entry.actionDisplay,
                            style: HerzogText.label(
                              fontSize: 11,
                              color: actionColor,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (entry.before.isNotEmpty || entry.after.isNotEmpty)
                          Icon(
                            isExpanded ? Icons.expand_less : Icons.expand_more,
                            size: 20,
                            color: HerzogColors.midGray,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Details
                    _detailRow(
                      'Time',
                      _timestampFormat.format(entry.timestamp),
                    ),
                    _detailRow('User', entry.userId),
                    if (entry.isAgent) _agentBadge(),
                    _detailRow('Role', entry.roleDisplay),
                    _detailRow(
                      'Entity',
                      '${entry.entityType} #${entry.entityId}',
                    ),
                    if (entry.notes.isNotEmpty)
                      _detailRow('Notes', entry.notes),
                    // Expanded diff
                    if (isExpanded) ...[
                      const Divider(height: 16),
                      JsonDiffViewer(before: entry.before, after: entry.after),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _agentBadge() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Semantics(
        label: 'via agent',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: HerzogColors.chartPurple.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: HerzogColors.chartPurple.withValues(alpha: 0.4),
            ),
          ),
          child: Text(
            'agent',
            style: HerzogText.label(
              fontSize: 10,
              color: HerzogColors.chartPurple,
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(label, style: HerzogText.label(
              fontSize: 10,
              color: isDark ? Colors.white : HerzogColors.richBlack,
            )),
          ),
          Expanded(child: Text(value, style: HerzogText.body(
            fontSize: 13,
            color: isDark ? Colors.white : HerzogColors.richBlack,
          ))),
        ],
      ),
    );
  }

  /// Full DataTable layout for wider viewports.
  Widget _buildDataTable(_PageData data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          for (final entry in data.entries) _buildTableRow(entry),
        ],
      ),
    );
  }

  Widget _buildTableRow(repo.AuditLogEntry entry) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isExpanded = _expandedRows.contains(entry.id);
    final actionColor = _actionColor(entry.action);
    final hasDiff = entry.before.isNotEmpty || entry.after.isNotEmpty;

    return Semantics(
      label:
          '${entry.actionDisplay} on ${entry.entityType} ${entry.entityId} by ${entry.userId}',
      child: Card(
        margin: const EdgeInsets.only(bottom: 4),
        child: Column(
          children: [
            InkWell(
              onTap: hasDiff ? () => _toggleExpand(entry.id) : null,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    // Expand indicator
                    SizedBox(
                      width: 24,
                      child: hasDiff
                          ? Icon(
                              isExpanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              size: 20,
                              color: HerzogColors.midGray,
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(width: 8),
                    // Timestamp
                    SizedBox(
                      width: 150,
                      child: Text(
                        _timestampFormat.format(entry.timestamp),
                        style: HerzogText.body(
                          fontSize: 12,
                          color: isDark ? Colors.white : HerzogColors.richBlack,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // User
                    SizedBox(
                      width: 140,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  entry.userId,
                                  style: HerzogText.body(
                                    fontSize: 12,
                                    color: isDark ? Colors.white : HerzogColors.richBlack,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (entry.isAgent) ...[
                                const SizedBox(width: 4),
                                Semantics(
                                  label: 'via agent',
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: HerzogColors.chartPurple
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: HerzogColors.chartPurple
                                            .withValues(alpha: 0.4),
                                      ),
                                    ),
                                    child: Text(
                                      'agent',
                                      style: HerzogText.label(
                                        fontSize: 9,
                                        color: HerzogColors.chartPurple,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            entry.roleDisplay,
                            style: HerzogText.body(
                              fontSize: 11,
                              color: isDark ? Colors.white : HerzogColors.midGray,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Action badge
                    SizedBox(
                      width: 110,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _actionIcon(entry.action),
                            size: 14,
                            color: actionColor,
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: actionColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              entry.actionDisplay,
                              style: HerzogText.label(
                                fontSize: 10,
                                color: actionColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Entity
                    SizedBox(
                      width: 110,
                      child: Text(
                        '${entry.entityType} #${entry.entityId}',
                        style: HerzogText.body(
                          fontSize: 12,
                          color: isDark ? Colors.white : HerzogColors.richBlack,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Notes
                    Expanded(
                      child: Text(
                        entry.notes.isNotEmpty ? entry.notes : '-',
                        style: HerzogText.body(
                          fontSize: 12,
                          color: entry.notes.isNotEmpty
                              ? (isDark ? Colors.white : HerzogColors.darkGray)
                              : HerzogColors.smoke,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Expanded diff section
            if (isExpanded) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: JsonDiffViewer(before: entry.before, after: entry.after),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Internal wrapper to avoid naming conflict with the page widget.
class _PageData {
  final List<repo.AuditLogEntry> entries;
  final int total;
  final int page;
  final int totalPages;

  _PageData(repo.AuditLogPage pageResult)
    : entries = pageResult.data,
      total = pageResult.total,
      page = pageResult.page,
      totalPages = pageResult.totalPages;
}
