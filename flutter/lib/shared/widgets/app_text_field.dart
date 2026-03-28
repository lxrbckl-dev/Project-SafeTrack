import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/herzog_theme.dart';

/// Herzog-styled text form field wrapper.
///
/// Provides consistent styling, label, optional validation, and semantic label
/// for ADA/WCAG compliance.
///
/// Usage:
/// ```dart
/// AppTextField(
///   label: 'Location',
///   hint: 'Enter job site location',
///   controller: _locationController,
///   validator: (v) => v == null || v.isEmpty ? 'Required' : null,
/// )
/// ```
class AppTextField extends StatelessWidget {
  /// Field label displayed above the input.
  final String label;

  /// Placeholder text shown when the field is empty.
  final String? hint;

  /// Controller for reading/writing the field value.
  final TextEditingController? controller;

  /// Validation function. Returns an error string or null.
  final String? Function(String?)? validator;

  /// Whether the field is required (adds * indicator to label).
  final bool required;

  /// Number of lines (1 = single-line, >1 = multiline).
  final int maxLines;

  /// Maximum character count.
  final int? maxLength;

  /// Keyboard type.
  final TextInputType keyboardType;

  /// Input formatters (e.g. numeric only).
  final List<TextInputFormatter>? inputFormatters;

  /// Whether the field is enabled for input.
  final bool enabled;

  /// Called when the value changes.
  final ValueChanged<String>? onChanged;

  /// Called when the user submits the field.
  final VoidCallback? onEditingComplete;

  /// Semantic label for screen readers. Defaults to [label].
  final String? semanticLabel;

  /// Focus node for programmatic focus management.
  final FocusNode? focusNode;

  /// Initial value (alternative to controller).
  final String? initialValue;

  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.validator,
    this.required = false,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.enabled = true,
    this.onChanged,
    this.onEditingComplete,
    this.semanticLabel,
    this.focusNode,
    this.initialValue,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveLabel = required ? '$label *' : label;
    final effectiveSemanticLabel = semanticLabel ?? label;

    return Semantics(
      label: effectiveSemanticLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Field label
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              effectiveLabel,
              style: HerzogText.label(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: HerzogColors.darkGray,
              ),
            ),
          ),
          // Input field
          TextFormField(
            controller: controller,
            initialValue: initialValue,
            focusNode: focusNode,
            enabled: enabled,
            maxLines: maxLines,
            maxLength: maxLength,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            onChanged: onChanged,
            onEditingComplete: onEditingComplete,
            validator: validator,
            style: HerzogText.body(
              fontSize: 14,
              color: enabled ? HerzogColors.darkGray : HerzogColors.smoke,
            ),
            decoration: InputDecoration(
              hintText: hint,
              counterText: '', // hide character counter
              filled: !enabled,
              fillColor: enabled
                  ? null
                  : HerzogColors.lightGray.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
