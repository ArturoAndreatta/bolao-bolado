import 'package:flutter/material.dart';

import '../../core/app_cores.dart';

/// Divisor "ou" entre o login por e-mail/senha e o botão de login social
/// (hoje só o do Google). Compartilhado entre login e cadastro para os dois
/// não divergirem no espaçamento/cor no dia em que um dos dois mudar.
class OuDivider extends StatelessWidget {
  const OuDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Row(
        children: [
          Expanded(child: Divider(color: cores.borda)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('ou', style: TextStyle(color: cores.textoSuave)),
          ),
          Expanded(child: Divider(color: cores.borda)),
        ],
      ),
    );
  }
}
