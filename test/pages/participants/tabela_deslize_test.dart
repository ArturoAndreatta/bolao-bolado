import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/pages/participants/participants_tabela.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Deslize de reordenação no corpo RECICLADO (desktop), onde a posição é
/// calculada pelo índice em vez de medida.
void main() {
  Map<String, dynamic> aposta(String uid, double valor) => {
    'uid': uid,
    'nome': uid,
    'valor': valor,
    'cotas': 1,
    'premio': 10.0,
  };

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
            alturaFixa: true,
          ),
        ),
      ),
    ),
  );

  setUp(() {
    // O cabeçalho estoura horizontalmente no ambiente de teste; não é o
    // objeto destes testes.
  });

  testWidgets('linha que muda de posição desliza em vez de teleportar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      montar([aposta('a', 30), aposta('b', 20), aposta('c', 10)]),
    );
    await tester.pumpAndSettle();
    tester.takeException();

    final yInicialC = tester.getTopLeft(find.text('c')).dy;

    // 'c' passa a valer mais e sobe para o topo.
    await tester.pumpWidget(
      montar([aposta('c', 90), aposta('a', 30), aposta('b', 20)]),
    );
    await tester.pump();
    tester.takeException();

    // No primeiro quadro depois da troca, 'c' ainda tem de estar perto de
    // onde estava — é isso que prova que ela desliza em vez de aparecer.
    final yDurante = tester.getTopLeft(find.text('c')).dy;
    expect(
      yDurante,
      greaterThan(yInicialC - kAlturaLinhaTabela),
      reason: 'c pulou direto para o destino em vez de deslizar',
    );

    await tester.pumpAndSettle();
    tester.takeException();

    // Terminada a animação, pousa na primeira linha.
    expect(
      tester.getTopLeft(find.text('c')).dy,
      closeTo(yInicialC - 2 * kAlturaLinhaTabela, 1),
    );
  });

  testWidgets('reordenação em RAJADA não faz a linha oscilar', (tester) async {
    // O defeito original: apostas chegando antes de a animação anterior
    // terminar. Com posição medida, cada quadro relia uma posição transitória
    // e a linha ia e voltava. Com posição calculada por índice, não há
    // grandeza transitória para reler.
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      montar([aposta('a', 30), aposta('b', 20), aposta('c', 10)]),
    );
    await tester.pumpAndSettle();
    tester.takeException();

    // Três apostas entrando em sequência rápida, cada uma antes de a anterior
    // assentar. 'a' vai sendo empurrada para baixo a cada uma.
    await tester.pumpWidget(
      montar([
        aposta('n1', 99),
        aposta('a', 30),
        aposta('b', 20),
        aposta('c', 10),
      ]),
    );
    await tester.pump(const Duration(milliseconds: 60));
    tester.takeException();

    await tester.pumpWidget(
      montar([
        aposta('n2', 98),
        aposta('n1', 97),
        aposta('a', 30),
        aposta('b', 20),
        aposta('c', 10),
      ]),
    );
    await tester.pump(const Duration(milliseconds: 60));
    tester.takeException();

    // 'a' só pode descer ao longo de tudo isso: subir seria a oscilação.
    var anterior = tester.getTopLeft(find.text('a')).dy;
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      final atual = tester.getTopLeft(find.text('a')).dy;
      expect(
        atual,
        greaterThanOrEqualTo(anterior - 0.01),
        reason: 'quadro $i: a voltou de $anterior para $atual',
      );
      anterior = atual;
    }

    await tester.pumpAndSettle();
    tester.takeException();
    expect(tester.takeException(), isNull);
  });
}

void _ignorar(int _) {}
