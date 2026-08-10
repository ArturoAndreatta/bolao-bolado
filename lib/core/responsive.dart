import 'package:flutter/material.dart';

/// Faixas de largura da tela.
///
/// Tudo aqui usa `MediaQuery.sizeOf` e **não** `MediaQuery.of`. A diferença
/// não é estilo: `of` cria dependência do `MediaQueryData` INTEIRO, então
/// qualquer campo que mude notifica quem chamou. O campo que muda toda hora é
/// `viewInsets` — o teclado do celular abrindo e fechando. Com `of`, digitar no
/// chat reconstruía a tela de Participantes inteira (filtro, ordenação e o card
/// Minha Aposta junto) mesmo com a largura parada no mesmo pixel. `sizeOf`
/// depende só do tamanho, que é o que estes métodos realmente leem.
class Responsive {
  // Abaixo de 600px: mobile. Entre 600 e 1024px: faixa intermediária (tablet),
  // não coberta por nenhum dos dois métodos — tratada como "não mobile" pelo restante do app.
  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 600;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 1024;

  // Largura mínima em que o layout lado a lado da tela de Participantes
  // (Minha Aposta, CustomCard maxWidth 460+20 de padding, ao lado do painel
  // de Participantes, HeaderCard/CustomCard maxWidth 937+20 de padding)
  // cabe sem estourar horizontalmente: 460+20 + 937+20 = 1437.
  static const double kLarguraMinimaLadoALado = 1440;

  // Abaixo de kLarguraMinimaLadoALado o layout lado a lado da tela de
  // Participantes estoura horizontalmente — usado para decidir quando cair
  // no layout empilhado em abas (mesmo usado no mobile) em vez do lado a lado.
  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < kLarguraMinimaLadoALado;
}
