import 'package:bolao_bolado/core/responsive.dart';
import 'package:bolao_bolado/pages/cadastrar_sala/cadastrar_sala_desktop.dart';
import 'package:bolao_bolado/pages/cadastrar_sala/cadastrar_sala_mobile.dart';
import 'package:flutter/material.dart';

class CadastrarSala extends StatelessWidget {
  const CadastrarSala({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = Responsive.isMobile(context);

        if (isMobile) {
          return const CadastrarSalaMobile();
        }

        return const CadastrarSalaDesktop();
      },
    );
  }
}
