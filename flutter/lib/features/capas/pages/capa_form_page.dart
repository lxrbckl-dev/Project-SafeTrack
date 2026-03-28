import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../app/herzog_theme.dart';
import '../../auth/data/auth_service.dart';
import '../../chat/data/form_fill_service.dart';
import '../../investigations/data/investigation_repository.dart';
import '../../training/data/training_repository.dart';
import '../data/capa_repository.dart';

/// Form page for creating a new CAPA from an investigation.
///
/// Route: /capas/new?investigationId=
///
/// Fields: type, category, description, assigned user, priority,
/// verification method. Due dates are auto-calculated based on priority
/// and shown read-only.
class CAPAFormPage extends StatefulWidget {
  final int? investigationId;

  const CAPAFormPage({super.key, this.investigationId});

  @override
  State<CAPAFormPage> createState() => _CAPAFormPageState();
}

class _CAPAFormPageState extends State<CAPAFormPage> {
  late final CAPARepository _capaRepo;
  late final InvestigationRepository _invRepo;
  late final AuthService _auth;
  final _formKey = GlobalKey<FormState>();

  // Form values
  String _type = 'Corrective';
  String _category = 'Training';
  String _priority = 'Medium';
  final _descriptionController = TextEditingController();
  final _assignedToController = TextEditingController();
  final _verificationMethodController = TextEditingController();

  // Investigation data
  Investigation? _investigation;
  bool _loadingInvestigation = false;
  String? _loadError;
  bool _submitting = false;

  static const _types = ['Corrective', 'Preventive'];
  static const _categories = [
    'Training',
    'Procedure Change',
    'Engineering Control',
    'PPE',
    'Equipment Modification',
    'Policy Change',
    'Other',
  ];
  static const _priorities = ['Critical', 'High', 'Medium', 'Low'];

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthService>();
    _capaRepo = CAPARepository(_auth);
    _invRepo = InvestigationRepository(_auth);
    if (widget.investigationId != null) {
      _loadInvestigation();
    }
    // TASK-019: Check for AI-dispatched form fill data and listen for future
    // dispatches (handles the case where the form is already mounted).
    final formFillService = context.read<FormFillService>();
    formFillService.addListener(_applyPendingFields);
    _applyPendingFields();
  }

  /// Applies any pending form fill data from [FormFillService] (AI agent
  /// dispatch). Called on init and reactively whenever the service notifies.
  void _applyPendingFields() {
    final formFillService = context.read<FormFillService>();
    final fields = formFillService.consumePendingFields();
    if (fields == null || fields.isEmpty) return;

    setState(() {
      for (final entry in fields.entries) {
        switch (entry.key) {
          case 'type':
            if (_types.contains(entry.value)) {
              _type = entry.value;
            }
          case 'category':
            if (_categories.contains(entry.value)) {
              _category = entry.value;
            }
          case 'description':
            _descriptionController.text = entry.value;
          case 'assignedTo':
            _assignedToController.text = entry.value;
          case 'priority':
            if (_priorities.contains(entry.value)) {
              _priority = entry.value;
            }
          case 'verificationMethod':
            _verificationMethodController.text = entry.value;
          // Silently skip unknown fields per spec.
        }
      }
    });
  }

  @override
  void dispose() {
    final formFillService = context.read<FormFillService>();
    formFillService.removeListener(_applyPendingFields);
    formFillService.clear();
    _descriptionController.dispose();
    _assignedToController.dispose();
    _verificationMethodController.dispose();
    super.dispose();
  }

  Future<void> _loadInvestigation() async {
    setState(() {
      _loadingInvestigation = true;
      _loadError = null;
    });
    try {
      final inv = await _invRepo.getInvestigation(widget.investigationId!);
      if (mounted) {
        setState(() {
          _investigation = inv;
          _loadingInvestigation = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e.toString();
          _loadingInvestigation = false;
        });
      }
    }
  }

  /// Returns the number of due days for the current priority.
  int get _dueDays {
    switch (_priority) {
      case 'Critical':
        return 7;
      case 'High':
        return 14;
      case 'Medium':
        return 30;
      case 'Low':
        return 60;
      default:
        return 30;
    }
  }

  DateTime get _calculatedDueDate =>
      DateTime.now().add(Duration(days: _dueDays));

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_investigation == null && widget.investigationId != null) return;

    setState(() => _submitting = true);

    try {
      final capa = await _capaRepo.createCAPA(
        investigationId: widget.investigationId ?? 0,
        incidentId: _investigation?.incidentId ?? 0,
        type: _type,
        category: _category,
        description: _descriptionController.text.trim(),
        assignedToUserId: _assignedToController.text.trim(),
        priority: _priority,
        verificationMethod: _verificationMethodController.text.trim(),
      );

      if (mounted) {
        // If Training category, auto-create training requirement and navigate to it.
        if (_category == 'Training' && capa.id != null) {
          try {
            final trainingRepo = TrainingRepository(_auth);
            final training = await trainingRepo.createTraining(
              capaId: capa.id!,
              courseName: _descriptionController.text.trim(),
              assignedToUserId: _assignedToController.text.trim(),
              description: 'Auto-created from Training CAPA #${capa.id}',
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Training CAPA and requirement created successfully',
                  ),
                ),
              );
              context.go('/training/${training.id}');
              return;
            }
          } catch (_) {
            // If training creation fails, fall through to CAPA detail.
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'CAPA created. Training requirement creation failed -- create manually.',
                  ),
                ),
              );
            }
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('CAPA created successfully')),
          );
          context.go('/capas/${capa.id}');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error creating CAPA: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CREATE CAPA'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/capas'),
          tooltip: 'Back to CAPAs',
        ),
      ),
      body: _loadingInvestigation
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? _buildLoadError()
          : _buildForm(),
    );
  }

  Widget _buildLoadError() {
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
            'Failed to load investigation',
            style: HerzogText.heading(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            _loadError ?? '',
            style: HerzogText.body(color: HerzogColors.midGray),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadInvestigation,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    final dateFmt = DateFormat('MM/dd/yyyy');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Investigation reference
                if (_investigation != null) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'LINKED INVESTIGATION',
                            style: HerzogText.label(fontSize: 11),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Investigation #${_investigation!.id} '
                            '(Incident #${_investigation!.incidentId})',
                            style: HerzogText.body(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Lead: ${_investigation!.leadInvestigatorId} | '
                            'Status: ${_investigation!.status}',
                            style: HerzogText.body(
                              fontSize: 12,
                              color: HerzogColors.midGray,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Type
                Text('CAPA Type', style: HerzogText.label(fontSize: 11)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(isDense: true),
                  items: _types
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _type = v);
                  },
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Type is required' : null,
                ),
                const SizedBox(height: 16),

                // Category
                Text('Category', style: HerzogText.label(fontSize: 11)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(isDense: true),
                  items: _categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _category = v);
                  },
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Category is required' : null,
                ),
                const SizedBox(height: 16),

                // Description
                Text('Description', style: HerzogText.label(fontSize: 11)),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    hintText: 'Describe the corrective/preventive action...',
                  ),
                  maxLines: 4,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                // Assigned To
                Text(
                  'Assigned To (User ID)',
                  style: HerzogText.label(fontSize: 11),
                ),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _assignedToController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. dev-safety_coordinator',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                // Priority
                Text('Priority', style: HerzogText.label(fontSize: 11)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: _priority,
                  decoration: const InputDecoration(isDense: true),
                  items: _priorities
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _priority = v);
                  },
                ),
                const SizedBox(height: 16),

                // Due Date (read-only, auto-calculated)
                Text(
                  'Due Date (auto-calculated)',
                  style: HerzogText.label(fontSize: 11),
                ),
                const SizedBox(height: 4),
                TextFormField(
                  readOnly: true,
                  decoration: InputDecoration(
                    hintText: dateFmt.format(_calculatedDueDate),
                    filled: true,
                    fillColor: HerzogColors.lightGray,
                    suffixIcon: const Icon(Icons.calendar_today, size: 16),
                  ),
                  controller: TextEditingController(
                    text:
                        '${dateFmt.format(_calculatedDueDate)} ($_dueDays days from today)',
                  ),
                ),
                const SizedBox(height: 16),

                // Verification Method
                Text(
                  'Verification Method',
                  style: HerzogText.label(fontSize: 11),
                ),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _verificationMethodController,
                  decoration: const InputDecoration(
                    hintText:
                        'How will effectiveness be verified? e.g. audit, inspection...',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),

                // Submit
                SizedBox(
                  width: double.infinity,
                  child: Semantics(
                    label: 'Create CAPA',
                    button: true,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: HerzogColors.white,
                              ),
                            )
                          : const Text('Create CAPA'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
