import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  SettingsService._();
  static final instance = SettingsService._();

  static const _smartTitlesKey = 'smart_titles_enabled';

  Future<bool> smartTitlesEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_smartTitlesKey) ?? false;
  }

  Future<void> setSmartTitlesEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_smartTitlesKey, value);
  }
}