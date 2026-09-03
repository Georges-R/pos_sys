import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos/custom_widgets/form_input_field/form_input_field.dart';
import 'package:pos/custom_widgets/pos_button/pos_button.dart';
import 'package:pos/modules/settings/controller/settings_controller.dart';
import 'package:pos/themes/styles/styles.dart';

class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    // The fields live on the controller so they survive a rebuild and get
    // disposed with it; creating them here leaked one set per build.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.grey[200],
        centerTitle: true,
      ),
      body: Align(
        alignment: Alignment.center,
        child: SizedBox(
          width: Styles.generaleWidth,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                FormInputField(
                  controller: controller.storeNameField,
                  label: 'Store Name',
                  hint: 'Enter store name',
                  isRequired: true,
                ),
                const SizedBox(height: 16),
                FormInputField(
                  controller: controller.exchangeRateField,
                  label: 'Exchange Rate to LBP',
                  hint: 'Enter exchange rate',
                  keyboardType: TextInputType.number,
                  allowDecimal: true,
                  isRequired: true,
                ),
                const SizedBox(height: 16),
                FormInputField(
                  controller: controller.tvaField,
                  label: 'TVA %',
                  hint: 'Enter TVA percentage',
                  keyboardType: TextInputType.number,
                  allowDecimal: true,
                  isRequired: true,
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Data Management',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: PosButton(
                              text: 'Export Data',
                              icon: Icons.download,
                              backgroundColor: Colors.green,
                              onPressed: () => controller.exportData(),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: PosButton(
                              text: 'Import Data',
                              icon: Icons.upload,
                              backgroundColor: Colors.orange,
                              onPressed: () => controller.importData(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Export: Save all your data to an Excel file\nImport: Load data from an Excel file (will replace existing data)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Align(
                  alignment: Alignment.centerRight,
                  child: PosButton(
                    text: 'Save Settings',
                    icon: Icons.save,
                    backgroundColor: Colors.blue,
                    onPressed: () => controller.saveSettings(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
