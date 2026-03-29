import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/herzog_theme.dart';
import '../data/investigation_repository.dart';

/// Card widget for managing witness statements with inline editing.
///
/// Features:
/// - Card showing witness info
/// - Fields: name, title, employer, phone, statement text, collection date,
///   collector name
/// - Inline edit / save
/// - Add new witness button
class WitnessStatementCards extends StatefulWidget {
  /// Current witness statements for the investigation.
  final List<WitnessStatement> witnesses;

  /// Whether the form is editable.
  final bool editable;

  /// Called when a new witness statement is created.
  final Future<void> Function(WitnessStatement statement) onAdd;

  /// Called when a witness statement is updated.
  final Future<void> Function(WitnessStatement statement) onUpdate;

  const WitnessStatementCards({
    super.key,
    required this.witnesses,
    required this.editable,
    required this.onAdd,
    required this.onUpdate,
  });

  @override
  State<WitnessStatementCards> createState() => _WitnessStatementCardsState();
}

class _WitnessStatementCardsState extends State<WitnessStatementCards> {
  bool _showAddForm = false;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.witnesses.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 48,
                        color: HerzogColors.smoke.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 12),
                      Builder(builder: (context) {
                        final isDark = Theme.of(context).brightness == Brightness.dark;
                        return Text(
                          'No witness statements yet',
                          style: HerzogText.body(
                            color: isDark ? Colors.white : HerzogColors.midGray,
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),

            // Existing statements
            ...widget.witnesses.map(
              (w) => _WitnessCard(
                witness: w,
                editable: widget.editable,
                onUpdate: widget.onUpdate,
              ),
            ),

            // Add new witness
            if (widget.editable) ...[
              const SizedBox(height: 16),
              if (_showAddForm)
                _AddWitnessForm(
                  onAdd: (w) async {
                    await widget.onAdd(w);
                    if (mounted) setState(() => _showAddForm = false);
                  },
                  onCancel: () => setState(() => _showAddForm = false),
                )
              else
                Center(
                  child: Semantics(
                    label: 'Add new witness statement',
                    button: true,
                    child: ElevatedButton.icon(
                      onPressed: () => setState(() => _showAddForm = true),
                      icon: const Icon(Icons.person_add, size: 16),
                      label: const Text('Add Witness'),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Individual witness statement card with inline editing capability.
class _WitnessCard extends StatefulWidget {
  final WitnessStatement witness;
  final bool editable;
  final Future<void> Function(WitnessStatement statement) onUpdate;

  const _WitnessCard({
    required this.witness,
    required this.editable,
    required this.onUpdate,
  });

  @override
  State<_WitnessCard> createState() => _WitnessCardState();
}

class _WitnessCardState extends State<_WitnessCard> {
  bool _editing = false;
  bool _saving = false;
  late TextEditingController _nameCtrl;
  late TextEditingController _titleCtrl;
  late TextEditingController _employerCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _statementCtrl;
  late TextEditingController _collectorCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.witness.witnessName);
    _titleCtrl = TextEditingController(text: widget.witness.witnessTitle);
    _employerCtrl = TextEditingController(text: widget.witness.witnessEmployer);
    _phoneCtrl = TextEditingController(text: widget.witness.witnessPhone);
    _statementCtrl = TextEditingController(text: widget.witness.statementText);
    _collectorCtrl = TextEditingController(text: widget.witness.collectorName);
  }

  @override
  void didUpdateWidget(covariant _WitnessCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing) {
      _nameCtrl.text = widget.witness.witnessName;
      _titleCtrl.text = widget.witness.witnessTitle;
      _employerCtrl.text = widget.witness.witnessEmployer;
      _phoneCtrl.text = widget.witness.witnessPhone;
      _statementCtrl.text = widget.witness.statementText;
      _collectorCtrl.text = widget.witness.collectorName;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _titleCtrl.dispose();
    _employerCtrl.dispose();
    _phoneCtrl.dispose();
    _statementCtrl.dispose();
    _collectorCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _statementCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Witness name and statement are required'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final updated = WitnessStatement(
        id: widget.witness.id,
        investigationId: widget.witness.investigationId,
        witnessName: _nameCtrl.text.trim(),
        witnessTitle: _titleCtrl.text.trim(),
        witnessEmployer: _employerCtrl.text.trim(),
        witnessPhone: _phoneCtrl.text.trim(),
        statementText: _statementCtrl.text.trim(),
        collectionDate: widget.witness.collectionDate ?? DateTime.now(),
        collectorName: _collectorCtrl.text.trim(),
      );
      await widget.onUpdate(updated);
      if (mounted) setState(() => _editing = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.witness;
    final dateStr = w.collectionDate != null
        ? DateFormat('MM/dd/yyyy').format(w.collectionDate!)
        : 'Not set';

    return Semantics(
      label: 'Witness statement from ${w.witnessName}',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(
                    Icons.person,
                    size: 20,
                    color: HerzogColors.navyBlue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Builder(builder: (context) {
                      final isDark = Theme.of(context).brightness == Brightness.dark;
                      return Text(
                        _editing ? 'Editing Statement' : w.witnessName,
                        style: HerzogText.heading(
                          fontSize: 14,
                          color: isDark ? HerzogColors.gold : HerzogColors.navyBlue,
                        ),
                      );
                    }),
                  ),
                  if (widget.editable && !_editing)
                    IconButton(
                      icon: const Icon(
                        Icons.edit,
                        size: 18,
                        color: HerzogColors.navyBlue,
                      ),
                      onPressed: () => setState(() => _editing = true),
                      tooltip: 'Edit statement',
                    ),
                  if (_editing) ...[
                    IconButton(
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.check,
                              size: 20,
                              color: HerzogColors.successGreen,
                            ),
                      onPressed: _saving ? null : _save,
                      tooltip: 'Save',
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        size: 20,
                        color: HerzogColors.midGray,
                      ),
                      onPressed: () => setState(() => _editing = false),
                      tooltip: 'Cancel',
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),

              if (_editing) ...[
                _editField('Witness Name', _nameCtrl),
                _editField('Title', _titleCtrl),
                _editField('Employer', _employerCtrl),
                _editField('Phone', _phoneCtrl),
                _editField('Statement', _statementCtrl, maxLines: 4),
                _editField('Collector Name', _collectorCtrl),
              ] else ...[
                _infoRow('Title', w.witnessTitle),
                _infoRow('Employer', w.witnessEmployer),
                _infoRow('Phone', w.witnessPhone),
                const SizedBox(height: 8),
                Builder(builder: (context) {
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  return Text(
                    'STATEMENT',
                    style: HerzogText.label(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : HerzogColors.midGray,
                    ),
                  );
                }),
                const SizedBox(height: 4),
                Builder(builder: (context) {
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  return Text(
                    w.statementText,
                    style: HerzogText.body(
                      fontSize: 13,
                      color: isDark ? Colors.white : HerzogColors.richBlack,
                    ),
                  );
                }),
                const SizedBox(height: 8),
                _infoRow('Collection Date', dateStr),
                _infoRow('Collected By', w.collectorName),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: HerzogText.label(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : HerzogColors.midGray,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: HerzogText.body(
                fontSize: 13,
                color: isDark ? Colors.white : HerzogColors.richBlack,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _editField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        label: label,
        textField: true,
        child: TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(labelText: label),
        ),
      ),
    );
  }
}

/// Form for adding a new witness statement.
class _AddWitnessForm extends StatefulWidget {
  final Future<void> Function(WitnessStatement statement) onAdd;
  final VoidCallback onCancel;

  const _AddWitnessForm({required this.onAdd, required this.onCancel});

  @override
  State<_AddWitnessForm> createState() => _AddWitnessFormState();
}

class _AddWitnessFormState extends State<_AddWitnessForm> {
  final _nameCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _employerCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _statementCtrl = TextEditingController();
  final _collectorCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _titleCtrl.dispose();
    _employerCtrl.dispose();
    _phoneCtrl.dispose();
    _statementCtrl.dispose();
    _collectorCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty || _statementCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Witness name and statement are required'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final statement = WitnessStatement(
        witnessName: _nameCtrl.text.trim(),
        witnessTitle: _titleCtrl.text.trim(),
        witnessEmployer: _employerCtrl.text.trim(),
        witnessPhone: _phoneCtrl.text.trim(),
        statementText: _statementCtrl.text.trim(),
        collectionDate: DateTime.now(),
        collectorName: _collectorCtrl.text.trim(),
      );
      await widget.onAdd(statement);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add witness: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Builder(builder: (context) {
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  return Text(
                    'NEW WITNESS STATEMENT',
                    style: HerzogText.heading(
                      fontSize: 14,
                      color: isDark ? HerzogColors.gold : HerzogColors.navyBlue,
                    ),
                  );
                }),
                const Spacer(),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    size: 20,
                    color: HerzogColors.midGray,
                  ),
                  onPressed: widget.onCancel,
                  tooltip: 'Cancel',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _field('Witness Name *', _nameCtrl),
            _field('Title', _titleCtrl),
            _field('Employer', _employerCtrl),
            _field('Phone', _phoneCtrl),
            _field('Statement *', _statementCtrl, maxLines: 4),
            _field('Collector Name', _collectorCtrl),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: HerzogColors.white,
                      ),
                    )
                  : const Icon(Icons.save, size: 16),
              label: const Text('Save Witness'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        label: label,
        textField: true,
        child: TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(labelText: label),
        ),
      ),
    );
  }
}
