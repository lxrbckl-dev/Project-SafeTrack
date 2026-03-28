import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../app/herzog_theme.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/data/role.dart';
import '../data/capa_repository.dart';

/// CAPA Dashboard page with KPI cards and a filterable CAPA table.
///
/// Replaces the CAPAs placeholder. Fetches dashboard metrics from
/// GET /api/capas/dashboard and a list from GET /api/capas.
class CAPADashboardPage extends StatefulWidget {
  const CAPADashboardPage({super.key});

  @override
  State<CAPADashboardPage> createState() => _CAPADashboardPageState();
}

class _CAPADashboardPageState extends State<CAPADashboardPage> {
  late final CAPARepository _repo;
  late final AuthService _auth;

  CAPADashboard? _dashboard;
  CAPAListResponse? _listResponse;
  bool _loading = true;
  String? _error;

  // Filters
  String _statusFilter = '';
  String _priorityFilter = '';
  String _assignedToFilter = '';
  bool _overdueFilter = false;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthService>();
    _repo = CAPARepository(_auth);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _repo.getDashboard(),
        _repo.listCAPAs(
          status: _statusFilter.isNotEmpty ? _statusFilter : null,
          priority: _priorityFilter.isNotEmpty ? _priorityFilter : null,
          assignedTo: _assignedToFilter.isNotEmpty ? _assignedToFilter : null,
          overdue: _overdueFilter ? true : null,
        ),
      ]);
      if (mounted) {
        setState(() {
          _dashboard = results[0] as CAPADashboard;
          _listResponse = results[1] as CAPAListResponse;
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

  bool get _canCreate {
    final role = _auth.currentRole;
    // Executive is read-only — cannot create.
    if (role == Role.executive) return false;
    return role != null && role.isAtLeast(Role.safetyCoordinator);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CAPA MANAGEMENT')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError()
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_dashboard != null) _buildKPICards(),
                    const SizedBox(height: 20),
                    _buildFilters(),
                    const SizedBox(height: 16),
                    if (_listResponse != null) _buildCAPATable(),
                  ],
                ),
              ),
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
            'Failed to load CAPA data',
            style: HerzogText.heading(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? '',
            style: HerzogText.body(color: HerzogColors.midGray),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // ---- KPI Cards ----

  Widget _buildKPICards() {
    final d = _dashboard!;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _kpiCard(
          'Open CAPAs',
          '${d.openCapas}',
          Icons.assignment,
          HerzogColors.navyBlue,
        ),
        _kpiCard(
          'Overdue',
          '${d.overdueCapas}',
          Icons.warning_amber,
          d.overdueCapas > 0
              ? HerzogColors.errorRed
              : HerzogColors.successGreen,
        ),
        _kpiCard(
          'Avg Time to Close',
          '${d.avgTimeToCloseDays.toStringAsFixed(1)} days',
          Icons.schedule,
          HerzogColors.infoTeal,
        ),
        _kpiCard(
          'Effectiveness Rate',
          '${d.effectivenessRate.toStringAsFixed(1)}%',
          Icons.verified,
          d.effectivenessRate >= 80
              ? HerzogColors.successGreen
              : HerzogColors.warningAmber,
        ),
      ],
    );
  }

  Widget _kpiCard(String title, String value, IconData icon, Color color) {
    return SizedBox(
      width: 200,
      child: Semantics(
        label: '$title: $value',
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 20, color: color),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: HerzogText.heading(fontSize: 24, color: color),
                ),
                const SizedBox(height: 4),
                Text(
                  title.toUpperCase(),
                  style: HerzogText.label(
                    fontSize: 10,
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

  // ---- Filters ----

  Widget _buildFilters() {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('FILTERS', style: HerzogText.label(fontSize: 11)),
        _filterDropdown(
          label: 'Status',
          value: _statusFilter,
          items: const [
            '',
            'Open',
            'In Progress',
            'Verification Pending',
            'Verified Effective',
            'Verified Ineffective',
          ],
          onChanged: (v) {
            setState(() => _statusFilter = v ?? '');
            _loadData();
          },
        ),
        _filterDropdown(
          label: 'Priority',
          value: _priorityFilter,
          items: const ['', 'Critical', 'High', 'Medium', 'Low'],
          onChanged: (v) {
            setState(() => _priorityFilter = v ?? '');
            _loadData();
          },
        ),
        SizedBox(
          width: 180,
          child: TextField(
            decoration: InputDecoration(
              labelText: 'Assigned To',
              labelStyle: HerzogText.label(fontSize: 11),
              isDense: true,
              suffixIcon: _assignedToFilter.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        setState(() => _assignedToFilter = '');
                        _loadData();
                      },
                    )
                  : null,
            ),
            style: HerzogText.body(fontSize: 13),
            onSubmitted: (v) {
              setState(() => _assignedToFilter = v.trim());
              _loadData();
            },
          ),
        ),
        FilterChip(
          label: Text(
            'Overdue Only',
            style: HerzogText.body(
              fontSize: 12,
              color: _overdueFilter
                  ? HerzogColors.white
                  : HerzogColors.darkGray,
            ),
          ),
          selected: _overdueFilter,
          selectedColor: HerzogColors.errorRed,
          checkmarkColor: HerzogColors.white,
          onSelected: (v) {
            setState(() => _overdueFilter = v);
            _loadData();
          },
        ),
      ],
    );
  }

  Widget _filterDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return SizedBox(
      width: 180,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: HerzogText.label(fontSize: 11),
          isDense: true,
        ),
        style: HerzogText.body(fontSize: 13),
        items: items
            .map(
              (e) => DropdownMenuItem(
                value: e,
                child: Text(e.isEmpty ? 'All' : e),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  // ---- CAPA Table ----

  Widget _buildCAPATable() {
    final capas = _listResponse!.data;

    if (capas.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Icon(
                Icons.assignment_outlined,
                size: 48,
                color: HerzogColors.smoke,
              ),
              const SizedBox(height: 12),
              Text(
                'No CAPAs found',
                style: HerzogText.heading(
                  fontSize: 16,
                  color: HerzogColors.midGray,
                ),
              ),
              if (_canCreate) ...[
                const SizedBox(height: 12),
                Text(
                  'CAPAs are created from approved investigations.',
                  style: HerzogText.body(
                    fontSize: 13,
                    color: HerzogColors.smoke,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        showCheckboxColumn: false,
        columns: const [
          DataColumn(label: Text('ID')),
          DataColumn(label: Text('TYPE')),
          DataColumn(label: Text('CATEGORY')),
          DataColumn(label: Text('PRIORITY')),
          DataColumn(label: Text('STATUS')),
          DataColumn(label: Text('ASSIGNED TO')),
          DataColumn(label: Text('DUE DATE')),
          DataColumn(label: Text('OVERDUE')),
        ],
        rows: capas.map((capa) => _buildRow(capa)).toList(),
      ),
    );
  }

  DataRow _buildRow(CAPA capa) {
    final isOverdue = capa.isOverdue;
    final rowColor = isOverdue
        ? WidgetStateProperty.all(HerzogColors.errorLight)
        : null;

    return DataRow(
      color: rowColor,
      onSelectChanged: (_) => context.go('/capas/${capa.id}'),
      cells: [
        DataCell(
          Semantics(label: 'CAPA ${capa.id}', child: Text('#${capa.id}')),
        ),
        DataCell(Text(capa.type)),
        DataCell(Text(capa.category)),
        DataCell(_priorityChip(capa.priority)),
        DataCell(_statusChip(capa.status)),
        DataCell(Text(capa.assignedToUserId)),
        DataCell(
          Text(
            capa.dueDate != null
                ? DateFormat('MM/dd/yyyy').format(capa.dueDate!)
                : '-',
          ),
        ),
        DataCell(
          isOverdue
              ? Semantics(
                  label:
                      'Overdue, escalation level ${capa.overdueEscalationLevel}',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.warning,
                        size: 14,
                        color: HerzogColors.errorRed,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Level ${capa.overdueEscalationLevel}',
                        style: HerzogText.body(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: HerzogColors.errorRed,
                        ),
                      ),
                    ],
                  ),
                )
              : const Text('-'),
        ),
      ],
    );
  }

  Widget _priorityChip(String priority) {
    final Color color;
    switch (priority) {
      case 'Critical':
        color = HerzogColors.errorRed;
      case 'High':
        color = HerzogColors.warningAmber;
      case 'Medium':
        color = HerzogColors.infoTeal;
      case 'Low':
        color = HerzogColors.successGreen;
      default:
        color = HerzogColors.midGray;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        priority.toUpperCase(),
        style: HerzogText.label(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    final Color color;
    switch (status) {
      case 'Open':
        color = HerzogColors.infoTeal;
      case 'In Progress':
        color = HerzogColors.warningAmber;
      case 'Completed':
        color = HerzogColors.navyBlue;
      case 'Verification Pending':
        color = HerzogColors.chartPurple;
      case 'Verified Effective':
        color = HerzogColors.successGreen;
      case 'Verified Ineffective':
        color = HerzogColors.errorRed;
      default:
        color = HerzogColors.midGray;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
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
    );
  }
}
