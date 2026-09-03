import 'package:get/get.dart';
import 'package:pos/core/helpers/notify.dart';
import 'package:flutter/material.dart';
import 'package:pos/core/helpers/money.dart';
import 'package:pos/http_client/local_storage/hive_service.dart';
import 'package:pos/modules/checkout/controller/checkout_controller.dart';
import 'package:pos/http_client/services/excel_service.dart';

class SettingsController extends GetxController {
  static const String _defaultStoreName = 'POS';

  final storeName = _defaultStoreName.obs;
  final exchangeRate = 0.0.obs;
  final tva = 0.0.obs;

  /// The form's own state. Edits used to be written straight onto the live
  /// values on every keystroke, so half-typed rates were charged to real
  /// customers and backing out of the screen never put them back.
  late final TextEditingController storeNameField;
  late final TextEditingController exchangeRateField;
  late final TextEditingController tvaField;

  @override
  void onInit() {
    super.onInit();
    loadSettings();
    storeNameField = TextEditingController(text: storeName.value);
    exchangeRateField =
        TextEditingController(text: _asText(exchangeRate.value));
    tvaField = TextEditingController(text: _asText(tva.value));
  }

  @override
  void onClose() {
    storeNameField.dispose();
    exchangeRateField.dispose();
    tvaField.dispose();
    super.onClose();
  }

  /// Re-seeds the form from what is actually saved, discarding any edits.
  void resetDraft() {
    storeNameField.text = storeName.value;
    exchangeRateField.text = _asText(exchangeRate.value);
    tvaField.text = _asText(tva.value);
  }

  static String _asText(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';

  void loadSettings() {
    final name = HiveService.getSetting('storeName');
    // An empty stored name is not a name: fall back to the default rather
    // than showing a blank header.
    storeName.value =
        (name is String && name.trim().isNotEmpty) ? name : _defaultStoreName;
    // An Excel import writes settings back as text, so a plain `as num` cast
    // crashed the settings screen after a restore.
    exchangeRate.value = Money.parse(HiveService.getSetting('exchangeRate'));
    tva.value = Money.parse(HiveService.getSetting('tva'));
  }

  Future<void> saveSettings() async {
    final name = storeNameField.text.trim();
    final rate = Money.parse(exchangeRateField.text, fallback: -1);
    final vat = Money.parse(tvaField.text, fallback: -1);

    if (name.isEmpty) {
      Notify.error('Invalid settings', 'The store needs a name');
      return;
    }
    // A zero rate silently turns every LBP total on every receipt into 0.
    if (rate <= 0) {
      Notify.error('Invalid settings', 'Enter an exchange rate above zero');
      return;
    }
    if (vat < 0 || vat > 100) {
      Notify.error('Invalid settings', 'VAT must be between 0 and 100');
      return;
    }

    storeName.value = name;
    exchangeRate.value = rate;
    tva.value = vat;

    await HiveService.storeSetting('storeName', name);
    await HiveService.storeSetting('exchangeRate', rate);
    await HiveService.storeSetting('tva', vat);
    // Checkout copies these rates when it is created, so a checkout screen
    // built earlier in the session would otherwise keep charging the old VAT.
    if (Get.isRegistered<CheckoutController>()) {
      Get.find<CheckoutController>().applySettings(
        exchangeRate: exchangeRate.value,
        tva: tva.value,
      );
    }
    Get.back();
  }

  Future<void> exportData() async {
    try {
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      final filePath = await ExcelService.exportToExcel();

      if (filePath != null) {
        Get.back();

        Notify.success(
            'Export Successful', 'Data exported successfully to: $filePath');
      } else {
        Get.back();

        Notify.error('Export Failed', 'Failed to export data to Excel');
      }
    } catch (e) {
      Get.back();

      Notify.error('Export Error', 'Error exporting data: $e');
    }
  }

  Future<void> importData() async {
    try {
      final confirm = await Get.dialog(
        AlertDialog(
          title: const Text('Import Data'),
          content: const Text(
              'This will replace all existing data with data from the Excel file. This action cannot be undone. Continue?'),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Get.back(result: true),
              child: const Text('Import', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      final success = await ExcelService.importFromExcel();

      if (success) {
        Get.back();

        loadSettings();

        Notify.success('Import Successful', 'Data imported successfully');
      } else {
        Get.back();

        Notify.error('Import Failed', 'Failed to import data from Excel');
      }
    } catch (e) {
      Get.back();

      Notify.error('Import Error', 'Error importing data: $e');
    }
  }
}
