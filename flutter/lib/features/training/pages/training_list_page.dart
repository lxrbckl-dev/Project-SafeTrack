import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../app/herzog_theme.dart';
import '../../auth/data/auth_service.dart';
import '../data/training_repository.dart';

/// List page for training requirements with status filter badges.
///
/// Route: /training
///
/// Shows pending and completed training requirements. Supports filtering
/// by status and assigned user. Safety Coordinator+ can access.
class TrainingListPage extends StatefulWidget {
  const TrainingListPage({super.key});

  @override
  State<TrainingListPage> createState() => _TrainingListPageState();
}

class _TrainingListPageState extends State<TrainingListPage> {
  late final TrainingRepository _repo;

  List<TrainingRequirement> _trainings = [];
  bool _loading = true;
  String? _error;
  String _statusFilter = '';
  int _total = 0;

  static const _statusOptions = ['', 'Pending', 'Completed'];

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthService>();
    _repo = TrainingRepository(auth);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _repo.listTraining(
        status: _statusFilter.isNotEmpty ? _statusFilter : null,
      );
      if (mounted) {
        setState(() {
          _trainings = response.data;
          _total = response.total;
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
    return Scaffold(
      appBar: AppBar(
        title: Text('TRAINING REQUIREMENTS', style: HerzogText.heading()),
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: HerzogColors.borderGray)),
      ),
      child: Row(
        children: [
          Text(
            'Filter: ',
            style: HerzogText.label(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          ..._statusOptions.map((status) {
            final label = status.isEmpty ? 'All' : status;
            final isSelected = _statusFilter == status;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Semantics(
                label: 'Filter by $label',
                selected: isSelected,
                child: FilterChip(
                  label: Text(
                    label,
                    style: HerzogText.body(
                      fontSize: 12,
                      color: isSelected
                          ? HerzogColors.white
                          : HerzogColors.darkGray,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: HerzogColors.navyBlue,
                  backgroundColor: HerzogColors.lightGray,
                  checkmarkColor: HerzogColors.white,
                  onSelected: (_) {
                    setState(() => _statusFilter = status);
                    _loadData();
                  },
                ),
              ),
            );
          }),
          const Spacer(),
          Text(
            '$_total total',
            style: HerzogText.body(fontSize: 12, color: HerzogColors.midGray),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
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
              'Failed to load training requirements',
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

    if (_trainings.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.school_outlined,
              size: 48,
              color: HerzogColors.smoke,
            ),
            const SizedBox(height: 12),
            Text(
              'No training requirements found',
              style: HerzogText.heading(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Training requirements are auto-created when a Training-category CAPA is created.',
              style: HerzogText.body(fontSize: 13, color: HerzogColors.midGray),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _trainings.length,
        itemBuilder: (context, index) => _buildTrainingCard(_trainings[index]),
      ),
    );
  }

  Widget _buildTrainingCard(TrainingRequirement training) {
    final dateFmt = DateFormat('MM/dd/yyyy');
    final isPending = training.status == 'Pending';
    final isOverdue =
        isPending &&
        training.dueDate != null &&
        training.dueDate!.isBefore(DateTime.now());

    return Semantics(
      label:
          'Training: ${training.courseName}, Status: ${training.status}, '
          'Due: ${training.dueDate != null ? dateFmt.format(training.dueDate!) : "N/A"}',
      button: true,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isOverdue ? HerzogColors.errorRed : HerzogColors.borderGray,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => context.go('/training/${training.id}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Status icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isPending
                        ? (isOverdue
                              ? HerzogColors.errorLight
                              : HerzogColors.warningLight)
                        : HerzogColors.successLight,
                  ),
                  child: Icon(
                    isPending
                        ? (isOverdue ? Icons.warning : Icons.schedule)
                        : Icons.check_circle,
                    color: isPending
                        ? (isOverdue
                              ? HerzogColors.errorRed
                              : HerzogColors.warningAmber)
                        : HerzogColors.successGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        training.courseName,
                        style: HerzogText.heading(fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'CAPA #${training.capaId} | Assigned to: ${training.assignedToUserId}',
                        style: HerzogText.body(
                          fontSize: 12,
                          color: HerzogColors.midGray,
                        ),
                      ),
                      if (training.dueDate != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Due: ${dateFmt.format(training.dueDate!)}',
                          style: HerzogText.body(
                            fontSize: 12,
                            color: isOverdue
                                ? HerzogColors.errorRed
                                : HerzogColors.midGray,
                            fontWeight: isOverdue
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Status badge
                _statusBadge(training.status, isOverdue),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: HerzogColors.smoke),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String status, bool isOverdue) {
    final Color bgColor;
    final Color fgColor;
    final String label;

    if (isOverdue) {
      bgColor = HerzogColors.errorLight;
      fgColor = HerzogColors.errorRed;
      label = 'OVERDUE';
    } else if (status == 'Pending') {
      bgColor = HerzogColors.warningLight;
      fgColor = HerzogColors.warningAmber;
      label = 'PENDING';
    } else {
      bgColor = HerzogColors.successLight;
      fgColor = HerzogColors.successGreen;
      label = 'COMPLETED';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: HerzogText.label(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fgColor,
        ),
      ),
    );
  }
}
