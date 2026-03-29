import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../app/herzog_theme.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/data/role.dart';
import '../data/investigation_repository.dart';

/// Filterable investigation list page with inline column-header filters,
/// status badges, and overdue highlighting.
///
/// Features:
/// - Inline column-header filters (status, investigator, incident ID, overdue)
/// - Due-date column sortable ascending / descending
/// - "Clear filters" action when any filter is active
/// - Overdue investigations highlighted (red/orange by escalation level)
/// - Status badges
/// - Safety Manager can navigate to create new investigation
class InvestigationListPage extends StatefulWidget {
  const InvestigationListPage({super.key});

  @override
  State<InvestigationListPage> createState() => _InvestigationListPageState();
}

class _InvestigationListPageState extends State<InvestigationListPage> {
  late final InvestigationRepository _repo;
  late final AuthService _auth;

  List<Investigation> _investigations = [];
  int _total = 0;
  int _page = 1;
  bool _loading = true;
  String? _error;

  // Filters
  String _statusFilter = '';
  String _investigatorFilter = '';
  String _incidentIdFilter = '';
  bool _overdueOnly = false;
  bool _sortAscending = true;

  // Filter text controllers
  final TextEditingController _investigatorController = TextEditingController();
  final TextEditingController _incidentIdController = TextEditingController();

  /// Returns true when any filter deviates from its default value.
  bool get _hasActiveFilters =>
      _statusFilter.isNotEmpty ||
      _investigatorFilter.isNotEmpty ||
      _incidentIdFilter.isNotEmpty ||
      _overdueOnly;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthService>();
    _repo = InvestigationRepository(_auth);
    _load();
  }

  @override
  void dispose() {
    _investigatorController.dispose();
    _incidentIdController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      int? incidentId;
      if (_incidentIdFilter.isNotEmpty) {
        incidentId = int.tryParse(_incidentIdFilter);
      }

      final result = await _repo.listInvestigations(
        status: _statusFilter.isNotEmpty ? _statusFilter : null,
        investigatorId: _investigatorFilter.isNotEmpty
            ? _investigatorFilter
            : null,
        incidentId: incidentId,
        overdue: _overdueOnly ? true : null,
        page: _page,
      );
      if (mounted) {
        setState(() {
          _investigations = result.data;
          _total = result.total;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _clearFilters() {
    _investigatorController.clear();
    _incidentIdController.clear();
    setState(() {
      _statusFilter = '';
      _investigatorFilter = '';
      _incidentIdFilter = '';
      _overdueOnly = false;
    });
    _page = 1;
    _load();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSafetyManager =
        _auth.currentRole != null &&
        _auth.currentRole != Role.executive &&
        (_auth.currentRole == Role.safetyManager ||
            _auth.currentRole == Role.admin);

    return Column(
      children: [
        // Action row: Clear filters (left) | New Investigation (right)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // Clear filters — only visible when a filter is active
              if (_hasActiveFilters)
                Semantics(
                  label: 'Clear all filters',
                  button: true,
                  child: TextButton.icon(
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.clear_all, size: 16),
                    label: const Text('Clear filters'),
                    style: TextButton.styleFrom(
                      foregroundColor: isDark ? HerzogColors.gold : HerzogColors.navyBlue,
                    ),
                  ),
                ),
              const Spacer(),
              if (isSafetyManager)
                Semantics(
                  label: 'Create new investigation',
                  button: true,
                  child: ElevatedButton.icon(
                    onPressed: () => context.go('/investigations/new'),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('New Investigation'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HerzogColors.gold,
                      foregroundColor: HerzogColors.richBlack,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Table
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? _buildError(isDark)
              : _investigations.isEmpty
              ? _buildEmpty(isDark)
              : _buildTable(isDark),
        ),

        // Pagination
        if (!_loading && _total > 50) _buildPagination(isDark),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Filterable column headers
  // ---------------------------------------------------------------------------

  /// STATUS header — opens a popup menu with status options.
  Widget _buildStatusHeader(bool isDark) {
    final isActive = _statusFilter.isNotEmpty;
    final activeColor = isDark ? HerzogColors.gold : HerzogColors.navyBlue;
    final inactiveColor = isDark ? Colors.white : HerzogColors.midGray;
    return Semantics(
      label: 'Filter by status',
      button: true,
      child: _FilterHeaderButton(
        onTap: (position) async {
          final result = await showMenu<String>(
            context: context,
            position: position,
            items: const [
              PopupMenuItem(value: '', child: Text('All')),
              PopupMenuItem(value: 'Assigned', child: Text('Assigned')),
              PopupMenuItem(value: 'In Progress', child: Text('In Progress')),
              PopupMenuItem(value: 'Under Review', child: Text('Under Review')),
              PopupMenuItem(value: 'Approved', child: Text('Approved')),
              PopupMenuItem(value: 'Returned', child: Text('Returned')),
            ],
          );
          if (result != null) {
            setState(() => _statusFilter = result);
            _page = 1;
            _load();
          }
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'STATUS',
              style: HerzogText.label(
                color: isActive ? activeColor : inactiveColor,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.filter_list,
                size: 14,
                color: activeColor,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// INVESTIGATOR header — opens a text-search dialog.
  Widget _buildInvestigatorHeader(bool isDark) {
    final isActive = _investigatorFilter.isNotEmpty;
    final activeColor = isDark ? HerzogColors.gold : HerzogColors.navyBlue;
    final inactiveColor = isDark ? Colors.white : HerzogColors.midGray;
    return Semantics(
      label: 'Filter by investigator',
      button: true,
      child: GestureDetector(
        onTap: () => _showTextFilterDialog(
          title: 'Filter by Investigator',
          controller: _investigatorController,
          onSubmit: (value) {
            setState(() => _investigatorFilter = value);
            _page = 1;
            _load();
          },
        ),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'INVESTIGATOR',
                style: HerzogText.label(
                  color: isActive ? activeColor : inactiveColor,
                ),
              ),
              if (isActive) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.filter_list,
                  size: 14,
                  color: activeColor,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// INCIDENT header — opens a text-search dialog.
  Widget _buildIncidentIdHeader(bool isDark) {
    final isActive = _incidentIdFilter.isNotEmpty;
    final activeColor = isDark ? HerzogColors.gold : HerzogColors.navyBlue;
    final inactiveColor = isDark ? Colors.white : HerzogColors.midGray;
    return Semantics(
      label: 'Filter by incident ID',
      button: true,
      child: GestureDetector(
        onTap: () => _showTextFilterDialog(
          title: 'Filter by Incident ID',
          controller: _incidentIdController,
          keyboardType: TextInputType.number,
          onSubmit: (value) {
            setState(() => _incidentIdFilter = value);
            _page = 1;
            _load();
          },
        ),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'INCIDENT',
                style: HerzogText.label(
                  color: isActive ? activeColor : inactiveColor,
                ),
              ),
              if (isActive) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.filter_list,
                  size: 14,
                  color: activeColor,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// OVERDUE header — tap toggles the overdue-only filter.
  Widget _buildOverdueHeader(bool isDark) {
    final inactiveColor = isDark ? Colors.white : HerzogColors.midGray;
    return Semantics(
      label: 'Toggle overdue only filter',
      button: true,
      toggled: _overdueOnly,
      child: GestureDetector(
        onTap: () {
          setState(() => _overdueOnly = !_overdueOnly);
          _page = 1;
          _load();
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'OVERDUE',
                style: HerzogText.label(
                  color: _overdueOnly
                      ? HerzogColors.errorRed
                      : inactiveColor,
                ),
              ),
              if (_overdueOnly) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.filter_list,
                  size: 14,
                  color: HerzogColors.errorRed,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// TARGET DATE header — tap toggles sort direction.
  Widget _buildDueDateHeader(bool isDark) {
    final color = isDark ? Colors.white : HerzogColors.midGray;
    return Semantics(
      label: 'Sort by due date',
      button: true,
      child: GestureDetector(
        onTap: () {
          setState(() => _sortAscending = !_sortAscending);
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'TARGET DATE',
                style: HerzogText.label(color: color),
              ),
              const SizedBox(width: 4),
              Icon(
                _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 14,
                color: color,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Text filter dialog
  // ---------------------------------------------------------------------------

  /// Opens a dialog with a [TextField] for filtering. Pressing Enter or the
  /// Apply button invokes [onSubmit]. Escape dismisses without changes.
  Future<void> _showTextFilterDialog({
    required String title,
    required TextEditingController controller,
    required ValueChanged<String> onSubmit,
    TextInputType keyboardType = TextInputType.text,
  }) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return KeyboardListener(
          focusNode: FocusNode(),
          onKeyEvent: (event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.escape) {
              Navigator.of(ctx).pop();
            }
          },
          child: AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              keyboardType: keyboardType,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Type to filter...',
                isDense: true,
              ),
              onSubmitted: (value) => Navigator.of(ctx).pop(value),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  controller.clear();
                  Navigator.of(ctx).pop('');
                },
                child: const Text('Clear'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(controller.text),
                child: const Text('Apply'),
              ),
            ],
          ),
        );
      },
    );
    if (result != null) {
      onSubmit(result);
    }
  }

  // ---------------------------------------------------------------------------
  // Table
  // ---------------------------------------------------------------------------

  Widget _buildTable(bool isDark) {
    // Client-side sort by target date
    final sorted = List<Investigation>.from(_investigations);
    sorted.sort((a, b) {
      final aDate = a.targetCompletionDate;
      final bDate = b.targetCompletionDate;
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return _sortAscending ? aDate.compareTo(bDate) : bDate.compareTo(aDate);
    });

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columns: [
            DataColumn(label: Text('ID', style: HerzogText.label(color: isDark ? Colors.white : HerzogColors.midGray))),
            DataColumn(label: _buildIncidentIdHeader(isDark)),
            DataColumn(label: _buildStatusHeader(isDark)),
            DataColumn(label: _buildInvestigatorHeader(isDark)),
            DataColumn(label: _buildDueDateHeader(isDark)),
            DataColumn(label: _buildOverdueHeader(isDark)),
          ],
          rows: sorted.map((inv) {
            final isOverdue = inv.isOverdue;
            final level = inv.overdueEscalationLevel;

            // Highlight overdue rows
            Color? rowColor;
            if (isOverdue) {
              if (level >= 3) {
                rowColor = HerzogColors.errorRed.withValues(alpha: 0.08);
              } else if (level >= 2) {
                rowColor = HerzogColors.errorRed.withValues(alpha: 0.05);
              } else {
                rowColor = HerzogColors.warningAmber.withValues(alpha: 0.05);
              }
            }

            final targetDate = inv.targetCompletionDate != null
                ? DateFormat('MM/dd/yyyy').format(inv.targetCompletionDate!)
                : 'N/A';

            return DataRow(
              color: rowColor != null
                  ? WidgetStateProperty.all(rowColor)
                  : null,
              cells: [
                DataCell(
                  Semantics(
                    label: 'Investigation ${inv.id}',
                    button: true,
                    child: InkWell(
                      onTap: () => context.go('/investigations/${inv.id}'),
                      child: Text(
                        '#${inv.id}',
                        style: HerzogText.body(
                          fontSize: 14,
                          color: isDark ? HerzogColors.gold : HerzogColors.navyBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                DataCell(
                  InkWell(
                    onTap: () => context.go('/incidents/${inv.incidentId}'),
                    child: Text(
                      '#${inv.incidentId}',
                      style: HerzogText.body(
                        fontSize: 14,
                        color: isDark ? HerzogColors.gold : HerzogColors.navyBlue,
                      ),
                    ),
                  ),
                ),
                DataCell(_statusBadge(inv.status)),
                DataCell(Text(
                  inv.leadInvestigatorId,
                  style: TextStyle(color: isDark ? Colors.white : HerzogColors.richBlack),
                )),
                DataCell(Text(
                  targetDate,
                  style: TextStyle(color: isDark ? Colors.white : HerzogColors.richBlack),
                )),
                DataCell(isOverdue
                    ? _overdueBadge(level)
                    : Text('-', style: TextStyle(color: isDark ? Colors.white : HerzogColors.richBlack))),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Badges
  // ---------------------------------------------------------------------------

  Widget _statusBadge(String status) {
    final color = _statusColor(status);
    return Semantics(
      label: 'Status: $status',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          status.toUpperCase(),
          style: HerzogText.label(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _overdueBadge(int level) {
    final Color color;
    final String text;
    if (level >= 3) {
      color = HerzogColors.errorRed;
      text = 'L3 (14+ days)';
    } else if (level >= 2) {
      color = HerzogColors.errorRed;
      text = 'L2 (7-13 days)';
    } else {
      color = HerzogColors.warningAmber;
      text = 'L1 (1-6 days)';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        style: HerzogText.label(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Error / empty / pagination
  // ---------------------------------------------------------------------------

  Widget _buildError(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: HerzogColors.errorRed,
          ),
          const SizedBox(height: 12),
          Text(
            'Failed to load investigations',
            style: HerzogText.heading(
              fontSize: 18,
              color: isDark ? Colors.white : HerzogColors.richBlack,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? '',
            style: HerzogText.body(color: isDark ? Colors.white : HerzogColors.midGray),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off,
            size: 48,
            color: HerzogColors.smoke.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'No investigations found',
            style: HerzogText.heading(
              fontSize: 18,
              color: isDark ? Colors.white : HerzogColors.richBlack,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Investigations appear here once assigned from incidents.',
            style: HerzogText.body(color: isDark ? Colors.white : HerzogColors.midGray),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination(bool isDark) {
    final totalPages = (_total / 50).ceil();
    return Container(
      color: isDark ? Colors.transparent : HerzogColors.white,
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _page > 1
                ? () {
                    setState(() => _page--);
                    _load();
                  }
                : null,
            tooltip: 'Previous page',
          ),
          Text(
            'Page $_page of $totalPages',
            style: HerzogText.body(
              fontSize: 13,
              color: isDark ? Colors.white : HerzogColors.richBlack,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _page < totalPages
                ? () {
                    setState(() => _page++);
                    _load();
                  }
                : null,
            tooltip: 'Next page',
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Assigned':
        return HerzogColors.infoTeal;
      case 'In Progress':
        return HerzogColors.warningAmber;
      case 'Under Review':
        return HerzogColors.navyBlue;
      case 'Approved':
        return HerzogColors.successGreen;
      case 'Returned':
        return HerzogColors.errorRed;
      default:
        return HerzogColors.midGray;
    }
  }
}

// ---------------------------------------------------------------------------
// Helper widget: captures tap position for showMenu positioning
// ---------------------------------------------------------------------------

/// A widget that captures the tap position of its child and passes a
/// [RelativeRect] suitable for [showMenu] to the [onTap] callback.
class _FilterHeaderButton extends StatelessWidget {
  const _FilterHeaderButton({required this.onTap, required this.child});

  final void Function(RelativeRect position) onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        final overlay =
            Overlay.of(context).context.findRenderObject()! as RenderBox;
        final position = RelativeRect.fromRect(
          Rect.fromLTWH(
            details.globalPosition.dx,
            details.globalPosition.dy,
            0,
            0,
          ),
          Offset.zero & overlay.size,
        );
        onTap(position);
      },
      child: MouseRegion(cursor: SystemMouseCursors.click, child: child),
    );
  }
}
