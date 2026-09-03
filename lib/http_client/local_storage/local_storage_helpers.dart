import 'dart:convert';
import 'hive_service.dart';

class LocalStorageHelpers {
  static Future<void> storeJson(
      String boxName, String key, Map<String, dynamic> json) async {
    final jsonString = jsonEncode(json);
    await HiveService.storeData(boxName, key, jsonString);
  }

  static Map<String, dynamic>? getJson(String boxName, String key) {
    final jsonString = HiveService.getData(boxName, key);
    if (jsonString != null && jsonString is String) {
      try {
        return jsonDecode(jsonString);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  static Future<void> storeJsonList(
      String boxName, String key, List<Map<String, dynamic>> jsonList) async {
    final jsonString = jsonEncode(jsonList);
    await HiveService.storeData(boxName, key, jsonString);
  }

  static List<Map<String, dynamic>>? getJsonList(String boxName, String key) {
    final jsonString = HiveService.getData(boxName, key);
    if (jsonString != null && jsonString is String) {
      try {
        final decoded = jsonDecode(jsonString);
        if (decoded is List) {
          return decoded.map((item) => item as Map<String, dynamic>).toList();
        }
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  static Future<void> storeValue<T>(String boxName, String key, T value) async {
    await HiveService.storeData(boxName, key, value);
  }

  static T? getValue<T>(String boxName, String key) {
    final value = HiveService.getData(boxName, key);
    if (value is T) {
      return value;
    }
    return null;
  }

  static bool hasKey(String boxName, String key) {
    return HiveService.hasData(boxName, key);
  }

  static Future<void> removeKey(String boxName, String key) async {
    await HiveService.deleteData(boxName, key);
  }

  static Future<void> clearBox(String boxName) async {
    await HiveService.clearBox(boxName);
  }

  static List<dynamic> getAllKeys(String boxName) {
    return HiveService.getAllKeys(boxName);
  }

  static List<dynamic> getAllValues(String boxName) {
    return HiveService.getAllValues(boxName);
  }
}
