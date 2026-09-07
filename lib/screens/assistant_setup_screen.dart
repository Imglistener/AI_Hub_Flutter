import 'package:flutter/material.dart';
import '../models/assistant.dart';
import '../models/custom_assistant_config.dart';
import '../services/api_key_service.dart';
import '../services/custom_assistant_service.dart';
import '../theme/app_theme.dart';

class AssistantSetupScreen extends StatefulWidget {
  const AssistantSetupScreen({
    super.key,
    required this.assistant,
    required this.isConnected,
  });

  final Assistant assistant;
  final bool isConnected;

  @override
  State<AssistantSetupScreen> createState() => _AssistantSetupScreenState();
}

class _AssistantSetupScreenState extends State<AssistantSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiKeyController = TextEditingController();
  final _endpointController = TextEditingController();
  final _modelController = TextEditingController();

  bool _obscureKey = true;
  bool _isSaving = false;
  bool _isConnected = false;

  bool get _isCustom => widget.assistant.id == 'custom';

  @override
  void initState() {
    super.initState();
    _isConnected = widget.isConnected;
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    if (_isCustom) {
      final config = await CustomAssistantService.instance.getConfig();
      if (!mounted || config == null) return;
      setState(() {
        _endpointController.text = config.endpoint;
        _modelController.text = config.model;
        _apiKeyController.text = config.apiKey;
        _isConnected = true;
      });
    } else {
      final existing = await ApiKeyService.instance.getKey(widget.assistant.id);
      if (!mounted || existing == null) return;
      setState(() {
        _apiKeyController.text = existing;
        _isConnected = true;
      });
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _endpointController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    if (_isCustom) {
      await CustomAssistantService.instance.saveConfig(
        CustomAssistantConfig(
          endpoint: _endpointController.text.trim(),
          apiKey: _apiKeyController.text.trim(),
          model: _modelController.text.trim(),
        ),
      );
    } else {
      await ApiKeyService.instance.saveKey(
        widget.assistant.id,
        _apiKeyController.text.trim(),
      );
    }

    if (!mounted) return;
    setState(() => _isSaving = false);
    Navigator.of(context).pop(true);
  }

  Future<void> _disconnect() async {
    if (_isCustom) {
      await CustomAssistantService.instance.deleteConfig();
    } else {
      await ApiKeyService.instance.deleteKey(widget.assistant.id);
    }
    if (!mounted) return;
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.assistant;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Connect ${a.name}'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: a.color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(a.icon, color: a.color, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.name,
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary)),
                          Text(
                            _isConnected ? 'Connected' : 'Not connected',
                            style: TextStyle(
                              color: _isConnected
                                  ? AppColors.success
                                  : AppColors.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                if (_isCustom) ...[
                  TextFormField(
                    controller: _endpointController,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Endpoint URL',
                      hintText: 'https://your-server.com/v1/chat/completions',
                      prefixIcon: Icon(Icons.link, color: AppColors.textSecondary),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Enter an endpoint URL';
                      if (!v.trim().startsWith('http')) return 'Must start with http:// or https://';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _modelController,
                    decoration: const InputDecoration(
                      labelText: 'Model name',
                      hintText: 'e.g. llama3, mixtral, gpt-4o',
                      prefixIcon: Icon(Icons.memory, color: AppColors.textSecondary),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Enter a model name' : null,
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _apiKeyController,
                  obscureText: _obscureKey,
                  decoration: InputDecoration(
                    labelText: _isCustom ? 'API key (optional)' : 'API key',
                    prefixIcon: const Icon(Icons.vpn_key_outlined,
                        color: AppColors.textSecondary),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureKey
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () =>
                          setState(() => _obscureKey = !_obscureKey),
                    ),
                  ),
                  validator: (v) {
                    if (_isCustom) return null; // optional for self-hosted setups
                    return (v == null || v.trim().length < 8)
                        ? 'Enter a valid API key'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  _isCustom
                      ? 'Assumes an OpenAI-compatible chat completions API. '
                        'Your endpoint and key are stored in this device\'s secure keychain.'
                      : 'Your key is stored in this device\'s secure keychain and is '
                        'only ever sent directly to ${a.name}\'s servers.',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.4, color: Colors.white),
                          )
                        : const Text('Save & connect'),
                  ),
                ),
                if (_isConnected) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _disconnect,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Disconnect'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}