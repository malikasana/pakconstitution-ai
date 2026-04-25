import 'dart:convert';
import 'article_reference.dart';

enum MessageRole { user, assistant }

class Message {
  final String id;
  final String conversationId;
  final MessageRole role;
  final String content;
  final String? summary; // one-sentence summary for context, never shown to user
  final List<ArticleReference> references;
  final DateTime createdAt;
  final bool isLoading;

  const Message({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.references,
    required this.createdAt,
    this.summary,
    this.isLoading = false,
  });

  bool get isUser => role == MessageRole.user;
  bool get isAssistant => role == MessageRole.assistant;

  Message copyWith({
    String? content,
    String? summary,
    List<ArticleReference>? references,
    bool? isLoading,
  }) {
    return Message(
      id: id,
      conversationId: conversationId,
      role: role,
      content: content ?? this.content,
      summary: summary ?? this.summary,
      references: references ?? this.references,
      createdAt: createdAt,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'role': role.name,
      'content': content,
      'summary': summary,
      'refs': jsonEncode(references.map((r) => r.toMap()).toList()),
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    final refsRaw = map['refs'] as String? ?? '[]';
    final refsList = (jsonDecode(refsRaw) as List)
        .map((r) => ArticleReference.fromMap(r as Map<String, dynamic>))
        .toList();

    return Message(
      id: map['id'] as String,
      conversationId: map['conversation_id'] as String,
      role: MessageRole.values.firstWhere(
        (r) => r.name == map['role'],
        orElse: () => MessageRole.user,
      ),
      content: map['content'] as String,
      summary: map['summary'] as String?,
      references: refsList,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}