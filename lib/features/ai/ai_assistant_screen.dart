import 'package:flutter/material.dart';

import '../../data/repositories/ai_assistant_repository.dart';
import '../../shared/widgets.dart';

class _ChatMessage {
  final String text;
  final bool fromUser;
  const _ChatMessage(this.text, this.fromUser);
}

/// AI Assistant (MedGuardian AI CORE-adjacent feature): "Chat/voice input +
/// answer cards — ask medicine-related questions in simple language."
///
/// Voice input isn't built (MedGuardian AI lists Tamil/English voice
/// support as a BONUS, "if time permits" item) — this is the text-chat
/// core. Answers come from [AiAssistantRepository], which is a local FAQ
/// stub until the Gemini/API work is picked back up; see that file's doc
/// comment for exactly where the real call plugs in.
class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final _repo = AiAssistantRepository();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<_ChatMessage> _messages = [
    const _ChatMessage(
      "Hi! Ask me about your medicines, doses, or reminders in simple "
      "language. I'm not a doctor, so I'll always point you to one for "
      "anything medical.",
      false,
    ),
  ];
  bool _sending = false;

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _messages.add(_ChatMessage(text, true));
      _input.clear();
      _sending = true;
    });
    _scrollToEnd();
    final answer = await _repo.ask(text);
    if (!mounted) return;
    setState(() {
      _messages.add(_ChatMessage(answer, false));
      _sending = false;
    });
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('AI Assistant')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: DisclaimerBanner(
              message:
                  'Answers here are explanations, not medical advice. For '
                  'anything about your specific condition, talk to your '
                  'doctor or caregiver.',
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _messages.length + (_sending ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= _messages.length) {
                  return _bubble(context, 'Thinking…', false, scheme);
                }
                final m = _messages[index];
                return _bubble(context, m.text, m.fromUser, scheme);
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
                      controller: _input,
                      decoration: const InputDecoration(
                        hintText: 'Ask about your medicines…',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _send(),
                      textInputAction: TextInputAction.send,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send_outlined),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(BuildContext context, String text, bool fromUser, ColorScheme scheme) {
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: fromUser ? scheme.primaryContainer : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: fromUser ? scheme.onPrimaryContainer : scheme.onSurface,
          ),
        ),
      ),
    );
  }
}
