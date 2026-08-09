import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/pages/participants/participants_tabela.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Garante que o corpo do desktop RECICLA as linhas.
///
/// Antes o corpo era `SingleChildScrollView` + `Column`: numa sala de 500
/// apostas isso mantinha as 500 linhas (≈2500 células) montadas e as
/// reconstruía a cada emissão do Firestore. Era esse custo — não a animação —
/// que deixava a entrada de uma aposta nova travada em sala grande.
void main() {
  List<Map<String, dynamic>> gerar(int quantas) => [
    for (var i = 0; i < quantas; i++)
      {
        'uid': 'u$i',
        'nome': 'Participante $i',
        'valor': (quantas - i).toDouble(),
        'cotas': 1,
        'premio': 10.0,
      },
  ];

  Widget montar(List<Map<String, dynamic>> rows) => MaterialApp(
    theme: ThemeData(extensions: [AppCores.claro]),
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: larguraTotal + 4,
          height: 400,
          child: TabelaApostas(
            rows: rows,
            colunaOrdenada: 1,
            ascendente: false,
            onCabecalhoTap: _ignorar,
            currentUid: null,
            // alturaFixa é o que liga o corpo rolável reciclado (desktop).
            alturaFixa: true,
          ),
        ),
      ),
    ),
  );

  testWidgets('com 500 apostas monta só as linhas visíveis', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(montar(gerar(500)));
    await tester.pumpAndSettle();
    tester.takeException(); // overflow do cabeçalho no ambiente de teste

    final montadas = find.byType(CelulaLinha).evaluate().length;

    // 400px de altura / 34px por linha ≈ 12 linhas, × 5 células = ~60.
    // O ListView monta algumas a mais como margem (cacheExtent), mas tem de
    // ficar MUITO longe das 2500 que as 500 apostas dariam.
    expect(
      montadas,
      lessThan(300),
      reason: 'montou $montadas células — a lista não está reciclando',
    );
    expect(montadas, greaterThan(0));
  });

  testWidgets('rolar não faz a contagem de células crescer', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(montar(gerar(500)));
    await tester.pumpAndSettle();
    tester.takeException();

    final antes = find.byType(CelulaLinha).evaluate().length;

    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    tester.takeException();

    final depois = find.byType(CelulaLinha).evaluate().length;

    // Reciclagem de verdade: as linhas que saíram são descartadas, então a
    // quantidade montada fica na mesma ordem de grandeza.
    expect(
      depois,
      lessThan(antes * 2),
      reason: 'de $antes para $depois células ao rolar — nada foi descartado',
    );
  });
}

void _ignorar(int _) {}
