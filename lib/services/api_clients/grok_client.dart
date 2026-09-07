import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/assistant.dart';
import '../assistant_api_service.dart';

/// xAI's API is OpenAI-compatible in shape.
class GrokApiService extends AssistantApiService {
  const GrokApiService({required this.apiKey});

  final String apiKey;

  // TODO: verify against https://docs.x.ai
  static const _model = 'grok-2-latest';
  static const _endpoint = 'https://api.x.ai/v1/chat/completions';

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
      throw const AssistantApiException('Could not reach Grok. Check your connection.');
    }

    if (response.statusCode == 401) {
      throw const AssistantApiException('Grok rejected the API key.');
    }
    if (response.statusCode != 200) {
      throw AssistantApiException('Grok error (${response.statusCode}).');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = data['choices'] as List<dynamic>?;
    final text = choices?.isNotEmpty == true
        ? (choices!.first['message']?['content'] as String?)
        : null;

    return text ?? '(No response text returned.)';
  }
}