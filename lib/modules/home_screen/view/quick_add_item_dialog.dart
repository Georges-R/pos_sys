import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos/custom_widgets/barcode_input_field/barcode_input_field.dart';
import 'package:pos/custom_widgets/form_dropdown/form_dropdown.dart';
import 'package:pos/custom_widgets/form_input_field/form_input_field.dart';
import 'package:pos/custom_widgets/pos_button/pos_button.dart';
import 'package:pos/http_client/data/models/items/add_edit_items_model.dart';
import 'package:pos/modules/home_screen/controller/home_sceen_controller.dart';
import 'package:pos/themes/styles/styles.dart';

/// Creates the catalog row for a barcode that scanned up empty, without
/// leaving the till.
///
/// Only what it takes to sell the item right now is asked for: name, category,
/// selling price and the stock on the shelf, with the scanned barcode
/// pre-filled and still editable in case the scan mangled it. Cost, TVA and
/// profit are left for the item screen — a cashier with a customer waiting
/// cannot stop to work out margins.
///
/// None of it is mandatory: a blank price or stock saves as 0. The one check
/// left is that the barcode is not already another item's, since two items on
/// one barcode would make every later scan, edit and delete ambiguous.
///
/// Pops the created product, or null if the cashier backed out.
class QuickAddItemDialog extends StatefulWidget {
  const QuickAddItemDialog({super.key, required this.barcode});

  final String barcode;

  static Future<AddEditItemModel?> show(
    BuildContext context, {
    required String barcode,
  }) {
    return showDialog<AddEditItemModel>(
      context: context,
      barrierDismissible: false,
      builder: (_) => QuickAddItemDialog(barcode: barcode),
    );
  }

  @override
  State<QuickAddItemDialog> createState() => _QuickAddItemDialogState();
}

class _QuickAddItemDialogState extends State<QuickAddItemDialog> {
  /// Stands in for "none of the existing categories". A shop that has just
  /// installed the app has no categories at all, so a plain dropdown would
  /// leave the cashier with nothing to pick and no way forward.
  static const String _newCategoryOption = '__new_category__';

  final HomeSceenController _controller = Get.find<HomeSceenController>();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _priceController;
  late final TextEditingController _quantityController;
  late final TextEditingController _newCategoryController;

  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _barcodeController = TextEditingController(text: widget.barcode);
    _priceController = TextEditingController();
    _quantityController = TextEditingController();
    _newCategoryController = TextEditingController();

    // The category the till is filtered on is almost always the one being
    // scanned, so start there.
    final filtered = _controller.selectedCategory.value;
    if (filtered.isNotEmpty && _controller.categories.contains(filtered)) {
      _selectedCategory = filtered;
    } else if (_controller.categories.isEmpty) {
      _selectedCategory = _newCategoryOption;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _newCategoryController.dispose();
    super.dispose();
  }

  bool get _isCreatingCategory => _selectedCategory == _newCategoryOption;

  /// Null when nothing was picked or the new category name was left blank.
  String? get _category {
    final name = _isCreatingCategory
        ? _newCategoryController.text.trim()
        : _selectedCategory;
    return (name == null || name.isEmpty) ? null : name;
  }

  String? _validateBarcode(String? value) {
    final code = value?.trim() ?? '';
    if (code.isEmpty) return null;
    // Two rows on the same barcode share an identity, so later edits and
    // deletes would hit whichever one happened to be found first.
    if (_controller.findByBarcode(code) != null) {
      return 'Another item already uses this barcode';
    }
    return null;
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final product = _controller.quickCreateProduct(
      description: _nameController.text,
      barcode: _barcodeController.text,
      sellingPrice: double.tryParse(_priceController.text.trim()) ?? 0,
      category: _category,
      quantity: int.tryParse(_quantityController.text.trim()) ?? 0,
    );

    if (product == null) {
      // Only reachable if the catalog changed under us between validating and
      // saving; re-validating surfaces it on the barcode field.
      _formKey.currentState?.validate();
      return;
    }
    Navigator.of(context).pop(product);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Item'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add the essentials now — the rest can be filled in from '
                  'Item Management later.',
                  style: Styles.hintTextStyle,
                ),
                const SizedBox(height: 16),
                FormInputField(
                  controller: _nameController,
                  label: 'Name',
                  hint: 'Enter item name',
                ),
                Styles.verticalSpacer,
                Obx(
                  () => FormDropdown<String>(
                    value: _selectedCategory,
                    items: [
                      ..._controller.categories.map(
                        (category) => DropdownMenuItem<String>(
                          value: category,
                          child: Text(category),
                        ),
                      ),
                      const DropdownMenuItem<String>(
                        value: _newCategoryOption,
                        child: Text('+ New category'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _selectedCategory = value),
                    label: 'Category',
                    hint: 'Select category',
                  ),
                ),
                if (_isCreatingCategory) ...[
                  Styles.verticalSpacer,
                  FormInputField(
                    controller: _newCategoryController,
                    label: 'New category name',
                    hint: 'Enter category name',
                  ),
                ],
                Styles.verticalSpacer,
                BarcodeInputField(
                  controller: _barcodeController,
                  label: 'Barcode',
                  hint: 'Scan or type a barcode',
                  validator: _validateBarcode,
                ),
                Styles.verticalSpacer,
                FormInputField(
                  controller: _priceController,
                  label: 'Selling Price',
                  hint: 'Enter selling price',
                  keyboardType: TextInputType.number,
                  allowDecimal: true,
                ),
                Styles.verticalSpacer,
                FormInputField(
                  controller: _quantityController,
                  label: 'Stock Quantity',
                  hint: 'Enter stock quantity',
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        PosButton(
          text: 'Save & Add to Sale',
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          onPressed: _save,
        ),
      ],
    );
  }
}
