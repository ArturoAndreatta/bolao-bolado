import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/core/app_radii.dart';
import 'package:flutter/material.dart';

// Decoração compartilhada por CustomField e CustomDropdownField, para que
// os dois campos irmãos mantenham exatamente a mesma aparência (cores,
// bordas, raio) a partir de uma única fonte.
class CustomFieldDecoration {
  static const double radius = 14;

  /// Passou a receber [context] junto com o dark mode: preenchimento, bordas
  /// e cor do rótulo saem da paleta do tema ativo em vez de hex fixos.
  static InputDecoration build(
    BuildContext context, {
    required String hint,
    IconData? icon,
    Widget? prefix,
    Widget? suffix,
  }) {
    final cores = AppCores.de(context);
    final borderRadius = BorderRadius.circular(radius);

    return InputDecoration(
      prefix: prefix,
      labelText: hint,
      labelStyle: TextStyle(color: cores.textoSuave),
      floatingLabelStyle: TextStyle(color: cores.texto),
      prefixIcon: icon != null ? Icon(icon, color: cores.textoSuave) : null,
      filled: true,
      fillColor: cores.campo,
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      // Erro vira só borda vermelha, sem texto — mensagem completa some
      // no dialog ao tentar confirmar, então o texto de erro não precisa
      // reservar altura (evitaria empurrar/gerar scroll no card).
      errorStyle: const TextStyle(height: 0, fontSize: 0),
      border: OutlineInputBorder(
        borderRadius: AppRadii.circularMd,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: cores.bordaCampo, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: cores.bordaCampoFoco, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: cores.vermelho, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: cores.vermelho, width: 2.5),
      ),
    );
  }
}
