import 'dart:developer';
import 'package:get/get.dart';
import 'package:pos/core/helpers/notify.dart';
import 'package:pos/core/helpers/money.dart';
import 'package:pos/core/routes/paths.dart';
import 'package:pos/http_client/data/models/items/add_edit_items_model.dart';
import 'package:pos/http_client/services/sales_service.dart';
import 'package:pos/modules/settings/controller/settings_controller.dart';
import 'package:pos/modules/home_screen/controller/home_sceen_controller.dart';
import 'package:pos/modules/clients/controller/clients_controller.dart';
import '../view/customer_selector_dialog.dart';

class CheckoutController extends GetxController {
  RxDouble subtotalUSD = 0.0.obs;
  RxDouble tvaAmountUSD = 0.0.obs;
  RxDouble totalUSD = 0.0.obs;
  RxDouble totalLBP = 0.0.obs;
  RxDouble exchangeRate = 0.0.obs;
  RxDouble tva = 0.0.obs;
  RxDouble remainingAmount = 0.0.obs;
  RxList<AddEditItemModel> cartItems = <AddEditItemModel>[].obs;
  RxString selectedCustomerId = ''.obs;

  final List<double> predefinedBills = [1, 5, 10, 20, 50, 100];

  @override
  void onInit() {
    super.onInit();
    final settingsController = Get.isRegistered<SettingsController>()
        ? Get.find<SettingsController>()
        : Get.put(SettingsController());
    exchangeRate.value = settingsController.exchangeRate.value;
    tva.value = settingsController.tva.value;
    final args = Get.arguments;
    if (args is List) {
      // Copies, not the till's own objects: editing a quantity here must not
      // silently rewrite the cart behind the cashier, and abandoning checkout
      // must leave the till exactly as it was.
      cartItems
          .assignAll(args.whereType<AddEditItemModel>().map((i) => i.copy()));
    }
    // A rate the shop never configured would turn every LBP total into zero.
    if (exchangeRate.value <= 0) {
      log('Exchange rate is not configured; LBP totals will read 0');
    }
    calculateTotals();
  }

  void addToCart(AddEditItemModel item) {
    cartItems.add(item);
    calculateTotals();
  }

  void removeFromCart(int index) {
    if (index < 0 || index >= cartItems.length) return;
    cartItems.removeAt(index);
    calculateTotals();

    // Deleting the last line is the cashier emptying the basket, not backing
    // out of checkout: leave an empty till behind and go back to it.
    if (cartItems.isEmpty) {
      if (Get.isRegistered<HomeSceenController>()) {
        Get.find<HomeSceenController>().clearCart();
      }
      Get.back();
    }
  }

  void updateQuantity(int index, int quantity) {
    if (index < 0 || index >= cartItems.length) return;
    if (quantity > 0) {
      cartItems[index].quantity = quantity;
      calculateTotals();
    }
  }

  void calculateTotals() {
    double subtotal = 0.0;
    for (final item in cartItems) {
      subtotal += (item.sellingPrice ?? 0.0) * (item.quantity ?? 1);
    }
    subtotalUSD.value = Money.round(subtotal);

    // The configured VAT was collected from settings and then never charged.
    final rate = tva.value <= 0 ? 0.0 : tva.value / 100;
    tvaAmountUSD.value = Money.round(subtotalUSD.value * rate);
    totalUSD.value = Money.round(subtotalUSD.value + tvaAmountUSD.value);
    totalLBP.value =
        Money.round(totalUSD.value * exchangeRate.value, decimals: 0);
    remainingAmount.value = totalUSD.value;
  }

  void applyPredefinedBill(double billAmount) {
    remainingAmount.value -= billAmount;
    if (remainingAmount.value < 0) {
      remainingAmount.value = 0;
    }
  }

  void updateExchangeRate(double newRate) {
    exchangeRate.value = newRate;
    calculateTotals();
  }

  /// Picks up a rate change made in settings after this screen was built.
  void applySettings({required double exchangeRate, required double tva}) {
    this.exchangeRate.value = exchangeRate;
    this.tva.value = tva;
    calculateTotals();
  }

  Future<void> payNow() async {
    if (cartItems.isEmpty) {
      Notify.error('Nothing to charge', 'Add an item before taking payment');
      return;
    }
    try {
      final items = cartItems.map((item) => item.toJson()).toList();
      await SalesService.saveSale(
          items, totalUSD.value, totalLBP.value, exchangeRate.value, tva.value);
      _finishSale();
    } catch (e) {
      // Leaving the cart intact and staying put is the only safe outcome: the
      // sale was not recorded, so the cashier must be able to try again.
      log('Error in payNow: $e');
      Notify.error('Sale not recorded', 'The sale could not be saved: $e');
    }
  }

  Future<void> payLater(String customerId) async {
    if (cartItems.isEmpty) {
      Notify.error('Nothing to charge', 'Add an item before opening a tab');
      return;
    }
    if (customerId.isEmpty) {
      Notify.error('No customer', 'Pick a customer to put this on their tab');
      return;
    }
    try {
      selectedCustomerId.value = customerId;
      final items = cartItems.map((item) => item.toJson()).toList();
      await SalesService.saveTab(customerId, items, totalUSD.value,
          totalLBP.value, exchangeRate.value, tva.value);
      _finishSale();
    } catch (e) {
      log('Error in payLater: $e');
      Notify.error('Tab not opened', 'The tab could not be saved: $e');
    }
  }

  /// Clears the till and returns to the sales screen. Only ever called once
  /// the sale is safely on disk.
  void _finishSale() {
    cartItems.clear();
    calculateTotals();

    if (Get.isRegistered<HomeSceenController>()) {
      Get.find<HomeSceenController>().clearCart();
    }

    // offNamed leaves the Home screen already under checkout in place and
    // pushes a second one, so Home stacked up all shift.
    Get.offAllNamed(Paths.homeScreen);
  }

  void showCustomerSelector() {
    if (!Get.isRegistered<ClientsController>()) {
      Get.put(ClientsController());
    }

    Get.dialog(
      const CustomerSelectorDialog(),
    ).then((result) {
      if (result != null && result is Map<String, dynamic>) {
        final customerId = result['id'] as String? ?? '';
        if (customerId.isNotEmpty) {
          payLater(customerId);
        } else {
          Notify.info('Info', 'Please select a customer');
        }
      }
      // Backing out is not worth a message; the cashier just changed their
      // mind and is still on the checkout screen.
    });
  }
}
