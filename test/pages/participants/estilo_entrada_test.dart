import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/core/debug_flags.dart';
import 'package:bolao_bolado/pages/participants/participants_estilo_entrada.dart';
import 'package:bolao_bolado/pages/participants/participants_tabela.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

  tearDown(() => estiloEntradaGlobal.value = EstiloEntrada.batida);

  group('EstiloEntrada', () {
    test('todo estilo tem rótulo e descrição', () {
      for (final e in EstiloEntrada.values) {
        expect(e.rotulo, isNotEmpty, reason: 'rótulo de $e');
        expect(e.descricao, isNotEmpty, reason: 'descrição de $e');
      }
    });

    test('batida é o padrão', () {
      expect(estiloEntradaGlobal.value, EstiloEntrada.batida);
      // E é o primeiro da lista: a ordem do enum é a ordem do seletor no
      // Painel ADM, e o padrão aparecer no topo evita procurar.
      expect(EstiloEntrada.values.first, EstiloEntrada.batida);
    });

    test('toda duração é positiva e razoável', () {
      for (final e in EstiloEntrada.values) {
        expect(e.duracaoMs, greaterThan(300), reason: '$e rápido demais');
        expect(e.duracaoMs, lessThan(3000), reason: '$e lento demais');
      }
    });

    test('todo estilo tem alguma coisa acontecendo', () {
      // Um estilo sem movimento, sem dissolução E com o efeito padrão seria
      // indistinguível de não animar.
      for (final e in EstiloEntrada.values) {
        final faz =
            e.deslocamentoX != 0 ||
            e.dissolver ||
            e.efeito != EfeitoEntrada.brilhoVarrendo;
        expect(faz, isTrue, reason: '$e não faz nada de diferente');
      }
    });
  });

  group('aplicarEstiloEntrada', () {
    testWidgets('no fim da animação não sobra transformação nenhuma', (
      tester,
    ) async {
      // entrada = 1 é o estado assentado: qualquer deslocamento ou escala
      // residual deixaria a linha fora do lugar para sempre. A referência é o
      // conteúdo SEM estilo nenhum, no mesmo layout.
      Future<(Offset, Size)> medir(Widget conteudo) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Align(alignment: Alignment.topLeft, child: conteudo),
            ),
          ),
        );
        await tester.pump();
        return (
          tester.getTopLeft(find.text('x').last),
          tester.getSize(find.text('x').last),
        );
      }

      const conteudo = SizedBox(
        width: 100,
        height: 34,
        child: Center(child: Text('x')),
      );

      final (posNua, tamNua) = await medir(conteudo);

      for (final estilo in EstiloEntrada.values) {
        final (pos, tam) = await medir(
          aplicarEstiloEntrada(
            estilo: estilo,
            entrada: 1,
            opacidade: 1,
            child: conteudo,
          ),
        );

        expect(
          pos.dx,
          closeTo(posNua.dx, 0.5),
          reason: '$estilo deixou a linha deslocada em X no fim',
        );
        expect(
          pos.dy,
          closeTo(posNua.dy, 0.5),
          reason: '$estilo deixou a linha deslocada em Y no fim',
        );
        expect(
          tam.height,
          closeTo(tamNua.height, 0.5),
          reason: '$estilo deixou a linha com altura errada no fim',
        );
        expect(
          tam.width,
          closeTo(tamNua.width, 0.5),
          reason: '$estilo deixou a linha com largura errada no fim',
        );
      }
    });

    testWidgets('no começo, todo estilo está diferente do estado final', (
      tester,
    ) async {
      // Compara o começo da animação com o fim, e não com a origem do
      // sistema de coordenadas: estilos que escalam a partir de uma borda
      // (desdobrar) deslocam o conteúdo sem nunca passar por (0,0).
      Future<(Offset, Size)> medir(EstiloEntrada estilo, double entrada) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: aplicarEstiloEntrada(
                  estilo: estilo,
                  entrada: entrada,
                  opacidade: 1,
                  child: const SizedBox(
                    width: 100,
                    height: 34,
                    child: Center(child: Text('x')),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        return (
          tester.getTopLeft(find.text('x').last),
          tester.getSize(find.text('x').last),
        );
      }

      for (final estilo in EstiloEntrada.values) {
        final (posInicio, tamInicio) = await medir(estilo, 0.1);
        final (posFim, tamFim) = await medir(estilo, 1);

        final mexeu =
            (posInicio.dx - posFim.dx).abs() > 0.5 ||
            (posInicio.dy - posFim.dy).abs() > 0.5 ||
            (tamInicio.width - tamFim.width).abs() > 0.5 ||
            (tamInicio.height - tamFim.height).abs() > 0.5;

        // Geometria não é a única forma de estar diferente: a dissolução
        // muda o que está VISÍVEL sem deslocar nada, e a medição de posição
        // e tamanho não a enxerga.
        expect(
          mexeu || estilo.dissolver,
          isTrue,
          reason: '$estilo está idêntico ao estado final logo no começo',
        );
      }
    });
  });

  group('estilo aplicado na tabela', () {
    testWidgets('batida entra pela esquerda', (tester) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      estiloEntradaGlobal.value = EstiloEntrada.batida;

      await tester.pumpWidget(montar([aposta('a', 30)]));
      await tester.pumpAndSettle();
      tester.takeException();

      await tester.pumpWidget(montar([aposta('nova', 99), aposta('a', 30)]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      tester.takeException();

      final xDurante = tester.getTopLeft(find.text('nova')).dx;
      await tester.pumpAndSettle();
      tester.takeException();
      final xFinal = tester.getTopLeft(find.text('nova')).dx;

      expect(
        xDurante,
        lessThan(xFinal - 1),
        reason: 'não entrou pela esquerda',
      );
    });

    testWidgets('a forja termina sem máscara sobrando na linha', (
      tester,
    ) async {
      // A máscara de dissolução tinha um limite em 1.0 que a fazia PARAR na
      // borda direita em vez de sair por ela: os últimos 25% da linha ficavam
      // presos num gradiente até transparente, e a coluna "Última Alteração"
      // terminava a animação opaca.
      //
      // Ao fim da animação nenhum ShaderMask pode restar na árvore.
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      estiloEntradaGlobal.value = EstiloEntrada.forja;

      await tester.pumpWidget(montar([aposta('a', 30)]));
      await tester.pumpAndSettle();
      tester.takeException();

      await tester.pumpWidget(montar([aposta('nova', 99), aposta('a', 30)]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      tester.takeException();

      // No meio da animação a máscara existe: é ela que revela o conteúdo.
      expect(
        find.byType(ShaderMask),
        findsWidgets,
        reason: 'a dissolução nem chegou a acontecer',
      );

      await tester.pumpAndSettle();
      tester.takeException();

      expect(
        find.byType(ShaderMask),
        findsNothing,
        reason: 'sobrou máscara depois da animação — a linha fica opaca',
      );
    });

    testWidgets('trocar o estilo no meio não muda a animação em curso', (
      tester,
    ) async {
      // O estilo é capturado no initState. Sem isso, mexer no seletor do
      // Painel ADM com uma aposta a meio caminho trocaria duração e curva no
      // ar, e a linha daria um salto.
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      estiloEntradaGlobal.value = EstiloEntrada.batida;

      await tester.pumpWidget(montar([aposta('a', 30)]));
      await tester.pumpAndSettle();
      tester.takeException();

      await tester.pumpWidget(montar([aposta('nova', 99), aposta('a', 30)]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      tester.takeException();

      final xAntes = tester.getTopLeft(find.text('nova')).dx;

      estiloEntradaGlobal.value = EstiloEntrada.glitch;
      await tester.pumpWidget(montar([aposta('nova', 99), aposta('a', 30)]));
      await tester.pump(const Duration(milliseconds: 30));
      tester.takeException();

      final xDepois = tester.getTopLeft(find.text('nova')).dx;

      expect(xDepois, greaterThan(xAntes), reason: 'parou de deslizar');
      expect(
        xDepois,
        lessThan(0),
        reason: 'a linha pulou para o destino ao trocar o estilo',
      );

      await tester.pumpAndSettle();
      tester.takeException();
    });
  });
}

void _ignorar(int _) {}
