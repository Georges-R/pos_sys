import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos/modules/sales/controller/sales_controller.dart';

Map<String, dynamic> _sale(DateTime date,
        {String type = 'immediate', String? status, double totalUSD = 1}) =>
    {
      'id': date.toIso8601String(),
      'date': date.toIso8601String(),
      'type': type,
      if (status != null) 'status': status,
      'totalUSD': totalUSD,
    };

void main() {
  // A Sunday, so "this week" has to reach back to the Monday before it.
  final now = DateTime(2026, 10, 25, 15, 30);

  group('quick periods', () {
    test('today is just today', () {
      final range = SalesController.rangeFor(SalesPeriod.today, now);
      expect(range.start, DateTime(2026, 10, 25));
      expect(range.end, DateTime(2026, 10, 25));
    });

    test('this week starts on Monday', () {
      final range = SalesController.rangeFor(SalesPeriod.week, now);
      expect(range.start, DateTime(2026, 10, 19));
      expect(range.end, DateTime(2026, 10, 25));
    });

    test('this week on a Monday is that Monday alone', () {
      final range =
          SalesController.rangeFor(SalesPeriod.week, DateTime(2026, 10, 19, 9));
      expect(range.start, DateTime(2026, 10, 19));
    });

    test('this week crosses back into last month', () {
      final range =
          SalesController.rangeFor(SalesPeriod.week, DateTime(2026, 10, 1));
      expect(range.start, DateTime(2026, 9, 28));
    });

    test('this month and this year start on their first day', () {
      expect(SalesController.rangeFor(SalesPeriod.month, now).start,
          DateTime(2026, 10, 1));
      expect(SalesController.rangeFor(SalesPeriod.year, now).start,
          DateTime(2026, 1, 1));
    });
  });

  group('a range of days', () {
    final range = DateTimeRange(
        start: DateTime(2026, 10, 20), end: DateTime(2026, 10, 22));

    test('includes the whole of its last day', () {
      expect(
          SalesController.isInRange(
              _sale(DateTime(2026, 10, 22, 23, 59)), range),
          isTrue);
      expect(SalesController.isInRange(_sale(DateTime(2026, 10, 23)), range),
          isFalse);
    });

    test('starts at midnight on its first day', () {
      expect(SalesController.isInRange(_sale(DateTime(2026, 10, 20)), range),
          isTrue);
      expect(
          SalesController.isInRange(
              _sale(DateTime(2026, 10, 19, 23, 59)), range),
          isFalse);
    });

    test('a sale with no readable date is never shown', () {
      expect(
          SalesController.isInRange(
              {'id': 'x', 'date': 'not a date', 'totalUSD': 1}, range),
          isFalse);
    });
  });

  group('paid and unpaid', () {
    test('a sale paid at the till is paid', () {
      expect(SalesController.isPaid(_sale(now)), isTrue);
    });

    test('an open tab is unpaid until it is settled', () {
      expect(SalesController.isPaid(_sale(now, type: 'tab', status: 'open')),
          isFalse);
      expect(SalesController.isPaid(_sale(now, type: 'tab', status: 'paid')),
          isTrue);
    });

    test('a tab restored without a status is still owed', () {
      expect(
          SalesController.isPaid(_sale(now, type: 'tab', status: '')), isFalse);
    });
  });

  test('sales are grouped one entry per day, newest first', () {
    final days = SalesController.groupByDay([
      _sale(DateTime(2026, 10, 25, 18), totalUSD: 2.10),
      _sale(DateTime(2026, 10, 25, 9), totalUSD: 1.20),
      _sale(DateTime(2026, 10, 23, 12), totalUSD: 5),
    ]);

    expect(days.map((d) => d.day),
        [DateTime(2026, 10, 25), DateTime(2026, 10, 23)]);
    expect(days.first.sales, hasLength(2));
    expect(days.first.totalUSD, 3.30);
    expect(days.last.totalUSD, 5);
  });
}
