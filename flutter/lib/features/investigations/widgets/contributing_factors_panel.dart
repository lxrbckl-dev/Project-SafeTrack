import 'package:flutter/material.dart';

import '../../../app/herzog_theme.dart';
import '../data/investigation_repository.dart';

/// Panel for managing contributing factors for an investigation.
///
/// Features:
/// - Factor types fetched from admin settings API (NOT hardcoded)
/// - Dropdown to select factor type from configurable list
/// - Description text field
/// - "Mark as Primary" toggle -- exactly one must be primary (visually indicated)
/// - Add/remove factor buttons
/// - ADA: keyboard navigable, semantic labels
class ContributingFactorsPanel extends StatefulWidget {
  /// Current contributing factors for the investigation.
  final List<ContributingFactor> factors;

  /// Available factor types from admin settings.
  final List<String> factorTypes;

  /// Whether the form is editable.
  final bool editable;

  /// Called when a new factor is added.
  final Future<void> Function(ContributingFactor factor) onAdd;

  /// Called when a factor is deleted.
  final Future<void> Function(int factorId) onDelete;

  const ContributingFactorsPanel({
    super.key,
    required this.factors,
    required this.factorTypes,
    required this.editable,
    required this.onAdd,
    required this.onDelete,
  });

  @override
  State<ContributingFactorsPanel> createState() =>
      _ContributingFactorsPanelState();
}

class _ContributingFactorsPanelState extends State<ContributingFactorsPanel> {
  String? _selectedType;
  final _descriptionCtrl = TextEditingController();
  bool _isPrimary = false;
  bool _adding = false;

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _addFactor() async {
    if (_selectedType == null || _selectedType!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a factor type')),
      );
      return;
    }

    setState(() => _adding = true);
    try {
      final factor = ContributingFactor(
        factorType: _selectedType!,
        factorDescription: _descriptionCtrl.text.trim(),
        isPrimary: _isPrimary,
      );
      await widget.onAdd(factor);
      if (mounted) {
        _descriptionCtrl.clear();
        setState(() {
          _selectedType = null;
          _isPrimary = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add factor: $e')));
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPrimary = widget.factors.any((f) => f.isPrimary);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warning if no primary factor
            if (widget.factors.isNotEmpty && !hasPrimary)
              Semantics(
                label: 'Warning: no primary contributing factor selected',
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: HerzogColors.warningLight,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: HerzogColors.warningAmber),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 20,
                        color: HerzogColors.warningAmber,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'At least one primary contributing factor is required '
                          'before submission.',
                          style: HerzogText.body(
                            fontSize: 13,
                            color: HerzogColors.warningAmber,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Existing factors
            ...widget.factors.map((factor) => _buildFactorCard(factor)),

            // Add new factor form
            if (widget.editable) ...[
              const SizedBox(height: 16),
              _buildAddForm(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFactorCard(ContributingFactor factor) {
    return Semantics(
      label:
          '${factor.factorType} factor${factor.isPrimary ? ", primary" : ""}',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Primary indicator
              if (factor.isPrimary)
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: HerzogColors.gold,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    'PRIMARY',
                    style: HerzogText.label(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: HerzogColors.richBlack,
                    ),
                  ),
                ),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      factor.factorType,
                      style: HerzogText.heading(
                        fontSize: 14,
                        color: HerzogColors.navyBlue,
                      ),
                    ),
                    if (factor.factorDescription.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        factor.factorDescription,
                        style: HerzogText.body(fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),

              if (widget.editable)
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: HerzogColors.errorRed,
                  ),
                  onPressed: () => widget.onDelete(factor.id!),
                  tooltip: 'Remove factor',
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ADD CONTRIBUTING FACTOR',
              style: HerzogText.heading(
                fontSize: 14,
                color: HerzogColors.navyBlue,
              ),
            ),
            const SizedBox(height: 12),

            // Factor type dropdown
            Semantics(
              label: 'Factor type',
              child: DropdownButtonFormField<String>(
                initialValue: _selectedType,
                decoration: const InputDecoration(labelText: 'Factor Type'),
                items: widget.factorTypes
                    .map(
                      (type) =>
                          DropdownMenuItem(value: type, child: Text(type)),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _selectedType = value),
              ),
            ),
            const SizedBox(height: 12),

            // Description
            Semantics(
              label: 'Factor description',
              textField: true,
              child: TextField(
                controller: _descriptionCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Describe this contributing factor...',
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Primary toggle
            Semantics(
              label: 'Mark as primary factor',
              toggled: _isPrimary,
              child: SwitchListTile(
                title: Text(
                  'Mark as Primary Factor',
                  style: HerzogText.body(fontSize: 14),
                ),
                value: _isPrimary,
                onChanged: (value) => setState(() => _isPrimary = value),
                activeThumbColor: HerzogColors.gold,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(height: 12),

            // Add button
            ElevatedButton.icon(
              onPressed: _adding ? null : _addFactor,
              icon: _adding
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: HerzogColors.white,
                      ),
                    )
                  : const Icon(Icons.add, size: 16),
              label: const Text('Add Factor'),
            ),
          ],
        ),
      ),
    );
  }
}
