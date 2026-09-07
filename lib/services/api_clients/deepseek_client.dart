import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/assistant.dart';
import '../assistant_api_service.dart';

/// DeepSeek's API is OpenAI-compatible in shape.
class DeepSeekApiService extends AssistantApiService {
  const DeepSeekApiService({required this.apiKey});

  final String apiKey;

  // TODO: verify against https://api-docs.deepseek.com
  static const _model = 'deepseek-chat';
  static const _endpoint = 'https://api.deepseek.com/chat/completions';

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
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({'model': _model, 'messages': messages}),
      );
    } catch (_) {
      throw const AssistantApiException('Could not reach DeepSeek. Check your connection.');
    }

    if (response.statusCode == 401) {
      throw const AssistantApiException('DeepSeek rejected the API key.');
    }
    if (response.statusCode != 200) {
      String detail = response.body;
      try {
        final errorJson = jsonDecode(response.body) as Map<String, dynamic>;
        detail = (errorJson['error'] as Map<String, dynamic>?)?['message'] as String? ?? response.body;
      } catch (_) {
        // response wasn't JSON — fall back to raw body
      }
      throw AssistantApiException('DeepSeek error (${response.statusCode}): $detail');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = data['choices'] as List<dynamic>?;
    final text = choices?.isNotEmpty == true
        ? (choices!.first['message']?['content'] as String?)
        : null;

    return text ?? '(No response text returned.)';
  }
}