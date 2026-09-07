import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores per-assistant API keys in the device's secure keychain/keystore.
/// Keys never leave the device and are never sent to our own backend.
class ApiKeyService {
  ApiKeyService._();
  static final instance = ApiKeyService._();

  final _storage = const FlutterSecureStorage();

  String _keyFor(String assistantId) => 'api_key_$assistantId';

  Future<void> saveKey(String assistantId, String apiKey) {
    return _storage.write(key: _keyFor(assistantId), value: apiKey);
  }

  Future<String?> getKey(String assistantId) {
    return _storage.read(key: _keyFor(assistantId));
  }

  Future<void> deleteKey(String assistantId) {
    return _storage.delete(key: _keyFor(assistantId));
  }

  Future<bool> hasKey(String assistantId) async {
    final key = await getKey(assistantId);
    return key != null && key.isNotEmpty;
  }
}