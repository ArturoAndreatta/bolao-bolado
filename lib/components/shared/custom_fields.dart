import 'package:bolao_bolado/components/formatters/money_input_format.dart';
import 'package:bolao_bolado/components/shared/custom_field_decoration.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
  final void Function(String)? onFieldSubmitted;
  final bool? isRequired;
  // Validação adicional, aplicada depois da checagem de obrigatório/numérico.
  // Retorne null para indicar que o valor passou nessa checagem extra.
  final String? Function(String?)? validator;

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
    this.onFieldSubmitted,
    this.prefix,
    this.isRequired = false,
    this.validator,
  });

  String? _validate(String? value) {
    if (isRequired!) {
      if (value == null || value.isEmpty) {
        return 'Campo obrigatório';
      }
      if (isNumeric!) {
        final number = MoneyInputFormat.parse(value);
        if (number == null || number == 0) {
          return 'Campo obrigatório';
        }
      }
    }
    return validator?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth!),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly!,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        style: const TextStyle(color: Color(0xFF1F2937), fontSize: 18),
        obscureText: obscure!,
        enableInteractiveSelection: true,
        onTap: onTap,
        onFieldSubmitted: onFieldSubmitted,
        inputFormatters: isNumeric! ? [MoneyInputFormat()] : null,
        validator: (isRequired! || validator != null) ? _validate : null,
        decoration: CustomFieldDecoration.build(
          hint: hint,
          icon: icon,
          prefix: prefix,
          suffix: suffix,
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
    this.validator,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(canvasColor: const Color(0xFFF3F4F6)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth ?? 300),
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
          decoration: CustomFieldDecoration.build(hint: hint, icon: icon),
          dropdownStyleData: DropdownStyleData(
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(CustomFieldDecoration.radius),
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

// Campo de data: encapsula showDatePicker + formatação (dd/MM/yyyy via
// intl), evitando reimplementar o picker e o padLeft manual em cada tela.
class CustomDateField extends StatelessWidget {
  final String hint;
  final IconData? icon;
  final TextEditingController controller;
  final double? maxWidth;
  final bool isRequired;
  final DateTime? initialDate;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final void Function(DateTime picked)? onPicked;
  final TextInputAction? textInputAction;

  static final DateFormat _formatter = DateFormat('dd/MM/yyyy');

  const CustomDateField({
    super.key,
    required this.hint,
    required this.controller,
    this.icon = Icons.calendar_today,
    this.maxWidth = 300,
    this.isRequired = false,
    this.initialDate,
    this.firstDate,
    this.lastDate,
    this.onPicked,
    this.textInputAction,
  });

  Future<void> _abrirPicker(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: firstDate ?? DateTime(2020),
      lastDate: lastDate ?? DateTime(2030),
    );
    if (picked == null) return;
    controller.text = _formatter.format(picked);
    onPicked?.call(picked);
  }

  @override
  Widget build(BuildContext context) {
    return CustomField(
      hint: hint,
      icon: icon,
      controller: controller,
      readOnly: true,
      isRequired: isRequired,
      maxWidth: maxWidth,
      textInputAction: textInputAction,
      onTap: () => _abrirPicker(context),
    );
  }
}

// Campo de hora: encapsula showTimePicker + formatação (HH:mm via intl),
// evitando reimplementar o picker e o padLeft manual em cada tela.
class CustomTimeField extends StatelessWidget {
  final String hint;
  final IconData? icon;
  final TextEditingController controller;
  final double? maxWidth;
  final bool isRequired;
  final TimeOfDay? initialTime;
  final void Function(TimeOfDay picked)? onPicked;
  final TextInputAction? textInputAction;

  const CustomTimeField({
    super.key,
    required this.hint,
    required this.controller,
    this.icon = Icons.schedule_outlined,
    this.maxWidth = 300,
    this.isRequired = false,
    this.initialTime,
    this.onPicked,
    this.textInputAction,
  });

  static String format(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  Future<void> _abrirPicker(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime ?? TimeOfDay.now(),
    );
    if (picked == null) return;
    controller.text = format(picked);
    onPicked?.call(picked);
  }

  @override
  Widget build(BuildContext context) {
    return CustomField(
      hint: hint,
      icon: icon,
      controller: controller,
      readOnly: true,
      isRequired: isRequired,
      maxWidth: maxWidth,
      textInputAction: textInputAction,
      onTap: () => _abrirPicker(context),
    );
  }
}
