import 'package:bolao_bolado/pages/cadastrar_sala/cadastrar_sala_desktop.dart';
import 'package:bolao_bolado/pages/cadastrar_sala/cadastrar_sala_mobile.dart';
import 'package:flutter/material.dart';

class CadastrarSala extends StatelessWidget {
  const CadastrarSala({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        if (width < 600) {
          return const CadastrarSalaMobile();
        }

        if (width >= 1024) {
          return const CadastrarSalaDesktop();
        }

        return const CadastrarSalaDesktop();
      },
    );
  }
}
