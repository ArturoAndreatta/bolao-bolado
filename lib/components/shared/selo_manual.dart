import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/core/app_radii.dart';
import 'package:flutter/material.dart';

/// Selo "M" exibido ao lado do nome de apostas lançadas manualmente pelo
/// admin (ver `criarApostaManual`), para diferenciá-las das apostas feitas
/// pelo próprio participante dentro do app.
///
/// Cinza de propósito: é um dado de origem do registro, não um estado da
/// aposta. As cores fortes da linha já significam outra coisa (verde =
/// verificada, amarelo = editada após verificação), e um selo colorido aqui
/// competiria com elas.
class SeloManual extends StatelessWidget {
  /// Fica um pouco menor na tabela do desktop, onde a fonte base é menor.
  final double tamanhoFonte;

  const SeloManual({super.key, this.tamanhoFonte = 10});

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    return Tooltip(
      message: 'Aposta lançada manualmente pelo admin',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: cores.superficieAlta,
          borderRadius: AppRadii.circularXs,
          border: Border.all(color: cores.borda),
        ),
        child: Text(
          'M',
          style: TextStyle(
            fontSize: tamanhoFonte,
            fontWeight: FontWeight.w700,
            color: cores.textoSuave,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}
