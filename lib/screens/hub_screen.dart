import 'dart:async';
import 'package:flutter/material.dart';
import '../models/assistant.dart';
import '../models/conversation.dart';
import '../services/api_key_service.dart';
import '../services/assistant_api_service.dart';
import '../services/assistant_registry.dart';
import '../services/conversation_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

const double _kWideBreakpoint = 900;
const double _kSidebarWidth = 280;

class HubScreen extends StatefulWidget {
  const HubScreen({super.key});

  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen> {
  final Set<String> _selectedIds = {kAssistants.first.id, kAssistants[1].id};
  final TextEditingController _composerController = TextEditingController();
  final Map<String, List<ChatMessage>> _conversations = {
    for (final a in kAssistants) a.id: <ChatMessage>[],
  };

  List<ConversationSummary> _history = [];
  bool _isLoadingHistory = true;
  bool _isLoadingTranscript = false;
  String? _activeConversationId;
  bool _sidebarCollapsed = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _composerController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final history = await ConversationService.instance.fetchConversations();
      if (!mounted) return;
      setState(() {
        _history = history;
        _isLoadingHistory = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingHistory = false);
    }
  }

  void _toggleAssistant(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _sendToAll() async {
    final text = _composerController.text.trim();
    if (text.isEmpty || _selectedIds.isEmpty) return;

    final targets = List<String>.from(_selectedIds);
    final preview = text.length > 80 ? '${text.substring(0, 80)}…' : text;

    setState(() {
      for (final id in targets) {
        _conversations[id]!.add(ChatMessage(text: text, isUser: true));
        _conversations[id]!.add(const ChatMessage(text: '', isUser: false, isLoading: true));
      }
    });
    _composerController.clear();

    var conversationId = _activeConversationId;

    if (conversationId == null) {
      final defaultTitle = text.length > 40 ? '${text.substring(0, 40)}…' : text;
      conversationId = await ConversationService.instance.createConversation(
        title: defaultTitle,
        preview: preview,
        assistantIds: targets,
      );
      if (!mounted) return;
      setState(() {
        _activeConversationId = conversationId;
        _history.insert(
          0,
          ConversationSummary(
            id: conversationId!,
            title: defaultTitle,
            preview: preview,
            timestamp: DateTime.now(),
            assistantIds: targets,
          ),
        );
      });

      if (await SettingsService.instance.smartTitlesEnabled()) {
        unawaited(_generateSmartTitle(conversationId, text, targets.first));
      }
    } else {
      final existingIndex = _history.indexWhere((c) => c.id == conversationId);
      final mergedAssistantIds = existingIndex == -1
          ? targets
          : {..._history[existingIndex].assistantIds, ...targets}.toList();

      await ConversationService.instance.updateConversationMeta(
        conversationId,
        preview: preview,
        assistantIds: mergedAssistantIds,
      );
      if (!mounted) return;
      setState(() {
        if (existingIndex != -1) {
          final updated = _history[existingIndex].copyWith(
            preview: preview,
            timestamp: DateTime.now(),
            assistantIds: mergedAssistantIds,
          );
          _history
            ..removeAt(existingIndex)
            ..insert(0, updated);
        }
      });
    }

    for (final id in targets) {
      unawaited(ConversationService.instance.addMessage(
        conversationId: conversationId,
        assistantId: id,
        role: 'user',
        content: text,
      ));
    }

    await Future.wait(targets.map((id) => _sendToOne(id, text, conversationId!)));
  }

  Future<void> _sendToOne(String assistantId, String prompt, String conversationId) async {
    String resultText;
    bool isError = false;

    final apiKey = await ApiKeyService.instance.getKey(assistantId);
    if (apiKey == null || apiKey.isEmpty) {
      resultText = 'Not connected. Add an API key in Settings → Manage assistants.';
      isError = true;
    } else {
      final client = AssistantApiRegistry.clientFor(assistantId, apiKey);
      if (client == null) {
        resultText = 'No client configured for this assistant.';
        isError = true;
      } else {
        final history = _conversations[assistantId]!
            .sublist(0, _conversations[assistantId]!.length - 2);
        try {
          resultText = await client.sendMessage(prompt: prompt, history: history);
        } on AssistantApiException catch (e) {
          resultText = e.message;
          isError = true;
        } catch (_) {
          resultText = 'Something went wrong. Please try again.';
          isError = true;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      final convo = _conversations[assistantId]!;
      convo.removeLast();
      convo.add(ChatMessage(text: resultText, isUser: false, isError: isError));
    });

    if (!isError) {
      unawaited(ConversationService.instance.addMessage(
        conversationId: conversationId,
        assistantId: assistantId,
        role: 'assistant',
        content: resultText,
      ));
    }
  }

  Future<void> _generateSmartTitle(
    String conversationId,
    String firstMessage,
    String assistantId,
  ) async {
    try {
      final apiKey = await ApiKeyService.instance.getKey(assistantId);
      if (apiKey == null || apiKey.isEmpty) return;
      final client = AssistantApiRegistry.clientFor(assistantId, apiKey);
      if (client == null) return;

      final rawTitle = await client.sendMessage(
        prompt: 'Summarize the following message as a short, plain title of '
            '6 words or fewer. No quotation marks, no trailing punctuation. '
            'Message: "$firstMessage"',
        history: const [],
      );
      final cleanTitle = rawTitle.trim().replaceAll('"', '');
      if (cleanTitle.isEmpty) return;

      await ConversationService.instance.updateConversationMeta(
        conversationId,
        title: cleanTitle,
      );
      if (!mounted) return;
      setState(() {
        final index = _history.indexWhere((c) => c.id == conversationId);
        if (index != -1) {
          _history[index] = _history[index].copyWith(title: cleanTitle);
        }
      });
    } catch (_) {
      // Best-effort — keep the fallback (truncated-text) title on failure.
    }
  }

  void _startNewChat() {
    setState(() {
      _activeConversationId = null;
      for (final id in _conversations.keys) {
        _conversations[id] = [];
      }
    });
    if (MediaQuery.of(context).size.width < _kWideBreakpoint) {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _selectConversation(String id) async {
    final summary = _history.firstWhere((c) => c.id == id);

    setState(() {
      _activeConversationId = id;
      _selectedIds
        ..clear()
        ..addAll(summary.assistantIds);
      for (final key in _conversations.keys) {
        _conversations[key] = [];
      }
      _isLoadingTranscript = true;
    });

    if (MediaQuery.of(context).size.width < _kWideBreakpoint) {
      Navigator.of(context).maybePop();
    }

    final transcript = await ConversationService.instance
        .fetchTranscript(id, summary.assistantIds);
    if (!mounted) return;
    setState(() {
      for (final entry in transcript.entries) {
        _conversations[entry.key] = entry.value;
      }
      _isLoadingTranscript = false;
    });
  }
  

  @override
  Widget build(BuildContext context) {
    final selectedAssistants =
        kAssistants.where((a) => _selectedIds.contains(a.id)).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _kWideBreakpoint;

        final sidebar = _HistorySidebar(
          conversations: _history,
          activeId: _activeConversationId,
          isLoading: _isLoadingHistory,
          onSelect: _selectConversation,
          onNewChat: _startNewChat,
        );

        return Scaffold(
          drawer: isWide ? null : Drawer(child: sidebar),
          appBar: AppBar(
            backgroundColor: AppColors.background,
            elevation: 0,
            titleSpacing: isWide ? 24 : 4,
            leading: isWide
                ? IconButton(
                    icon: Icon(
                      _sidebarCollapsed
                          ? Icons.view_sidebar_outlined
                          : Icons.view_sidebar,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () =>
                        setState(() => _sidebarCollapsed = !_sidebarCollapsed),
                  )
                : null,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: AppColors.accentGradient,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.hub_outlined, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Nexus',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: AppColors.textSecondary),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                ),
                child: const CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.surfaceElevated,
                  child: Icon(Icons.person_outline, size: 18, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
          body: Row(
            children: [
              if (isWide && !_sidebarCollapsed) ...[
                SizedBox(width: _kSidebarWidth, child: sidebar),
                const VerticalDivider(width: 1, color: AppColors.border),
              ],
              Expanded(
                child: Column(
                  children: [
                    _AssistantSelector(
                      selectedIds: _selectedIds,
                      onToggle: _toggleAssistant,
                    ),
                    const Divider(height: 1, color: AppColors.border),
                    Expanded(
                      child: _isLoadingTranscript
                          ? const Center(child: CircularProgressIndicator())
                          : selectedAssistants.isEmpty
                              ? const _EmptyState()
                              : _ResponseGrid(
                                  assistants: selectedAssistants,
                                  conversations: _conversations,
                                ),
                    ),
                    _Composer(
                      controller: _composerController,
                      onSend: _sendToAll,
                      enabled: _selectedIds.isNotEmpty,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
// ── History sidebar ─────────────────────────────────────────────────────

class _HistorySidebar extends StatefulWidget {
  const _HistorySidebar({
    required this.conversations,
    required this.activeId,
    required this.isLoading,
    required this.onSelect,
    required this.onNewChat,
  });

  final List<ConversationSummary> conversations;
  final String? activeId;
  final bool isLoading;
  final ValueChanged<String> onSelect;
  final VoidCallback onNewChat;

  @override
  State<_HistorySidebar> createState() => _HistorySidebarState();
}

class _HistorySidebarState extends State<_HistorySidebar> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _groupLabel(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(timestamp.year, timestamp.month, timestamp.day);
    final diff = today.difference(date).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff <= 7) return 'Previous 7 days';
    return 'Older';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.conversations
        .where((c) =>
            _query.isEmpty || c.title.toLowerCase().contains(_query.toLowerCase()))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final grouped = <String, List<ConversationSummary>>{};
    for (final c in filtered) {
      grouped.putIfAbsent(_groupLabel(c.timestamp), () => []).add(c);
    }
    const order = ['Today', 'Yesterday', 'Previous 7 days', 'Older'];
    final groupKeys = order.where((k) => grouped.containsKey(k)).toList();

    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: widget.onNewChat,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New chat'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.centerLeft,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Search chats',
                prefixIcon: Icon(Icons.search, size: 18, color: AppColors.textMuted),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: widget.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.only(top: 40),
                          child: Text(
                            'No conversations found',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                          ),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        children: [
                          for (final key in groupKeys) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(10, 14, 10, 6),
                              child: Text(
                                key.toUpperCase(),
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                            for (final c in grouped[key]!)
                              _HistoryTile(
                                conversation: c,
                                selected: c.id == widget.activeId,
                                onTap: () => widget.onSelect(c.id),
                              ),
                          ],
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.conversation,
    required this.selected,
    required this.onTap,
  });

  final ConversationSummary conversation;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? AppColors.surfaceElevated : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  conversation.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? AppColors.textPrimary : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  conversation.preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
