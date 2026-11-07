import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos/custom_widgets/barcode_input_field/barcode_input_field.dart';
import 'package:pos/custom_widgets/category_dropdown/category_dropdown.dart';
import 'package:pos/custom_widgets/form_input_field/form_input_field.dart';
import 'package:pos/custom_widgets/pos_button/pos_button.dart';
import 'package:pos/modules/items/add_edit_item/controller/add_edit_item_controller.dart';
import 'package:pos/themes/styles/styles.dart';

class AddEditItemView extends GetView<AddEditItemController> {
  const AddEditItemView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Item Management'),
        centerTitle: true,
      ),
      body: Align(
        alignment: Alignment.center,
        child: SizedBox(
          width: Styles.generaleWidth,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Form(
                key: controller.formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FormInputField(
                      controller: controller.descriptionController,
                      label: 'Description',
                      hint: 'Enter description',
                    ),
                    Styles.verticalSpacer,
                    Obx(
                      () => CategoryDropdown(
                        value: controller.selectedCategory.value,
                        onChanged: (value) {
                          if (value != null) {
                            controller.selectedCategory.value = value;
                          }
                        },
                      ),
                    ),
                    Styles.verticalSpacer,
                    BarcodeInputField(
                      controller: controller.barcodeController,
                      label: "Barcode",
                      hint: "Scan or type a barcode",
                    ),
                    Styles.verticalSpacer,
                    FormInputField(
                      controller: controller.quantityController,
                      label: 'Quantity',
                      hint: 'Enter quantity',
                      keyboardType: TextInputType.number,
                      allowDecimal: false,
                    ),
                    Styles.verticalSpacer,
                    FormInputField(
                      controller: controller.lowStockWarningController,
                      label: 'Low Stock Warning',
                      hint: 'Warn when stock falls to this quantity',
                      keyboardType: TextInputType.number,
                      allowDecimal: false,
                    ),
                    Styles.verticalSpacer,
                    FormInputField(
                      controller: controller.costPriceController,
                      label: 'Cost Price',
                      hint: 'Enter cost price',
                      keyboardType: TextInputType.number,
                      allowDecimal: true,
                      onChange: () => controller.calculatePriceAfterTva(),
                    ),
                    Styles.verticalSpacer,
                    FormInputField(
                      controller: controller.tvaPercentController,
                      label: 'TVA %',
                      hint: 'Enter TVA percentage',
                      keyboardType: TextInputType.number,
                      allowDecimal: true,
                      onChange: () => controller.calculatePriceAfterTva(),
                    ),
                    Styles.verticalSpacer,
                    FormInputField(
                      controller: controller.priceAfterTvaController,
                      label: 'Price After TVA',
                      hint: 'Enter price after TVA',
                      keyboardType: TextInputType.number,
                      allowDecimal: true,
                      onChange: () {
                        controller.calculateTvaPercent();
                        controller.calculateSellingPrice();
                      },
                    ),
                    Styles.verticalSpacer,
                    FormInputField(
                      controller: controller.profitPercentController,
                      label: 'Profit %',
                      hint: 'Enter profit percentage',
                      keyboardType: TextInputType.number,
                      allowDecimal: true,
                      onChange: () => controller.calculateSellingPrice(),
                    ),
                    Styles.verticalSpacer,
                    FormInputField(
                      controller: controller.sellingPriceController,
                      label: 'Selling Price',
                      hint: 'Enter selling price',
                      keyboardType: TextInputType.number,
                      allowDecimal: true,
                      onChange: () => controller.calculateProfitPercent(),
                    ),
                    Styles.verticalSpacer,
                    Align(
                      alignment: Alignment.centerRight,
                      child: PosButton(
                        text: 'Save Item',
                        onPressed: () {
                          controller.submitForm();
                        },
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
