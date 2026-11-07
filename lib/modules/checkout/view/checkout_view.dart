import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pos/custom_widgets/totals_tiles/totals_tiles.dart';
import '../controller/checkout_controller.dart';

class CheckoutView extends GetView<CheckoutController> {
  const CheckoutView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: Obx(
              () => controller.cartItems.isEmpty
                  ? const Center(child: Text('No items in cart'))
                  : ListView.builder(
                      itemCount: controller.cartItems.length,
                      itemBuilder: (context, index) {
                        final item = controller.cartItems[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 8),
                          title: Text(
                            item.description ?? 'Product',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Price: \$${item.sellingPrice} x ${item.quantity}',
                              style: const TextStyle(
                                fontSize: 24,
                              ),
                            ),
                          ),
                          trailing: IconButton(
                            iconSize: 36,
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => controller.removeFromCart(index),
                          ),
                        );
                      },
                    ),
            ),
          ),
          // Totals + Actions Panel
          //
          // Two equal-width total tiles (USD | LBP) sit exactly above the two
          // equal-width buttons: both rows share the same [Expanded, 16,
          // Expanded] skeleton, so the outer edges and the centre gutter
          // coincide at every width.
          Obx(
            () {
              final theme = Theme.of(context);
              final tva = controller.tva.value;
              final rate = controller.exchangeRate.value;
              final lbp = NumberFormat('#,###');

              return Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(
                    top: BorderSide(color: theme.dividerColor, width: 1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 18,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                child: SafeArea(
                  top: false,
                  minimum: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TotalsTiles(
                        totalUSD: controller.totalUSD.value,
                        totalLBP: controller.totalLBP.value,
                        usdFootnote: tva > 0
                            ? 'Includes ${NumberFormat('#,##0.##').format(tva)}% VAT'
                                '  ·  \$${NumberFormat('#,##0.00').format(controller.tvaAmountUSD.value)}'
                            : null,
                        lbpFootnote: rate > 0
                            ? '1 USD  =  ${lbp.format(rate)} LBP'
                            : 'Exchange rate not set',
                      ),
                      const SizedBox(height: 16),
                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: _ActionButton(
                              label: 'Pay Now',
                              icon: Icons.check_circle_outline,
                              color: const Color(0xFF2E9E52),
                              onPressed: controller.payNow,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _ActionButton(
                              label: 'Pay Later',
                              icon: Icons.person_outline,
                              color: const Color(0xFF2F7BE8),
                              onPressed: controller.showCustomerSelector,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 24),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}
