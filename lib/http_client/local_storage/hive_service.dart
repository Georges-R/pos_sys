import 'package:hive_flutter/hive_flutter.dart';

class HiveService {
  static const String _userBox = 'userBox';
  static const String _settingsBox = 'settingsBox';
  static const String _itemsBox = 'itemsBox';
  static const String _clientsBox = 'clientsBox';
  static const String _salesBox = 'salesBox';

  static Future<void> init() async {
    await Hive.initFlutter();
    await _openBoxes();
    await migrateClientDataOutOfSalesBox();
  }

  static Future<void> _openBoxes() async {
    await Hive.openBox(_userBox);
    await Hive.openBox(_settingsBox);
    await Hive.openBox(_itemsBox);
    await Hive.openBox(_clientsBox);
    await Hive.openBox(_salesBox);
  }

  static Future<void> storeData(
      String boxName, String key, dynamic value) async {
    final box = Hive.box(boxName);
    await box.put(key, value);
  }

  static dynamic getData(String boxName, String key) {
    final box = Hive.box(boxName);
    return box.get(key);
  }

  static Future<void> deleteData(String boxName, String key) async {
    final box = Hive.box(boxName);
    await box.delete(key);
  }

  static Future<void> clearBox(String boxName) async {
    final box = Hive.box(boxName);
    await box.clear();
  }

  static bool hasData(String boxName, String key) {
    final box = Hive.box(boxName);
    return box.containsKey(key);
  }

  static List<dynamic> getAllKeys(String boxName) {
    final box = Hive.box(boxName);
    return box.keys.toList();
  }

  static List<dynamic> getAllValues(String boxName) {
    final box = Hive.box(boxName);
    return box.values.toList();
  }

  static Map<String, dynamic> getBox(String boxName) {
    final box = Hive.box(boxName);
    return box.toMap().map<String, dynamic>(
        (key, dynamic value) => MapEntry(key.toString(), normalize(value)));
  }

  /// Hive hands back `Map<dynamic, dynamic>` / `List<dynamic>` once a value
  /// has been through a disk round trip, which every `Map<String, dynamic>`
  /// cast downstream then trips over. Normalising on read keeps the rest of
  /// the app working with the shapes it was written with.
  static dynamic normalize(dynamic value) {
    if (value is Map) {
      return value.map<String, dynamic>(
          (key, dynamic v) => MapEntry(key.toString(), normalize(v)));
    }
    if (value is List) {
      return value.map<dynamic>(normalize).toList();
    }
    return value;
  }

  static List<Map<String, dynamic>> getMapList(String boxName, String key) {
    final raw = normalize(getData(boxName, key));
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw.whereType<Map<String, dynamic>>().toList();
  }

  static Future<void> storeUserData(String key, dynamic value) async {
    await storeData(_userBox, key, value);
  }

  static dynamic getUserData(String key) {
    return getData(_userBox, key);
  }

  static Future<void> storeSetting(String key, dynamic value) async {
    await storeData(_settingsBox, key, value);
  }

  static dynamic getSetting(String key) {
    return getData(_settingsBox, key);
  }

  static Future<void> storeItem(String key, dynamic value) async {
    await storeData(_itemsBox, key, value);
  }

  static dynamic getItem(String key) {
    return getData(_itemsBox, key);
  }

  static Future<void> storeClient(String key, dynamic value) async {
    await storeData(_clientsBox, key, value);
  }

  static dynamic getClient(String key) {
    return normalize(getData(_clientsBox, key));
  }

  static List<dynamic> getAllClients() {
    return getAllValues(_clientsBox);
  }

  /// Client-scoped storage. These used to share the sales box, which put the
  /// customer book and its payment history inside the sales ledger.
  static Future<void> setClientValue(String key, dynamic value) async {
    await storeData(_clientsBox, key, value);
  }

  static dynamic getClientValue(String key) {
    return normalize(getData(_clientsBox, key));
  }

  static List<Map<String, dynamic>> getClientMapList(String key) {
    return getMapList(_clientsBox, key);
  }

  static Future<void> storeSale(String key, dynamic value) async {
    await storeData(_salesBox, key, value);
  }

  static dynamic getSale(String key) {
    return normalize(getData(_salesBox, key));
  }

  static List<dynamic> getAllSales() {
    return getAllValues(_salesBox);
  }

  static Future<void> deleteSale(String key) async {
    await deleteData(_salesBox, key);
  }

  /// One-off cleanup for installs created before clients had their own box:
  /// the customer book and payment history were written into the sales box,
  /// where every sales report then read them as if they were sales.
  static Future<void> migrateClientDataOutOfSalesBox() async {
    final sales = Hive.box(_salesBox);
    final clientsBox = Hive.box(_clientsBox);
    final strayKeys = sales.keys
        .where((key) =>
            key == 'clients' ||
            (key is String &&
                key.startsWith('client_') &&
                key.endsWith('_history')))
        .toList();
    for (final key in strayKeys) {
      if (!clientsBox.containsKey(key)) {
        await clientsBox.put(key, sales.get(key));
      }
      await sales.delete(key);
    }
  }

  static Future<void> close() async {
    await Hive.close();
  }
}
