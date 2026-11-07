import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos/core/helpers/notify.dart';
import 'package:intl/intl.dart';
import 'package:pos/core/routes/paths.dart';
import 'package:pos/custom_widgets/custom_left_drawer/custom_left_drawer.dart';
import 'package:pos/custom_widgets/order_item_card/order_item_card.dart';
import 'package:pos/custom_widgets/pos_button/pos_button.dart';
import 'package:pos/custom_widgets/totals_tiles/totals_tiles.dart';
import 'package:pos/http_client/data/models/items/add_edit_items_model.dart';
import 'package:pos/modules/home_screen/controller/home_sceen_controller.dart';
import 'package:pos/modules/home_screen/view/edit_item_dialog.dart';
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
  final ScrollController _cartScroll = ScrollController();
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

    final linesBefore = controller.cart.length;
    final found = controller.findAndAddByBarcode(code);
    _barcodeController.clear();
    _firstKeystrokeAt = null;

    if (found) {
      if (controller.cart.length > linesBefore) _scrollCartToEnd();
      _refocusScanner();
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
      _refocusScanner();
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
      _scrollCartToEnd();
    }
    _refocusScanner();
  }

  /// Puts the cursor back in the barcode field so the next item can be
  /// scanned straight away, whatever the cashier just did.
  void _refocusScanner() {
    if (!mounted) return;
    _barcodeFocus.requestFocus();
  }

  /// Opens another screen and, once the cashier comes back to the till,
  /// leaves the cursor in the barcode field again.
  Future<void> _openAndReturnToScanner(String path, {dynamic arguments}) async {
    await Get.toNamed(path, arguments: arguments);
    _refocusScanner();
  }

  /// A new line goes to the bottom of the cart. Once the cart is longer than
  /// the screen, that is out of sight, so follow it down.
  void _scrollCartToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_cartScroll.hasClients) return;
      _cartScroll.animateTo(
        _cartScroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _scanDebounce?.cancel();
    _barcodeController.removeListener(_onBarcodeChanged);
    _barcodeController.dispose();
    _barcodeFocus.dispose();
    _cartScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(settingsController.storeName.value.isNotEmpty
            ? settingsController.storeName.value
            : 'POS Desktop Demo')),
        backgroundColor: Colors.grey[200],
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _openAndReturnToScanner(Paths.settingsScreen),
          ),
        ],
      ),
      onDrawerChanged: (isOpen) {
        if (!isOpen) _refocusScanner();
      },
      drawer: CustomLeftDrawer(
        items: [
          'Item Management',
          'Stock',
          'Clients',
          'Sales History',
        ],
        onItemTap: [
          () => _openAndReturnToScanner(Paths.addEditItemScreen,
              arguments: controller.selectedCategory.value),
          () => _openAndReturnToScanner(Paths.itemListingScreen),
          () => _openAndReturnToScanner(Paths.clients),
          () => _openAndReturnToScanner(Paths.salesListingScreen),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // The cart takes the wide side; the scanner and totals column
          // grows with the window but never squeezes the cart out.
          final sideWidth = (constraints.maxWidth * 0.4).clamp(380.0, 560.0);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildCart()),
              Container(
                width: sideWidth,
                color: Colors.grey[100],
                child: _buildScannerAndTotals(context),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCart() {
    return Obx(() {
      if (controller.cart.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.qr_code_scanner, size: 72, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Scan a barcode to start a sale',
                style: TextStyle(fontSize: 22, color: Colors.grey[600]),
              ),
            ],
          ),
        );
      }
      return ListView.builder(
        controller: _cartScroll,
        padding: const EdgeInsets.all(12),
        itemCount: controller.cart.length,
        itemBuilder: (context, index) {
          final item = controller.cart[index];
          // The line's quantity is the count being sold; the stock and its
          // warning level live on the catalog row.
          final product = controller.catalogProductFor(item);
          return OrderItemCard(
            productName: item.description ?? '',
            quantity: item.quantity ?? 0,
            unitPrice: item.sellingPrice ?? 0,
            lowStockLeft: product != null && product.isLowOnStock
                ? product.quantity ?? 0
                : null,
            onIncrease: () {
              controller.updateQuantity(index, 1);
              _refocusScanner();
            },
            onDecrease: () {
              controller.updateQuantity(index, -1);
              _refocusScanner();
            },
            onRemove: () {
              controller.removeItem(index);
              _refocusScanner();
            },
            onLongPress: () => _editCartItem(item),
          );
        },
      );
    });
  }

  Widget _buildScannerAndTotals(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _barcodeController,
            focusNode: _barcodeFocus,
            textInputAction: TextInputAction.done,
            autofocus: true,
            // The next scan has to land here whatever the cashier last
            // touched. On a tablet, touching anywhere outside a text field
            // drops its focus by default, and the scanner's keystrokes then
            // go nowhere.
            onTapOutside: (_) {},
            style: const TextStyle(fontSize: 22),
            decoration: InputDecoration(
              hintText: 'Scan barcode here',
              prefixIcon: const Icon(Icons.qr_code_scanner, size: 30),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              filled: true,
              fillColor: Colors.white,
              hintStyle: Styles.hintTextStyle.copyWith(fontSize: 20),
            ),
            onSubmitted: (value) {
              final code = value.trim();
              if (code.isNotEmpty) {
                _processScannedCode(code);
              } else {
                _refocusScanner();
              }
            },
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Obx(() {
              final rate = settingsController.exchangeRate.value;
              final count = controller.cart
                  .fold<int>(0, (sum, item) => sum + (item.quantity ?? 0));
              return TotalsTiles(
                totalUSD: controller.total,
                totalLBP: controller.total * rate,
                amountSize: 96,
                // One above the other at any width.
                stackBelowWidth: double.infinity,
                usdFootnote: count == 1 ? '1 item' : '$count items',
                lbpFootnote: rate > 0
                    ? '1 USD  =  ${NumberFormat('#,###').format(rate)} LBP'
                    : 'Exchange rate not set',
              );
            }),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: PosButton(
            text: 'Checkout',
            icon: Icons.shopping_cart_checkout,
            iconSize: 34,
            padding: const EdgeInsets.symmetric(vertical: 26),
            textStyle: Styles.inputTextStyleWhite
                .copyWith(fontSize: 26, fontWeight: FontWeight.w700),
            onPressed: () {
              if (controller.cart.isEmpty) {
                Notify.error('Empty cart', 'Add an item first');
                _refocusScanner();
                return;
              }
              _openAndReturnToScanner(Paths.checkout,
                  arguments: controller.cart);
            },
          ),
        ),
        const SizedBox(height: 8),
        // A cashier needs to be able to abandon a basket; clearCart()
        // existed but nothing on screen called it.
        Obx(
          () => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextButton.icon(
              onPressed: controller.cart.isEmpty
                  ? null
                  : () => _confirmClearCart(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                textStyle: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontSize: 21, fontWeight: FontWeight.w600),
              ),
              icon: const Icon(Icons.remove_shopping_cart, size: 28),
              label: const Text('Clear cart'),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  /// Long-pressing a cart line edits the catalog row behind it.
  Future<void> _editCartItem(AddEditItemModel cartItem) async {
    final product = controller.catalogProductFor(cartItem);
    if (product == null) {
      Notify.error('Not in catalog',
          '${cartItem.description} has been deleted from the catalog');
      _refocusScanner();
      return;
    }
    final saved = await EditItemDialog.show(context, product: product);
    if (!mounted) return;
    if (saved == true) {
      Notify.success('Item updated', '${product.description} was saved');
    }
    _refocusScanner();
  }

  Future<void> _confirmClearCart(BuildContext context) async {
    await showDialog<void>(
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
    _refocusScanner();
  }
}
