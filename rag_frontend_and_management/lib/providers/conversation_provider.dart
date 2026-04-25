import 'package:flutter/material.dart';
import '../models/conversation.dart';
import '../services/database_service.dart';

class ConversationProvider extends ChangeNotifier {
  final _db = DatabaseService();

  List<Conversation> _conversations = [];
  String? _activeId;

  List<Conversation> get conversations => _conversations;
  String? get activeId => _activeId;

  Future<void> loadConversations() async {
    _conversations = await _db.getAllConversations();
    notifyListeners();
  }

  Future<Conversation> createConversation(String firstMessage) async {
    final title = firstMessage.length > 45
        ? '${firstMessage.substring(0, 45)}…'
        : firstMessage;

    final conv = Conversation(
      id: _uid(),
      title: title,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _db.insertConversation(conv);
    await loadConversations();
    setActive(conv.id);
    return conv;
  }

  Future<Conversation?> getConversation(String id) async {
    return await _db.getConversation(id);
  }

  Future<void> renameConversation(String id, String newTitle) async {
    final conv = await _db.getConversation(id);
    if (conv == null) return;
    await _db.updateConversation(conv.copyWith(title: newTitle));
    await loadConversations();
  }

  Future<void> updateConversation(Conversation conv) async {
    await _db.updateConversation(conv);
    await loadConversations();
  }

  Future<void> touchConversation(String id) async {
    final conv = await _db.getConversation(id);
    if (conv == null) return;
    await _db.updateConversation(conv.copyWith(updatedAt: DateTime.now()));
    await loadConversations();
  }

  Future<void> deleteConversation(String id) async {
    await _db.deleteConversation(id);
    if (_activeId == id) _activeId = null;
    await loadConversations();
  }

  Future<void> deleteAll() async {
    await _db.deleteAllConversations();
    _activeId = null;
    await loadConversations();
  }

  void setActive(String? id) {
    _activeId = id;
    notifyListeners();
  }

  String _uid() =>
      DateTime.now().millisecondsSinceEpoch.toRadixString(36) +
      (DateTime.now().microsecond).toRadixString(36);
}