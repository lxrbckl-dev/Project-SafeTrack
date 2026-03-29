import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/herzog_theme.dart';
import '../../auth/data/auth_service.dart';
import '../data/api_key_repository.dart';

/// Admin page for managing agent API keys.
///
/// Features:
/// - Create new API key (shows full key once with copy button + warning)
/// - List active keys (prefix, name, last used)
/// - Revoke keys
///
/// Route: /admin/api-keys
/// Access: Admin and Safety Manager only (enforced by router).
class ApiKeysPage extends StatefulWidget {
  const ApiKeysPage({super.key});

  @override
  State<ApiKeysPage> createState() => _ApiKeysPageState();
}

class _ApiKeysPageState extends State<ApiKeysPage> {
  final ApiKeyRepository _repo = ApiKeyRepository();

  bool _loading = true;
  String? _error;
  List<AgentApiKey> _keys = [];
  bool _showRevoked = false;

  @override
  void initState() {
    super.initState();
    _loadKeys();
  }

  Future<void> _loadKeys() async {
    final auth = context.read<AuthService>();
    final token = auth.token;
    if (token == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final keys = await _repo.listKeys(token, showRevoked: _showRevoked);
      if (!mounted) return;
      setState(() {
        _keys = keys;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _createKey() async {
    final auth = context.read<AuthService>();
    final token = auth.token;
    if (token == null) return;

    final result = await showDialog<CreateKeyResponse>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CreateKeyDialog(repo: _repo, token: token),
    );

    if (result != null) {
      // Show the full key in a modal that the user must acknowledge.
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _ShowKeyDialog(response: result),
      );
      _loadKeys();
    }
  }

  Future<void> _revokeKey(AgentApiKey key) async {
    final auth = context.read<AuthService>();
    final token = auth.token;
    if (token == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke API Key'),
        content: Text(
          'Are you sure you want to revoke the key "${key.name}" '
          '(${key.keyPrefix}...)? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: HerzogColors.errorRed,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _repo.revokeKey(token, key.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('API key "${key.name}" revoked'),
          backgroundColor: HerzogColors.successGreen,
        ),
      );
      _loadKeys();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to revoke key: $e'),
          backgroundColor: HerzogColors.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent API Keys'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to Admin',
          onPressed: () => context.go('/admin'),
        ),
        actions: [
          // Toggle to show/hide revoked keys.
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Show revoked'),
              Semantics(
                label: 'Show revoked keys',
                child: Switch(
                  value: _showRevoked,
                  onChanged: (v) {
                    setState(() => _showRevoked = v);
                    _loadKeys();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _createKey,
            icon: const Icon(Icons.add),
            label: const Text('Create Key'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: HerzogColors.errorRed),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: HerzogColors.errorRed)),
            const SizedBox(height: 16),
            FilledButton(onPressed: _loadKeys, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_keys.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.vpn_key_off, size: 64, color: HerzogColors.smoke),
            const SizedBox(height: 16),
            Text(
              'No API keys yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Create an API key to allow external agents to authenticate.',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _createKey,
              icon: const Icon(Icons.add),
              label: const Text('Create Key'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadKeys,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _keys.length,
        itemBuilder: (context, index) {
          final key = _keys[index];
          return _KeyCard(
            apiKey: key,
            onRevoke: key.isActive ? () => _revokeKey(key) : null,
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Key card widget
// ---------------------------------------------------------------------------

class _KeyCard extends StatelessWidget {
  final AgentApiKey apiKey;
  final VoidCallback? onRevoke;

  const _KeyCard({required this.apiKey, this.onRevoke});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRevoked = !apiKey.isActive;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isRevoked ? HerzogColors.lightGray : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Key icon.
            Icon(
              isRevoked ? Icons.vpn_key_off : Icons.vpn_key,
              color: isRevoked ? HerzogColors.smoke : HerzogColors.navyBlue,
              size: 32,
            ),
            const SizedBox(width: 16),

            // Key details.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        apiKey.name,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          decoration: isRevoked
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      if (isRevoked) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: HerzogColors.errorLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'REVOKED',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: HerzogColors.errorRed,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Prefix: ${apiKey.keyPrefix}...',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: isDark ? Colors.white : HerzogColors.midGray,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'User ID: ${apiKey.userId}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (apiKey.lastUsedAt != null)
                    Text(
                      'Last used: ${_formatDate(apiKey.lastUsedAt!)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  Text(
                    'Created: ${_formatDate(apiKey.createdAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (apiKey.revokedAt != null)
                    Text(
                      'Revoked: ${_formatDate(apiKey.revokedAt!)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: HerzogColors.errorRed,
                      ),
                    ),
                ],
              ),
            ),

            // Revoke button.
            if (onRevoke != null)
              Tooltip(
                message: 'Revoke this API key',
                child: IconButton(
                  icon: const Icon(Icons.block, color: HerzogColors.errorRed),
                  onPressed: onRevoke,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ---------------------------------------------------------------------------
// Create key dialog
// ---------------------------------------------------------------------------

class _CreateKeyDialog extends StatefulWidget {
  final ApiKeyRepository repo;
  final String token;

  const _CreateKeyDialog({required this.repo, required this.token});

  @override
  State<_CreateKeyDialog> createState() => _CreateKeyDialogState();
}

class _CreateKeyDialogState extends State<_CreateKeyDialog> {
  final _nameController = TextEditingController();
  final _userIdController = TextEditingController();
  bool _creating = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final userIdStr = _userIdController.text.trim();
    final userId = int.tryParse(userIdStr);

    if (name.isEmpty || userId == null || userId <= 0) {
      setState(() => _error = 'Please provide a valid name and user ID.');
      return;
    }

    setState(() {
      _creating = true;
      _error = null;
    });

    try {
      final result = await widget.repo.createKey(
        widget.token,
        userId: userId,
        name: name,
      );
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _creating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Agent API Key'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Key Name',
                hintText: 'e.g., OpenClaw agent',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _userIdController,
              decoration: const InputDecoration(
                labelText: 'User ID',
                hintText: 'e.g., 1',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: HerzogColors.errorRed),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _creating ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _creating ? null : _submit,
          child: _creating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Show key dialog (edge case 5: show full key exactly once)
// ---------------------------------------------------------------------------

class _ShowKeyDialog extends StatefulWidget {
  final CreateKeyResponse response;

  const _ShowKeyDialog({required this.response});

  @override
  State<_ShowKeyDialog> createState() => _ShowKeyDialogState();
}

class _ShowKeyDialogState extends State<_ShowKeyDialog> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: HerzogColors.warningAmber,
          ),
          const SizedBox(width: 8),
          const Text('API Key Created'),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warning banner.
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: HerzogColors.warningLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: HerzogColors.warningAmber),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: HerzogColors.warningAmber),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Copy this key now. You will not be able to see it again.',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: HerzogColors.warningAmber,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Key display.
            Text('Name: ${widget.response.name}'),
            const SizedBox(height: 4),
            Text('User ID: ${widget.response.userId}'),
            const SizedBox(height: 4),
            Text('Role: ${widget.response.role}'),
            const SizedBox(height: 12),
            const Text(
              'API Key:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: HerzogColors.lightGray,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: HerzogColors.borderGray),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      widget.response.key,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Copy to clipboard',
                    child: IconButton(
                      icon: Icon(
                        _copied ? Icons.check : Icons.copy,
                        color: _copied
                            ? HerzogColors.successGreen
                            : HerzogColors.navyBlue,
                      ),
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: widget.response.key),
                        );
                        setState(() => _copied = true);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('API key copied to clipboard'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_copied ? 'Done' : 'I have copied the key'),
        ),
      ],
    );
  }
}
