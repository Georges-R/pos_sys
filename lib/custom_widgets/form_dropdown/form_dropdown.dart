import 'package:flutter/material.dart';
import 'package:pos/themes/styles/styles.dart';

class FormDropdown<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final DropdownButtonBuilder? selectedItemBuilder;
  final void Function(T?)? onChanged;
  final String? hint, label, helper;
  final bool isRequired;
  final String? Function(T?)? validator;

  const FormDropdown({
    super.key,
    required this.value,
    required this.items,
    this.selectedItemBuilder,
    this.onChanged,
    this.hint,
    this.helper,
    required this.label,
    this.isRequired = false,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label!,
          style: Styles.labelTextStyle,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          initialValue: value,
          items: items,
          selectedItemBuilder: selectedItemBuilder,
          onChanged: onChanged,
          validator: validator ??
              (isRequired
                  ? (val) => val == null ? "This field cannot be empty" : null
                  : null),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: Styles.hintTextStyle,
            helperText: helper,
            enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.grey),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.black),
            ),
            errorBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
              borderSide: BorderSide(
                color: Colors.red,
                width: 2,
                style: BorderStyle.solid,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
