import 'package:flutter/material.dart';

// Decoração compartilhada por CustomField e CustomDropdownField, para que
// os dois campos irmãos mantenham exatamente a mesma aparência (cores,
// bordas, raio) a partir de uma única fonte.
class CustomFieldDecoration {
  static const double radius = 14;

  static InputDecoration build({
    required String hint,
    IconData? icon,
    Widget? prefix,
    Widget? suffix,
  }) {
    final borderRadius = BorderRadius.circular(radius);

    return InputDecoration(
      prefix: prefix,
      labelText: hint,
      floatingLabelStyle: const TextStyle(color: Colors.black),
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
        borderSide: const BorderSide(color: Color(0xFFDDDDDD), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: const BorderSide(color: Color(0xFFCCCCCC), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: const BorderSide(color: Colors.red, width: 2.5),
      ),
    );
  }
}
