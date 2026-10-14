import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureStorageHelper {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  /// Retrieves an API key securely from KeyStore/Keychain.
  /// Automatically migrates any legacy plaintext keys from SharedPreferences.
  static Future<String> getApiKey(String key) async {
    try {
      final value = await _storage.read(key: key);
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    } catch (_) {}

    // Check and migrate legacy value from SharedPreferences if present
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacyValue = prefs.getString(key);
      if (legacyValue != null && legacyValue.trim().isNotEmpty) {
        final trimmed = legacyValue.trim();
        await _storage.write(key: key, value: trimmed);
        await prefs.remove(key); // Remove plaintext key after migrating
        return trimmed;
      }
    } catch (_) {}

    return '';
  }

  /// Saves an API key securely to KeyStore/Keychain and removes any plaintext copy.
  static Future<void> setApiKey(String key, String value) async {
    final trimmed = value.trim();
    try {
      if (trimmed.isEmpty) {
        await _storage.delete(key: key);
      } else {
        await _storage.write(key: key, value: trimmed);
      }
    } catch (_) {}

    // Ensure plaintext key is never retained in SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (_) {}
  }

  /// Deletes an API key from secure storage and SharedPreferences.
  static Future<void> deleteApiKey(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (_) {}
  }
}
