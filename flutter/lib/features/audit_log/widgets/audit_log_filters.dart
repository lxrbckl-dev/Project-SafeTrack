import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/herzog_theme.dart';
import '../data/audit_log_repository.dart';

/// The set of valid action types the API supports for filtering.
const _actionTypes = <String, String>{
  '': 'All Actions',
  'create': 'Create',
  'update': 'Update',
  'status_change': 'Status Change',
  'approve': 'Approve',
  'reject': 'Reject',
  'assign': 'Assign',
  'verify': 'Verify',
};

/// The set of valid entity types.
const _entityTypes = <String, String>{
  '': 'All Entity Types',
  'incident': 'Incident',
  'investigation': 'Investigation',
  'capa': 'CAPA',
  'setting': 'Setting',
};

/// Filter bar for the audit log viewer.
///
/// Provides dropdowns for entity type, action type, a text field for user ID,
/// and a date range picker. Calls [onFilterChanged] whenever any filter changes.
class AuditLogFilters extends StatefulWidget {
  final AuditLogFilter filter;
  final ValueChanged<AuditLogFilter> onFilterChanged;

  const AuditLogFilters({
    super.key,
    required this.filter,
    required this.onFilterChanged,
  });

  @override
  State<AuditLogFilters> createState() => _AuditLogFiltersState();
}

class _AuditLogFiltersState extends State<AuditLogFilters> {
  late TextEditingController _userController;
  final DateFormat _dateFormat = DateFormat('MMM d, yyyy');

  @override
  void initState() {
    super.initState();
    _userController = TextEditingController(text: widget.filter.userId ?? '');
  }

  @override
  void didUpdateWidget(AuditLogFilters oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filter.userId != widget.filter.userId) {
      _userController.text = widget.filter.userId ?? '';
    }
  }

  @override
  void dispose() {
    _userController.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: widget.filter.dateStart != null
          ? DateTimeRange(
              start: widget.filter.dateStart!,
              end: widget.filter.dateEnd ?? now,
            )
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: HerzogColors.navyBlue,
              onPrimary: HerzogColors.white,
              surface: HerzogColors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (result != null) {
      widget.onFilterChanged(
        widget.filter.copyWith(
          dateStart: result.start,
          dateEnd: result.end,
          page: 1,
        ),
      );
    }
  }

  void _clearDateRange() {
    widget.onFilterChanged(
      widget.filter.copyWith(page: 1, clearDateStart: true, clearDateEnd: true),
    );
  }

  void _clearAllFilters() {
    _userController.clear();
    widget.onFilterChanged(const AuditLogFilter());
  }

  bool get _hasActiveFilters =>
      (widget.filter.entityType != null &&
          widget.filter.entityType!.isNotEmpty) ||
      (widget.filter.action != null && widget.filter.action!.isNotEmpty) ||
      (widget.filter.userId != null && widget.filter.userId!.isNotEmpty) ||
      widget.filter.dateStart != null;

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 600;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.filter_list, size: 18, color: HerzogColors.midGray),
                const SizedBox(width: 8),
                Text('Filters', style: HerzogText.label(fontSize: 12)),
                const Spacer(),
                if (_hasActiveFilters)
                  TextButton.icon(
                    onPressed: _clearAllFilters,
                    icon: const Icon(Icons.clear_all, size: 16),
                    label: Text(
                      'Clear All',
                      style: HerzogText.body(
                        fontSize: 12,
                        color: HerzogColors.navyBlue,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                // Entity Type dropdown
                SizedBox(
                  width: isNarrow ? double.infinity : 180,
                  child: _buildDropdown<String>(
                    label: 'Entity Type',
                    value: widget.filter.entityType ?? '',
                    items: _entityTypes,
                    onChanged: (val) {
                      widget.onFilterChanged(
                        val == null || val.isEmpty
                            ? widget.filter.copyWith(
                                page: 1,
                                clearEntityType: true,
                              )
                            : widget.filter.copyWith(entityType: val, page: 1),
                      );
                    },
                  ),
                ),

                // Action Type dropdown
                SizedBox(
                  width: isNarrow ? double.infinity : 180,
                  child: _buildDropdown<String>(
                    label: 'Action',
                    value: widget.filter.action ?? '',
                    items: _actionTypes,
                    onChanged: (val) {
                      widget.onFilterChanged(
                        val == null || val.isEmpty
                            ? widget.filter.copyWith(page: 1, clearAction: true)
                            : widget.filter.copyWith(action: val, page: 1),
                      );
                    },
                  ),
                ),

                // User ID text field
                SizedBox(
                  width: isNarrow ? double.infinity : 200,
                  child: Semantics(
                    label: 'Filter by user ID',
                    child: TextField(
                      controller: _userController,
                      decoration: InputDecoration(
                        labelText: 'User ID',
                        labelStyle: HerzogText.body(
                          fontSize: 12,
                          color: HerzogColors.midGray,
                        ),
                        isDense: true,
                        suffixIcon: _userController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                tooltip: 'Clear user filter',
                                onPressed: () {
                                  _userController.clear();
                                  widget.onFilterChanged(
                                    widget.filter.copyWith(
                                      page: 1,
                                      clearUserId: true,
                                    ),
                                  );
                                },
                              )
                            : null,
                      ),
                      style: HerzogText.body(fontSize: 13),
                      onSubmitted: (val) {
                        widget.onFilterChanged(
                          val.isEmpty
                              ? widget.filter.copyWith(
                                  page: 1,
                                  clearUserId: true,
                                )
                              : widget.filter.copyWith(userId: val, page: 1),
                        );
                      },
                    ),
                  ),
                ),

                // Date range picker
                SizedBox(
                  width: isNarrow ? double.infinity : 260,
                  child: Semantics(
                    label: 'Filter by date range',
                    button: true,
                    child: InkWell(
                      onTap: _pickDateRange,
                      borderRadius: BorderRadius.circular(5),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Date Range',
                          labelStyle: HerzogText.body(
                            fontSize: 12,
                            color: HerzogColors.midGray,
                          ),
                          isDense: true,
                          suffixIcon: widget.filter.dateStart != null
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  tooltip: 'Clear date range',
                                  onPressed: _clearDateRange,
                                )
                              : const Icon(Icons.date_range, size: 18),
                        ),
                        child: Text(
                          widget.filter.dateStart != null
                              ? '${_dateFormat.format(widget.filter.dateStart!)} - ${_dateFormat.format(widget.filter.dateEnd ?? DateTime.now())}'
                              : 'All dates',
                          style: HerzogText.body(fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required Map<T, String> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Semantics(
      label: 'Filter by $label',
      child: DropdownButtonFormField<T>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: HerzogText.body(
            fontSize: 12,
            color: HerzogColors.midGray,
          ),
          isDense: true,
        ),
        style: HerzogText.body(fontSize: 13),
        items: items.entries
            .map((e) => DropdownMenuItem<T>(value: e.key, child: Text(e.value)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}
