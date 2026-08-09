import 'package:flutter/material.dart';

class Responsive {
  // Abaixo de 600px: mobile. Entre 600 e 1024px: faixa intermediária (tablet),
  // não coberta por nenhum dos dois métodos — tratada como "não mobile" pelo restante do app.
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1024;

  // Largura mínima em que o layout lado a lado da tela de Participantes
  // (Minha Aposta, CustomCard maxWidth 460+20 de padding, ao lado do painel
  // de Participantes, HeaderCard/CustomCard maxWidth 937+20 de padding)
  // cabe sem estourar horizontalmente: 460+20 + 937+20 = 1437.
  static const double kLarguraMinimaLadoALado = 1440;

  // Abaixo de kLarguraMinimaLadoALado o layout lado a lado da tela de
  // Participantes estoura horizontalmente — usado para decidir quando cair
  // no layout empilhado em abas (mesmo usado no mobile) em vez do lado a lado.
  static bool isCompact(BuildContext context) =>
      MediaQuery.of(context).size.width < kLarguraMinimaLadoALado;
}
