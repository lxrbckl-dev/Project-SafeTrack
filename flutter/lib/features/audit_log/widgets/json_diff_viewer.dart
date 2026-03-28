import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../app/herzog_theme.dart';

/// Displays a side-by-side Before/After JSON diff for an audit log entry.
///
/// Attempts to pretty-print the JSON. If the string is not valid JSON,
/// falls back to displaying the raw text.
class JsonDiffViewer extends StatelessWidget {
  final String before;
  final String after;

  const JsonDiffViewer({super.key, required this.before, required this.after});

  String _prettyPrint(String raw) {
    if (raw.isEmpty) return '(empty)';
    try {
      final decoded = jsonDecode(raw);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 700;
    final prettyBefore = _prettyPrint(before);
    final prettyAfter = _prettyPrint(after);

    if (isNarrow) {
      // Stack vertically on narrow screens
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _JsonPanel(
            title: 'Before',
            content: prettyBefore,
            color: HerzogColors.errorLight,
            textColor: HerzogColors.errorRed,
          ),
          const SizedBox(height: 8),
          _JsonPanel(
            title: 'After',
            content: prettyAfter,
            color: HerzogColors.successLight,
            textColor: HerzogColors.successGreen,
          ),
        ],
      );
    }

    // Side-by-side on wider screens
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _JsonPanel(
            title: 'Before',
            content: prettyBefore,
            color: HerzogColors.errorLight,
            textColor: HerzogColors.errorRed,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _JsonPanel(
            title: 'After',
            content: prettyAfter,
            color: HerzogColors.successLight,
            textColor: HerzogColors.successGreen,
          ),
        ),
      ],
    );
  }
}

class _JsonPanel extends StatelessWidget {
  final String title;
  final String content;
  final Color color;
  final Color textColor;

  const _JsonPanel({
    required this.title,
    required this.content,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$title JSON snapshot',
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: textColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: textColor.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(5),
                  topRight: Radius.circular(5),
                ),
              ),
              child: Text(
                title,
                style: HerzogText.label(fontSize: 11, color: textColor),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                content,
                style: HerzogText.body(
                  fontSize: 12,
                  color: HerzogColors.darkGray,
                ).copyWith(fontFamily: 'monospace', height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
