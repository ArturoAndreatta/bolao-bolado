import 'package:flutter/services.dart';

class MoneyInputFormat extends TextInputFormatter {
  MoneyInputFormat({this.maximoDigitos = 12});

  final int maximoDigitos;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue valorAntigo,
    TextEditingValue valorNovo,
  ) {
    String digitos = valorNovo.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (digitos.length > maximoDigitos) {
      return valorAntigo;
    }

    digitos = digitos.padLeft(3, '0');

    final centavos = digitos.substring(digitos.length - 2);
    final inteiro = digitos.substring(0, digitos.length - 2);
    final inteiroComMilhar = _adicionarSeparadorMilhar(inteiro);
    final valorFormatado = '$inteiroComMilhar,$centavos';

    return TextEditingValue(
      text: valorFormatado,
      selection: TextSelection.collapsed(offset: valorFormatado.length),
    );
  }

  String _adicionarSeparadorMilhar(String valor) {
    valor = valor.replaceFirst(RegExp(r'^0+(?=\d)'), '');

    if (valor.isEmpty) return '0';

    final buffer = StringBuffer();

    for (int i = 0; i < valor.length; i++) {
      final indiceReverso = valor.length - 1 - i;
      buffer.write(valor[indiceReverso]);

      if ((i + 1) % 3 == 0 && i + 1 != valor.length) {
        buffer.write('.');
      }
    }
    return buffer.toString().split('').reversed.join();
  }
}
