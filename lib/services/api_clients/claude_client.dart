import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/assistant.dart';
import '../assistant_api_service.dart';

class ClaudeApiService extends AssistantApiService {
  const ClaudeApiService({required this.apiKey});

  final String apiKey;


  static const _model = 'claude-opus-5';
  static const _endpoint = 'https://api.anthropic.com/v1/messages';

  @override
  Future<String> sendMessage({
    required String prompt,
    required List<ChatMessage> history,
  }) async {
    final messages = [
      for (final m in history)
        {'role': m.isUser ? 'user' : 'assistant', 'content': m.text},
      {'role': 'user', 'content': prompt},
    ];

    http.Response response;
    try {
      response = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'content-type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': _model,
          'max_tokens': 1024,
          'messages': messages,
        }),
      );
    } catch (_) {
      throw const AssistantApiException('Could not reach Claude. Check your connection.');
    }

    if (response.statusCode == 401) {
      throw const AssistantApiException('Claude rejected the API key.');
    }
    if (response.statusCode != 200) {
      String detail = response.body;
      try {
        final errorJson = jsonDecode(response.body) as Map<String, dynamic>;
        detail = (errorJson['error'] as Map<String, dynamic>?)?['message'] as String? ?? response.body;
      } catch (_) {
        // response wasn't JSON — fall back to raw body
      }
      throw AssistantApiException('Claude error (${response.statusCode}): $detail');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final content = data['content'] as List<dynamic>?;
    final text = content
        ?.whereType<Map<String, dynamic>>()
        .firstWhere((b) => b['type'] == 'text', orElse: () => const {})['text']
        as String?;

    return text ?? '(No response text returned.)';
  }
}