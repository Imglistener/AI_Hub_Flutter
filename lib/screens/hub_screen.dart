import 'package:flutter/material.dart';
import '../models/assistant.dart';
import '../theme/app_theme.dart';

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

  @override
  void dispose() {
    _composerController.dispose();
    super.dispose();
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

  void _sendToAll() {
    final text = _composerController.text.trim();
    if (text.isEmpty || _selectedIds.isEmpty) return;

    setState(() {
      for (final id in _selectedIds) {
        _conversations[id]!.add(ChatMessage(text: text, isUser: true));
        _conversations[id]!.add(const ChatMessage(text: '', isUser: false, isLoading: true));
      }
    });
    _composerController.clear();

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() {
        for (final id in _selectedIds) {
          final convo = _conversations[id]!;
          convo.removeLast();
          convo.add(ChatMessage(
            text: 'This is a placeholder reply from '
                '${kAssistants.firstWhere((a) => a.id == id).name}.',
            isUser: false,
          ));
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedAssistants =
        kAssistants.where((a) => _selectedIds.contains(a.id)).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        titleSpacing: 24,
        title: Row(
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
            onPressed: () {},
          ),
          const SizedBox(width: 8),
          const CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.surfaceElevated,
            child: Icon(Icons.person_outline, size: 18, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          _AssistantSelector(
            selectedIds: _selectedIds,
            onToggle: _toggleAssistant,
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: selectedAssistants.isEmpty
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
    );
  }
}

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
          color: isUser ? accent.withValues(alpha: 0.16) : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isUser ? accent.withValues(alpha: 0.4) : AppColors.border,
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