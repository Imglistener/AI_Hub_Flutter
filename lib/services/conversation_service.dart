import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/assistant.dart';
import '../models/conversation.dart';

class ConversationService {
  ConversationService._();
  static final instance = ConversationService._();

  SupabaseClient get _client => Supabase.instance.client;

  Future<String> createConversation({
    required String title,
    required String preview,
    required List<String> assistantIds,
  }) async {
    final userId = _client.auth.currentUser!.id;
    final row = await _client
        .from('conversations')
        .insert({
          'user_id': userId,
          'title': title,
          'preview': preview,
          'assistant_ids': assistantIds,
        })
        .select()
        .single();
    return row['id'] as String;
  }

  Future<void> updateConversationMeta(
    String id, {
    String? title,
    String? preview,
    List<String>? assistantIds,
  }) async {
    final updates = <String, dynamic>{'updated_at': DateTime.now().toIso8601String()};
    if (title != null) updates['title'] = title;
    if (preview != null) updates['preview'] = preview;
    if (assistantIds != null) updates['assistant_ids'] = assistantIds;
    await _client.from('conversations').update(updates).eq('id', id);
  }

  Future<void> addMessage({
    required String conversationId,
    required String assistantId,
    required String role,
    required String content,
  }) async {
    await _client.from('messages').insert({
      'conversation_id': conversationId,
      'assistant_id': assistantId,
      'role': role,
      'content': content,
    });
  }

  Future<List<ConversationSummary>> fetchConversations() async {
    final userId = _client.auth.currentUser!.id;
    final rows = await _client
        .from('conversations')
        .select()
        .eq('user_id', userId)
        .order('updated_at', ascending: false);
    return (rows as List<dynamic>)
        .map((r) => ConversationSummary.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, List<ChatMessage>>> fetchTranscript(
    String conversationId,
    List<String> assistantIds,
  ) async {
    final rows = await _client
        .from('messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true);

    final result = {for (final id in assistantIds) id: <ChatMessage>[]};
    for (final r in (rows as List<dynamic>).cast<Map<String, dynamic>>()) {
      final assistantId = r['assistant_id'] as String;
      result.putIfAbsent(assistantId, () => <ChatMessage>[]);
      result[assistantId]!.add(ChatMessage(
        text: r['content'] as String,
        isUser: r['role'] == 'user',
      ));
    }
    return result;
  }
}