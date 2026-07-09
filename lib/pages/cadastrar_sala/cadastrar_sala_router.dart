import 'package:bolao_bolado/core/responsive.dart';
import 'package:bolao_bolado/pages/cadastrar_sala/cadastrar_sala_desktop.dart';
import 'package:bolao_bolado/pages/cadastrar_sala/cadastrar_sala_mobile.dart';
import 'package:flutter/material.dart';

class CadastrarSala extends StatelessWidget {
  final String? salaId;

  const CadastrarSala({super.key, this.salaId});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive.isMobile define o breakpoint que decide entre a versão
        // mobile e a desktop desta página (ver core/responsive.dart).
        final isMobile = Responsive.isMobile(context);

        if (isMobile) {
          return CadastrarSalaMobile(salaId: salaId);
        }

        return CadastrarSalaDesktop(salaId: salaId);
      },
    );
  }
}

// Combina os campos separados de data (dd/mm/aaaa) e hora (hh:mm) dos
// formulários de cadastro/edição de sala em um único DateTime.
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
