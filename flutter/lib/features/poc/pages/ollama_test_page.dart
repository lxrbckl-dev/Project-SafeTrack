import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class OllamaTestPage extends StatefulWidget {
  const OllamaTestPage({super.key});

  @override
  State<OllamaTestPage> createState() => _OllamaTestPageState();
}

class _OllamaTestPageState extends State<OllamaTestPage> {
  final _controller = TextEditingController();
  String _response = '';
  bool _loading = false;
  String _status = 'Ready';
  int _latencyMs = 0;

  Future<void> _sendPrompt() async {
    if (_controller.text.isEmpty) return;

    setState(() {
      _loading = true;
      _response = '';
      _status = 'Sending to Qwen 2.5 3B...';
    });

    final stopwatch = Stopwatch()..start();

    try {
      final res = await http.post(
        Uri.parse('http://localhost:11434/api/generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': 'qwen2.5:3b',
          'prompt': _controller.text,
          'stream': false,
        }),
      );

      stopwatch.stop();

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _response = data['response'] ?? 'No response field';
          _latencyMs = stopwatch.elapsedMilliseconds;
          _status = 'Response received in ${_latencyMs}ms';
          _loading = false;
        });
      } else {
        setState(() {
          _status = 'Error: HTTP ${res.statusCode}';
          _response = res.body;
          _loading = false;
        });
      }
    } catch (e) {
      stopwatch.stop();
      setState(() {
        _status = 'Connection failed';
        _response = 'Error: $e\n\nIs Ollama running? Try: ollama serve';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ollama / Qwen Test'),
        backgroundColor: const Color(0xFF000000),
        foregroundColor: const Color(0xFFFFD100),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _status.startsWith('Error') || _status == 'Connection failed'
                  ? const Color(0xFFF8D7DA)
                  : _status.startsWith('Response')
                      ? const Color(0xFFD4EDDA)
                      : const Color(0xFFFFF3CD),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                if (_loading) ...[
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    _status,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (_latencyMs > 0)
                  Text(
                    '${_latencyMs}ms',
                    style: const TextStyle(
                      fontFamily: 'Courier New',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: 'Ask Qwen something...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _loading ? null : _sendPrompt,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A5F),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Send'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E5E5)),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  _response.isEmpty ? 'Response will appear here...' : _response,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    color: Color(0xFF58595B),
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
