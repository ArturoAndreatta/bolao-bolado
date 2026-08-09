import 'package:bolao_bolado/core/app_cores.dart';
import 'package:flutter/material.dart';

class GradientDecoration {
  /// Gradiente de fundo da aplicação.
  ///
  /// Recebe [context] (em vez de ser const como antes) porque os dois tons
  /// mudam com o tema: no escuro eles descem para versões profundas do mesmo
  /// dourado→verde-água, senão a moldura da página ficaria clara e ofuscante
  /// em volta de cards escuros.
  static BoxDecoration backgroundGradient(BuildContext context) {
    final cores = AppCores.de(context);
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: cores.gradienteFundo,
        stops: cores.paradasGradiente,
      ),
    );
  }
}
