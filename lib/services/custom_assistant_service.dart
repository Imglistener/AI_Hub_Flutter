import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/custom_assistant_config.dart';

/// Stores the single custom-assistant configuration (endpoint, key, model)
/// in the device's secure keychain/keystore, same as the other providers.
class CustomAssistantService {
  CustomAssistantService._();
  static final instance = CustomAssistantService._();

  final _storage = const FlutterSecureStorage();
  static const _key = 'custom_assistant_config';

  Future<void> saveConfig(CustomAssistantConfig config) {
    return _storage.write(key: _key, value: jsonEncode(config.toJson()));
  }

  Future<CustomAssistantConfig?> getConfig() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    try {
      return CustomAssistantConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteConfig() {
    return _storage.delete(key: _key);
  }

  Future<bool> hasConfig() async {
    final config = await getConfig();
    return config != null;
  }
}