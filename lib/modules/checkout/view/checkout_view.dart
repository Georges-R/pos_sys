import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
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
                          title: Text(
                            item.description ?? 'Product',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            'Price: \$${item.sellingPrice} x ${item.quantity}',
                            style: const TextStyle(
                              fontSize: 18,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => controller.removeFromCart(index),
                          ),
                        );
                      },
                    ),
            ),
          ),
          const Divider(),
          // Totals Section
          Obx(
            () => Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subtotal:', style: TextStyle(fontSize: 18)),
                      Text(
                        '${NumberFormat('#,##0.00').format(controller.subtotalUSD.value)} \$',
                        style: const TextStyle(fontSize: 18),
                      ),
                    ],
                  ),
                  if (controller.tva.value > 0)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'VAT (${NumberFormat('#,##0.##').format(controller.tva.value)}%):',
                          style: const TextStyle(fontSize: 18),
                        ),
                        Text(
                          '${NumberFormat('#,##0.00').format(controller.tvaAmountUSD.value)} \$',
                          style: const TextStyle(fontSize: 18),
                        ),
                      ],
                    ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total (USD):',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${NumberFormat('#,##0.00').format(controller.totalUSD.value)} \$',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total (LBP):',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${NumberFormat('#,###').format(controller.totalLBP.value)} LBP',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  // Row(
                  //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  //   children: [
                  //     const Text('Remaining:'),
                  //     Text(
                  //       '\$${controller.remainingAmount.value.toStringAsFixed(2)}',
                  //       style: const TextStyle(
                  //         fontWeight: FontWeight.bold,
                  //         color: Colors.green,
                  //       ),
                  //     ),
                  //   ],
                  // ),
                ],
              ),
            ),
          ),
          const Divider(),
          // Predefined Bills Section
          // Expanded(
          //   flex: 1,
          //   child: Padding(
          //     padding: const EdgeInsets.all(8.0),
          //     child: GridView.count(
          //       crossAxisCount: 3,
          //       childAspectRatio: 2,
          //       children: controller.predefinedBills
          //           .map(
          //             (bill) => Card(
          //               child: InkWell(
          //                 onTap: () => controller.applyPredefinedBill(bill),
          //                 child: Center(
          //                   child: Text(
          //                     '\$$bill',
          //                     style: const TextStyle(
          //                       fontWeight: FontWeight.bold,
          //                       fontSize: 16,
          //                     ),
          //                   ),
          //                 ),
          //               ),
          //             ),
          //           )
          //           .toList(),
          //     ),
          //   ),
          // ),
          // Action Buttons
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => controller.payNow(),
                    icon: const Icon(Icons.check),
                    label: const Text('Pay Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      textStyle: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => controller.showCustomerSelector(),
                    icon: const Icon(Icons.person),
                    label: const Text('Pay Later'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      textStyle: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
