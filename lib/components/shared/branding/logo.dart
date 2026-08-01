import 'package:flutter/material.dart';

class Logo extends StatelessWidget {
  final bool? isSmall;
  final String? logo;

  /// Padrão é `logo4.png`, e não `logo.png`, por causa do dark mode:
  /// `logo.png` não tem transparência real — o fundo dele é branco chapado
  /// (#FEFEFE opaco, 0% de pixels transparentes), o que passava despercebido
  /// sobre o card claro e virava um retângulo branco berrante sobre o card
  /// escuro. `logo4.png` é a mesma arte com alpha de verdade, então funciona
  /// nos dois temas. Ao trocar a arte, confira o canal alfa antes.
  const Logo({super.key, this.isSmall, this.logo = 'images/logo4.png'});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 15),
      child: Image.asset(
        logo!,
        height: (isSmall == true) ? 150 : 250,
        width: (isSmall == true) ? 200 : 335,
      ),
    );
  }
}
