import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomField extends StatelessWidget {
  final String hint;
  final IconData icon;
  final bool isNumeric;
  final TextEditingController controller;

  const CustomField({
    super.key,
    required this.hint,
    required this.icon,
    required this.isNumeric,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    const double radius = 14;
    BorderRadius borderRadius = BorderRadius.circular(radius);

    return SizedBox(
      width: 300,
      child: Form(
        child: TextFormField(
          controller: controller,
          keyboardType: isNumeric
              ? TextInputType.numberWithOptions(decimal: false)
              : null,
          inputFormatters: isNumeric
              ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
              : null,
          validator: isNumeric
              ? (value) {
                  if (value == null || value.isEmpty) {
                    return null;
                  }
                  final number = int.tryParse(value);
                  if (number == null || number < 0) {
                    return 'Valor inválido';
                  }
                  if (number % 6 != 0) {
                    return 'O número deve ser divisível por 6';
                  }
                  return null; // válido
                }
              : null,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: TextStyle(color: Color(0xFF1F2937), fontSize: 18),
          decoration: InputDecoration(
            labelText: hint,
            hintStyle: TextStyle(color: Colors.grey),
            floatingLabelStyle: TextStyle(color: Colors.grey),
            prefixIcon: Icon(icon, color: Colors.grey),
            fillColor: Color(0xFFF6F6F6),
            enabledBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: BorderSide(color: Color(0xFFDDDDDD), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: BorderSide(color: Color(0xFFCCCCCC), width: 2.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: BorderSide(color: Colors.red, width: 1),
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
