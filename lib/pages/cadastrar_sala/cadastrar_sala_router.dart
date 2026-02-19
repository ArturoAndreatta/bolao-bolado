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

DateTime juntarDataHora(String data, String hora) {
  final separadorData = data.split('/');
  final dia = int.parse(separadorData[0]);
  final mes = int.parse(separadorData[1]);
  final ano = int.parse(separadorData[2]);

  final separadorHora = hora.split(':');
  final hh = int.parse(separadorHora[0]);
  final mm = int.parse(separadorHora[1]);

  return DateTime(ano, mes, dia, hh, mm);
}
