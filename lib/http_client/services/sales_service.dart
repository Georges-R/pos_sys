import 'package:uuid/uuid.dart';
import '../local_storage/hive_service.dart';

class SalesService {
  static const String _salesBox = 'salesBox';
  static final Uuid uuid = Uuid();

  static Future<void> saveSale(
    List<Map<String, dynamic>> items,
    double totalUSD,
    double totalLBP,
    double exchangeRate,
    double tva,
  ) async {
    final saleId = uuid.v4();
    final sale = {
      'id': saleId,
      'items': items,
      'totalUSD': totalUSD,
      'totalLBP': totalLBP,
      'exchangeRate': exchangeRate,
      'tva': tva,
      'date': DateTime.now().toIso8601String(),
      'type': 'immediate',
    };
    await HiveService.storeSale(saleId, sale);
  }

  static Future<void> saveTab(
    String clientId,
    List<Map<String, dynamic>> items,
    double totalUSD,
    double totalLBP,
    double exchangeRate,
    double tva,
  ) async {
    final tabId = uuid.v4();
    final tab = {
      'id': tabId,
      'clientId': clientId,
      'items': items,
      'totalUSD': totalUSD,
      'totalLBP': totalLBP,
      'exchangeRate': exchangeRate,
      'tva': tva,
      'date': DateTime.now().toIso8601String(),
      'type': 'tab',
      'status': 'open',
    };
    await HiveService.storeSale(tabId, tab);
  }

  /// Only real sale records. The box has held stray non-sale entries in the
  /// past, and a report that casts every value to a sale crashes on them.
  static Map<String, dynamic> getAllSales() {
    final entries = HiveService.getBox(_salesBox);
    entries.removeWhere((key, dynamic value) => !_isSale(value));
    return entries;
  }

  static bool _isSale(dynamic value) =>
      value is Map && value['id'] != null && value['date'] != null;

  static List<Map<String, dynamic>> getSalesByDateRange(
      DateTime startDate, DateTime endDate) {
    return getAllSales().values.whereType<Map<String, dynamic>>().where((sale) {
      final saleDate = DateTime.tryParse('${sale['date']}');
      if (saleDate == null) return false;
      return !saleDate.isBefore(startDate) && !saleDate.isAfter(endDate);
    }).toList();
  }

  static Map<String, dynamic> getClientTabs(String clientId) {
    final allSales = getAllSales();
    final clientTabs = <String, dynamic>{};

    allSales.forEach((key, value) {
      if (value is Map &&
          value['type'] == 'tab' &&
          value['clientId'] == clientId) {
        clientTabs[key] = value;
      }
    });
    return clientTabs;
  }

  static Future<void> markTabAsPaid(String tabId) async {
    final sale = HiveService.getSale(tabId);
    final tab = sale != null ? Map<String, dynamic>.from(sale) : null;
    if (tab != null && tab['type'] == 'tab') {
      tab['status'] = 'paid';
      tab['paidAt'] = DateTime.now().toIso8601String();
      await HiveService.storeSale(tabId, tab);
    }
  }

  static Future<void> deleteTab(String tabId) async {
    await HiveService.deleteData(_salesBox, tabId);
  }

  static double totalRevenue() {
    return getAllSales().values.fold<double>(0.0, (sum, dynamic sale) {
      final value = (sale as Map)['totalUSD'];
      return sum + (value is num ? value.toDouble() : 0.0);
    });
  }
}
