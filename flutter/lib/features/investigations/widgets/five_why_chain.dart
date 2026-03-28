import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/herzog_theme.dart';
import '../data/investigation_repository.dart';

/// Check if any modifier key (Alt, Control) is pressed.
bool _hasModifier(KeyDownEvent event) {
  return HardwareKeyboard.instance.isAltPressed ||
      HardwareKeyboard.instance.isControlPressed;
}

/// Interactive vertical chain widget for 5-Why root cause analysis.
///
/// Features:
/// - In-place editing: tap a question/answer to edit inline
/// - Keyboard-navigable (Tab between fields, Enter to save)
/// - Screen-reader friendly (Semantics on each level)
/// - "Add Why Level" button at the bottom
/// - Min 3 levels enforced visually (warning if < 3)
/// - Vertical connecting arrows between levels
class FiveWhyChain extends StatefulWidget {
  /// Current five-why entries, sorted by sortOrder.
  final List<FiveWhy> fiveWhys;

  /// Whether the form is editable (false when investigation is Approved).
  final bool editable;

  /// Called when a five-why entry is created or updated.
  final Future<void> Function(FiveWhy fiveWhy) onSave;

  /// Called when a five-why entry is deleted.
  final Future<void> Function(int whyId) onDelete;

  const FiveWhyChain({
    super.key,
    required this.fiveWhys,
    required this.editable,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<FiveWhyChain> createState() => _FiveWhyChainState();
}

class _FiveWhyChainState extends State<FiveWhyChain> {
  @override
  Widget build(BuildContext context) {
    final whys = List<FiveWhy>.from(widget.fiveWhys)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Minimum level warning
            if (whys.length < 3)
              Semantics(
                label:
                    'Warning: minimum 3 why levels required. Currently ${whys.length}.',
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
                          'Minimum 3 Why levels required before submission. '
                          'Currently ${whys.length} of 3.',
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

            // Chain entries
            for (int i = 0; i < whys.length; i++) ...[
              _FiveWhyLevel(
                fiveWhy: whys[i],
                levelIndex: i + 1,
                editable: widget.editable,
                onSave: widget.onSave,
                onDelete: () => widget.onDelete(whys[i].id!),
              ),
              if (i < whys.length - 1) _buildArrow(),
            ],

            // Add button
            if (widget.editable) ...[
              if (whys.isNotEmpty) _buildArrow(),
              Center(
                child: Semantics(
                  label: 'Add why level ${whys.length + 1}',
                  button: true,
                  child: ElevatedButton.icon(
                    onPressed: () => _addLevel(whys.length + 1),
                    icon: const Icon(Icons.add, size: 16),
                    label: Text('Add Why Level ${whys.length + 1}'),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildArrow() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            Container(width: 2, height: 20, color: HerzogColors.navyBlue),
            const Icon(
              Icons.arrow_downward,
              size: 20,
              color: HerzogColors.navyBlue,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addLevel(int level) async {
    final fiveWhy = FiveWhy(
      level: level,
      question: 'Why?',
      answer: '',
      evidence: '',
      sortOrder: level,
    );
    await widget.onSave(fiveWhy);
  }
}

/// A single level in the five-why chain with inline editing.
class _FiveWhyLevel extends StatefulWidget {
  final FiveWhy fiveWhy;
  final int levelIndex;
  final bool editable;
  final Future<void> Function(FiveWhy fiveWhy) onSave;
  final VoidCallback onDelete;

  const _FiveWhyLevel({
    required this.fiveWhy,
    required this.levelIndex,
    required this.editable,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<_FiveWhyLevel> createState() => _FiveWhyLevelState();
}

class _FiveWhyLevelState extends State<_FiveWhyLevel> {
  bool _editing = false;
  late TextEditingController _questionCtrl;
  late TextEditingController _answerCtrl;
  late TextEditingController _evidenceCtrl;
  final _questionFocus = FocusNode();
  final _answerFocus = FocusNode();
  final _evidenceFocus = FocusNode();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _questionCtrl = TextEditingController(text: widget.fiveWhy.question);
    _answerCtrl = TextEditingController(text: widget.fiveWhy.answer);
    _evidenceCtrl = TextEditingController(text: widget.fiveWhy.evidence);
  }

  @override
  void didUpdateWidget(covariant _FiveWhyLevel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing) {
      _questionCtrl.text = widget.fiveWhy.question;
      _answerCtrl.text = widget.fiveWhy.answer;
      _evidenceCtrl.text = widget.fiveWhy.evidence;
    }
  }

  @override
  void dispose() {
    _questionCtrl.dispose();
    _answerCtrl.dispose();
    _evidenceCtrl.dispose();
    _questionFocus.dispose();
    _answerFocus.dispose();
    _evidenceFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final updated = FiveWhy(
        id: widget.fiveWhy.id,
        investigationId: widget.fiveWhy.investigationId,
        level: widget.fiveWhy.level,
        question: _questionCtrl.text.trim(),
        answer: _answerCtrl.text.trim(),
        evidence: _evidenceCtrl.text.trim(),
        sortOrder: widget.fiveWhy.sortOrder,
      );
      await widget.onSave(updated);
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
    return Semantics(
      label: 'Why level ${widget.levelIndex}',
      child: Card(
        child: InkWell(
          onTap: widget.editable && !_editing
              ? () {
                  setState(() => _editing = true);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _questionFocus.requestFocus();
                  });
                }
              : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Level header
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: HerzogColors.navyBlue,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${widget.levelIndex}',
                        style: HerzogText.heading(
                          fontSize: 14,
                          color: HerzogColors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'WHY #${widget.levelIndex}',
                        style: HerzogText.heading(
                          fontSize: 14,
                          color: HerzogColors.navyBlue,
                        ),
                      ),
                    ),
                    if (widget.editable && _editing) ...[
                      IconButton(
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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
                        onPressed: () {
                          setState(() {
                            _editing = false;
                            _questionCtrl.text = widget.fiveWhy.question;
                            _answerCtrl.text = widget.fiveWhy.answer;
                            _evidenceCtrl.text = widget.fiveWhy.evidence;
                          });
                        },
                        tooltip: 'Cancel',
                      ),
                    ],
                    if (widget.editable)
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: HerzogColors.errorRed,
                        ),
                        onPressed: widget.onDelete,
                        tooltip: 'Delete this why level',
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Question field
                _buildField(
                  label: 'Question',
                  controller: _questionCtrl,
                  focusNode: _questionFocus,
                  nextFocus: _answerFocus,
                  value: widget.fiveWhy.question,
                  semanticLabel: 'Why ${widget.levelIndex} question',
                ),
                const SizedBox(height: 10),

                // Answer field
                _buildField(
                  label: 'Answer',
                  controller: _answerCtrl,
                  focusNode: _answerFocus,
                  nextFocus: _evidenceFocus,
                  value: widget.fiveWhy.answer,
                  semanticLabel: 'Why ${widget.levelIndex} answer',
                  maxLines: 3,
                ),
                const SizedBox(height: 10),

                // Evidence field (optional)
                _buildField(
                  label: 'Evidence (optional)',
                  controller: _evidenceCtrl,
                  focusNode: _evidenceFocus,
                  value: widget.fiveWhy.evidence,
                  semanticLabel: 'Why ${widget.levelIndex} evidence',
                  maxLines: 2,
                  isLast: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    FocusNode? nextFocus,
    required String value,
    required String semanticLabel,
    int maxLines = 1,
    bool isLast = false,
  }) {
    if (!_editing) {
      // Display mode
      return Semantics(
        label: '$semanticLabel: $value',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: HerzogText.label(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: HerzogColors.midGray,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value.isEmpty ? '(not set)' : value,
              style: HerzogText.body(
                fontSize: 14,
                color: value.isEmpty
                    ? HerzogColors.smoke
                    : HerzogColors.darkGray,
              ),
            ),
          ],
        ),
      );
    }

    // Edit mode
    return Semantics(
      label: semanticLabel,
      textField: true,
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.enter &&
              !_hasModifier(event) &&
              maxLines == 1) {
            if (isLast) {
              _save();
            } else {
              nextFocus?.requestFocus();
            }
          }
        },
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          maxLines: maxLines,
          textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
          onSubmitted: maxLines == 1
              ? (_) {
                  if (isLast) {
                    _save();
                  } else {
                    nextFocus?.requestFocus();
                  }
                }
              : null,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: HerzogText.label(
              fontSize: 12,
              color: HerzogColors.midGray,
            ),
          ),
        ),
      ),
    );
  }
}
