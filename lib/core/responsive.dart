import 'package:flutter/material.dart';

class Responsive {
  // Abaixo de 600px: mobile. Entre 600 e 1024px: faixa intermediária (tablet),
  // não coberta por nenhum dos dois métodos — tratada como "não mobile" pelo restante do app.
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1024;
}
