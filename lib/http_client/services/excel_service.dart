import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'package:uuid/uuid.dart';

import '../../core/helpers/money.dart';
import '../local_storage/hive_service.dart';
import '../local_storage/local_storage_helpers.dart';
import 'clients_service.dart';

class ExcelService {
  static const Uuid _uuid = Uuid();
  static const String _settingsSheet = 'Settings';
  static const String _clientsSheet = 'Clients';
  static const String _itemsSheet = 'Items';
  static const String _salesSheet = 'Sales';

  /// Builds the backup workbook from whatever is in storage.
  ///
  /// Kept separate from the file write so the round trip can be exercised
  /// without a filesystem or a file picker.
  static Future<Excel> buildWorkbook() async {
    final excel = Excel.createExcel();
    excel.delete('Sheet1');

    await _exportSettings(excel);
    await _exportClients(excel);
    await _exportItems(excel);
    await _exportSales(excel);

    return excel;
  }

  /// Applies a backup workbook to storage. Returns false if nothing usable
  /// was found, so the caller does not report a successful restore.
  static Future<bool> applyWorkbook(Excel excel) async {
    final sheets = excel.tables.keys.toSet();
    if (!sheets.contains(_settingsSheet) &&
        !sheets.contains(_clientsSheet) &&
        !sheets.contains(_itemsSheet) &&
        !sheets.contains(_salesSheet)) {
      debugPrint('Workbook has none of the expected sheets');
      return false;
    }

    if (sheets.contains(_settingsSheet)) await _importSettings(excel);
    if (sheets.contains(_clientsSheet)) await _importClients(excel);
    if (sheets.contains(_itemsSheet)) await _importItems(excel);
    if (sheets.contains(_salesSheet)) await _importSales(excel);
    return true;
  }

  static Future<String?> exportToExcel() async {
    try {
      final excel = await buildWorkbook();

      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'POS_Backup_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final filePath = '${directory.path}/$fileName';

      final bytes = excel.encode();
      if (bytes == null) {
        debugPrint('Excel encoding produced no bytes');
        return null;
      }
      await File(filePath).writeAsBytes(bytes);

      return filePath;
    } catch (e) {
      debugPrint('Error exporting to Excel: $e');
      return null;
    }
  }

  static Future<bool> importFromExcel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      final path = result?.files.single.path;
      if (path == null) {
        return false;
      }

      final bytes = await File(path).readAsBytes();
      return applyWorkbook(Excel.decodeBytes(bytes));
    } catch (e) {
      debugPrint('Error importing from Excel: $e');
      return false;
    }
  }

  static Future<void> _exportSettings(Excel excel) async {
    final sheet = excel[_settingsSheet];
    if (sheet.rows.isEmpty) {
      sheet.appendRow([
        'Key',
        'Value',
      ]);
    }

    try {
      final settingsData = HiveService.getBox('settingsBox');
      for (var entry in settingsData.entries) {
        sheet.appendRow([
          entry.key.toString(),
          entry.value?.toString() ?? '',
        ]);
      }
    } catch (e) {
      debugPrint('Error exporting settings: $e');
    }
  }

  static Future<void> _exportClients(Excel excel) async {
    final sheet = excel[_clientsSheet];
    if (sheet.rows.isEmpty) {
      sheet.appendRow([
        'ID',
        'Name',
        'Phone',
        'Created Date',
        'Status',
      ]);
    }

    try {
      final clients = ClientsService.getAllClients();
      {
        for (final client in clients) {
          {
            sheet.appendRow([
              client['id'] ?? '',
              client['name'] ?? '',
              client['phone'] ?? '',
              client['createdDate'] ?? '',
              client['status'] ?? 'active',
            ]);
          }
        }
      }
    } catch (e) {
      debugPrint('Error exporting clients: $e');
    }
  }

  static Future<void> _exportItems(Excel excel) async {
    final sheet = excel[_itemsSheet];
    if (sheet.rows.isEmpty) {
      sheet.appendRow([
        'Description',
        'Category',
        'Barcode',
        'Quantity',
        'Cost Price',
        'TVA Percent',
        'Price After TVA',
        'Profit Percent',
        'Selling Price',
      ]);
    }

    try {
      final products =
          LocalStorageHelpers.getJsonList('itemsBox', 'products') ??
              <Map<String, dynamic>>[];
      {
        for (final product in products) {
          {
            sheet.appendRow([
              product['description'] ?? '',
              product['category'] ?? '',
              product['barcode'] ?? '',
              product['quantity'] ?? 0,
              product['cost_price'] ?? 0.0,
              product['tva_percent'] ?? 0.0,
              product['price_after_tva'] ?? 0.0,
              product['profit_percent'] ?? 0.0,
              product['selling_price'] ?? 0.0,
            ]);
          }
        }
      }

      final categories =
          LocalStorageHelpers.getJsonList('itemsBox', 'categories') ??
              <Map<String, dynamic>>[];
      if (categories.isNotEmpty) {
        sheet.appendRow([]);
        sheet.appendRow(['Categories:']);
        for (final category in categories) {
          sheet.appendRow([category['name'] ?? '']);
        }
      }
    } catch (e) {
      debugPrint('Error exporting items: $e');
    }
  }

  static Future<void> _exportSales(Excel excel) async {
    final sheet = excel[_salesSheet];
    if (sheet.rows.isEmpty) {
      sheet.appendRow([
        'ID',
        'Type',
        'Client ID',
        'Items',
        'Total USD',
        'Total LBP',
        'Exchange Rate',
        'TVA',
        'Date',
        'Status',
      ]);
    }

    try {
      final salesMap = HiveService.getBox('salesBox');
      for (var entry in salesMap.entries) {
        final sale = entry.value;
        if (sale is Map) {
          sheet.appendRow([
            sale['id'] ?? '',
            sale['type'] ?? '',
            sale['clientId'] ?? '',
            sale['items']?.toString() ?? '',
            sale['totalUSD'] ?? 0.0,
            sale['totalLBP'] ?? 0.0,
            sale['exchangeRate'] ?? 0.0,
            sale['tva'] ?? 0.0,
            sale['date'] ?? '',
            sale['status'] ?? '',
          ]);
        }
      }
    } catch (e) {
      debugPrint('Error exporting sales: $e');
    }
  }

  static Future<void> _importSettings(Excel excel) async {
    try {
      final sheet = excel[_settingsSheet];
      if (sheet.rows.isEmpty) return;

      for (int i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];

        if (row.length >= 2 && row[0]?.value != null && row[1]?.value != null) {
          final keyValue = row[0]?.value;
          final valueValue = row[1]?.value;
          if (keyValue != null && valueValue != null) {
            String key = keyValue.toString();
            String valueString = valueValue.toString();

            if (key.isNotEmpty) {
              final number = num.tryParse(valueString);
              await HiveService.storeSetting(key, number ?? valueString);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error importing settings: $e');
    }
  }

  static Future<void> _importClients(Excel excel) async {
    try {
      final sheet = excel[_clientsSheet];
      if (sheet.rows.isEmpty) return;

      final header = _headerIndex(sheet);
      if (!_hasColumns(header, ['id', 'name'])) {
        debugPrint('Clients sheet is missing an ID or Name column; skipping');
        return;
      }

      final clients = <Map<String, dynamic>>[];
      for (int i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        final name = _getCellString(_cell(row, header, 'Name'));
        // Only the name is essential. Requiring every cell to be filled meant
        // one customer with no phone number was dropped from the import.
        if (name.isEmpty) continue;
        final id = _getCellString(_cell(row, header, 'ID'));
        final status = _getCellString(_cell(row, header, 'Status'));
        clients.add({
          'id': id.isEmpty ? _uuid.v4() : id,
          'name': name,
          'phone': _getCellString(_cell(row, header, 'Phone')),
          'createdDate': _getCellString(_cell(row, header, 'Created Date')),
          'status': status.isEmpty ? 'active' : status,
        });
      }

      // An import that parsed nothing must not be allowed to wipe the
      // customer book and still report success.
      if (clients.isEmpty && ClientsService.getAllClients().isNotEmpty) {
        debugPrint('Clients sheet held no usable rows; keeping existing data');
        return;
      }

      await HiveService.setClientValue('clients', clients);
    } catch (e) {
      debugPrint('Error importing clients: $e');
    }
  }

  static Future<void> _importItems(Excel excel) async {
    try {
      final sheet = excel[_itemsSheet];
      if (sheet.rows.isEmpty) return;

      final header = _headerIndex(sheet);
      if (!_hasColumns(header, ['description'])) {
        debugPrint('Items sheet is missing a Description column; skipping');
        return;
      }

      final products = <Map<String, dynamic>>[];
      final categories = <String>{};

      for (int i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        if (row.isEmpty || row.every((cell) => cell?.value == null)) continue;

        final description = _getCellString(_cell(row, header, 'Description'));
        // The export appends a "Categories:" block below the products.
        if (description.isEmpty || description.startsWith('Categories:')) {
          continue;
        }

        final category = _getCellString(_cell(row, header, 'Category'));
        products.add({
          'description': description,
          'category': category,
          'barcode': _getCellString(_cell(row, header, 'Barcode')),
          'quantity': _parseInt(_cell(row, header, 'Quantity')?.toString()),
          'cost_price':
              _parseDouble(_cell(row, header, 'Cost Price')?.toString()),
          'tva_percent':
              _parseDouble(_cell(row, header, 'TVA Percent')?.toString()),
          'price_after_tva':
              _parseDouble(_cell(row, header, 'Price After TVA')?.toString()),
          'profit_percent':
              _parseDouble(_cell(row, header, 'Profit Percent')?.toString()),
          'selling_price':
              _parseDouble(_cell(row, header, 'Selling Price')?.toString()),
        });
        if (category.isNotEmpty) categories.add(category);
      }

      final existing =
          LocalStorageHelpers.getJsonList('itemsBox', 'products') ??
              const <Map<String, dynamic>>[];
      if (products.isEmpty && existing.isNotEmpty) {
        debugPrint('Items sheet held no usable rows; keeping existing catalog');
        return;
      }

      // The app reads its catalog from itemsBox as a JSON list; writing it
      // anywhere else means an import appears to succeed and changes nothing.
      await LocalStorageHelpers.storeJsonList('itemsBox', 'products', products);
      await LocalStorageHelpers.storeJsonList('itemsBox', 'categories',
          categories.map((c) => <String, dynamic>{'name': c}).toList());
    } catch (e) {
      debugPrint('Error importing items: $e');
    }
  }

  static Future<void> _importSales(Excel excel) async {
    try {
      final sheet = excel[_salesSheet];
      if (sheet.rows.isEmpty) return;

      final header = _headerIndex(sheet);
      if (!_hasColumns(header, ['id', 'date'])) {
        debugPrint('Sales sheet is missing an ID or Date column; skipping');
        return;
      }

      for (int i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        final id = _getCellString(_cell(row, header, 'ID'));
        final date = _getCellString(_cell(row, header, 'Date'));
        // A tab has no status and a cash sale has no client; demanding every
        // cell be present threw away most of the ledger.
        if (id.isEmpty || date.isEmpty) continue;

        await HiveService.storeSale(id, {
          'id': id,
          'type': _getCellString(_cell(row, header, 'Type')),
          'clientId': _getCellString(_cell(row, header, 'Client ID')),
          'items': _getCellString(_cell(row, header, 'Items')),
          'totalUSD': _parseDouble(_cell(row, header, 'Total USD')?.toString()),
          'totalLBP': _parseDouble(_cell(row, header, 'Total LBP')?.toString()),
          'exchangeRate':
              _parseDouble(_cell(row, header, 'Exchange Rate')?.toString()),
          'tva': _parseDouble(_cell(row, header, 'TVA')?.toString()),
          'date': date,
          'status': _getCellString(_cell(row, header, 'Status')),
        });
      }
    } catch (e) {
      debugPrint('Error importing sales: $e');
    }
  }

  static double? _parseDouble(String? value) {
    if (value == null || value.isEmpty) return 0.0;
    return Money.parse(value);
  }

  static int? _parseInt(String? value) {
    if (value == null || value.isEmpty) return 0;
    return int.tryParse(value.trim()) ?? Money.parse(value).round();
  }

  static String _getCellString(Object? value) {
    if (value == null) return '';
    if (value is String) return value.trim();
    return value.toString().trim();
  }

  /// Maps a sheet's header row to column indexes.
  ///
  /// Reading columns by position meant a file whose columns had been reordered
  /// imported prices into the description field, and a file missing a single
  /// column imported nothing at all.
  static Map<String, int> _headerIndex(Sheet sheet) {
    final index = <String, int>{};
    if (sheet.rows.isEmpty) return index;
    final header = sheet.rows.first;
    for (var i = 0; i < header.length; i++) {
      final name = _getCellString(header[i]?.value).toLowerCase();
      if (name.isNotEmpty) index[name] = i;
    }
    return index;
  }

  static Object? _cell(List<Data?> row, Map<String, int> header, String name) {
    final i = header[name.toLowerCase()];
    if (i == null || i >= row.length) return null;
    return row[i]?.value;
  }

  static bool _hasColumns(Map<String, int> header, List<String> required) =>
      required.every((c) => header.containsKey(c.toLowerCase()));
}
