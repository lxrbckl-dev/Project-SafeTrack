import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../app/herzog_theme.dart';

/// A microphone [IconButton] that performs voice-to-text input and appends
/// recognized speech to the given [TextEditingController].
///
/// Lifecycle:
/// 1. On first build, [SpeechToText.initialize] is called. If the platform
///    does not support speech recognition, the button is **not rendered**
///    (graceful degradation).
/// 2. Tap to start listening — a pulsing red indicator appears.
/// 3. Tap again (or speech ends) to stop listening — recognized text is
///    appended to [controller].
///
/// ADA/WCAG:
/// - Wrapped in [Semantics] with `button: true`.
/// - Label switches between "Start voice input" and "Stop voice input"
///   depending on listening state.
///
/// Usage:
/// ```dart
/// VoiceInputButton(controller: _descriptionController)
/// ```
class VoiceInputButton extends StatefulWidget {
  /// The [TextEditingController] to append recognized speech text to.
  final TextEditingController controller;

  const VoiceInputButton({super.key, required this.controller});

  @override
  State<VoiceInputButton> createState() => _VoiceInputButtonState();
}

class _VoiceInputButtonState extends State<VoiceInputButton>
    with SingleTickerProviderStateMixin {
  final SpeechToText _speech = SpeechToText();

  /// Whether the speech recognition service is available on this platform.
  bool _available = false;

  /// Whether we are currently listening.
  bool _isListening = false;

  /// Animation controller for the pulsing red indicator.
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 800),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            _pulseController.reverse();
          } else if (status == AnimationStatus.dismissed && _isListening) {
            _pulseController.forward();
          }
        });
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initializeSpeech();
  }

  Future<void> _initializeSpeech() async {
    final available = await _speech.initialize(
      onError: (_) {
        if (mounted) {
          setState(() => _isListening = false);
          _pulseController.stop();
        }
      },
      onStatus: (status) {
        // When the recognizer finishes (e.g. silence timeout), stop UI state.
        if (status == 'done' || status == 'notListening') {
          if (mounted && _isListening) {
            setState(() => _isListening = false);
            _pulseController.stop();
            _pulseController.reset();
          }
        }
      },
    );
    if (mounted) {
      setState(() => _available = available);
    }
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) {
        setState(() => _isListening = false);
        _pulseController.stop();
        _pulseController.reset();
      }
    } else {
      setState(() => _isListening = true);
      _pulseController.forward();

      await _speech.listen(
        onResult: (result) {
          if (mounted && result.finalResult) {
            final recognized = result.recognizedWords.trim();
            if (recognized.isNotEmpty) {
              // Read CURRENT text at result time so typing while mic is open
              // is not overwritten.
              final existingText = widget.controller.text;
              final separator =
                  existingText.isNotEmpty && !existingText.endsWith(' ')
                  ? ' '
                  : '';
              widget.controller.text = '$existingText$separator$recognized';
              // Move cursor to end.
              widget.controller.selection = TextSelection.fromPosition(
                TextPosition(offset: widget.controller.text.length),
              );
            }
          }
        },
        pauseFor: const Duration(seconds: 3),
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          partialResults: false,
        ),
      );
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Graceful degradation: don't render if speech is unavailable.
    if (!_available) return const SizedBox.shrink();

    final semanticLabel = _isListening
        ? 'Stop voice input'
        : 'Start voice input';

    return Semantics(
      label: semanticLabel,
      button: true,
      child: _isListening
          ? ScaleTransition(
              scale: _pulseAnimation,
              child: IconButton(
                icon: const Icon(Icons.mic, color: HerzogColors.errorRed),
                tooltip: 'Stop voice input',
                onPressed: _toggleListening,
              ),
            )
          : IconButton(
              icon: Icon(
                Icons.mic_none,
                color: Theme.of(context).brightness == Brightness.dark
                    ? HerzogColors.white
                    : HerzogColors.navyBlue,
              ),
              tooltip: 'Start voice input',
              onPressed: _toggleListening,
            ),
    );
  }
}
