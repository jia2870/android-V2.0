import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/recommendation_model.dart';
import '../providers/theme_provider.dart';
import '../services/ai_advisor_chat_service.dart';
import '../utils/money_format.dart';

class AIAdvisorChatScreen extends StatefulWidget {
  const AIAdvisorChatScreen({super.key, required this.result});

  final RecommendationResult result;

  @override
  State<AIAdvisorChatScreen> createState() => _AIAdvisorChatScreenState();
}

class _AIAdvisorChatScreenState extends State<AIAdvisorChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <_ChatBubble>[];
  final _apiHistory = <AdvisorChatMessage>[];
  bool _sending = false;

  static const _suggestions = [
    'Why did you pick #1 over the others?',
    'What if I increase my budget by RM 50k?',
    'Why was my preferred area not included?',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _messages.add(_ChatBubble(isUser: true, text: text));
      _sending = true;
      _controller.clear();
    });
    _scrollToBottom();

    final reply = await AIAdvisorChatService.ask(
      result: widget.result,
      history: _apiHistory,
      userMessage: text,
    );

    if (!mounted) return;

    setState(() {
      _apiHistory.add(AdvisorChatMessage(role: 'user', content: text));
      _apiHistory.add(AdvisorChatMessage(role: 'assistant', content: reply));
      _messages.add(_ChatBubble(isUser: false, text: reply));
      _sending = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ask AI Advisor'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                _buildIntro(isDark),
                if (_messages.isEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Try asking:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final suggestion in _suggestions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ActionChip(
                        label: Text(suggestion),
                        onPressed: _sending ? null : () => _send(suggestion),
                      ),
                    ),
                ],
                for (final msg in _messages) ...[
                  const SizedBox(height: 10),
                  _MessageBubble(message: msg, isDark: isDark),
                ],
                if (_sending) ...[
                  const SizedBox(height: 12),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !_sending,
                      decoration: InputDecoration(
                        hintText: 'Ask a follow-up question…',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: _sending ? null : (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : () => _send(),
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntro(bool isDark) {
    final snap = widget.result.financialSnapshot;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.blue[50],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Follow-up about your ${widget.result.recommendations.length} picks',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.blue[900],
            ),
          ),
          if (snap != null && snap.monthlyIncome > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Income ${MoneyFormat.display(snap.monthlyIncome)} · '
              'DSR ${snap.currentDsrPercent.toStringAsFixed(1)}% · '
              'Budget ${MoneyFormat.display(snap.recommendedBudget)}',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChatBubble {
  const _ChatBubble({required this.isUser, required this.text});

  final bool isUser;
  final String text;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isDark});

  final _ChatBubble message;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final align =
        message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final color = message.isUser
        ? Colors.blue
        : (isDark ? const Color(0xFF1E1E2E) : Colors.grey[100]!);
    final textColor = message.isUser
        ? Colors.white
        : (isDark ? Colors.white70 : Colors.black87);

    return Column(
      crossAxisAlignment: align,
      children: [
        Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.82,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            message.text,
            style: TextStyle(color: textColor, height: 1.45),
          ),
        ),
      ],
    );
  }
}
