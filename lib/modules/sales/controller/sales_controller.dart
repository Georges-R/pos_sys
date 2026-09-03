import 'package:get/get.dart';
import 'package:pos/core/helpers/money.dart';
import 'package:pos/http_client/services/clients_service.dart';
import 'package:pos/http_client/services/sales_service.dart';

class SalesController extends GetxController {
  final RxList<Map<String, dynamic>> sales = <Map<String, dynamic>>[].obs;

  /// 'all' | 'immediate' | 'tab'
  final RxString filter = 'all'.obs;

  @override
  void onInit() {
    super.onInit();
    loadSales();
  }

  void loadSales() {
    final all = SalesService.getAllSales()
        .values
        .whereType<Map<String, dynamic>>()
        .toList();
    // Newest first: a cashier looking things up wants today's sales.
    all.sort((a, b) {
      final left = DateTime.tryParse('${a['date']}') ?? DateTime(0);
      final right = DateTime.tryParse('${b['date']}') ?? DateTime(0);
      return right.compareTo(left);
    });
    sales.assignAll(all);
  }

  List<Map<String, dynamic>> get visibleSales {
    if (filter.value == 'all') return sales;
    return sales.where((s) => s['type'] == filter.value).toList();
  }

  double get totalTakings => Money.round(visibleSales.fold<double>(
      0.0, (sum, sale) => sum + Money.parse(sale['totalUSD'])));

  int get openTabCount =>
      sales.where((s) => s['type'] == 'tab' && s['status'] == 'open').length;

  String customerName(Map<String, dynamic> sale) {
    final clientId = '${sale['clientId'] ?? ''}';
    if (clientId.isEmpty) return '';
    return '${ClientsService.getClientById(clientId)?['name'] ?? 'Unknown'}';
  }

  int itemCount(Map<String, dynamic> sale) {
    final items = sale['items'];
    if (items is List) return items.length;
    return 0;
  }
}
