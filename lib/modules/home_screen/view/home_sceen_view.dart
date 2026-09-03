import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos/core/helpers/notify.dart';
import 'package:intl/intl.dart';
import 'package:pos/core/routes/paths.dart';
import 'package:pos/custom_widgets/custom_left_drawer/custom_left_drawer.dart';
import 'package:pos/custom_widgets/order_item_card/order_item_card.dart';
import 'package:pos/custom_widgets/pos_button/pos_button.dart';
import 'package:pos/custom_widgets/product_card/product_card.dart';
import 'package:pos/http_client/data/models/items/add_edit_items_model.dart';
import 'package:pos/modules/home_screen/controller/home_sceen_controller.dart';
import 'package:pos/modules/settings/controller/settings_controller.dart';
import 'package:pos/themes/styles/styles.dart';

class HomeScreenView extends StatefulWidget {
  const HomeScreenView({super.key});

  @override
  State<HomeScreenView> createState() => _HomeScreenViewState();
}

class _HomeScreenViewState extends State<HomeScreenView> {
  final HomeSceenController controller = Get.find();
  final SettingsController settingsController = Get.find();
  final TextEditingController _barcodeController = TextEditingController();
  final FocusNode _barcodeFocus = FocusNode();
  Timer? _scanDebounce;

  @override
  void initState() {
    super.initState();
    _barcodeController.addListener(_onBarcodeChanged);
  }

  /// A hardware scanner types a whole code in a few milliseconds and usually
  /// ends with a newline. A person types slowly and presses Enter.
  ///
  /// Auto-submitting after a 220 ms pause meant a cashier keying in a code by
  /// hand had it snatched away mid-entry, cleared, and reported "not found"
  /// on every partial code. Only a scanner-speed burst is submitted on its
  /// own; anything typed by hand waits for Enter.
  static const Duration _scanBurstWindow = Duration(milliseconds: 120);
  static const int _minScanLength = 4;
  DateTime? _firstKeystrokeAt;

  void _onBarcodeChanged() {
    _scanDebounce?.cancel();

    final raw = _barcodeController.text;
    if (raw.isEmpty) {
      _firstKeystrokeAt = null;
      return;
    }
    _firstKeystrokeAt ??= DateTime.now();

    if (raw.contains('\n') || raw.contains('\r')) {
      final code = raw.replaceAll(RegExp(r'[\r\n]'), '').trim();
      _processScannedCode(code);
      return;
    }

    final startedAt = _firstKeystrokeAt;
    _scanDebounce = Timer(_scanBurstWindow, () {
      final code = _barcodeController.text.trim();
      if (code.length < _minScanLength || startedAt == null) return;
      final typedIn = DateTime.now().difference(startedAt);
      // Faster than a human could have typed it: treat it as a scan.
      if (typedIn <= _scanBurstWindow * 2) {
        _processScannedCode(code);
      }
    });
  }

  Future<void> _processScannedCode(String code) async {
    if (code.isEmpty) return;

    final found = controller.findAndAddByBarcode(code);
    _barcodeController.clear();
    _firstKeystrokeAt = null;
    _barcodeFocus.requestFocus();

    if (!found) {
      Notify.error('Not found', 'No product matches the scanned code');
    }
  }

  @override
  void dispose() {
    _scanDebounce?.cancel();
    _barcodeController.removeListener(_onBarcodeChanged);
    _barcodeController.dispose();
    _barcodeFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsController = Get.find<SettingsController>();
    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(settingsController.storeName.value.isNotEmpty
            ? settingsController.storeName.value
            : 'POS Desktop Demo')),
        backgroundColor: Colors.grey[200],
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Get.toNamed(Paths.settingsScreen),
          ),
        ],
      ),
      drawer: CustomLeftDrawer(
        items: [
          'Item Management',
          'Stock',
          'Clients',
          'Sales History',
        ],
        onItemTap: [
          () => Get.toNamed(Paths.addEditItemScreen,
              arguments: controller.selectedCategory.value),
          () => Get.toNamed(Paths.itemListingScreen),
          () => Get.toNamed(Paths.clients),
          () => Get.toNamed(Paths.salesListingScreen),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Container(
                  height: 100,
                  color: Colors.grey[100],
                  child: Obx(
                    () => Row(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: controller.categories.length,
                            itemBuilder: (context, index) {
                              final category = controller.categories[index];
                              return GestureDetector(
                                onTap: () => controller.selectedCategory.value =
                                    category,
                                onLongPress: () => _showDeleteCategoryDialog(
                                    context, category),
                                child: Obx(() {
                                  final isSelected =
                                      controller.selectedCategory.value ==
                                          category;
                                  return Container(
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 16),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.blue
                                          : Colors.grey.shade300,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        category,
                                        style: TextStyle(
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.black,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              );
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, color: Colors.blue),
                          onPressed: () =>
                              controller.showAddCategoryDialog(context),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Obx(
                    () => GridView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: controller.filteredProducts.length,
                      // Six fixed columns squeezed the tiles to nothing on
                      // any window narrower than a full-size tablet.
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 180,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1.25,
                      ),
                      itemBuilder: (context, index) {
                        final p = controller.filteredProducts[index];
                        return ProductCard(
                          productName: p.description ?? '',
                          price: p.sellingPrice ?? 0,
                          onAddToCart: () => controller.addToCart(p),
                          onLongPress: () =>
                              _showDeleteProductDialog(context, p),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 400,
            color: Colors.grey[100],
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: TextField(
                    controller: _barcodeController,
                    focusNode: _barcodeFocus,
                    textInputAction: TextInputAction.done,
                    autofocus: true,
                    decoration: InputDecoration(
                        hintText: 'Scan barcode here',
                        prefixIcon: const Icon(Icons.qr_code_scanner),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                        hintStyle: Styles.hintTextStyle,
                        labelStyle: Styles.labelTextStyle),
                    onSubmitted: (value) {
                      final code = value.trim();
                      if (code.isNotEmpty) _processScannedCode(code);
                    },
                  ),
                ),
                Expanded(
                  child: Obx(
                    () => ListView.builder(
                      itemCount: controller.cart.length,
                      itemBuilder: (context, index) {
                        final item = controller.cart[index];
                        return OrderItemCard(
                          productName: item.description ?? '',
                          quantity: item.quantity ?? 0,
                          unitPrice: item.sellingPrice ?? 0,
                          onIncrease: () => controller.updateQuantity(index, 1),
                          onDecrease: () =>
                              controller.updateQuantity(index, -1),
                          onRemove: () => controller.removeItem(index),
                        );
                      },
                    ),
                  ),
                ),
                const Divider(),
                Obx(
                  () => Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        Text(
                          'Total: \$${controller.total.toStringAsFixed(2)}',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Total LBP: ${NumberFormat('#,###').format(controller.total * settingsController.exchangeRate.value)} LBP',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                PosButton(
                  text: 'Checkout',
                  icon: Icons.shopping_cart_checkout,
                  onPressed: () {
                    if (controller.cart.isEmpty) {
                      Notify.error('Empty cart', 'Add an item first');
                      return;
                    }
                    Get.toNamed(Paths.checkout, arguments: controller.cart);
                  },
                ),
                const SizedBox(height: 8),
                // A cashier needs to be able to abandon a basket; clearCart()
                // existed but nothing on screen called it.
                Obx(
                  () => TextButton.icon(
                    onPressed: controller.cart.isEmpty
                        ? null
                        : () => _confirmClearCart(context),
                    icon: const Icon(Icons.remove_shopping_cart),
                    label: const Text('Clear cart'),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmClearCart(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear cart'),
        content: const Text('Remove every item from the current sale?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () {
              controller.clearCart();
              Navigator.of(context).pop();
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showDeleteProductDialog(
      BuildContext context, AddEditItemModel product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content:
            Text('Are you sure you want to delete "${product.description}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              controller.deleteProduct(product);
              Navigator.of(context).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showDeleteCategoryDialog(BuildContext context, String category) {
    final productsInCategory =
        controller.allProducts.where((p) => p.category == category).toList();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text(
            'Are you sure you want to delete "$category"? This will also delete ${productsInCategory.length} product(s) in this category.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (productsInCategory.isNotEmpty) {
                Navigator.of(context).pop();
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Confirm Deletion'),
                    content: const Text(
                        'This category contains products. Deleting it will remove all associated products. Are you absolutely sure?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          controller.deleteCategory(category);
                          Navigator.of(context).pop();
                        },
                        child: const Text('Yes, Delete All'),
                      ),
                    ],
                  ),
                );
              } else {
                controller.deleteCategory(category);
                Navigator.of(context).pop();
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
