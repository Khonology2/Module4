import 'package:flutter/material.dart';
import '../services/backend_api_service.dart';

class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <Map<String, String>>[
    {
      'role': 'system',
      'content':
          'You are a helpful assistant for a project delivery and sign-off tool. Keep responses concise, practical, and safe. Do not fabricate data.',
    },
  ];

  bool _isSending = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
      _messages.add({'role': 'user', 'content': text});
      _controller.clear();
    });

    try {
      final resp = await BackendApiService()
          .aiChat(_messages, temperature: 0.4, maxTokens: 500);
      final data = resp.data is Map ? Map<String, dynamic>.from(resp.data as Map) : {};
      final content = (data['content'] ??
              (data['data'] is Map ? (data['data']['content'] ?? data['data']['message']) : null) ??
              data['message'])
          ?.toString()
          .trim();

      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': resp.isSuccess
              ? (content?.isNotEmpty == true ? content! : 'No response received.')
              : (resp.error ?? 'Request failed.'),
        });
      });
    } catch (e) {
      setState(() {
        _messages.add({'role': 'assistant', 'content': 'Error: $e'});
      });
    } finally {
      setState(() => _isSending = false);
      if (mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _messages.where((m) => m['role'] != 'system').toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Assistant'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: visible.length,
              itemBuilder: (context, index) {
                final m = visible[index];
                final role = (m['role'] ?? '').toLowerCase();
                final isUser = role == 'user';
                final content = m['content'] ?? '';
                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Card(
                      color: isUser
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(content),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Ask a question…',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _isSending ? null : _send,
                    child: Text(_isSending ? 'Sending…' : 'Send'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

