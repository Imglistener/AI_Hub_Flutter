import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/assistant.dart';
import '../assistant_api_service.dart';

class GeminiApiService extends AssistantApiService {
  const GeminiApiService({required this.apiKey});

  final String apiKey;

  // TODO: verify against https://ai.google.dev/gemini-api/docs/models
  static const _model = 'gemini-3.8-flash';

  Uri get _endpoint => Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$apiKey',
      );

  @override
  Future<String> sendMessage({
    required String prompt,
    required List<ChatMessage> history,
  }) async {
    final contents = [
      for (final m in history)
        {
          'role': m.isUser ? 'user' : 'model',
          'parts': [
            {'text': m.text}
          ],
        },
      {
        'role': 'user',
        'parts': [
          {'text': prompt}
        ],
      },
    ];

    http.Response response;
    try {
      response = await http.post(
        _endpoint,
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'contents': contents}),
      );
    } catch (_) {
      throw const AssistantApiException('Could not reach Gemini. Check your connection.');
    }

    if (response.statusCode == 400 || response.statusCode == 401 || response.statusCode == 403) {
      throw const AssistantApiException('Gemini rejected the API key.');
    }
        if (response.statusCode != 200) {
      String detail = response.body;
      try {
        final errorJson = jsonDecode(response.body) as Map<String, dynamic>;
        detail = (errorJson['error'] as Map<String, dynamic>?)?['message'] as String? ?? response.body;
      } catch (_) {
        // response wasn't JSON — fall back to raw body
      }
      throw AssistantApiException('Gemini error (${response.statusCode}): $detail');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List<dynamic>?;
    final parts = candidates?.isNotEmpty == true
        ? (candidates!.first['content']?['parts'] as List<dynamic>?)
        : null;
    final text = parts?.isNotEmpty == true ? parts!.first['text'] as String? : null;

    return text ?? '(No response text returned.)';
  }
}