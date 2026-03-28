import 'package:flutter/material.dart';

import '../../../app/herzog_theme.dart';

/// A modal overlay listing all available keyboard shortcuts.
///
/// Triggered by pressing **?** (Shift+/) anywhere in the app shell.
/// Shows shortcuts grouped by category with Herzog branding.
///
/// ADA/WCAG:
/// - Dialog has a semantic label (WCAG 1.3.1)
/// - Sufficient contrast on all text (WCAG 1.4.3)
/// - Dismissible via Escape or tap-outside (WCAG 2.1.2)
/// - Focus trapped in modal while open (WCAG 2.4.3)
class KeyboardShortcutOverlay extends StatelessWidget {
  const KeyboardShortcutOverlay({super.key});

  /// Show the overlay as a dialog.
  static void show(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss keyboard shortcuts',
      builder: (_) => const KeyboardShortcutOverlay(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Keyboard shortcuts reference',
      child: Dialog(
        backgroundColor: HerzogColors.richBlack,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: HerzogColors.gold, width: 2),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(onClose: () => Navigator.of(context).pop()),
                const SizedBox(height: 20),
                const _ShortcutGroup(
                  title: 'NAVIGATION',
                  shortcuts: [
                    _ShortcutRow(
                      key: 'Ctrl+Shift+H',
                      description: 'Go to Dashboard',
                    ),
                    _ShortcutRow(
                      key: 'Ctrl+Shift+N',
                      description: 'Go to Incidents',
                    ),
                    _ShortcutRow(
                      key: 'Ctrl+Shift+V',
                      description: 'Go to Investigations',
                    ),
                    _ShortcutRow(
                      key: 'Ctrl+Shift+A',
                      description: 'Go to CAPAs',
                    ),
                    _ShortcutRow(
                      key: 'Ctrl+Shift+S',
                      description: 'Global Search',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const _ShortcutGroup(
                  title: 'PANELS',
                  shortcuts: [
                    _ShortcutRow(
                      key: 'Ctrl+Shift+K  /  /',
                      description: 'Toggle AI Chat',
                    ),
                    _ShortcutRow(key: 'Esc', description: 'Close open panel'),
                  ],
                ),
                const SizedBox(height: 16),
                const _ShortcutGroup(
                  title: 'HELP',
                  shortcuts: [
                    _ShortcutRow(key: '?', description: 'Show this dialog'),
                  ],
                ),
                const SizedBox(height: 20),
                _Footer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  final VoidCallback onClose;

  const _Header({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.keyboard, color: HerzogColors.gold, size: 20),
        const SizedBox(width: 10),
        Text(
          'KEYBOARD SHORTCUTS',
          style: HerzogText.heading(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: HerzogColors.gold,
          ),
        ),
        const Spacer(),
        Semantics(
          label: 'Close keyboard shortcuts dialog',
          button: true,
          child: IconButton(
            icon: const Icon(Icons.close, color: HerzogColors.smoke, size: 18),
            onPressed: onClose,
            tooltip: 'Close (Esc)',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ),
      ],
    );
  }
}

class _ShortcutGroup extends StatelessWidget {
  final String title;
  final List<_ShortcutRow> shortcuts;

  const _ShortcutGroup({required this.title, required this.shortcuts});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: HerzogText.label(
            fontSize: 10,
            color: HerzogColors.smoke,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: HerzogColors.darkGray),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            children: shortcuts
                .asMap()
                .entries
                .map(
                  (entry) =>
                      _buildRow(entry.key, entry.value, shortcuts.length),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildRow(int index, _ShortcutRow row, int total) {
    final isLast = index == total - 1;
    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: HerzogColors.darkGray)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          _KeyBadge(keyLabel: row.key),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              row.description,
              style: HerzogText.body(fontSize: 13, color: HerzogColors.smoke),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single shortcut entry: key badge + description.
class _ShortcutRow {
  final String key;
  final String description;

  const _ShortcutRow({required this.key, required this.description});
}

/// Styled keyboard key badge.
class _KeyBadge extends StatelessWidget {
  final String keyLabel;

  const _KeyBadge({required this.keyLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: HerzogColors.darkGray,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: HerzogColors.midGray),
      ),
      child: Text(
        keyLabel,
        style: HerzogText.label(
          fontSize: 11,
          color: HerzogColors.gold,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '/ shortcut is disabled while a text field is focused',
        style: HerzogText.label(fontSize: 10, color: HerzogColors.midGray),
        textAlign: TextAlign.center,
      ),
    );
  }
}
