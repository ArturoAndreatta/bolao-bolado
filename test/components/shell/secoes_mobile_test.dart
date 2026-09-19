import 'package:bolao_bolado/components/shell/secoes_mobile.dart';
import 'package:bolao_bolado/core/app_cores.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Os cinco itens do Painel ADM: o caso mais apertado da barra.
const _itens = [
  ItemSecaoMobile(indice: 0, rotulo: 'Resumo', icone: Icons.dashboard),
  ItemSecaoMobile(
    indice: 1,
    rotulo: 'Apostas',
    icone: Icons.groups,
    contador: 4,
  ),
  ItemSecaoMobile(indice: 2, rotulo: 'Ranking', icone: Icons.leaderboard),
  ItemSecaoMobile(indice: 3, rotulo: 'Sala', icone: Icons.meeting_room),
  ItemSecaoMobile(indice: 4, rotulo: 'Ajustes', icone: Icons.settings),
];

class _Barra extends StatefulWidget {
  const _Barra();

  @override
  State<_Barra> createState() => _BarraState();
}

class _BarraState extends State<_Barra> {
  int ativa = 0;

  @override
  Widget build(BuildContext context) {
    return BarraSecoesMobile(
      itens: _itens,
      ativa: ativa,
      onSelecionar: (i) => setState(() => ativa = i),
    );
  }
}

void main() {
  testWidgets('trocar de opção anima sem estourar a barra de celular', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [AppCores.claro]),
        home: const Scaffold(bottomNavigationBar: _Barra()),
      ),
    );

    for (final rotulo in ['Sala', 'Resumo', 'Ajustes', 'Apostas']) {
      await tester.tap(find.bySemanticsLabel(RegExp('^$rotulo')));
      // Quadros no meio da animação: é aí que um overflow apareceria.
      await tester.pump(const Duration(milliseconds: 80));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.pumpAndSettle();
      expect(find.text(rotulo), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });
}
