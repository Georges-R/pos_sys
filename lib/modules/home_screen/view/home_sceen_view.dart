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
import 'package:pos/custom_widgets/totals_tiles/totals_tiles.dart';
import 'package:pos/http_client/data/models/items/add_edit_items_model.dart';
import 'package:pos/modules/home_screen/controller/home_sceen_controller.dart';
import 'package:pos/modules/home_screen/view/quick_add_item_dialog.dart';
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

    if (found) {
      _barcodeFocus.requestFocus();
      return;
    }
    await _offerToCreateProduct(code);
  }

  /// A code that matches nothing is usually a product the shop has started
  /// selling but never entered. Telling the cashier "not found" left them to
  /// abandon the sale or leave the till for the item screen, so offer to
  /// create it here and ring it up straight away.
  Future<void> _offerToCreateProduct(String code) async {
    if (!mounted) return;
    final wantsToCreate = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Item not found'),
        content: Text(
          'No product in the catalog uses barcode "$code".\n\n'
          'Create it now so you can add it to this sale?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Create item'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (wantsToCreate != true) {
      _barcodeFocus.requestFocus();
      return;
    }

    final product = await QuickAddItemDialog.show(context, barcode: code);
    if (!mounted) return;
    if (product != null) {
      controller.addToCart(product);
      Notify.success(
        'Item created',
        '${product.description} was added to the catalog and this sale',
      );
    }
    _barcodeFocus.requestFocus();
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
                                        horizontal: 18, vertical: 10),
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
                                          fontSize: 19,
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
                        maxCrossAxisExtent: 200,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        // Each tile carries a name plus both currencies, so
                        // it needs to be a touch taller than it is wide.
                        childAspectRatio: 1.15,
                      ),
                      itemBuilder: (context, index) {
                        final p = controller.filteredProducts[index];
                        return ProductCard(
                          productName: p.description ?? '',
                          price: p.sellingPrice ?? 0,
                          exchangeRate: settingsController.exchangeRate.value,
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
                const Divider(height: 1),
                // Same total tiles as the checkout screen; the 400px sidebar
                // is below the widget's breakpoint, so they stack vertically.
                Obx(
                  () {
                    final rate = settingsController.exchangeRate.value;
                    final count = controller.cart.fold<int>(
                        0, (sum, item) => sum + (item.quantity ?? 0));
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      child: TotalsTiles(
                        totalUSD: controller.total,
                        totalLBP: controller.total * rate,
                        amountSize: 44,
                        usdFootnote: count == 1 ? '1 item' : '$count items',
                        lbpFootnote: rate > 0
                            ? '1 USD  =  ${NumberFormat('#,###').format(rate)} LBP'
                            : 'Exchange rate not set',
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                // Full width so the button's edges line up with the tiles.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: PosButton(
                      text: 'Checkout',
                      icon: Icons.shopping_cart_checkout,
                      onPressed: () {
                        if (controller.cart.isEmpty) {
                          Notify.error('Empty cart', 'Add an item first');
                          return;
                        }
                        Get.toNamed(Paths.checkout,
                            arguments: controller.cart);
                      },
                    ),
                  ),
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
