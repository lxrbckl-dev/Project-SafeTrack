import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../app/herzog_theme.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/data/role.dart';
import '../data/capa_repository.dart';
import '../widgets/capa_lifecycle_stepper.dart';
import '../widgets/ineffective_action_dialog.dart';

/// Detail page for a single CAPA with lifecycle stepper, info display,
/// and workflow action buttons (Complete, Verify).
///
/// CRITICAL: The Verify button is completely hidden from the assignee --
/// not shown with an error, not greyed out, absent from the widget tree.
class CAPADetailPage extends StatefulWidget {
  final int capaId;

  const CAPADetailPage({super.key, required this.capaId});

  @override
  State<CAPADetailPage> createState() => _CAPADetailPageState();
}

class _CAPADetailPageState extends State<CAPADetailPage> {
  late final CAPARepository _repo;
  late final AuthService _auth;

  CAPA? _capa;
  bool _loading = true;
  String? _error;

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
      final capa = await _repo.getCAPA(widget.capaId);
      if (mounted) {
        setState(() {
          _capa = capa;
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

  /// Whether the current user is the assignee of this CAPA.
  bool get _isAssignee => _auth.userId == _capa?.assignedToUserId;

  /// Whether the current user has Safety Coordinator or higher role.
  bool get _isSafetyCoordinatorPlus {
    final role = _auth.currentRole;
    return role != null && role.isAtLeast(Role.safetyCoordinator);
  }

  /// Whether the current user has a read-only role (Executive).
  bool get _isReadOnly => _auth.currentRole == Role.executive;

  /// Complete button visible to assignee only when status is Open or In Progress.
  /// Hidden for Executive (read-only).
  bool get _showComplete {
    if (_isReadOnly) return false;
    final status = _capa?.status ?? '';
    return _isAssignee && (status == 'Open' || status == 'In Progress');
  }

  /// CRITICAL: Verify button HIDDEN from assignee entirely.
  /// Visible to other Safety Coordinator+ users when status is Verification Pending.
  /// Hidden for Executive (read-only).
  bool get _showVerify {
    if (_isReadOnly) return false;
    final status = _capa?.status ?? '';
    if (status != 'Verification Pending') return false;
    if (_isAssignee) return false; // HIDDEN from assignee
    return _isSafetyCoordinatorPlus;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_capa != null ? 'CAPA #${_capa!.id}' : 'CAPA DETAIL'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/capas'),
          tooltip: 'Back to CAPAs',
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
          Text('Failed to load CAPA', style: HerzogText.heading(fontSize: 18)),
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

  Widget _buildContent() {
    final capa = _capa!;
    final dateFmt = DateFormat('MM/dd/yyyy');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Lifecycle stepper
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: CAPALifecycleStepper(status: capa.status),
                ),
              ),
              const SizedBox(height: 20),

              // Overdue warning
              if (capa.isOverdue) _buildOverdueWarning(capa),

              // CAPA Info
              _sectionTitle('CAPA INFORMATION'),
              _detailRow('ID', '#${capa.id}'),
              _detailRow('Type', capa.type),
              _detailRow('Category', capa.category),
              _detailRow('Priority', capa.priority),
              _detailRow('Status', capa.status),
              _detailRow('Description', capa.description),
              const SizedBox(height: 12),

              _sectionTitle('ASSIGNMENT'),
              _detailRow('Assigned To', capa.assignedToUserId),
              _detailRow('Assigned By', capa.assignedByUserId),
              _detailRow('Investigation', '#${capa.investigationId}'),
              _detailRow('Incident', '#${capa.incidentId}'),
              const SizedBox(height: 12),

              _sectionTitle('DATES'),
              _detailRow(
                'Due Date',
                capa.dueDate != null ? dateFmt.format(capa.dueDate!) : '-',
              ),
              if (capa.completionDate != null)
                _detailRow('Completed', dateFmt.format(capa.completionDate!)),
              if (capa.verificationDueDate != null)
                _detailRow(
                  'Verification Due',
                  dateFmt.format(capa.verificationDueDate!),
                ),
              if (capa.verificationDate != null)
                _detailRow('Verified', dateFmt.format(capa.verificationDate!)),
              const SizedBox(height: 12),

              _sectionTitle('VERIFICATION'),
              _detailRow('Verification Method', capa.verificationMethod),
              if (capa.verifiedByUserId.isNotEmpty)
                _detailRow('Verified By', capa.verifiedByUserId),
              if (capa.verificationNotes.isNotEmpty)
                _detailRow('Verification Notes', capa.verificationNotes),
              const SizedBox(height: 12),

              // Completion details
              if (capa.completionNotes.isNotEmpty ||
                  capa.completionEvidence.isNotEmpty) ...[
                _sectionTitle('COMPLETION DETAILS'),
                if (capa.completionNotes.isNotEmpty)
                  _detailRow('Notes', capa.completionNotes),
                if (capa.completionEvidence.isNotEmpty)
                  _detailRow('Evidence', capa.completionEvidence),
                const SizedBox(height: 12),
              ],

              // Action buttons
              _buildActions(),
              const SizedBox(height: 24),

              // Navigation links
              Wrap(
                spacing: 12,
                children: [
                  Semantics(
                    label: 'View linked investigation',
                    button: true,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          context.go('/investigations/${capa.investigationId}'),
                      icon: const Icon(Icons.search, size: 16),
                      label: Text('Investigation #${capa.investigationId}'),
                    ),
                  ),
                  Semantics(
                    label: 'View linked incident',
                    button: true,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          context.go('/incidents/${capa.incidentId}'),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: Text('Incident #${capa.incidentId}'),
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

  Widget _buildOverdueWarning(CAPA capa) {
    final level = capa.overdueEscalationLevel;
    final Color bgColor;
    final Color fgColor;
    final String message;

    if (level >= 3) {
      bgColor = HerzogColors.errorLight;
      fgColor = HerzogColors.errorRed;
      message = 'CRITICAL: CAPA is 14+ days overdue (Escalation Level 3)';
    } else if (level >= 2) {
      bgColor = HerzogColors.errorLight;
      fgColor = HerzogColors.errorRed;
      message = 'CAPA is 7-13 days overdue (Escalation Level 2)';
    } else {
      bgColor = HerzogColors.warningLight;
      fgColor = HerzogColors.warningAmber;
      message = 'CAPA is overdue (Escalation Level 1)';
    }

    return Semantics(
      label: message,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: fgColor),
        ),
        child: Row(
          children: [
            Icon(Icons.warning, size: 20, color: fgColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: HerzogText.body(
                  fontSize: 13,
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

  Widget _buildActions() {
    return Row(
      children: [
        // Complete button -- visible to assignee when Open or In Progress
        if (_showComplete)
          Semantics(
            label: 'Mark this CAPA as complete',
            button: true,
            child: ElevatedButton.icon(
              onPressed: _onComplete,
              icon: const Icon(Icons.check_circle, size: 16),
              label: const Text('Complete CAPA'),
              style: ElevatedButton.styleFrom(
                backgroundColor: HerzogColors.successGreen,
              ),
            ),
          ),

        // CRITICAL: Verify button HIDDEN from assignee entirely.
        // Only shown to other Safety Coordinator+ users when Verification Pending.
        if (_showVerify) ...[
          if (_showComplete) const SizedBox(width: 12),
          Semantics(
            label: 'Verify this CAPA effectiveness',
            button: true,
            child: ElevatedButton.icon(
              onPressed: _onVerify,
              icon: const Icon(Icons.verified, size: 16),
              label: const Text('Verify CAPA'),
              style: ElevatedButton.styleFrom(
                backgroundColor: HerzogColors.navyBlue,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ---- Dialogs & Actions ----

  Future<void> _onComplete() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const _CompletionDialog(),
    );
    if (result == null || !mounted) return;

    try {
      await _repo.completeCAPA(
        widget.capaId,
        notes: result['notes'] ?? '',
        evidence: result['evidence'] ?? '',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CAPA marked as complete')),
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

  Future<void> _onVerify() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _VerifyDialog(),
    );
    if (result == null || !mounted) return;

    try {
      final response = await _repo.verifyCAPA(
        widget.capaId,
        effective: result['effective'] as bool,
        notes: result['notes'] as String? ?? '',
      );

      if (!mounted) return;

      // If ineffective, show the ineffective action dialog
      if (response.nextSteps != null) {
        final action = await IneffectiveActionDialog.show(
          context,
          investigationId: _capa!.investigationId,
          incidentId: _capa!.incidentId,
        );

        if (action == 'new_capa' && mounted) {
          context.go('/capas/new?investigationId=${_capa!.investigationId}');
          return;
        } else if (action == 'reopen_investigation' && mounted) {
          context.go('/investigations/${_capa!.investigationId}');
          return;
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CAPA verified as effective')),
        );
      }

      _loadData();
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
              color: HerzogColors.richBlack,
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
                color: HerzogColors.midGray,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: HerzogText.body(
                fontSize: 14,
                color: HerzogColors.darkGray,
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
  final _notesController = TextEditingController();
  final _evidenceController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    _evidenceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Complete CAPA', style: HerzogText.heading(fontSize: 18)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Provide completion notes and evidence for this CAPA.',
              style: HerzogText.body(fontSize: 13, color: HerzogColors.midGray),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Completion Notes',
                hintText: 'Describe the actions taken...',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _evidenceController,
              decoration: const InputDecoration(
                labelText: 'Evidence',
                hintText: 'Reference documents, photos, training records...',
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: HerzogText.body(color: HerzogColors.midGray),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop({
            'notes': _notesController.text.trim(),
            'evidence': _evidenceController.text.trim(),
          }),
          child: const Text('Complete'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Verify Dialog
// ---------------------------------------------------------------------------

class _VerifyDialog extends StatefulWidget {
  const _VerifyDialog();

  @override
  State<_VerifyDialog> createState() => _VerifyDialogState();
}

class _VerifyDialogState extends State<_VerifyDialog> {
  final _notesController = TextEditingController();
  bool _effective = true;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Verify CAPA Effectiveness',
        style: HerzogText.heading(fontSize: 18),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Was this CAPA effective in addressing the root cause?',
              style: HerzogText.body(fontSize: 13, color: HerzogColors.midGray),
            ),
            const SizedBox(height: 16),
            // Effective toggle
            Row(
              children: [
                Text(
                  'Effective:',
                  style: HerzogText.body(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Text('Yes'),
                  selected: _effective,
                  selectedColor: HerzogColors.successLight,
                  onSelected: (_) => setState(() => _effective = true),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('No'),
                  selected: !_effective,
                  selectedColor: HerzogColors.errorLight,
                  onSelected: (_) => setState(() => _effective = false),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Verification Notes',
                hintText: 'Describe findings and observations...',
              ),
              maxLines: 3,
            ),
            if (!_effective) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: HerzogColors.warningLight,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: HerzogColors.warningAmber,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Marking ineffective will prompt you to create a new '
                        'CAPA or reopen the investigation.',
                        style: HerzogText.body(
                          fontSize: 12,
                          color: HerzogColors.warningAmber,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: HerzogText.body(color: HerzogColors.midGray),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop({
            'effective': _effective,
            'notes': _notesController.text.trim(),
          }),
          style: ElevatedButton.styleFrom(
            backgroundColor: _effective
                ? HerzogColors.successGreen
                : HerzogColors.errorRed,
          ),
          child: Text(_effective ? 'Verify Effective' : 'Verify Ineffective'),
        ),
      ],
    );
  }
}
