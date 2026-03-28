import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../app/herzog_theme.dart';
import '../../../features/auth/data/auth_service.dart';
import '../data/action_dispatcher.dart';
import '../data/chat_repository.dart';

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

/// A single chat message (user or AI), optionally carrying structured actions.
class _ChatMessage {
  final String text;
  final bool isUser;
  final List<ChatAction> actions;

  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.actions = const [],
  });

  bool get hasActions => actions.isNotEmpty;
}

// ---------------------------------------------------------------------------
// Public widget: ChatFab
// ---------------------------------------------------------------------------

/// Floating AI Chat widget for the Highlander app.
///
/// Renders as a gold FAB in the bottom-right corner of the shell. When tapped,
/// expands to an overlay chat panel powered by Qwen 2.5 7B via [POST /api/chat].
///
/// TASK-019 enhancement: AI responses can include structured actions (navigate,
/// fill, navigate_and_fill). Action buttons are shown below the message bubble.
/// Actions are permission-gated via [ChatActionDispatcher].
///
/// ADA compliance:
/// - FAB has semantic label "Open AI assistant" / "Close AI assistant"
/// - Chat panel is keyboard navigable; focus is managed on open/close
/// - Send button has semantic label "Send message"
/// - Messages have Semantics wrappers with speaker labels
/// - Action buttons have semantic labels describing the action
/// - Loading indicator has semantic label "Waiting for AI response"
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
    });
    _inputController.clear();
    _scrollToBottom();

    final result = await _repo.sendMessage(text, token: token);

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result.isSuccess) {
        _messages.add(
          _ChatMessage(
            text: result.response!,
            isUser: false,
            actions: result.actions,
          ),
        );

        // Auto-dispatch "fill" actions immediately (no button needed —
        // the form on the current page picks up the pending data).
        for (final action in result.actions) {
          if (action.action == 'fill') {
            ChatActionDispatcher.execute(context, action);
          }
        }
      } else {
        _messages.add(
          _ChatMessage(text: 'Error: ${result.error}', isUser: false),
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

  const _ChatPanel({
    required this.messages,
    required this.isLoading,
    required this.scrollController,
    required this.inputController,
    required this.inputFocus,
    required this.onSend,
    required this.onActionTap,
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
              _PanelHeader(),
              const Divider(
                height: 1,
                thickness: 1,
                color: HerzogColors.borderGray,
              ),
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
          const Spacer(),
          Text(
            'Qwen 2.5 7B',
            style: HerzogText.label(fontSize: 10, color: HerzogColors.smoke),
          ),
        ],
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
          // Loading indicator at bottom
          return Semantics(
            label: 'Waiting for AI response',
            child: const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      HerzogColors.navyBlue,
                    ),
                  ),
                ),
              ),
            ),
          );
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
/// text bubble.
class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;
  final ValueChanged<ChatAction> onActionTap;

  const _MessageBubble({required this.message, required this.onActionTap});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

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
                    child: SelectableText(
                      message.text,
                      style: HerzogText.body(
                        fontSize: 13,
                        color: isUser
                            ? HerzogColors.white
                            : HerzogColors.darkGray,
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
          ],
        ),
      ),
    );
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
