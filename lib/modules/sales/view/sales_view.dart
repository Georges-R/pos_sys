import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pos/modules/sales/controller/sales_controller.dart';

class SalesView extends GetView<SalesController> {
  const SalesView({super.key});

  static final NumberFormat _usd = NumberFormat('#,##0.00');
  static const TextStyle _chipLabel = TextStyle(fontSize: 20);
  static const EdgeInsets _chipPadding =
      EdgeInsets.symmetric(horizontal: 12, vertical: 10);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales History'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: controller.loadSales,
          ),
        ],
      ),
      body: Obx(() {
        final days = controller.visibleDays;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final period in SalesPeriod.values)
                      if (period != SalesPeriod.custom)
                        _PeriodChip(period: period),
                    ChoiceChip(
                      avatar: const Icon(Icons.date_range, size: 24),
                      label: Text(controller.period.value == SalesPeriod.custom
                          ? _rangeLabel(controller.range.value)
                          : 'Pick dates'),
                      labelStyle: _chipLabel,
                      padding: _chipPadding,
                      selected: controller.period.value == SalesPeriod.custom,
                      showCheckmark: false,
                      onSelected: (_) => _pickRange(context),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _FilterChip(label: 'All', value: 'all'),
                  const SizedBox(width: 12),
                  _FilterChip(label: 'Paid', value: 'paid'),
                  const SizedBox(width: 12),
                  _FilterChip(label: 'Unpaid', value: 'unpaid'),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _rangeLabel(controller.range.value),
                        style:
                            TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      Text(
                        'Total: ${_usd.format(controller.totalTakings)} \$',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: days.isEmpty
                  ? Center(
                      child: Text(
                        _emptyMessage(),
                        style: const TextStyle(fontSize: 22),
                      ),
                    )
                  : _buildDays(days),
            ),
          ],
        );
      }),
    );
  }

  /// One header per day followed by that day's sales, built lazily: a year
  /// of history is thousands of rows.
  Widget _buildDays(List<SalesDay> days) {
    final rows = <Object>[
      for (final day in days) ...[day, ...day.sales],
    ];
    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        if (row is SalesDay) return _DayHeader(day: row);
        final sale = row as Map<String, dynamic>;
        final next = index + 1 < rows.length ? rows[index + 1] : null;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSaleTile(sale),
            // The day header that follows draws its own edge.
            if (next is! SalesDay && next != null) const Divider(height: 1),
          ],
        );
      },
    );
  }

  Widget _buildSaleTile(Map<String, dynamic> sale) {
    final isTab = sale['type'] == 'tab';
    final isPaid = SalesController.isPaid(sale);
    final customer = controller.customerName(sale);
    final date = DateTime.tryParse('${sale['date']}');
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Icon(
        isPaid ? Icons.payments : Icons.schedule,
        color: isPaid ? Colors.green : Colors.orange,
        size: 36,
      ),
      title: Text(
        '${_usd.format(sale['totalUSD'] is num ? sale['totalUSD'] : 0)} \$'
        '${customer.isEmpty ? '' : '  ·  $customer'}',
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          [
            if (date != null) DateFormat('HH:mm').format(date),
            '${controller.itemCount(sale)} item(s)',
            if (isTab) 'Tab · ${sale['status'] ?? 'open'}',
          ].join('  ·  '),
          style: const TextStyle(fontSize: 24),
        ),
      ),
      trailing: Text(
        '${NumberFormat('#,###').format(sale['totalLBP'] is num ? sale['totalLBP'] : 0)} LBP',
        style: TextStyle(fontSize: 24, color: Colors.grey[600]),
      ),
    );
  }

  String _emptyMessage() {
    if (controller.sales.isEmpty) return 'No sales recorded yet';
    return switch (controller.filter.value) {
      'paid' => 'No paid sales in this period',
      'unpaid' => 'No unpaid tabs in this period',
      _ => 'No sales in this period',
    };
  }

  Future<void> _pickRange(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: controller.range.value,
      helpText: 'Show sales from – to',
      saveText: 'Show',
      builder: _enlarged,
    );
    if (picked != null) controller.selectRange(picked);
  }

  /// Flutter draws the range picker at a fixed size: a calendar at most 384pt
  /// wide with 42pt rows, and text that will not scale past 1.3x. On a tablet
  /// that left a small island of dates in the middle of the screen.
  ///
  /// Laying the picker out on a smaller virtual screen and scaling that up to
  /// the real one enlarges every part of it together — the dates, the from–to
  /// heading, the buttons and the area each tap lands on. The scale stops
  /// where the heading and a whole month still fit on screen.
  static Widget _enlarged(BuildContext context, Widget? child) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final calendarWidth = size.width > size.height ? 420.0 : 520.0;
    final scale = math
        .min(size.width / calendarWidth, size.height / 500)
        .clamp(1.0, 2.5)
        .toDouble();
    final virtual = size / scale;
    return FittedBox(
      child: SizedBox.fromSize(
        size: virtual,
        child: MediaQuery(
          data: media.copyWith(
            size: virtual,
            padding: media.padding / scale,
            viewPadding: media.viewPadding / scale,
            viewInsets: media.viewInsets / scale,
          ),
          child: child!,
        ),
      ),
    );
  }

  static String _rangeLabel(DateTimeRange range) {
    final last = DateFormat('d MMM y').format(range.end);
    if (range.start == range.end) return last;
    final first =
        DateFormat(range.start.year == range.end.year ? 'd MMM' : 'd MMM y')
            .format(range.start);
    return '$first – $last';
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day});

  final SalesDay day;

  String get _label {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateFormat('EEEE d MMM y').format(day.day);
    if (day.day == today) return 'Today  ·  $date';
    if (day.day == DateTime(today.year, today.month, today.day - 1)) {
      return 'Yesterday  ·  $date';
    }
    return date;
  }

  @override
  Widget build(BuildContext context) {
    final count = day.sales.length;
    return Container(
      color: Colors.grey[200],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _label,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          Text(
            '${count == 1 ? '1 sale' : '$count sales'}  ·  '
            '${SalesView._usd.format(day.totalUSD)} \$',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _PeriodChip extends GetView<SalesController> {
  const _PeriodChip({required this.period});

  final SalesPeriod period;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => ChoiceChip(
        label: Text(period.label),
        labelStyle: SalesView._chipLabel,
        padding: SalesView._chipPadding,
        selected: controller.period.value == period,
        onSelected: (_) => controller.selectPeriod(period),
      ),
    );
  }
}

class _FilterChip extends GetView<SalesController> {
  const _FilterChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => ChoiceChip(
        label: Text(label),
        labelStyle: SalesView._chipLabel,
        padding: SalesView._chipPadding,
        selected: controller.filter.value == value,
        onSelected: (_) => controller.filter.value = value,
      ),
    );
  }
}
