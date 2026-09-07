import 'package:flutter/material.dart';
import '../models/assistant.dart';
import '../services/api_key_service.dart';
import '../services/custom_assistant_service.dart';
import '../theme/app_theme.dart';
import 'assistant_setup_screen.dart';

class ManageAssistantsScreen extends StatefulWidget {
  const ManageAssistantsScreen({super.key});

  @override
  State<ManageAssistantsScreen> createState() =>
      _ManageAssistantsScreenState();
}

class _ManageAssistantsScreenState extends State<ManageAssistantsScreen> {
  Map<String, bool> _connected = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConnections();
  }

  Future<void> _loadConnections() async {
    final entries = await Future.wait(kAssistants.map((a) async {
      final isConnected = a.id == 'custom'
          ? await CustomAssistantService.instance.hasConfig()
          : await ApiKeyService.instance.hasKey(a.id);
      return MapEntry(a.id, isConnected);
    }));
    if (!mounted) return;
    setState(() {
      _connected = Map.fromEntries(entries);
      _isLoading = false;
    });
  }

  Future<void> _openSetup(Assistant a) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => AssistantSetupScreen(
          assistant: a,
          isConnected: _connected[a.id] ?? false,
        ),
      ),
    );
    if (result != null) {
      setState(() => _connected[a.id] = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Manage assistants'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: kAssistants.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final a = kAssistants[index];
                  final isConnected = _connected[a.id] ?? false;
                  return _AssistantTile(
                    assistant: a,
                    isConnected: isConnected,
                    onTap: () => _openSetup(a),
                  );
                },
              ),
      ),
    );
  }
}

class _AssistantTile extends StatelessWidget {
  const _AssistantTile({
    required this.assistant,
    required this.isConnected,
    required this.onTap,
  });

  final Assistant assistant;
  final bool isConnected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: assistant.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(assistant.icon, color: assistant.color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      assistant.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isConnected ? 'Connected' : 'Not connected',
                      style: TextStyle(
                        color:
                            isConnected ? AppColors.success : AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isConnected
                    ? Icons.check_circle
                    : Icons.arrow_forward_ios_rounded,
                size: isConnected ? 20 : 14,
                color: isConnected ? AppColors.success : AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}