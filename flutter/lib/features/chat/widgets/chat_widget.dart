import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/herzog_theme.dart';
import '../../../features/auth/data/auth_service.dart';
import '../data/action_dispatcher.dart';
import '../data/chat_repository.dart';

// ---------------------------------------------------------------------------
// AI status enum
// ---------------------------------------------------------------------------

enum _AiStatus { warmingUp, ready, offline }

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

/// A single chat message (user or AI), optionally carrying structured actions.
class _ChatMessage {
  final String text;
  final bool isUser;
  final List<ChatAction> actions;

  /// True when this message is a system/offline notification rather than a
  /// normal AI reply.  Offline messages are rendered with muted grey italic
  /// styling and a [Icons.cloud_off] icon so users can distinguish them from
  /// real AI responses.
  final bool isOffline;

  /// How long the AI took to respond.  Only set for AI messages that are the
  /// direct reply to a user prompt (not for offline/error messages and not for
  /// action-result messages).
  final Duration? responseTime;

  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.actions = const [],
    this.isOffline = false,
    this.responseTime,
  });

  bool get hasActions => actions.isNotEmpty;
}

// ---------------------------------------------------------------------------
// Public widget: ChatFab
// ---------------------------------------------------------------------------

/// Floating AI Chat widget for the SafeTrack app.
///
/// Renders as a gold FAB in the bottom-right corner of the shell. When tapped,
/// expands to an overlay chat panel powered by Qwen 2.5 3B via [POST /api/chat].
///
/// TASK-019 enhancement: AI responses can include structured actions (navigate,
/// fill, navigate_and_fill). Action buttons are shown below the message bubble.
/// Actions are permission-gated via [ChatActionDispatcher].
///
/// Issue #172 enhancements:
/// - Animated typing indicator (_TypingIndicator) while waiting for a response.
/// - Cold-start warning banner shown until the first successful AI response.
/// - Connection-status dot in the header (yellow → green / red).
/// - Response-time label ("responded in X.Xs") below each AI message.
///
/// ADA compliance:
/// - FAB has semantic label "Open AI assistant" / "Close AI assistant"
/// - Chat panel is keyboard navigable; focus is managed on open/close
/// - Send button has semantic label "Send message"
/// - Messages have Semantics wrappers with speaker labels
/// - Action buttons have semantic labels describing the action
/// - Typing indicator has semantic label "AI is thinking"
/// - Status dot has semantic label "AI status: …"
///
/// Degrades gracefully when Ollama is unavailable — shows an error message
/// in the chat panel and does not crash.
class ChatFab extends StatefulWidget {
  const ChatFab({super.key});

  @override
  State<ChatFab> createState() => _ChatFabState();
}

class _ChatFabState extends State<ChatFab> with SingleTickerProviderStateMixin {
  bool _isOpen = false;
  final List<_ChatMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocus = FocusNode();
  bool _isLoading = false;

  // --- Issue #172 state ---
  _AiStatus _aiStatus = _AiStatus.warmingUp;
  bool _showColdStartWarning = true;
  DateTime? _requestStartTime;

  late final ChatRepository _repo;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _repo = context.read<ChatRepository>();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _togglePanel() {
    setState(() => _isOpen = !_isOpen);
    if (_isOpen) {
      // Delay focus so the panel is rendered first
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _inputFocus.requestFocus();
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isLoading) return;

    final token = context.read<AuthService>().token;

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _isLoading = true;
      _requestStartTime = DateTime.now();
    });
    _inputController.clear();
    _scrollToBottom();

    final result = await _repo.sendMessage(text, token: token);

    if (!mounted) return;

    final elapsed = _requestStartTime != null
        ? DateTime.now().difference(_requestStartTime!)
        : Duration.zero;

    setState(() {
      _isLoading = false;
      if (result.isSuccess) {
        // Detect the backend's offline/system message and apply offline styling.
        final offline = result.response == kOllamaOfflineMessage;

        if (offline) {
          _aiStatus = _AiStatus.offline;
          _messages.add(
            _ChatMessage(
              text: result.response!,
              isUser: false,
              actions: result.actions,
              isOffline: true,
            ),
          );
        } else {
          // Successful real response — mark ready and dismiss cold-start banner.
          _aiStatus = _AiStatus.ready;
          _showColdStartWarning = false;
          _messages.add(
            _ChatMessage(
              text: result.response!,
              isUser: false,
              actions: result.actions,
              isOffline: false,
              responseTime: elapsed,
            ),
          );

          // Auto-dispatch "fill" actions immediately (no button needed —
          // the form on the current page picks up the pending data).
          for (final action in result.actions) {
            if (action.action == 'fill') {
              ChatActionDispatcher.execute(context, action);
            }
          }
        }
      } else {
        // Network/timeout failures — show with offline styling so the user
        // sees a clear system message rather than a raw "Error: ..." string.
        _aiStatus = _AiStatus.offline;
        _messages.add(
          _ChatMessage(
            text: result.error ?? kOllamaOfflineMessage,
            isUser: false,
            isOffline: true,
          ),
        );
      }
    });
    _scrollToBottom();
    _inputFocus.requestFocus();
  }

  void _executeAction(ChatAction action) {
    final resultMsg = ChatActionDispatcher.execute(context, action);

    setState(() {
      _messages.add(_ChatMessage(text: resultMsg, isUser: false));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Chat panel — visible only when open
        if (_isOpen)
          _ChatPanel(
            messages: _messages,
            isLoading: _isLoading,
            scrollController: _scrollController,
            inputController: _inputController,
            inputFocus: _inputFocus,
            onSend: _sendMessage,
            onActionTap: _executeAction,
            aiStatus: _aiStatus,
            showColdStartWarning: _showColdStartWarning,
          ),

        const SizedBox(height: 8),

        // FAB toggle button
        Semantics(
          label: _isOpen ? 'Close AI assistant' : 'Open AI assistant',
          button: true,
          child: FloatingActionButton(
            heroTag: 'chat_fab',
            onPressed: _togglePanel,
            backgroundColor: HerzogColors.gold,
            foregroundColor: HerzogColors.richBlack,
            tooltip: _isOpen ? 'Close AI assistant' : 'Open AI assistant',
            child: Icon(
              _isOpen ? Icons.close : Icons.chat_bubble_outline,
              semanticLabel: _isOpen ? 'Close' : 'Chat',
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Chat panel widget
// ---------------------------------------------------------------------------

/// The expanded chat panel shown above the FAB.
///
/// Stateless — all state lives in [_ChatFabState].
class _ChatPanel extends StatelessWidget {
  final List<_ChatMessage> messages;
  final bool isLoading;
  final ScrollController scrollController;
  final TextEditingController inputController;
  final FocusNode inputFocus;
  final VoidCallback onSend;
  final ValueChanged<ChatAction> onActionTap;
  final _AiStatus aiStatus;
  final bool showColdStartWarning;

  const _ChatPanel({
    required this.messages,
    required this.isLoading,
    required this.scrollController,
    required this.inputController,
    required this.inputFocus,
    required this.onSend,
    required this.onActionTap,
    required this.aiStatus,
    required this.showColdStartWarning,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'AI assistant chat panel',
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        color: HerzogColors.white,
        child: Container(
          width: 340,
          height: 440,
          decoration: BoxDecoration(
            border: Border.all(color: HerzogColors.borderGray),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _PanelHeader(aiStatus: aiStatus),
              const Divider(
                height: 1,
                thickness: 1,
                color: HerzogColors.borderGray,
              ),
              // Cold-start warning banner
              if (showColdStartWarning) const _ColdStartBanner(),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: _MessageList(
                    messages: messages,
                    isLoading: isLoading,
                    scrollController: scrollController,
                    onActionTap: onActionTap,
                  ),
                ),
              ),
              const Divider(
                height: 1,
                thickness: 1,
                color: HerzogColors.borderGray,
              ),
              _InputBar(
                controller: inputController,
                focusNode: inputFocus,
                isLoading: isLoading,
                onSend: onSend,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Panel header
// ---------------------------------------------------------------------------

class _PanelHeader extends StatelessWidget {
  final _AiStatus aiStatus;

  const _PanelHeader({required this.aiStatus});

  Color get _statusColor {
    switch (aiStatus) {
      case _AiStatus.ready:
        return HerzogColors.successGreen;
      case _AiStatus.warmingUp:
        return HerzogColors.gold;
      case _AiStatus.offline:
        return HerzogColors.errorRed;
    }
  }

  String get _statusLabel {
    switch (aiStatus) {
      case _AiStatus.ready:
        return 'AI status: ready';
      case _AiStatus.warmingUp:
        return 'AI status: warming up';
      case _AiStatus.offline:
        return 'AI status: offline';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: HerzogColors.richBlack,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: HerzogColors.gold, size: 18),
          const SizedBox(width: 8),
          Text(
            'AI ASSISTANT',
            style: HerzogText.heading(
              fontSize: 13,
              color: HerzogColors.gold,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          // Connection status dot
          Semantics(
            label: _statusLabel,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _statusColor,
              ),
            ),
          ),
          const Spacer(),
          Text(
            'Qwen 2.5 3B',
            style: HerzogText.label(fontSize: 10, color: HerzogColors.smoke),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cold-start warning banner
// ---------------------------------------------------------------------------

/// Yellow banner shown at the top of the chat panel until the first successful
/// AI response.  Informs users that the first response may take up to 60 s
/// while the AI backend warms up.
class _ColdStartBanner extends StatelessWidget {
  const _ColdStartBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: HerzogColors.warningLight,
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: HerzogColors.warningAmber,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'AI assistant is warming up — first response may take up to 60 seconds.',
              style: HerzogText.body(
                fontSize: 11,
                color: HerzogColors.warningAmber,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Typing indicator
// ---------------------------------------------------------------------------

/// Animated "AI is thinking…" indicator with three pulsing dots shown while
/// waiting for an AI response.
///
/// Each dot animates opacity and scale with a staggered delay so they pulse
/// in sequence left-to-right, giving a clear visual indication of activity.
///
/// ADA: wrapped in a [Semantics] node labelled "AI is thinking".
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with TickerProviderStateMixin {
  static const _dotCount = 3;
  static const _duration = Duration(milliseconds: 1200);
  // Fraction of the full cycle each dot occupies (0..1)
  static const _dotWindow = 0.4;
  // Offset between consecutive dots as a fraction of the cycle
  static const _staggerStep = 0.2;

  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _opacities;
  late final List<Animation<double>> _scales;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      _dotCount,
      (_) => AnimationController(vsync: this, duration: _duration),
    );

    _opacities = List.generate(_dotCount, (i) {
      final begin = _staggerStep * i;
      final end = begin + _dotWindow;
      final items = <TweenSequenceItem<double>>[];
      if (begin > 0) {
        items.add(TweenSequenceItem(tween: ConstantTween(0.2), weight: begin));
      }
      items.add(
        TweenSequenceItem(
          tween: Tween(begin: 0.2, end: 1.0),
          weight: _dotWindow / 2,
        ),
      );
      items.add(
        TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 0.2),
          weight: _dotWindow / 2,
        ),
      );
      if (end < 1.0) {
        items.add(
          TweenSequenceItem(tween: ConstantTween(0.2), weight: 1.0 - end),
        );
      }
      return TweenSequence<double>(items).animate(_controllers[i]);
    });

    _scales = List.generate(_dotCount, (i) {
      final begin = _staggerStep * i;
      final end = begin + _dotWindow;
      final items = <TweenSequenceItem<double>>[];
      if (begin > 0) {
        items.add(TweenSequenceItem(tween: ConstantTween(1.0), weight: begin));
      }
      items.add(
        TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 1.4),
          weight: _dotWindow / 2,
        ),
      );
      items.add(
        TweenSequenceItem(
          tween: Tween(begin: 1.4, end: 1.0),
          weight: _dotWindow / 2,
        ),
      );
      if (end < 1.0) {
        items.add(
          TweenSequenceItem(tween: ConstantTween(1.0), weight: 1.0 - end),
        );
      }
      return TweenSequence<double>(items).animate(_controllers[i]);
    });

    for (final c in _controllers) {
      c.repeat();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'AI is thinking',
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: HerzogColors.offWhite,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
                bottomLeft: Radius.circular(2),
                bottomRight: Radius.circular(12),
              ),
              border: Border.all(color: HerzogColors.borderGray),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(_dotCount, (i) {
                return Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : 4),
                  child: AnimatedBuilder(
                    animation: _controllers[i],
                    builder: (context, child) {
                      return Opacity(
                        opacity: _opacities[i].value,
                        child: Transform.scale(
                          scale: _scales[i].value,
                          child: child,
                        ),
                      );
                    },
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: HerzogColors.smoke,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Message list
// ---------------------------------------------------------------------------

class _MessageList extends StatelessWidget {
  final List<_ChatMessage> messages;
  final bool isLoading;
  final ScrollController scrollController;
  final ValueChanged<ChatAction> onActionTap;

  const _MessageList({
    required this.messages,
    required this.isLoading,
    required this.scrollController,
    required this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: messages.length + (isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == messages.length) {
          // Animated typing indicator replaces the old spinner
          return const _TypingIndicator();
        }

        final msg = messages[index];
        return _MessageBubble(message: msg, onActionTap: onActionTap);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Message bubble
// ---------------------------------------------------------------------------

/// A single chat bubble — right-aligned for user, left-aligned for AI.
///
/// When the AI message has actions, action buttons are displayed below the
/// text bubble.  When the AI message has a [_ChatMessage.responseTime],
/// a light-gray "responded in X.Xs" label is shown below the bubble.
class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;
  final ValueChanged<ChatAction> onActionTap;

  const _MessageBubble({required this.message, required this.onActionTap});

  /// Formats a [Duration] as seconds with one decimal place, e.g. "1.2s".
  static String _formatDuration(Duration d) {
    final seconds = d.inMilliseconds / 1000.0;
    return '${seconds.toStringAsFixed(1)}s';
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final isOffline = message.isOffline;

    // Offline/system messages use a muted style regardless of sender.
    if (isOffline) {
      return _OfflineMessageBubble(text: message.text);
    }

    return Semantics(
      label: '${isUser ? "You" : "AI assistant"}: ${message.text}',
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: isUser
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isUser) ...[
                  const CircleAvatar(
                    radius: 12,
                    backgroundColor: HerzogColors.navyBlue,
                    child: Icon(
                      Icons.auto_awesome,
                      size: 12,
                      color: HerzogColors.gold,
                      semanticLabel: 'AI',
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isUser
                          ? HerzogColors.navyBlue
                          : HerzogColors.offWhite,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(12),
                        topRight: const Radius.circular(12),
                        bottomLeft: Radius.circular(isUser ? 12 : 2),
                        bottomRight: Radius.circular(isUser ? 2 : 12),
                      ),
                      border: isUser
                          ? null
                          : Border.all(color: HerzogColors.borderGray),
                    ),
                    child: isUser
                        ? SelectableText(
                            message.text,
                            style: HerzogText.body(
                              fontSize: 13,
                              color: HerzogColors.white,
                            ),
                          )
                        : _MarkdownLinkText(
                            text: message.text,
                            baseStyle: HerzogText.body(
                              fontSize: 13,
                              color: HerzogColors.darkGray,
                            ),
                          ),
                  ),
                ),
                if (isUser) const SizedBox(width: 6),
              ],
            ),
            // Action buttons — shown only for AI messages with actions
            if (!isUser && message.hasActions)
              _ActionButtons(
                actions: message.actions,
                onActionTap: onActionTap,
              ),
            // Response timing label — shown only for AI messages with timing
            if (!isUser && message.responseTime != null)
              Padding(
                padding: const EdgeInsets.only(left: 30, top: 2),
                child: Text(
                  'responded in ${_formatDuration(message.responseTime!)}',
                  style: HerzogText.body(
                    fontSize: 10,
                    color: HerzogColors.smoke,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Offline / system message bubble
// ---------------------------------------------------------------------------

/// Renders a system or offline notification with distinct muted styling:
/// - Light grey background (more muted than normal AI messages)
/// - Grey italic text
/// - [Icons.cloud_off] warning icon
///
/// Used whenever Ollama is unavailable or a network error prevents the request
/// from reaching the backend.
class _OfflineMessageBubble extends StatelessWidget {
  final String text;

  const _OfflineMessageBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'System: $text',
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const CircleAvatar(
              radius: 12,
              backgroundColor: Color(0xFFBDBDBD), // grey[400]
              child: Icon(
                Icons.cloud_off,
                size: 12,
                color: Colors.white,
                semanticLabel: 'Offline',
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  // Slightly more muted/lighter than the normal AI offWhite
                  color: const Color(0xFFF0F0F0),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                    bottomLeft: Radius.circular(2),
                    bottomRight: Radius.circular(12),
                  ),
                  border: Border.all(color: const Color(0xFFD0D0D0)),
                ),
                child: SelectableText(
                  text,
                  style: HerzogText.body(
                    fontSize: 13,
                    color: const Color(0xFF757575), // grey[600]
                  ).copyWith(fontStyle: FontStyle.italic),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Markdown link text
// ---------------------------------------------------------------------------

/// Regex that matches well-formed markdown links: [text](url)
///
/// Requires:
/// - `[` followed by one or more non-`]` characters (the link text)
/// - `]` immediately followed by `(`
/// - One or more non-`)` characters (the URL)
/// - `)`
///
/// Malformed variants like `[text][url]`, `[[double]]`, or `[text](` without
/// closing `)` will NOT match and render as plain text (TASK-045 edge case #6).
final RegExp _markdownLinkRe = RegExp(r'\[([^\]]+)\]\(([^)]+)\)');

/// A text span that represents either plain text or a parsed markdown link.
class _TextSegment {
  final String text;
  final String? url;

  const _TextSegment.plain(this.text) : url = null;
  const _TextSegment.link(this.text, this.url);

  bool get isLink => url != null;
}

/// Parses a string containing markdown links into a list of segments.
///
/// Well-formed `[text](url)` patterns become link segments; everything else
/// becomes plain text segments. Malformed markdown is left as plain text
/// (TASK-045 edge case #6).
List<_TextSegment> _parseMarkdownLinks(String text) {
  final segments = <_TextSegment>[];
  int lastEnd = 0;

  for (final match in _markdownLinkRe.allMatches(text)) {
    // Plain text before this match.
    if (match.start > lastEnd) {
      segments.add(_TextSegment.plain(text.substring(lastEnd, match.start)));
    }

    final linkText = match.group(1)!;
    final linkUrl = match.group(2)!;
    segments.add(_TextSegment.link(linkText, linkUrl));

    lastEnd = match.end;
  }

  // Trailing plain text after last match.
  if (lastEnd < text.length) {
    segments.add(_TextSegment.plain(text.substring(lastEnd)));
  }

  // If nothing matched, return the whole text as plain.
  if (segments.isEmpty) {
    segments.add(_TextSegment.plain(text));
  }

  return segments;
}

/// Renders AI message text with clickable markdown links.
///
/// Detects `[text](url)` patterns and renders them as tappable links styled
/// with Herzog gold underline. Internal routes (starting with `/`) navigate
/// via `context.go(url)`. External URLs are ignored for security.
///
/// Malformed markdown links render as plain text (TASK-045 edge case #6).
///
/// ADA: Links have semantic labels and are keyboard-focusable via the
/// [TapGestureRecognizer] on the [TextSpan].
class _MarkdownLinkText extends StatefulWidget {
  final String text;
  final TextStyle baseStyle;

  const _MarkdownLinkText({required this.text, required this.baseStyle});

  @override
  State<_MarkdownLinkText> createState() => _MarkdownLinkTextState();
}

class _MarkdownLinkTextState extends State<_MarkdownLinkText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void didUpdateWidget(_MarkdownLinkText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      for (final r in _recognizers) {
        r.dispose();
      }
      _recognizers.clear();
    }
  }

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  void _handleLinkTap(String url) {
    // Only navigate for internal routes starting with '/'.
    if (url.startsWith('/')) {
      context.go(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final segments = _parseMarkdownLinks(widget.text);
    final spans = <InlineSpan>[];

    for (final segment in segments) {
      if (segment.isLink) {
        final recognizer = TapGestureRecognizer()
          ..onTap = () => _handleLinkTap(segment.url!);
        _recognizers.add(recognizer);

        spans.add(
          TextSpan(
            text: segment.text,
            style: widget.baseStyle.copyWith(
              color: HerzogColors.darkYellow,
              decoration: TextDecoration.underline,
              decorationColor: HerzogColors.gold,
              decorationThickness: 2,
              fontWeight: FontWeight.w600,
            ),
            recognizer: recognizer,
            semanticsLabel: '${segment.text}, link to ${segment.url}',
          ),
        );
      } else {
        spans.add(TextSpan(text: segment.text, style: widget.baseStyle));
      }
    }

    return SelectableText.rich(TextSpan(children: spans));
  }
}

// ---------------------------------------------------------------------------
// Action buttons
// ---------------------------------------------------------------------------

/// Renders action buttons below an AI message bubble.
///
/// Only shows buttons for "navigate" and "navigate_and_fill" actions.
/// "fill" actions are auto-dispatched and do not need a button.
class _ActionButtons extends StatelessWidget {
  final List<ChatAction> actions;
  final ValueChanged<ChatAction> onActionTap;

  const _ActionButtons({required this.actions, required this.onActionTap});

  @override
  Widget build(BuildContext context) {
    // Filter to actions that need user confirmation (navigate, navigate_and_fill).
    final buttonActions = actions
        .where((a) => a.action == 'navigate' || a.action == 'navigate_and_fill')
        .toList();

    if (buttonActions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 30, top: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: buttonActions.map((action) {
          return Semantics(
            label: action.buttonLabel,
            button: true,
            child: OutlinedButton.icon(
              onPressed: () => onActionTap(action),
              icon: Icon(
                action.action == 'navigate_and_fill'
                    ? Icons.edit_note
                    : Icons.arrow_forward,
                size: 14,
              ),
              label: Text(
                action.buttonLabel,
                style: HerzogText.body(
                  fontSize: 11,
                  color: HerzogColors.navyBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: HerzogColors.navyBlue,
                side: const BorderSide(color: HerzogColors.navyBlue),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                minimumSize: const Size(0, 28),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Input bar
// ---------------------------------------------------------------------------

/// Text field + send button at the bottom of the panel.
///
/// ADA: Enter key sends the message (keyboard-navigable).
class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(
            child: Shortcuts(
              shortcuts: {
                LogicalKeySet(LogicalKeyboardKey.enter): const _SendIntent(),
              },
              child: Actions(
                actions: {
                  _SendIntent: CallbackAction<_SendIntent>(
                    onInvoke: (_) {
                      onSend();
                      return null;
                    },
                  ),
                },
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  enabled: !isLoading,
                  maxLines: 3,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  style: HerzogText.body(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Ask the AI assistant…',
                    hintStyle: HerzogText.body(
                      fontSize: 13,
                      color: HerzogColors.smoke,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: HerzogColors.inputBorder,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: HerzogColors.inputBorder,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: HerzogColors.navyBlue,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Semantics(
            label: 'Send message',
            button: true,
            child: IconButton(
              onPressed: isLoading ? null : onSend,
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          HerzogColors.navyBlue,
                        ),
                      ),
                    )
                  : const Icon(Icons.send),
              color: HerzogColors.navyBlue,
              disabledColor: HerzogColors.smoke,
              tooltip: 'Send message',
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Intent for keyboard shortcut
// ---------------------------------------------------------------------------

class _SendIntent extends Intent {
  const _SendIntent();
}
