import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../app/herzog_theme.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/data/role.dart';
import '../data/investigation_repository.dart';

/// Filterable investigation list page with status badges and overdue
/// highlighting.
///
/// Features:
/// - Filterable table with status, investigator, incident ID filters
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

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthService>();
    _repo = InvestigationRepository(_auth);
    _load();
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

  @override
  Widget build(BuildContext context) {
    final isSafetyManager =
        _auth.currentRole != null &&
        (_auth.currentRole == Role.safetyManager ||
            _auth.currentRole == Role.admin);

    return Scaffold(
      appBar: AppBar(
        title: const Text('INVESTIGATIONS'),
        actions: [
          if (isSafetyManager)
            Padding(
              padding: const EdgeInsets.only(right: 12),
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
      body: Column(
        children: [
          // Filters bar
          _buildFilters(),
          const Divider(height: 1),

          // Table
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? _buildError()
                : _investigations.isEmpty
                ? _buildEmpty()
                : _buildTable(),
          ),

          // Pagination
          if (!_loading && _total > 50) _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      color: HerzogColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Status filter
          SizedBox(
            width: 180,
            child: Semantics(
              label: 'Filter by status',
              child: DropdownButtonFormField<String>(
                initialValue: _statusFilter.isEmpty ? null : _statusFilter,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: '', child: Text('All')),
                  DropdownMenuItem(value: 'Assigned', child: Text('Assigned')),
                  DropdownMenuItem(
                    value: 'In Progress',
                    child: Text('In Progress'),
                  ),
                  DropdownMenuItem(
                    value: 'Under Review',
                    child: Text('Under Review'),
                  ),
                  DropdownMenuItem(value: 'Approved', child: Text('Approved')),
                  DropdownMenuItem(value: 'Returned', child: Text('Returned')),
                ],
                onChanged: (value) {
                  setState(() => _statusFilter = value ?? '');
                  _page = 1;
                  _load();
                },
              ),
            ),
          ),

          // Investigator filter
          SizedBox(
            width: 180,
            child: Semantics(
              label: 'Filter by investigator ID',
              textField: true,
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Investigator',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                onSubmitted: (value) {
                  setState(() => _investigatorFilter = value);
                  _page = 1;
                  _load();
                },
              ),
            ),
          ),

          // Incident ID filter
          SizedBox(
            width: 140,
            child: Semantics(
              label: 'Filter by incident ID',
              textField: true,
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Incident ID',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                keyboardType: TextInputType.number,
                onSubmitted: (value) {
                  setState(() => _incidentIdFilter = value);
                  _page = 1;
                  _load();
                },
              ),
            ),
          ),

          // Overdue only toggle
          Semantics(
            label: 'Show overdue only',
            toggled: _overdueOnly,
            child: FilterChip(
              label: const Text('Overdue Only'),
              selected: _overdueOnly,
              onSelected: (value) {
                setState(() => _overdueOnly = value);
                _page = 1;
                _load();
              },
              selectedColor: HerzogColors.errorLight,
              checkmarkColor: HerzogColors.errorRed,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
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
            style: HerzogText.heading(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? '',
            style: HerzogText.body(color: HerzogColors.midGray),
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

  Widget _buildEmpty() {
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
            style: HerzogText.heading(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Investigations appear here once assigned from incidents.',
            style: HerzogText.body(color: HerzogColors.midGray),
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columns: const [
            DataColumn(label: Text('ID')),
            DataColumn(label: Text('INCIDENT')),
            DataColumn(label: Text('STATUS')),
            DataColumn(label: Text('INVESTIGATOR')),
            DataColumn(label: Text('TARGET DATE')),
            DataColumn(label: Text('OVERDUE')),
          ],
          rows: _investigations.map((inv) {
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
                          color: HerzogColors.navyBlue,
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
                        color: HerzogColors.navyBlue,
                      ),
                    ),
                  ),
                ),
                DataCell(_statusBadge(inv.status)),
                DataCell(Text(inv.leadInvestigatorId)),
                DataCell(Text(targetDate)),
                DataCell(isOverdue ? _overdueBadge(level) : const Text('-')),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

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

  Widget _buildPagination() {
    final totalPages = (_total / 50).ceil();
    return Container(
      color: HerzogColors.white,
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
            style: HerzogText.body(fontSize: 13),
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
