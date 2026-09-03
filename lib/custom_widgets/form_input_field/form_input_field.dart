import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pos/themes/styles/styles.dart';

class FormInputField extends StatefulWidget {
  final TextEditingController controller;
  final bool isObscured,
      isReadOnly,
      isRequired,
      specialCharactersValidator,
      isSeparator,
      showSuffix,
      allowDecimal;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? hint, label;
  final void Function()? onChange;
  final List<TextInputFormatter>? inputFormatters;
  final Color? enabledBorderColor;
  final Color? focusedBorderColor;
  final Color? errorBorderColor;
  final String? Function(String?)? customValidator;

  const FormInputField({
    super.key,
    required this.controller,
    this.onChange,
    this.isObscured = false,
    this.isReadOnly = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.hint,
    this.isRequired = false,
    this.specialCharactersValidator = false,
    required this.label,
    this.isSeparator = false,
    this.showSuffix = false,
    this.allowDecimal = false,
    this.inputFormatters,
    this.enabledBorderColor,
    this.focusedBorderColor,
    this.errorBorderColor,
    this.customValidator,
  });

  @override
  State<FormInputField> createState() => _FormInputFieldState();
}

class _FormInputFieldState extends State<FormInputField> {
  late bool _obscured;

  @override
  void initState() {
    super.initState();
    _obscured = widget.isObscured;
  }

  void _toggleObscure() {
    setState(() {
      _obscured = !_obscured;
    });
  }

  List<TextInputFormatter> _getDefaultFormatters() {
    if (widget.keyboardType == TextInputType.number) {
      if (widget.allowDecimal) {
        return [_DecimalInputFormatter()];
      } else {
        return [FilteringTextInputFormatter.digitsOnly];
      }
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label!,
          style: Styles.labelTextStyle,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.controller,
          obscureText: _obscured,
          readOnly: widget.isReadOnly,
          maxLines: !_obscured ? null : 1,
          keyboardType:
              !_obscured ? TextInputType.multiline : widget.keyboardType,
          textInputAction: widget.textInputAction ??
              (_obscured ? TextInputAction.next : TextInputAction.newline),
          validator: (val) {
            if (_obscured) {
              return null;
            }

            if (widget.isRequired && (val == null || val.trim().isEmpty)) {
              return "This field cannot be empty";
            }

            if (widget.keyboardType == TextInputType.number &&
                val != null &&
                val.isNotEmpty) {
              final num? parsed = num.tryParse(val);
              if (parsed == null) {
                return "Please enter a valid number";
              }
            }

            final emojiRegex = RegExp(
              r'[\u{1F600}-\u{1F64F}'
              r'\u{1F300}-\u{1F5FF}'
              r'\u{1F680}-\u{1F6FF}'
              r'\u{1F700}-\u{1F77F}'
              r'\u{1F780}-\u{1F7FF}'
              r'\u{1F800}-\u{1F8FF}'
              r'\u{1F900}-\u{1F9FF}'
              r'\u{1FA00}-\u{1FA6F}'
              r'\u{1FA70}-\u{1FAFF}'
              r'\u{2600}-\u{26FF}'
              r'\u{2700}-\u{27BF}]',
              unicode: true,
            );
            if (val != null && emojiRegex.hasMatch(val)) {
              return "Emojis are not allowed";
            }

            if (widget.specialCharactersValidator) {
              final regex = RegExp(r'[!@#\$%^&*(),.?":{}|<>]');
              if (val != null && regex.hasMatch(val)) {
                return "Special characters are not allowed";
              }
            }

            if (widget.customValidator != null) {
              return widget.customValidator!(val);
            }

            return null;
          },
          onChanged: (val) {
            if (widget.isSeparator) {
              final newVal = val.replaceAll(',', '');
              if (newVal.isEmpty) return;

              final num? parsed = num.tryParse(newVal);
              if (parsed != null) {
                final formatted = NumberFormat.decimalPattern().format(parsed);

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  widget.controller.value = TextEditingValue(
                    text: formatted,
                    selection: TextSelection.collapsed(
                      offset: formatted.length,
                    ),
                  );
                });
              }
            }

            widget.onChange?.call();
          },
          style: Styles.inputTextStyle,
          inputFormatters: widget.inputFormatters ?? _getDefaultFormatters(),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: Styles.hintTextStyle,
            enabledBorder: OutlineInputBorder(
              borderSide:
                  BorderSide(color: widget.enabledBorderColor ?? Colors.grey),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide:
                  BorderSide(color: widget.focusedBorderColor ?? Colors.black),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              borderSide: BorderSide(
                color: widget.errorBorderColor ?? Colors.red,
                width: 2,
                style: BorderStyle.solid,
              ),
            ),
            suffixIcon: widget.showSuffix
                ? IconButton(
                    icon: Icon(
                      _obscured ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: _toggleObscure,
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

/// Rejects an edit that would leave a non-numeric value, keeping what was
/// already typed.
///
/// The previous formatter was `FilteringTextInputFormatter.allow` with an
/// anchored pattern. That filter keeps only the matching parts of the string,
/// and an anchored pattern matches nothing once a stray character is present
/// — so one bad keystroke erased the whole field. Typing 89500 and fumbling a
/// key left the rate at 500.
class _DecimalInputFormatter extends TextInputFormatter {
  static final RegExp _decimal = RegExp(r'^\d*\.?\d*$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty || _decimal.hasMatch(newValue.text)) {
      return newValue;
    }
    return oldValue;
  }
}
