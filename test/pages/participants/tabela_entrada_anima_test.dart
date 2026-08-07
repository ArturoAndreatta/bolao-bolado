import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/pages/participants/participants_tabela.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A aposta nova entra deslizando PELA ESQUERDA.
///
/// A direção importa: o corpo do desktop usa `itemExtent`, então a altura do
/// item é fixa e o `heightFactor` da chegada não produz nada ali. Uma versão
/// intermediária compensou fazendo o conteúdo subir de baixo, mas essa
/// vertical competia com o deslize lateral e era ela que o olho lia — a
/// entrada pela margem passava despercebida.
///
/// Por isso os testes olham o eixo X do conteúdo: é lá que a chegada acontece.
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

  testWidgets('a aposta nova entra pela esquerda', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(montar([aposta('a', 30), aposta('b', 20)]));
    await tester.pumpAndSettle();
    tester.takeException(); // overflow do cabeçalho no ambiente de teste

    // Chega uma aposta nova no topo.
    await tester.pumpWidget(
      montar([aposta('nova', 99), aposta('a', 30), aposta('b', 20)]),
    );
    await tester.pump();
    // Um quadro de animação: no `pump` que só monta a árvore o controller
    // ainda não avançou.
    await tester.pump(const Duration(milliseconds: 30));
    tester.takeException();

    final xInicial = tester.getTopLeft(find.text('nova')).dx;
    final yInicial = tester.getTopLeft(find.text('nova')).dy;

    await tester.pumpAndSettle();
    tester.takeException();
    final xFinal = tester.getTopLeft(find.text('nova')).dx;
    final yFinal = tester.getTopLeft(find.text('nova')).dy;

    // Começa à ESQUERDA do lugar final e caminha para a direita.
    expect(
      xInicial,
      lessThan(xFinal - 1),
      reason:
          'o conteúdo nasceu em x=$xInicial e terminou em x=$xFinal — não '
          'está entrando pela esquerda',
    );

    // E não se mexe na vertical: qualquer movimento em Y competiria com a
    // entrada lateral e roubaria a atenção dela.
    expect(
      yInicial,
      closeTo(yFinal, 0.5),
      reason: 'houve movimento vertical (de $yInicial para $yFinal)',
    );
  });

  testWidgets('a segunda emissão do Firestore não corta a animação', (
    tester,
  ) async {
    // Na aba que ESTÁ simulando, cada aposta chega duas vezes: o cache local
    // pinta na hora (escrita pendente) e a confirmação do servidor emite de
    // novo. No segundo build `detectarLinhaNova` já conhece o valor e devolve
    // `animar: false` — o widget trocava para o conteúdo estático e o deslize
    // morria aos ~30ms de 1150ms.
    //
    // Na aba que só observa isso não aparecia: lá chega uma emissão só.
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final base = [aposta('a', 30), aposta('b', 20)];

    await tester.pumpWidget(montar(base));
    await tester.pumpAndSettle();
    tester.takeException();

    // Emissão 1: cache local.
    await tester.pumpWidget(montar([aposta('nova', 99), ...base]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    tester.takeException();

    final xDurante = tester.getTopLeft(find.text('nova')).dx;

    // Emissão 2: servidor confirma. Mesma lista, objetos novos — é o rebuild
    // em que `animar` vira false.
    await tester.pumpWidget(montar([aposta('nova', 99), ...base]));
    await tester.pump(const Duration(milliseconds: 30));
    tester.takeException();

    final xDepois = tester.getTopLeft(find.text('nova')).dx;
    final xFinal = tester.getTopLeft(find.text('a')).dx;

    // A linha tem de continuar a caminho, não saltar para o destino.
    expect(
      xDepois,
      lessThan(xFinal - 1),
      reason:
          'a linha saltou de $xDurante para $xDepois (destino $xFinal) — a '
          'segunda emissão cortou a animação',
    );

    await tester.pumpAndSettle();
    tester.takeException();
  });

  testWidgets('o deslize lateral acontece aos poucos, não de uma vez', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(montar([aposta('a', 30)]));
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.pumpWidget(montar([aposta('nova', 99), aposta('a', 30)]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    tester.takeException();

    var anterior = tester.getTopLeft(find.text('nova')).dx;
    var quadrosComMovimento = 0;

    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 40));
      tester.takeException();
      final atual = tester.getTopLeft(find.text('nova')).dx;
      if ((atual - anterior).abs() > 0.01) quadrosComMovimento++;
      anterior = atual;
    }

    // Vários quadros com deslocamento: um salto único daria 1, e uma curva
    // que dispara no começo (easeOutQuint) daria pouquíssimos.
    expect(
      quadrosComMovimento,
      greaterThan(5),
      reason:
          'só $quadrosComMovimento quadros tiveram movimento — a entrada '
          'está concentrada demais no começo para o olho acompanhar',
    );

    await tester.pumpAndSettle();
    tester.takeException();
  });
}

void _ignorar(int _) {}
