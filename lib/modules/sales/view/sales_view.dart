import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pos/modules/sales/controller/sales_controller.dart';

class SalesView extends GetView<SalesController> {
  const SalesView({super.key});

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
        final sales = controller.visibleSales;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _FilterChip(label: 'All', value: 'all'),
                  const SizedBox(width: 8),
                  _FilterChip(label: 'Paid', value: 'immediate'),
                  const SizedBox(width: 8),
                  _FilterChip(label: 'Tabs', value: 'tab'),
                  const Spacer(),
                  Text(
                    'Total: ${NumberFormat('#,##0.00').format(controller.totalTakings)} \$',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: sales.isEmpty
                  ? const Center(child: Text('No sales recorded yet'))
                  : ListView.separated(
                      itemCount: sales.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final sale = sales[index];
                        final isTab = sale['type'] == 'tab';
                        final customer = controller.customerName(sale);
                        final date = DateTime.tryParse('${sale['date']}');
                        return ListTile(
                          leading: Icon(
                            isTab ? Icons.schedule : Icons.payments,
                            color: isTab ? Colors.orange : Colors.green,
                          ),
                          title: Text(
                            '${NumberFormat('#,##0.00').format(sale['totalUSD'] is num ? sale['totalUSD'] : 0)} \$'
                            '${customer.isEmpty ? '' : '  ·  $customer'}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            [
                              if (date != null)
                                DateFormat('d MMM y  HH:mm').format(date),
                              '${controller.itemCount(sale)} item(s)',
                              if (isTab) 'Tab · ${sale['status'] ?? 'open'}',
                            ].join('  ·  '),
                          ),
                          trailing: Text(
                            '${NumberFormat('#,###').format(sale['totalLBP'] is num ? sale['totalLBP'] : 0)} LBP',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      }),
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
        selected: controller.filter.value == value,
        onSelected: (_) => controller.filter.value = value,
      ),
    );
  }
}
