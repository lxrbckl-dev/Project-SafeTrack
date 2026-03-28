import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/herzog_theme.dart';
import '../../auth/data/auth_service.dart';
import '../data/admin_repository.dart';

/// Full CRUD management of contributing factor types.
///
/// Factor types are stored as a JSON array in the `factor_types` setting.
/// Changes are persisted via PUT /api/settings/factor_types.
///
/// Route: /admin/factor-types
class FactorTypesPage extends StatefulWidget {
  const FactorTypesPage({super.key});

  @override
  State<FactorTypesPage> createState() => _FactorTypesPageState();
}

class _FactorTypesPageState extends State<FactorTypesPage> {
  final AdminRepository _repo = AdminRepository();

  bool _loading = true;
  bool _saving = false;
  String? _error;

  List<String> _factorTypes = [];

  // Controller for the "add new factor type" text field
  final TextEditingController _addController = TextEditingController();

  // Tracks which row (by index) is currently being edited inline
  int? _editingIndex;
  final TextEditingController _editController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFactorTypes();
  }

  @override
  void dispose() {
    _addController.dispose();
    _editController.dispose();
    super.dispose();
  }

  Future<void> _loadFactorTypes() async {
    final token = context.read<AuthService>().token;
    if (token == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final setting = await _repo.getSetting(token, 'factor_types');
      final decoded = jsonDecode(setting.value);
      setState(() {
        _factorTypes = List<String>.from(decoded as List<dynamic>);
      });
    } catch (e) {
      setState(() => _error = e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load factor types: $e'),
            action: SnackBarAction(label: 'Retry', onPressed: _loadFactorTypes),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _persist() async {
    final token = context.read<AuthService>().token;
    if (token == null) return;

    setState(() => _saving = true);
    try {
      final value = jsonEncode(_factorTypes);
      await _repo.updateSetting(token, 'factor_types', value);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Factor types saved.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addFactorType() {
    final text = _addController.text.trim();
    if (text.isEmpty) return;
    if (_factorTypes.contains(text)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('"$text" already exists.')));
      return;
    }
    setState(() {
      _factorTypes.add(text);
      _addController.clear();
    });
    _persist();
  }

  void _startEdit(int index) {
    setState(() {
      _editingIndex = index;
      _editController.text = _factorTypes[index];
    });
  }

  void _commitEdit(int index) {
    final text = _editController.text.trim();
    if (text.isEmpty) {
      _cancelEdit();
      return;
    }
    setState(() {
      _factorTypes[index] = text;
      _editingIndex = null;
    });
    _persist();
  }

  void _cancelEdit() {
    setState(() => _editingIndex = null);
  }

  Future<void> _confirmDelete(int index) async {
    final name = _factorTypes[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete factor type?'),
        content: Text('Remove "$name" from the list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: HerzogColors.errorRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() => _factorTypes.removeAt(index));
      _persist();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FACTOR TYPES'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: HerzogColors.gold,
                ),
              ),
            ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadFactorTypes,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildErrorState()
          : _buildContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: HerzogColors.errorRed),
          const SizedBox(height: 12),
          Text('Failed to load factor types', style: HerzogText.body()),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _loadFactorTypes,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _factorTypes.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, indent: 16, endIndent: 16),
            itemBuilder: (ctx, i) => _buildRow(i),
          ),
        ),
        _buildAddRow(),
      ],
    );
  }

  Widget _buildRow(int index) {
    final isEditing = _editingIndex == index;

    if (isEditing) {
      return ListTile(
        title: Semantics(
          label: 'Edit factor type',
          child: TextField(
            controller: _editController,
            autofocus: true,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
            onSubmitted: (_) => _commitEdit(index),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              button: true,
              label: 'Confirm edit',
              child: IconButton(
                icon: const Icon(Icons.check, color: HerzogColors.successGreen),
                onPressed: () => _commitEdit(index),
                tooltip: 'Save',
              ),
            ),
            Semantics(
              button: true,
              label: 'Cancel edit',
              child: IconButton(
                icon: const Icon(Icons.close, color: HerzogColors.midGray),
                onPressed: _cancelEdit,
                tooltip: 'Cancel',
              ),
            ),
          ],
        ),
      );
    }

    return ListTile(
      title: Text(_factorTypes[index], style: HerzogText.body()),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            label: 'Edit ${_factorTypes[index]}',
            child: IconButton(
              icon: Icon(
                Icons.edit_outlined,
                color: HerzogColors.navyBlue,
                size: 20,
              ),
              onPressed: () => _startEdit(index),
              tooltip: 'Edit',
            ),
          ),
          Semantics(
            button: true,
            label: 'Delete ${_factorTypes[index]}',
            child: IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: HerzogColors.errorRed,
                size: 20,
              ),
              onPressed: () => _confirmDelete(index),
              tooltip: 'Delete',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddRow() {
    return Container(
      color: HerzogColors.lightGray,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              label: 'New factor type name',
              child: TextField(
                controller: _addController,
                decoration: const InputDecoration(
                  labelText: 'Add new factor type',
                  hintText: 'e.g. Contractor',
                ),
                onSubmitted: (_) => _addFactorType(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Semantics(
            button: true,
            label: 'Add factor type',
            child: ElevatedButton.icon(
              onPressed: _addFactorType,
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ),
        ],
      ),
    );
  }
}
