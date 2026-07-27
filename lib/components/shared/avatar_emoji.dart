import 'package:flutter/material.dart';

/// Avatar circular com emoji, usado no chat, na lista de participantes, no
/// painel admin e no drawer.
///
/// Existe para os quatro lugares pararem de montar seu próprio `CircleAvatar`
/// com um fontSize escolhido no olho: cada um usava uma proporção diferente
/// entre círculo e emoji (13/28, 14/32, 16/32, 20/52), então o mesmo avatar
/// aparecia com pesos visuais diferentes dependendo da tela.
class AvatarEmoji extends StatelessWidget {
  /// Diâmetro do círculo.
  final double tamanho;
  final Color cor;
  final String emoji;

  /// Borda opcional ao redor do círculo (usada no drawer e na seleção).
  final Color? corBorda;
  final double larguraBorda;

  const AvatarEmoji({
    super.key,
    required this.tamanho,
    required this.cor,
    required this.emoji,
    this.corBorda,
    this.larguraBorda = 2,
  });

  @override
  Widget build(BuildContext context) {
    // 0.58 do diâmetro deixa uma margem visual constante entre o emoji e a
    // borda do círculo em qualquer tamanho.
    final tamanhoEmoji = tamanho * 0.58;

    return Container(
      width: tamanho,
      height: tamanho,
      decoration: BoxDecoration(
        color: cor,
        shape: BoxShape.circle,
        border: corBorda != null
            ? Border.all(color: corBorda!, width: larguraBorda)
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        emoji,
        textAlign: TextAlign.center,
        // height: 1 e o textHeightBehavior descartando as métricas de linha
        // são o que centraliza o emoji de fato. Sem isso o Text reserva o
        // leading da fonte acima e abaixo do glifo, e como esse espaço é
        // assimétrico o emoji assenta uns 2px acima do centro do círculo —
        // sutil isolado, mas visível numa coluna de avatares empilhados.
        textHeightBehavior: const TextHeightBehavior(
          applyHeightToFirstAscent: false,
          applyHeightToLastDescent: false,
        ),
        style: TextStyle(fontSize: tamanhoEmoji, height: 1),
      ),
    );
  }
}
