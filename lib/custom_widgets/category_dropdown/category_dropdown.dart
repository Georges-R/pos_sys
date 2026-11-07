import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos/core/helpers/notify.dart';
import 'package:pos/custom_widgets/form_dropdown/form_dropdown.dart';
import 'package:pos/custom_widgets/pos_button/pos_button.dart';
import 'package:pos/modules/home_screen/controller/home_sceen_controller.dart';

/// The category picker on every item form.
///
/// Double-tapping a category, in the open list or once picked in the field,
/// renames it. A typo made while creating a category otherwise stayed on
/// every item filed under it, with nothing in the app able to change it.
class CategoryDropdown extends StatelessWidget {
  const CategoryDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.newCategoryOption,
  });

  final String? value;

  /// Also called with the new name when the picked category is renamed, so
  /// the form saves the item under a name that still exists.
  final ValueChanged<String?> onChanged;

  /// When set, a last entry with this value lets the user create a category.
  final String? newCategoryOption;

  static const String _newCategoryLabel = '+ New category';

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HomeSceenController>();
    return Obx(() {
      final categories = controller.categories.toList();
      final option = newCategoryOption;
      final values = [...categories, if (option != null) option];
      return FormDropdown<String>(
        // The dropdown asserts its value is one of its items, so a category
        // deleted under the form shows as unpicked rather than crashing it.
        value: values.contains(value) ? value : null,
        items: [
          for (final category in categories)
            DropdownMenuItem<String>(
              value: category,
              child: _renamable(context, category, fillRow: true),
            ),
          if (option != null)
            DropdownMenuItem<String>(
              value: option,
              child: const Text(_newCategoryLabel),
            ),
        ],
        selectedItemBuilder: (_) => [
          for (final category in categories) _renamable(context, category),
          if (option != null) const Text(_newCategoryLabel),
        ],
        onChanged: onChanged,
        label: 'Category',
        hint: 'Select category',
        helper:
            categories.isEmpty ? null : 'Double-tap a category to rename it',
      );
    });
  }

  /// In the open list the whole row takes the double-tap, not just the name:
  /// a first tap that missed the text would pick the category and close the
  /// list before the second one landed.
  Widget _renamable(BuildContext formContext, String category,
      {bool fillRow = false}) {
    return Builder(
      builder: (itemContext) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: () => _rename(formContext, itemContext, category),
        child: fillRow
            ? SizedBox(width: double.infinity, child: Text(category))
            : Text(category),
      ),
    );
  }

  Future<void> _rename(BuildContext formContext, BuildContext itemContext,
      String category) async {
    // A double-tap on a row of the open list leaves that list open over the
    // form; close it so the form underneath shows the new name.
    if (ModalRoute.of(itemContext) != ModalRoute.of(formContext)) {
      Navigator.of(itemContext).pop();
    }

    final name = await showDialog<String>(
      context: formContext,
      builder: (_) => _RenameCategoryDialog(category: category),
    );
    if (name == null || name == category) return;

    if (!Get.find<HomeSceenController>().renameCategory(category, name)) {
      return;
    }
    if (value == category) onChanged(name);
    Notify.success('Category renamed', '"$category" is now "$name"');
  }
}

/// Pops the new name, or null if the user backed out.
class _RenameCategoryDialog extends StatefulWidget {
  const _RenameCategoryDialog({required this.category});

  final String category;

  @override
  State<_RenameCategoryDialog> createState() => _RenameCategoryDialogState();
}

class _RenameCategoryDialogState extends State<_RenameCategoryDialog> {
  final HomeSceenController _controller = Get.find<HomeSceenController>();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    // Selected, so typing replaces the old name outright; a typo fix can
    // still tap into the text to change one letter.
    _nameController = TextEditingController(text: widget.category)
      ..selection =
          TextSelection(baseOffset: 0, extentOffset: widget.category.length);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String? _validate(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Enter a category name';
    // Renaming onto an existing category would quietly merge the two.
    if (name != widget.category && _controller.categories.contains(name)) {
      return 'Another category already has this name';
    }
    return null;
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(_nameController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename Category'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: true,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Category name',
                  helperText: 'Every item in this category moves with it',
                ),
                validator: _validate,
                onFieldSubmitted: (_) => _save(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        PosButton(
          text: 'Rename',
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          onPressed: _save,
        ),
      ],
    );
  }
}
