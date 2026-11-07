import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos/core/helpers/money.dart';
import 'package:pos/http_client/services/clients_service.dart';
import 'package:pos/http_client/services/sales_service.dart';

/// The quick picks above the history. [custom] is a range chosen by hand.
enum SalesPeriod {
  today('Today'),
  week('This week'),
  month('This month'),
  year('This year'),
  custom('Custom');

  const SalesPeriod(this.label);

  final String label;
}

/// One day of the history, newest sale first.
class SalesDay {
  SalesDay(this.day, this.sales);

  /// Midnight at the start of the day.
  final DateTime day;
  final List<Map<String, dynamic>> sales;

  double get totalUSD => Money.round(
      sales.fold<double>(0.0, (sum, s) => sum + Money.parse(s['totalUSD'])));
}

class SalesController extends GetxController {
  final RxList<Map<String, dynamic>> sales = <Map<String, dynamic>>[].obs;

  /// 'all' | 'paid' | 'unpaid'
  final RxString filter = 'all'.obs;

  final Rx<SalesPeriod> period = SalesPeriod.today.obs;

  /// The first and last day shown, both whole days.
  final Rx<DateTimeRange> range =
      rangeFor(SalesPeriod.today, DateTime.now()).obs;

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
    // A screen left open overnight would otherwise keep calling yesterday
    // "Today".
    if (period.value != SalesPeriod.custom) selectPeriod(period.value);
  }

  void selectPeriod(SalesPeriod value) {
    if (value == SalesPeriod.custom) return;
    period.value = value;
    range.value = rangeFor(value, DateTime.now());
  }

  void selectRange(DateTimeRange picked) {
    period.value = SalesPeriod.custom;
    range.value = DateTimeRange(
      start: _startOfDay(picked.start),
      end: _startOfDay(picked.end),
    );
  }

  /// The days [period] covers, from its first day up to today. Weeks start on
  /// Monday.
  static DateTimeRange rangeFor(SalesPeriod period, DateTime now) {
    final today = _startOfDay(now);
    final start = switch (period) {
      SalesPeriod.today || SalesPeriod.custom => today,
      SalesPeriod.week =>
        DateTime(today.year, today.month, today.day - (today.weekday - 1)),
      SalesPeriod.month => DateTime(today.year, today.month, 1),
      SalesPeriod.year => DateTime(today.year, 1, 1),
    };
    return DateTimeRange(start: start, end: today);
  }

  /// A sale paid at the till, or a tab that has since been settled. Only an
  /// open tab is still owed.
  static bool isPaid(Map<String, dynamic> sale) =>
      sale['type'] != 'tab' || sale['status'] == 'paid';

  /// Whether [sale] was made on one of the days of [range]. The range holds
  /// whole days, so its last day runs until the following midnight.
  static bool isInRange(Map<String, dynamic> sale, DateTimeRange range) {
    final date = DateTime.tryParse('${sale['date']}');
    if (date == null) return false;
    final end = DateTime(range.end.year, range.end.month, range.end.day + 1);
    return !date.isBefore(range.start) && date.isBefore(end);
  }

  /// Splits [sales], already newest first, into one entry per calendar day.
  static List<SalesDay> groupByDay(List<Map<String, dynamic>> sales) {
    final days = <SalesDay>[];
    for (final sale in sales) {
      final date = DateTime.tryParse('${sale['date']}');
      if (date == null) continue;
      final day = _startOfDay(date);
      if (days.isEmpty || days.last.day != day) {
        days.add(SalesDay(day, []));
      }
      days.last.sales.add(sale);
    }
    return days;
  }

  static DateTime _startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  List<Map<String, dynamic>> get visibleSales {
    final shown = range.value;
    return sales.where((s) {
      if (!isInRange(s, shown)) return false;
      return switch (filter.value) {
        'paid' => isPaid(s),
        'unpaid' => !isPaid(s),
        _ => true,
      };
    }).toList();
  }

  List<SalesDay> get visibleDays => groupByDay(visibleSales);

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
