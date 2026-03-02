import 'package:bolao_bolado/components/formatters/money_input_format.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';

class CustomField extends StatelessWidget {
  final String hint;
  final IconData? icon;
  final bool? isNumeric;
  final TextInputType? keyboardType;
  final TextEditingController controller;
  final TextInputAction? textInputAction;
  final double? maxWidth;
  final Widget? suffix;
  final bool? obscure;
  final bool? readOnly;
  final Widget? prefix;
  final void Function()? onTap;
  final bool? isRequired;

  const CustomField({
    super.key,
    required this.hint,
    required this.controller,
    this.icon,
    this.isNumeric = false,
    this.obscure = false,
    this.textInputAction,
    this.keyboardType,
    this.maxWidth = 300,
    this.suffix,
    this.readOnly = false,
    this.onTap,
    this.prefix,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    const double radius = 14;
    BorderRadius borderRadius = BorderRadius.circular(radius);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth!),
      child: Form(
        child: TextFormField(
          controller: controller,
          readOnly: readOnly!,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: TextStyle(color: Color(0xFF1F2937), fontSize: 18),
          obscureText: obscure!,
          enableInteractiveSelection: true,
          onTap: onTap,
          inputFormatters: isNumeric! ? [MoneyInputFormat()] : null,
          validator: isRequired!
              ? (value) {
                  if (value == null || value.isEmpty) {
                    return 'Campo obrigatório';
                  }
                  if (isNumeric!) {
                    final number = double.tryParse(
                      value.replaceAll(',', '').replaceAll('.', ''),
                    );
                    if (number == 0) {
                      return 'Campo obrigatório';
                    }
                  }
                  return null;
                }
              : null,
          decoration: InputDecoration(
            prefix: prefix,
            labelText: hint,
            floatingLabelStyle: TextStyle(color: Colors.black),
            prefixIcon: icon != null ? Icon(icon) : null,
            filled: true,
            fillColor: const Color(0xFFF3F4F6),
            suffixIcon: suffix,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: BorderSide(color: Color(0xFFDDDDDD), width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: BorderSide(color: Color(0xFFCCCCCC), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: BorderSide(color: Colors.red, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: BorderSide(color: Colors.red, width: 2.5),
            ),
          ),
        ),
      ),
    );
  }
}

class CustomDropdownField<T> extends StatelessWidget {
  final String hint;
  final IconData? icon;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final double? maxWidth;
  final Widget? suffix;
  final String? Function(T?)? validator;
  final bool enabled;

  const CustomDropdownField({
    super.key,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
    this.icon,
    this.maxWidth,
    this.suffix,
    this.validator,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    const double radius = 14;
    final BorderRadius borderRadius = BorderRadius.circular(radius);

    return Theme(
      data: Theme.of(context).copyWith(canvasColor: const Color(0xFFF3F4F6)),
      child: ConstrainedBox(
        constraints: maxWidth != null
            ? BoxConstraints(maxWidth: maxWidth!)
            : const BoxConstraints(maxWidth: 300),
        child: DropdownButtonFormField2(
          value: value,
          items: items,
          onChanged: enabled ? onChanged : null,
          validator: validator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          isExpanded: true,
          iconStyleData: const IconStyleData(
            icon: Icon(Icons.keyboard_arrow_down_rounded),
            iconSize: 26,
          ),
          style: const TextStyle(color: Color(0xFF1F2937), fontSize: 18),
          decoration: InputDecoration(
            labelText: hint,
            floatingLabelStyle: const TextStyle(color: Colors.black),
            prefixIcon: Icon(icon),
            filled: true,
            fillColor: const Color(0xFFF3F4F6),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: const BorderSide(
                color: Color(0xFFDDDDDD),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: const BorderSide(
                color: Color(0xFFCCCCCC),
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: const BorderSide(color: Colors.red, width: 2.5),
            ),
          ),
          dropdownStyleData: DropdownStyleData(
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(radius),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ],
            ),
          ),
          menuItemStyleData: const MenuItemStyleData(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            height: 48,
          ),
        ),
      ),
    );
  }
}
