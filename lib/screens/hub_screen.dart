import 'dart:async';
import 'package:flutter/material.dart';
import '../models/assistant.dart';
import '../models/conversation.dart';
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

    final client = await AssistantApiRegistry.build(assistantId);
    if (client == null) {
      resultText = assistantId == 'custom'
          ? 'Not connected. Set up your custom assistant in Settings → Manage assistants.'
          : 'Not connected. Add an API key in Settings → Manage assistants.';
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
      final client = await AssistantApiRegistry.build(assistantId);
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
                    color: AppColors.textPrimary,
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

// ── Assistant selector, response grid, composer ─────────────────────────

class _AssistantSelector extends StatelessWidget {
  const _AssistantSelector({required this.selectedIds, required this.onToggle});

  final Set<String> selectedIds;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: kAssistants.map((a) {
            final selected = selectedIds.contains(a.id);
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: _AssistantChip(
                assistant: a,
                selected: selected,
                onTap: () => onToggle(a.id),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _AssistantChip extends StatelessWidget {
  const _AssistantChip({
    required this.assistant,
    required this.selected,
    required this.onTap,
  });

  final Assistant assistant;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? assistant.color.withValues(alpha: 0.14) : AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? assistant.color : AppColors.border,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(assistant.icon, size: 16, color: assistant.color),
              const SizedBox(width: 8),
              Text(
                assistant.name,
                style: TextStyle(
                  color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 6),
                Icon(Icons.check_circle, size: 14, color: assistant.color),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.forum_outlined, size: 40, color: AppColors.textMuted),
          const SizedBox(height: 12),
          const Text(
            'Select at least one assistant to start',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ResponseGrid extends StatelessWidget {
  const _ResponseGrid({required this.assistants, required this.conversations});

  final List<Assistant> assistants;
  final Map<String, List<ChatMessage>> conversations;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 700;
      final columns = isWide ? assistants.length.clamp(1, 3) : 1;

      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          childAspectRatio: isWide ? 0.72 : 1.5,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: assistants.length,
        itemBuilder: (context, index) {
          final a = assistants[index];
          return _AssistantPanel(assistant: a, messages: conversations[a.id]!);
        },
      );
    });
  }
}

class _AssistantPanel extends StatelessWidget {
  const _AssistantPanel({required this.assistant, required this.messages});

  final Assistant assistant;
  final List<ChatMessage> messages;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Icon(assistant.icon, size: 16, color: assistant.color),
                const SizedBox(width: 8),
                Text(
                  assistant.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Text(
                      'No messages yet',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      final m = messages[i];
                      return _MessageBubble(message: m, accent: assistant.color);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.accent});

  final ChatMessage message;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 260),
        decoration: BoxDecoration(
          color: message.isError
              ? AppColors.error.withValues(alpha: 0.14)
              : (isUser ? accent.withValues(alpha: 0.16) : AppColors.surfaceElevated),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: message.isError
                ? AppColors.error.withValues(alpha: 0.4)
                : (isUser ? accent.withValues(alpha: 0.4) : AppColors.border),
          ),
        ),
        child: message.isLoading
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: accent),
              )
            : Text(
                message.text,
                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.35),
              ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend, required this.enabled});

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: enabled
                      ? 'Message all selected assistants…'
                      : 'Select an assistant to begin',
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              decoration: BoxDecoration(
                gradient: enabled ? AppColors.accentGradient : null,
                color: enabled ? null : AppColors.surfaceElevated,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_upward, color: Colors.white),
                onPressed: enabled ? onSend : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}