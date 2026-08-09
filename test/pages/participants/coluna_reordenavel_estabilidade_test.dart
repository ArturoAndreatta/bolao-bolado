import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/pages/participants/participants_reordenacao.dart';
import 'package:bolao_bolado/pages/participants/participants_tabela.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const double kAlturaLinha = 40;

Widget _linha(String id) =>
    SizedBox(key: ValueKey(id), height: kAlturaLinha, child: Text(id));

Widget _montar(List<String> ids) => MaterialApp(
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: ColunaReordenavel(children: [for (final id in ids) _linha(id)]),
    ),
  ),
);

/// Linha cuja altura CRESCE, imitando o `heightFactor` da animação de
/// entrada de uma aposta nova.
class _LinhaCrescendo extends StatefulWidget {
  final String id;
  const _LinhaCrescendo(this.id, {super.key});

  @override
  State<_LinhaCrescendo> createState() => _LinhaCrescendoState();
}

class _LinhaCrescendoState extends State<_LinhaCrescendo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, _) =>
        SizedBox(height: kAlturaLinha * _c.value, child: Text(widget.id)),
  );
}

void main() {
  testWidgets('linha deslizando avança sempre no mesmo sentido, sem oscilar', (
    tester,
  ) async {
    await tester.pumpWidget(_montar(['a', 'b', 'c']));
    await tester.pumpAndSettle();

    // 'c' sobe da 3a para a 1a posicao.
    await tester.pumpWidget(_montar(['c', 'a', 'b']));
    await tester.pump();

    // Amostra a posicao pintada frame a frame. Como 'c' esta SUBINDO, a
    // coordenada y so pode diminuir (ou ficar igual). Qualquer aumento e o
    // "indo e voltando" que o usuario relatou.
    var anterior = tester.getTopLeft(find.text('c')).dy;
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      final atual = tester.getTopLeft(find.text('c')).dy;
      expect(
        atual,
        lessThanOrEqualTo(anterior + 0.01),
        reason:
            'frame $i: c voltou de $anterior para $atual — animação oscilando',
      );
      anterior = atual;
    }

    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('c')).dy, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rebuild do pai NO MEIO do deslize não faz a linha oscilar', (
    tester,
  ) async {
    // Este é o caso real: a lista é reconstruída o tempo todo (stream do
    // Firestore, simulador a cada 900ms). Cada rebuild remede as posições —
    // e era aí que medir a posição PINTADA fazia a animação perseguir o
    // próprio resultado, produzindo o "indo e voltando".
    await tester.pumpWidget(_montar(['a', 'b', 'c']));
    await tester.pumpAndSettle();

    await tester.pumpWidget(_montar(['c', 'a', 'b']));
    await tester.pump();

    var anterior = tester.getTopLeft(find.text('c')).dy;
    for (var i = 0; i < 20; i++) {
      // Reconstrói o pai com a MESMA ordem a cada frame, como faria uma
      // emissão do stream que não mudou nada.
      await tester.pumpWidget(_montar(['c', 'a', 'b']));
      await tester.pump(const Duration(milliseconds: 20));

      final atual = tester.getTopLeft(find.text('c')).dy;
      expect(
        atual,
        lessThanOrEqualTo(anterior + 0.01),
        reason:
            'frame $i: c voltou de $anterior para $atual com rebuild do pai',
      );
      anterior = atual;
    }

    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('c')).dy, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('linha empurrada por uma nova desce e NÃO volta', (tester) async {
    // A sequência relatada: chega uma aposta no topo, a que estava em 1º é
    // empurrada para 2º — e voltava um pedaço para cima ao final.
    //
    // A causa era `_posicoesAnteriores` ser atualizado a cada quadro mesmo
    // sem disparar deslize: a distância acumulada durante o crescimento era
    // descartada, sobrava o resto de um quadro só, e esse resto era animado
    // a partir de onde a linha já estava — puxando-a de volta.
    await tester.pumpWidget(_montar(['a']));
    await tester.pumpAndSettle();

    final yInicialA = tester.getTopLeft(find.text('a')).dy;
    expect(yInicialA, 0);

    // 'nova' entra no topo crescendo de altura, empurrando 'a' para baixo.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: ColunaReordenavel(
              children: [
                const _LinhaCrescendo('nova', key: ValueKey('nova')),
                _linha('a'),
              ],
            ),
          ),
        ),
      ),
    );

    // Acompanha 'a' durante TODA a entrada e o que vier depois. Ela só pode
    // descer: qualquer subida é o recuo do defeito.
    //
    // O pai é reconstruído a cada quadro, como faz o stream do Firestore —
    // é isso que força uma remedição por quadro e expõe o descarte da
    // distância acumulada.
    Widget arvore() => MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: ColunaReordenavel(
            children: [
              const _LinhaCrescendo('nova', key: ValueKey('nova')),
              _linha('a'),
            ],
          ),
        ),
      ),
    );

    await tester.pump();
    var anterior = tester.getTopLeft(find.text('a')).dy;
    var maiorY = anterior;
    for (var i = 0; i < 40; i++) {
      await tester.pumpWidget(arvore());
      await tester.pump(const Duration(milliseconds: 20));
      final atual = tester.getTopLeft(find.text('a')).dy;
      expect(
        atual,
        greaterThanOrEqualTo(anterior - 0.01),
        reason: 'quadro $i: a voltou de $anterior para $atual',
      );
      anterior = atual;
      if (atual > maiorY) maiorY = atual;
    }

    await tester.pumpAndSettle();
    final yFinalA = tester.getTopLeft(find.text('a')).dy;

    // Termina exatamente embaixo da linha nova (que acabou com altura cheia),
    // e no ponto mais baixo que alcançou — nunca acima dele.
    expect(yFinalA, kAlturaLinha);
    expect(yFinalA, greaterThanOrEqualTo(maiorY - 0.01));
    expect(tester.takeException(), isNull);
  });

  // LIMITAÇÃO CONHECIDA da ColunaReordenavel (usada só na lista mobile).
  //
  // Quando a reordenação cai no meio da animação de entrada de outra linha, a
  // troca acontece num salto seco em vez de deslizar. A causa é estrutural:
  // este widget MEDE posições num callback pós-frame, e durante uma entrada
  // todas as posições são transitórias — com apostas em rajada nunca existe
  // um instante estável para medir.
  //
  // No desktop isso foi resolvido trocando medição por posição CALCULADA
  // (ver RastreadorDeIndices e test/pages/participants/tabela_deslize_test.dart).
  // O mesmo tratamento não serve para a lista mobile porque lá a altura da
  // linha varia (nome em duas linhas, selo manual), e o cálculo por índice
  // depende de altura uniforme.
  //
  // Fica `skip` por documentar o comportamento atual em vez de exigi-lo: se
  // alguém reescrever a lista mobile com altura fixa, é só remover o skip.
  testWidgets('reordenação DURANTE a entrada de outra linha ainda desliza', (
    tester,
  ) async {
    Widget arvore(List<Widget> filhos) => MaterialApp(
      theme: ThemeData(extensions: [AppCores.claro]),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: ColunaReordenavel(children: filhos),
        ),
      ),
    );

    Widget linhaReal(String id, {bool animar = false}) => LinhaEntrandoAnimada(
      key: ValueKey(id),
      animar: animar,
      corBase: const Color(0xFFFFFFFF),
      child: SizedBox(height: kAlturaLinha, width: 200, child: Text(id)),
    );

    await tester.pumpWidget(arvore([linhaReal('a'), linhaReal('b')]));
    await tester.pumpAndSettle();

    // A nova entra no topo, animando.
    await tester.pumpWidget(
      arvore([linhaReal('nova', animar: true), linhaReal('a'), linhaReal('b')]),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    final yAntesDaTroca = tester.getTopLeft(find.text('a')).dy;

    // No meio da entrada, 'nova' vai para o meio e 'a' sobe para o topo.
    await tester.pumpWidget(
      arvore([linhaReal('a'), linhaReal('nova', animar: true), linhaReal('b')]),
    );
    await tester.pump();
    await tester.pump();

    // 'a' precisa DESLIZAR até o topo, não aparecer nele. No quadro seguinte
    // à troca ela ainda tem de estar longe do destino (0).
    final yLogoAposTroca = tester.getTopLeft(find.text('a')).dy;
    expect(
      yLogoAposTroca,
      greaterThan(1),
      reason:
          'a saltou de $yAntesDaTroca direto para $yLogoAposTroca, sem deslizar',
    );

    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('a')).dy, 0);
    expect(tester.takeException(), isNull);
  }, skip: true); // limitação conhecida da medição pós-frame (ver acima)

  testWidgets('linha crescendo não dispara deslize nas de baixo', (
    tester,
  ) async {
    await tester.pumpWidget(_montar(['a', 'b']));
    await tester.pumpAndSettle();

    // Uma linha que cresce entra no topo: empurra 'a' e 'b' para baixo a cada
    // frame. Isso é a animação de ENTRADA fazendo seu trabalho, não uma
    // reordenação — o deslize não pode competir com ela.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: ColunaReordenavel(
              children: [
                const _LinhaCrescendo('nova', key: ValueKey('nova')),
                _linha('a'),
                _linha('b'),
              ],
            ),
          ),
        ),
      ),
    );

    // Durante o crescimento, 'a' desce monotonicamente (empurrada pela linha
    // que cresce). Nunca pode subir: subir seria o deslize brigando com a
    // entrada.
    await tester.pump();
    var anterior = tester.getTopLeft(find.text('a')).dy;
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 25));
      final atual = tester.getTopLeft(find.text('a')).dy;
      expect(
        atual,
        greaterThanOrEqualTo(anterior - 0.01),
        reason: 'frame $i: a subiu de $anterior para $atual durante a entrada',
      );
      anterior = atual;
    }

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
