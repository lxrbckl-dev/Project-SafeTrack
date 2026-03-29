import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../app/herzog_theme.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/data/role.dart';
import '../data/training_repository.dart';

/// Detail page for a single training requirement with completion form.
///
/// Route: /training/:id
///
/// Shows requirement details and, if pending, a completion form for
/// Safety Coordinator+ users. Completed trainings show the completion record.
class TrainingDetailPage extends StatefulWidget {
  final int trainingId;

  const TrainingDetailPage({super.key, required this.trainingId});

  @override
  State<TrainingDetailPage> createState() => _TrainingDetailPageState();
}

class _TrainingDetailPageState extends State<TrainingDetailPage> {
  late final TrainingRepository _repo;
  late final AuthService _auth;

  TrainingDetail? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthService>();
    _repo = TrainingRepository(_auth);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await _repo.getTraining(widget.trainingId);
      if (mounted) {
        setState(() {
          _detail = detail;
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

  /// Whether the current user can mark training as complete.
  /// Safety Coordinator+ only (not Executive read-only).
  bool get _canComplete {
    final role = _auth.currentRole;
    if (role == null) return false;
    if (role == Role.executive) return false;
    if (!role.isAtLeast(Role.safetyCoordinator)) return false;
    return _detail?.training.status == 'Pending';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _detail != null
              ? 'Training: ${_detail!.training.courseName}'
              : 'TRAINING DETAIL',
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/training'),
          tooltip: 'Back to Training',
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError()
          : _buildContent(),
    );
  }

  Widget _buildError() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
            'Failed to load training requirement',
            style: HerzogText.heading(
              fontSize: 18,
              color: isDark ? Colors.white : HerzogColors.richBlack,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? '',
            style: HerzogText.body(
              color: isDark ? Colors.white : HerzogColors.midGray,
            ),
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

  Widget _buildContent() {
    final training = _detail!.training;
    final completion = _detail!.completion;
    final dateFmt = DateFormat('MM/dd/yyyy');
    final isPending = training.status == 'Pending';
    final isOverdue =
        isPending &&
        training.dueDate != null &&
        training.dueDate!.isBefore(DateTime.now());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status banner
              _buildStatusBanner(training.status, isOverdue),
              const SizedBox(height: 20),

              // Requirement details
              _sectionTitle('TRAINING REQUIREMENT'),
              _detailRow('ID', '#${training.id}'),
              _detailRow('Course Name', training.courseName),
              _detailRow('Description', training.description),
              _detailRow('Status', training.status),
              _detailRow('Assigned To', training.assignedToUserId),
              _detailRow('Assigned By', training.assignedByUserId),
              _detailRow(
                'Due Date',
                training.dueDate != null
                    ? dateFmt.format(training.dueDate!)
                    : '-',
              ),
              _detailRow('Linked CAPA', '#${training.capaId}'),
              const SizedBox(height: 12),

              // Completion record
              if (completion != null) ...[
                _sectionTitle('COMPLETION RECORD'),
                _detailRow(
                  'Completion Date',
                  completion.completionDate != null
                      ? dateFmt.format(completion.completionDate!)
                      : '-',
                ),
                _detailRow('Duration', '${completion.durationHours} hours'),
                _detailRow('Instructor', completion.instructorName),
                _detailRow('Completed By', completion.completedByUserId),
                _detailRow('Notes', completion.notes),
                _detailRow('Evidence', completion.evidence),
                const SizedBox(height: 12),
              ],

              // Complete button
              if (_canComplete) ...[
                const SizedBox(height: 16),
                Semantics(
                  label: 'Mark this training as complete',
                  button: true,
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _onComplete,
                      icon: const Icon(Icons.check_circle, size: 18),
                      label: const Text('Record Training Completion'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HerzogColors.successGreen,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Navigation to linked CAPA
              Semantics(
                label: 'View linked CAPA',
                button: true,
                child: ElevatedButton.icon(
                  onPressed: () => context.go('/capas/${training.capaId}'),
                  icon: const Icon(Icons.assignment_turned_in, size: 16),
                  label: Text('View CAPA #${training.capaId}'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBanner(String status, bool isOverdue) {
    final Color bgColor;
    final Color fgColor;
    final IconData icon;
    final String message;

    if (isOverdue) {
      bgColor = HerzogColors.errorLight;
      fgColor = HerzogColors.errorRed;
      icon = Icons.warning;
      message = 'Training is overdue';
    } else if (status == 'Pending') {
      bgColor = HerzogColors.warningLight;
      fgColor = HerzogColors.warningAmber;
      icon = Icons.schedule;
      message = 'Training is pending completion';
    } else {
      bgColor = HerzogColors.successLight;
      fgColor = HerzogColors.successGreen;
      icon = Icons.check_circle;
      message = 'Training completed';
    }

    return Semantics(
      label: message,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: fgColor),
        ),
        child: Row(
          children: [
            Icon(icon, color: fgColor, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: HerzogText.body(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: fgColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onComplete() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _CompletionDialog(),
    );
    if (result == null || !mounted) return;

    try {
      await _repo.completeTraining(
        widget.trainingId,
        completionDate: result['completionDate'] as String,
        durationHours: result['durationHours'] as double,
        instructorName: result['instructorName'] as String? ?? '',
        notes: result['notes'] as String? ?? '',
        evidence: result['evidence'] as String? ?? '',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Training completed. Linked CAPA has been updated.'),
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ---- Helpers ----

  Widget _sectionTitle(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: HerzogText.heading(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : HerzogColors.richBlack,
            ),
          ),
          const SizedBox(height: 2),
          Container(height: 2, width: 30, color: HerzogColors.gold),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: HerzogText.label(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : HerzogColors.midGray,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: HerzogText.body(
                fontSize: 14,
                color: isDark ? Colors.white : HerzogColors.darkGray,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Completion Dialog
// ---------------------------------------------------------------------------

class _CompletionDialog extends StatefulWidget {
  const _CompletionDialog();

  @override
  State<_CompletionDialog> createState() => _CompletionDialogState();
}

class _CompletionDialogState extends State<_CompletionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _hoursController = TextEditingController();
  final _instructorController = TextEditingController();
  final _notesController = TextEditingController();
  final _evidenceController = TextEditingController();
  DateTime _completionDate = DateTime.now();

  @override
  void dispose() {
    _hoursController.dispose();
    _instructorController.dispose();
    _notesController.dispose();
    _evidenceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('MM/dd/yyyy');

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      title: Text(
        'Record Training Completion',
        style: HerzogText.heading(
          fontSize: 18,
          color: isDark ? Colors.white : HerzogColors.richBlack,
        ),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Enter training completion details.',
                  style: HerzogText.body(
                    fontSize: 13,
                    color: isDark ? Colors.white : HerzogColors.midGray,
                  ),
                ),
                const SizedBox(height: 16),

                // Completion date picker
                Semantics(
                  label: 'Completion date',
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _completionDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() => _completionDate = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Completion Date',
                        suffixIcon: Icon(Icons.calendar_today, size: 18),
                      ),
                      child: Text(dateFmt.format(_completionDate)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Duration hours
                TextFormField(
                  controller: _hoursController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Duration (hours)',
                    hintText: 'e.g., 2.5',
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (double.tryParse(v) == null) return 'Enter a number';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Instructor name
                TextFormField(
                  controller: _instructorController,
                  decoration: const InputDecoration(
                    labelText: 'Instructor Name',
                    hintText: 'Name of the trainer/instructor',
                  ),
                ),
                const SizedBox(height: 12),

                // Notes
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    hintText: 'Describe what was covered...',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),

                // Evidence
                TextFormField(
                  controller: _evidenceController,
                  decoration: const InputDecoration(
                    labelText: 'Evidence',
                    hintText: 'Certificate number, sign-in sheet reference...',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: HerzogText.body(
              color: isDark ? Colors.white : HerzogColors.midGray,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop({
              'completionDate': _completionDate
                  .toIso8601String()
                  .split('T')
                  .first,
              'durationHours':
                  double.tryParse(_hoursController.text.trim()) ?? 0.0,
              'instructorName': _instructorController.text.trim(),
              'notes': _notesController.text.trim(),
              'evidence': _evidenceController.text.trim(),
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: HerzogColors.successGreen,
          ),
          child: const Text('Submit Completion'),
        ),
      ],
    );
  }
}
