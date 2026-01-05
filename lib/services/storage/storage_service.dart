import 'package:hive_flutter/hive_flutter.dart';
import '../../core/utils/logger.dart';

class StorageService {
  static const String authBoxName = 'auth';
  static const String userBoxName = 'user';
  static const String settingsBoxName = 'settings';

  static Future<void> init() async {
    try {
      await Hive.initFlutter();
      await Hive.openBox(authBoxName);
      await Hive.openBox(userBoxName);
      await Hive.openBox(settingsBoxName);
      Logger.info('Storage initialized successfully');
    } catch (e) {
      Logger.error('Failed to initialize storage', e, null, 'StorageService');
      rethrow;
    }
  }

  // Auth storage
  static Future<void> saveAuthToken(String token) async {
    final box = Hive.box(authBoxName);
    await box.put('token', token);
  }

  static String? getAuthToken() {
    final box = Hive.box(authBoxName);
    return box.get('token');
  }

  static Future<void> saveRefreshToken(String token) async {
    final box = Hive.box(authBoxName);
    await box.put('refreshToken', token);
  }

  static String? getRefreshToken() {
    final box = Hive.box(authBoxName);
    return box.get('refreshToken');
  }

  static Future<void> clearAuth() async {
    final box = Hive.box(authBoxName);
    await box.clear();
  }

  // User storage
  static Future<void> saveUserData(Map<String, dynamic> userData) async {
    final box = Hive.box(userBoxName);
    await box.put('user', userData);
  }

  static Map<String, dynamic>? getUserData() {
    final box = Hive.box(userBoxName);
    final data = box.get('user');
    if (data == null) return null;
    // Convert dynamic map to Map<String, dynamic> recursively
    if (data is Map) {
      return _convertMap(data);
    }
    return null;
  }

  // Helper method to recursively convert Map<dynamic, dynamic> to Map<String, dynamic>
  static Map<String, dynamic> _convertMap(Map map) {
    return Map<String, dynamic>.fromEntries(
      map.entries.map((entry) {
        final key = entry.key.toString();
        final value = entry.value;

        if (value is Map) {
          return MapEntry(key, _convertMap(value));
        } else if (value is List) {
          return MapEntry(key, _convertList(value));
        } else {
          return MapEntry(key, value);
        }
      }),
    );
  }

  // Helper method to convert List with dynamic maps
  static List _convertList(List list) {
    return list.map((item) {
      if (item is Map) {
        return _convertMap(item);
      } else if (item is List) {
        return _convertList(item);
      }
      return item;
    }).toList();
  }

  static Future<void> clearUserData() async {
    final box = Hive.box(userBoxName);
    await box.clear();
  }

  // Settings storage
  static Future<void> saveSetting(String key, dynamic value) async {
    final box = Hive.box(settingsBoxName);
    await box.put(key, value);
  }

  static T? getSetting<T>(String key, {T? defaultValue}) {
    final box = Hive.box(settingsBoxName);
    return box.get(key, defaultValue: defaultValue) as T?;
  }

  // Preferences storage (for settings screen)
  static Future<void> savePreferences(Map<String, dynamic> prefs) async {
    final box = Hive.box(settingsBoxName);
    await box.put('preferences', prefs);
  }

  static Map<String, dynamic>? getPreferences() {
    final box = Hive.box(settingsBoxName);
    final data = box.get('preferences');
    if (data == null) return null;
    if (data is Map) {
      return _convertMap(data);
    }
    return null;
  }

  // Clear all storage
  static Future<void> clearAll() async {
    await clearAuth();
    await clearUserData();
    final box = Hive.box(settingsBoxName);
    await box.clear();
  }
}
