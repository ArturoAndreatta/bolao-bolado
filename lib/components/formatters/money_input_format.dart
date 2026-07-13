import 'package:flutter/services.dart';

class MoneyInputFormat extends TextInputFormatter {
  MoneyInputFormat({this.maximoDigitos = 12, this.semCentavos = false});

  final int maximoDigitos;
  // Quando true, o campo exibe só a parte inteira (ex: "6", "1.000"), sem
  // sufixo de centavos — usado em valores sempre inteiros, como o valor de
  // aposta em salas de cota inteira (Mega-Sena, R$6). Sem ",00" fixo no
  // texto não há ambiguidade entre "dígito digitado" e "sufixo decorativo",
  // que é o que causava zeros fantasmas ao editar/apagar.
  final bool semCentavos;

  // Converte o texto exibido de volta para double. Aceita tanto o formato
  // com centavos (ex: "1.234,56") quanto sem vírgula (modo semCentavos,
  // ex: "1.234") — único ponto de parse inverso do MoneyInputFormat, para
  // não duplicar essa lógica em quem consome o campo.
  static double? parse(String valorFormatado) {
    if (valorFormatado.isEmpty) return null;
    final normalizado = valorFormatado.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(normalizado);
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue valorAntigo,
    TextEditingValue valorNovo,
  ) {
    // Descarta tudo que não for dígito: o usuário digita "livre" e a máscara
    // é sempre reconstruída a partir dos números puros (não do texto exibido).
    String digitos = valorNovo.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (digitos.length > maximoDigitos) {
      return valorAntigo;
    }

    final valorFormatado = semCentavos
        ? _formatarSemCentavos(digitos)
        : _formatarComCentavos(digitos);

    // Cursor sempre no final: como o texto inteiro é reconstruído a cada
    // tecla, não há como preservar a posição original de forma confiável.
    return TextEditingValue(
      text: valorFormatado,
      selection: TextSelection.collapsed(offset: valorFormatado.length),
    );
  }

  String _formatarComCentavos(String digitos) {
    // Garante ao menos "0,00": os 2 últimos dígitos são sempre os centavos,
    // então o valor precisa ter no mínimo 3 caracteres antes de fatiar.
    digitos = digitos.padLeft(3, '0');

    final centavos = digitos.substring(digitos.length - 2);
    final inteiro = digitos.substring(0, digitos.length - 2);
    final inteiroComMilhar = _adicionarSeparadorMilhar(inteiro);
    return '$inteiroComMilhar,$centavos';
  }

  // Todos os dígitos digitados formam a parte inteira; sem sufixo fixo,
  // então apagar/digitar se comporta como um campo numérico comum.
  String _formatarSemCentavos(String digitos) {
    if (digitos.isEmpty) return '';
    return _adicionarSeparadorMilhar(digitos);
  }

  // Insere "." a cada 3 dígitos (padrão pt-BR de milhar), construindo o
  // resultado da direita para a esquerda e depois revertendo.
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
