import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos/core/helpers/money.dart';
import 'package:pos/core/helpers/notify.dart';
import 'package:pos/custom_widgets/barcode_input_field/barcode_input_field.dart';
import 'package:pos/custom_widgets/form_dropdown/form_dropdown.dart';
import 'package:pos/custom_widgets/form_input_field/form_input_field.dart';
import 'package:pos/custom_widgets/pos_button/pos_button.dart';
import 'package:pos/http_client/data/models/items/add_edit_items_model.dart';
import 'package:pos/modules/home_screen/controller/home_sceen_controller.dart';
import 'package:pos/themes/styles/styles.dart';

/// Edits every field of a catalog row without leaving the till.
///
/// Opened by long-pressing a line in the cart. Saving rewrites the catalog
/// row, and [HomeSceenController.updateProduct] carries the new name and
/// price onto the line being sold.
///
/// Pops true once saved, or null if the cashier backed out.
class EditItemDialog extends StatefulWidget {
  const EditItemDialog({super.key, required this.product});

  /// The catalog row, not the cart line: the line's quantity is the count
  /// being sold, while here it is the stock.
  final AddEditItemModel product;

  static Future<bool?> show(
    BuildContext context, {
    required AddEditItemModel product,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EditItemDialog(product: product),
    );
  }

  @override
  State<EditItemDialog> createState() => _EditItemDialogState();
}

class _EditItemDialogState extends State<EditItemDialog> {
  static const String _newCategoryOption = '__new_category__';

  final HomeSceenController _controller = Get.find<HomeSceenController>();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _quantityController;
  late final TextEditingController _costController;
  late final TextEditingController _tvaController;
  late final TextEditingController _priceAfterTvaController;
  late final TextEditingController _profitController;
  late final TextEditingController _sellingController;
  late final TextEditingController _newCategoryController;

  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p.description ?? '');
    _barcodeController = TextEditingController(text: p.barcode ?? '');
    _quantityController =
        TextEditingController(text: p.quantity?.toString() ?? '');
    _costController = TextEditingController(text: _text(p.costPrice));
    _tvaController = TextEditingController(text: _text(p.tvaPercent));
    _priceAfterTvaController =
        TextEditingController(text: _text(p.priceAfterTva));
    _profitController = TextEditingController(text: _text(p.profitPercent));
    _sellingController = TextEditingController(text: _text(p.sellingPrice));
    _newCategoryController = TextEditingController();

    // The dropdown asserts its value is one of its items, so a category that
    // has since been deleted starts unselected rather than crashing the form.
    if (_controller.categories.contains(p.category)) {
      _selectedCategory = p.category;
    } else if (_controller.categories.isEmpty) {
      _selectedCategory = _newCategoryOption;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _quantityController.dispose();
    _costController.dispose();
    _tvaController.dispose();
    _priceAfterTvaController.dispose();
    _profitController.dispose();
    _sellingController.dispose();
    _newCategoryController.dispose();
    super.dispose();
  }

  static String _text(double? value) => value?.toString() ?? '';

  static double? _read(TextEditingController c) =>
      double.tryParse(c.text.trim());

  bool get _isCreatingCategory => _selectedCategory == _newCategoryOption;

  /// Null when nothing was picked or the new category name was left blank.
  String? get _category {
    final name = _isCreatingCategory
        ? _newCategoryController.text.trim()
        : _selectedCategory;
    return (name == null || name.isEmpty) ? null : name;
  }

  // Pricing chain: cost → (TVA) → price after TVA → (profit) → selling price.
  //
  // An item made from the till has a selling price and nothing before it in
  // the chain. Each step therefore only runs when its inputs are there, so
  // filling in a cost later derives the profit from the price already
  // charged instead of overwriting that price.

  void _onCostOrTvaChanged() {
    final cost = _read(_costController);
    if (cost == null) return;
    final tva = _read(_tvaController) ?? 0;
    _priceAfterTvaController.text = (cost * (1 + tva / 100)).toStringAsFixed(2);
    _carryToSellingPrice();
  }

  void _onPriceAfterTvaChanged() {
    final cost = _read(_costController);
    final after = _read(_priceAfterTvaController);
    if (cost != null && cost != 0 && after != null) {
      _tvaController.text = (((after / cost) - 1) * 100).toStringAsFixed(2);
    }
    _carryToSellingPrice();
  }

  void _carryToSellingPrice() {
    if (_read(_profitController) != null) {
      _sellingFromProfit();
    } else {
      _profitFromSelling();
    }
  }

  void _sellingFromProfit() {
    final after = _read(_priceAfterTvaController);
    final profit = _read(_profitController);
    if (after == null || profit == null) return;
    _sellingController.text = (after * (1 + profit / 100)).toStringAsFixed(2);
  }

  void _profitFromSelling() {
    final after = _read(_priceAfterTvaController);
    final selling = _read(_sellingController);
    if (after == null || after == 0 || selling == null) return;
    _profitController.text = (((selling / after) - 1) * 100).toStringAsFixed(2);
  }

  String? _validateBarcode(String? value) {
    final code = value?.trim() ?? '';
    if (code.isEmpty) return null;
    final owner = _controller.findByBarcode(code);
    if (owner != null && owner.identityKey != widget.product.identityKey) {
      return 'Another item already uses this barcode';
    }
    return null;
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final category = _category;
    if (_isCreatingCategory && category != null) {
      _controller.addCategory(category);
    }

    final updated = AddEditItemModel(
      description: _nameController.text.trim(),
      category: category,
      barcode: _barcodeController.text.trim(),
      quantity: int.tryParse(_quantityController.text.trim()) ?? 0,
      costPrice: _read(_costController),
      tvaPercent: _read(_tvaController),
      priceAfterTva: _read(_priceAfterTvaController),
      profitPercent: _read(_profitController),
      sellingPrice: Money.round(_read(_sellingController) ?? 0),
    );

    if (!_controller.updateProduct(widget.product, updated)) {
      Notify.error('Not saved', 'That item is no longer in the catalog');
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pop(true);
  }

  /// Two fields side by side; the form has nine, and stacked they would not
  /// fit on a tablet without scrolling.
  Widget _pair(Widget left, Widget right) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 16),
        Expanded(child: right),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Item'),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _pair(
                  FormInputField(
                    controller: _nameController,
                    label: 'Name',
                    hint: 'Enter item name',
                  ),
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
                _pair(
                  BarcodeInputField(
                    controller: _barcodeController,
                    label: 'Barcode',
                    hint: 'Scan or type a barcode',
                    validator: _validateBarcode,
                  ),
                  FormInputField(
                    controller: _quantityController,
                    label: 'Stock Quantity',
                    hint: 'Enter stock quantity',
                    keyboardType: TextInputType.number,
                  ),
                ),
                Styles.verticalSpacer,
                _pair(
                  FormInputField(
                    controller: _costController,
                    label: 'Cost Price',
                    hint: 'Enter cost price',
                    keyboardType: TextInputType.number,
                    allowDecimal: true,
                    onChange: _onCostOrTvaChanged,
                  ),
                  FormInputField(
                    controller: _tvaController,
                    label: 'TVA %',
                    hint: 'Enter TVA percentage',
                    keyboardType: TextInputType.number,
                    allowDecimal: true,
                    onChange: _onCostOrTvaChanged,
                  ),
                ),
                Styles.verticalSpacer,
                _pair(
                  FormInputField(
                    controller: _priceAfterTvaController,
                    label: 'Price After TVA',
                    hint: 'Enter price after TVA',
                    keyboardType: TextInputType.number,
                    allowDecimal: true,
                    onChange: _onPriceAfterTvaChanged,
                  ),
                  FormInputField(
                    controller: _profitController,
                    label: 'Profit %',
                    hint: 'Enter profit percentage',
                    keyboardType: TextInputType.number,
                    allowDecimal: true,
                    onChange: _sellingFromProfit,
                  ),
                ),
                Styles.verticalSpacer,
                FormInputField(
                  controller: _sellingController,
                  label: 'Selling Price',
                  hint: 'Enter selling price',
                  keyboardType: TextInputType.number,
                  allowDecimal: true,
                  textInputAction: TextInputAction.done,
                  onChange: _profitFromSelling,
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
          text: 'Save Changes',
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          onPressed: _save,
        ),
      ],
    );
  }
}
