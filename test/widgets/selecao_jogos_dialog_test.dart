import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/widgets/selecao_jogos_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Abre o modal e devolve um getter do resultado — o valor só chega quando o
/// diálogo fecha, então o teste precisa poder olhar depois.
Future<List<List<int>>? Function()> abrir(
  WidgetTester tester, {
  String? sorteio = 'mega',
  required int cotas,
  List<List<int>> jogosIniciais = const [],
}) async {
  List<List<int>>? resultado;
  var fechou = false;

  await tester.pumpWidget(
    MaterialApp(
      // Só a extension, sem passar por AppTema: o modal lê tudo de
      // AppCores.de(context), e montar o ThemeData completo só amarraria o
      // teste à forma como o tema é construído.
      theme: ThemeData(extensions: [AppCores.claro]),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              resultado = await mostrarSelecaoJogos(
                context,
                sorteio: sorteio,
                cotasDisponiveis: cotas,
                jogosIniciais: jogosIniciais,
              );
              fechou = true;
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return () => fechou ? resultado : null;
}

/// Marca os [quantidade] primeiros números da grade.
Future<void> marcar(WidgetTester tester, int quantidade) async {
  for (var numero = 1; numero <= quantidade; numero++) {
    await tester.tap(find.text('$numero'));
    await tester.pump();
  }
}

void main() {
  group('orçamento em cotas', () {
    testWidgets('sobra não vira aviso nem contador na tela', (tester) async {
      await abrir(
        tester,
        cotas: 20,
        jogosIniciais: [
          [1, 2, 3, 4, 5, 6, 7], // 7 cotas de 20
        ],
      );

      expect(find.text('Jogo 1 · 7 números'), findsOneWidget);
      expect(find.textContaining('cotas usadas'), findsNothing);
      expect(find.textContaining('Sobram'), findsNothing);
    });

    testWidgets('sobra não impede confirmar', (tester) async {
      final resultado = await abrir(
        tester,
        cotas: 20,
        jogosIniciais: [
          [1, 2, 3, 4, 5, 6],
        ],
      );

      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      expect(resultado(), [
        [1, 2, 3, 4, 5, 6],
      ]);
    });

    testWidgets('excesso avisa e trava o Confirmar', (tester) async {
      // Jogos montados antes de o usuário baixar o valor da aposta.
      final resultado = await abrir(
        tester,
        cotas: 2,
        jogosIniciais: [
          [1, 2, 3, 4, 5, 6, 7], // 7 cotas para 2 pagas
        ],
      );

      expect(find.textContaining('passam 5 cotas'), findsOneWidget);

      // warnIfMissed: o botão está sob IgnorePointer de propósito — é
      // exatamente o bloqueio que este teste verifica.
      await tester.tap(find.text('Confirmar'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(resultado(), isNull, reason: 'o diálogo não podia ter fechado');

      // Remover o jogo caro libera a confirmação.
      await tester.tap(find.byTooltip('Remover'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(resultado(), isEmpty);
    });

    testWidgets('sem cota livre não dá para adicionar jogo', (tester) async {
      await abrir(
        tester,
        cotas: 1,
        jogosIniciais: [
          [1, 2, 3, 4, 5, 6],
        ],
      );

      await tester.tap(find.text('Jogo'));
      await tester.pumpAndSettle();
      // Continua na lista: a grade de números não abriu.
      expect(find.text('Novo jogo'), findsNothing);
    });
  });

  group('tamanho do jogo', () {
    testWidgets('só oferece tamanhos que cabem no orçamento', (tester) async {
      // 7 cotas compram um jogo de 6 (1 cota) ou de 7 (7 cotas). O de 8
      // custaria 28.
      await abrir(tester, cotas: 7);
      await tester.tap(find.text('Jogo'));
      await tester.pumpAndSettle();

      expect(find.text('6 números'), findsOneWidget);
      expect(find.text('7 números'), findsOneWidget);
      expect(find.text('8 números'), findsNothing);
    });

    testWidgets('editar um jogo devolve as cotas dele ao orçamento', (
      tester,
    ) async {
      // Sem essa devolução, reabrir o jogo de 7 numa aposta de 7 cotas não
      // ofereceria o próprio tamanho 7 — ele contaria como já gasto.
      await abrir(
        tester,
        cotas: 7,
        jogosIniciais: [
          [1, 2, 3, 4, 5, 6, 7],
        ],
      );

      await tester.tap(find.byTooltip('Editar'));
      await tester.pumpAndSettle();

      expect(find.text('Editar jogo'), findsOneWidget);
      expect(find.text('7 números'), findsOneWidget);
    });

    testWidgets('diminuir o tamanho corta os números excedentes', (
      tester,
    ) async {
      await abrir(tester, cotas: 7);
      await tester.tap(find.text('Jogo'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('7 números'));
      await tester.pump();
      await marcar(tester, 7);
      expect(find.text('7 de 7 · 7 cotas'), findsOneWidget);

      await tester.tap(find.text('6 números'));
      await tester.pump();
      expect(find.text('6 de 6 · 1 cota'), findsOneWidget);
    });

    testWidgets('Lotofácil parte de 15 números', (tester) async {
      await abrir(tester, sorteio: 'lotofacil', cotas: 16);
      await tester.tap(find.text('Jogo'));
      await tester.pumpAndSettle();

      expect(find.text('15 números'), findsOneWidget);
      expect(find.text('16 números'), findsOneWidget);
      // A grade vai só até 25 na Lotofácil.
      expect(find.text('25'), findsOneWidget);
      expect(find.text('26'), findsNothing);
    });
  });

  group('sorteio de números', () {
    testWidgets('Surpresinha completa a cartela preservando o marcado', (
      tester,
    ) async {
      final resultado = await abrir(tester, cotas: 5);
      await tester.tap(find.text('Jogo'));
      await tester.pumpAndSettle();

      await marcar(tester, 2);
      await tester.tap(find.text('Surpresinha'));
      await tester.pumpAndSettle();

      expect(find.text('6 de 6 · 1 cota'), findsOneWidget);

      await tester.tap(find.text('Salvar jogo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      final jogos = resultado()!;
      expect(jogos, hasLength(1));
      expect(jogos.single, hasLength(6));
      expect(jogos.single, containsAll([1, 2]));
    });

    testWidgets('Sortear resto mostra a composição de cada estilo', (
      tester,
    ) async {
      // 14 cotas: dois jogos de 7 ou quatorze de 6.
      await abrir(tester, cotas: 14);
      await tester.tap(find.text('Sortear resto'));
      await tester.pumpAndSettle();

      expect(find.text('Jogos maiores primeiro'), findsOneWidget);
      expect(find.text('2×7'), findsOneWidget);
      expect(find.text('Só jogos simples'), findsOneWidget);
      expect(find.text('14×6'), findsOneWidget);
    });

    testWidgets('estilo maiores fecha o orçamento com menos jogos', (
      tester,
    ) async {
      final resultado = await abrir(tester, cotas: 14);

      await tester.tap(find.text('Sortear resto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jogos maiores primeiro'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      final jogos = resultado()!;
      expect(jogos, hasLength(2));
      expect(jogos.every((jogo) => jogo.length == 7), isTrue);
    });

    testWidgets('estilo simples enche de jogos mínimos', (tester) async {
      final resultado = await abrir(tester, cotas: 4);

      await tester.tap(find.text('Sortear resto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Só jogos simples'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(resultado(), hasLength(4));
    });
  });

  testWidgets('cartela incompleta não pode ser salva', (tester) async {
    await abrir(tester, cotas: 5);
    await tester.tap(find.text('Jogo'));
    await tester.pumpAndSettle();

    await marcar(tester, 3);
    // Botão desabilitado por IgnorePointer enquanto a cartela não fecha.
    await tester.tap(find.text('Salvar jogo'), warnIfMissed: false);
    await tester.pumpAndSettle();

    // Segue na grade, sem ter voltado para a lista.
    expect(find.text('Novo jogo'), findsOneWidget);
  });

  testWidgets('cancelar descarta tudo o que foi montado', (tester) async {
    final resultado = await abrir(tester, cotas: 5);

    await tester.tap(find.text('Sortear resto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Só jogos simples'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(resultado(), isNull);
  });

  group('transições', () {
    /// Quanto do widget aparece de fato: os FadeTransition aninhados
    /// multiplicam, então o produto é a opacidade que chega na tela.
    double visibilidade(WidgetTester tester, String texto) {
      if (find.textContaining(texto).evaluate().isEmpty) return 0;
      return tester
          .widgetList<FadeTransition>(
            find.ancestor(
              of: find.textContaining(texto),
              matching: find.byType(FadeTransition),
            ),
          )
          .fold<double>(1, (acumulado, f) => acumulado * f.opacity.value);
    }

    testWidgets('lista e grade nunca aparecem juntas na troca de tela', (
      tester,
    ) async {
      // Regressão: o fade era CRUZADO, então por ~150ms a lista continuava
      // pintada atrás da grade. Como a linha de jogo tem fundo próprio, ela
      // lia como uma caixa cinza atravessada nos números, que sumia sozinha.
      await abrir(
        tester,
        cotas: 20,
        jogosIniciais: const [
          [1, 2, 3, 4, 5, 6],
        ],
      );

      await tester.tap(find.text('Jogo'));
      for (var t = 0; t < 8; t++) {
        await tester.pump(const Duration(milliseconds: 30));
        final lista = visibilidade(tester, 'Jogo 1');
        final grade = visibilidade(tester, 'Novo jogo');
        expect(
          lista > 0.05 && grade > 0.05,
          isFalse,
          reason:
              'as duas telas visíveis ao mesmo tempo '
              '(lista=$lista, grade=$grade)',
        );
      }
      await tester.pumpAndSettle();
    });

    testWidgets('a caixa cresce e encolhe no mesmo ritmo', (tester) async {
      // Regressão: com as duas telas dimensionando o Stack, ele reportava
      // sempre a MAIOR altura. Abrir a grade animava o tamanho junto com o
      // deslize, mas voltar segurava a caixa alta pelos 220ms da troca e só
      // depois encolhia — o fechamento não era o inverso da abertura.
      double altura() => tester.getSize(find.byType(AnimatedSize)).height;

      await abrir(
        tester,
        cotas: 20,
        jogosIniciais: const [
          [1, 2, 3, 4, 5, 6],
        ],
      );
      final naLista = altura();

      await tester.tap(find.text('Jogo'));
      // Um frame para o AnimatedSize medir o tamanho novo e disparar; só o
      // seguinte é que anda no tempo.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 110));
      final crescendo = altura();
      await tester.pumpAndSettle();
      final naGrade = altura();
      expect(naGrade, greaterThan(naLista), reason: 'a grade é mais alta');
      expect(crescendo, greaterThan(naLista));
      expect(crescendo, lessThan(naGrade));

      await tester.tap(find.text('Voltar'));
      // Um frame para o AnimatedSize medir o tamanho novo e disparar; só o
      // seguinte é que anda no tempo.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 110));
      final encolhendo = altura();
      expect(
        encolhendo,
        lessThan(naGrade),
        reason: 'a caixa tem de encolher DURANTE a troca, não depois dela',
      );
      expect(encolhendo, greaterThan(naLista));
      await tester.pumpAndSettle();
      expect(altura(), naLista);
    });

    /// Só a animação da PRÓPRIA linha (o FadeTransition mais interno), sem o
    /// fade da troca de tela que envolve a lista inteira.
    double opacidadeDaLinha(WidgetTester tester, String texto) => tester
        .widgetList<FadeTransition>(
          find.ancestor(
            of: find.textContaining(texto),
            matching: find.byType(FadeTransition),
          ),
        )
        .first
        .opacity
        .value;

    testWidgets('voltar da grade não faz as linhas antigas reanimarem', (
      tester,
    ) async {
      // Regressão: o subárvore da lista é reconstruído a cada volta, e todas
      // as linhas repipocavam em cascata — salvar UM jogo parecia ter
      // recriado a lista inteira.
      await abrir(
        tester,
        cotas: 20,
        jogosIniciais: const [
          [1, 2, 3, 4, 5, 6],
        ],
      );

      await tester.tap(find.text('Jogo'));
      await tester.pumpAndSettle();
      for (var n = 20; n <= 25; n++) {
        await tester.tap(find.text('$n'));
        await tester.pump();
      }
      await tester.tap(find.text('Salvar jogo'));
      await tester.pump();

      var novoAnimou = false;
      for (var t = 0; t < 6; t++) {
        await tester.pump(const Duration(milliseconds: 40));
        expect(
          opacidadeDaLinha(tester, 'Jogo 1'),
          1.0,
          reason: 'a linha que já existia não pode reanimar',
        );
        if (opacidadeDaLinha(tester, 'Jogo 2') < 1.0) novoAnimou = true;
      }

      // E a linha NOVA continua entrando animada — a correção não pode ter
      // simplesmente desligado a animação.
      expect(novoAnimou, isTrue);
      await tester.pumpAndSettle();
    });
  });
}
