import 'package:flutter/material.dart';
import '../models/message.dart';
import '../services/database_service.dart';
import '../services/api_service.dart';
import '../providers/conversation_provider.dart';

class ChatProvider extends ChangeNotifier {
  final _db = DatabaseService();
  final _api = ApiService();

  List<Message> _messages = [];
  List<Map<String, String>> _contextWindow = [];
  bool _isLoading = false;
  String? _error;

  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get contextCount => (_contextWindow.length / 2).floor();

  int maxContextTurns = 3;

  Future<void> loadMessages(String conversationId) async {
    _messages = await _db.getMessages(conversationId);
    _rebuildContextWindow();
    notifyListeners();
  }

  void clearMessages() {
    _messages = [];
    _contextWindow = [];
    _error = null;
    notifyListeners();
  }

  Future<void> sendMessage({
    required String text,
    required String conversationId,
    required ConversationProvider convProvider,
    String? apiUrl,
  }) async {
    if (text.trim().isEmpty || _isLoading) return;

    if (apiUrl != null && apiUrl.isNotEmpty) {
      _api.setUrl(apiUrl);
    }

    _error = null;

    // Save and show user message
    final userMsg = Message(
      id: _uid(),
      conversationId: conversationId,
      role: MessageRole.user,
      content: text.trim(),
      references: [],
      createdAt: DateTime.now(),
    );

    await _db.insertMessage(userMsg);
    _messages.add(userMsg);
    _addToContext('user', text.trim()); // user always sends full content
    _isLoading = true;
    notifyListeners();

    await convProvider.touchConversation(conversationId);

    try {
      final response = await _api.sendMessage(
        message: text.trim(),
        context: List.from(_contextWindow),
      );

      // Save assistant message with summary
      final assistantMsg = Message(
        id: _uid(),
        conversationId: conversationId,
        role: MessageRole.assistant,
        content: response.answer,
        summary: response.summary, // store summary, never shown in UI
        references: response.references,
        createdAt: DateTime.now(),
      );

      await _db.insertMessage(assistantMsg);
      _messages.add(assistantMsg);

      // Context uses summary if available, falls back to full answer
      final contextContent = response.summary ?? response.answer;
      _addToContext('assistant', contextContent);

      // Prune old summaries — keep circular buffer at maxContextTurns
      await _db.pruneOldSummaries(conversationId, maxContextTurns);

      await convProvider.touchConversation(conversationId);
    } catch (e) {
      _error = 'Something went wrong. Please try again.';
    }

    _isLoading = false;
    notifyListeners();
  }

  void _addToContext(String role, String content) {
    _contextWindow.add({'role': role, 'content': content});
    final maxEntries = maxContextTurns * 2;
    if (_contextWindow.length > maxEntries) {
      _contextWindow = _contextWindow.sublist(_contextWindow.length - maxEntries);
    }
  }

  void _rebuildContextWindow() {
    // When loading old messages, use summary for assistant turns if available
    // falls back to full content if summary is null (old messages before this feature)
    _contextWindow = [];
    final maxEntries = maxContextTurns * 2;
    final recent = _messages.length > maxEntries
        ? _messages.sublist(_messages.length - maxEntries)
        : _messages;

    for (final m in recent) {
      final content = m.isAssistant
          ? (m.summary ?? m.content) // use summary if exists
          : m.content;               // user always uses full content
      _contextWindow.add({'role': m.role.name, 'content': content});
    }
  }

  void updateMaxContext(int turns) {
    maxContextTurns = turns;
    _rebuildContextWindow();
    notifyListeners();
  }

  String _uid() =>
      DateTime.now().millisecondsSinceEpoch.toRadixString(36) +
      (DateTime.now().microsecond).toRadixString(36);
}