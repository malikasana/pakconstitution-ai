import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/article_reference.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String _baseUrl = '';

  String get baseUrl => _baseUrl;

  void setUrl(String url) {
    _baseUrl = url.trim();
  }

  Future<ApiResponse> sendMessage({
    required String message,
    required List<Map<String, String>> context,
  }) async {
    if (_baseUrl.isEmpty) {
      throw Exception('API URL not set. Go to Settings and enter your backend URL.');
    }
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': message,
          'context': context,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ApiResponse(
          answer: data['answer'] as String,
          summary: data['summary'] as String?, // optional — null safe
          references: (data['references'] as List)
              .map((r) => ArticleReference.fromMap(r))
              .toList(),
        );
      }
      throw Exception('Server error: ${response.statusCode}');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}

class ApiResponse {
  final String answer;
  final String? summary;
  final List<ArticleReference> references;

  const ApiResponse({
    required this.answer,
    this.summary,
    required this.references,
  });
}