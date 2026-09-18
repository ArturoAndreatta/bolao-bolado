import 'package:bolao_bolado/models/mensagem.dart';
import 'package:bolao_bolado/widgets/chat/barra_reacoes.dart';
import 'package:bolao_bolado/widgets/chat/bolha_mensagem.dart';
import 'package:bolao_bolado/widgets/chat/texto_mensagem.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Só mensagem PRÓPRIA nestes testes: a bolha dos outros monta o avatar, que
/// lê `usuarios/{uid}` no Firestore.
Widget _montar(
  Mensagem mensagem, {
  void Function(String emoji)? onReagir,
  Map<String, String> nomesPorUid = const {},
  bool podeInteragir = true,
}) {
  return MaterialApp(
    home: Scaffold(
      body: BolhaMensagem(
        mensagem: mensagem,
        isMinha: true,
        iniciaBloco: true,
        encerraBloco: true,
        compacto: false,
        uidAtual: 'eu',
        isAdmin: false,
        podeInteragir: podeInteragir,
        fixada: false,
        nomesPorUid: nomesPorUid,
        onReagir: onReagir ?? (_) {},
        onFixar: () {},
        onDesafixar: () {},
        onApagar: () {},
      ),
    ),
  );
}

Mensagem _mensagem({DateTime? criadoEm}) => Mensagem(
  id: 'm1',
  texto: 'bora fechar',
  autorUid: 'eu',
  autorNome: 'Eu',
  criadoEm: criadoEm,
);

Mensagem _mensagemComReacoes(Map<String, String> reacoes) => Mensagem(
  id: 'm1',
  texto: 'bora fechar',
  autorUid: 'eu',
  autorNome: 'Eu',
  criadoEm: DateTime(2026, 8, 15),
  reacoes: reacoes,
);

/// Opacidade do FadeTransition mais próximo que envolve o emoji — é por ele
/// que a entrada/saída do chip de reação anima.
double opacidadeDoChip(WidgetTester tester, String emoji) {
  final fade = find
      .ancestor(of: find.text(emoji), matching: find.byType(FadeTransition))
      .first;
  return tester.widget<FadeTransition>(fade).opacity.value;
}

void main() {
  testWidgets('mensagem ainda não confirmada já mostra a hora', (tester) async {
    // Regressão: sem carimbo, a bolha nascia estreita e mudava de largura
    // quando o serverTimestamp voltava — a mensagem "pulava" na tela.
    await tester.pumpWidget(_montar(_mensagem()));

    final horario = find.byWidgetPredicate(
      (w) => w is Text && (w.data ?? '').contains(RegExp(r'^\d{2}:\d{2}$')),
    );
    expect(horario, findsOneWidget);
  });

  testWidgets('o carimbo pendente tem o MESMO estilo do confirmado', (
    tester,
  ) async {
    // Qualquer diferença visual (cor mais apagada, ícone de relógio) some
    // quando o servidor responde, e some é exatamente a impressão de que
    // "algo mudou" na mensagem já enviada.
    Text carimbo() => tester.widget<Text>(
      find.byWidgetPredicate(
        (w) => w is Text && (w.data ?? '').contains(RegExp(r'^\d{2}:\d{2}$')),
      ),
    );

    await tester.pumpWidget(_montar(_mensagem()));
    final estiloPendente = carimbo().style;

    await tester.pumpWidget(
      _montar(_mensagem(criadoEm: DateTime(2026, 8, 15, 10, 30))),
    );
    expect(carimbo().style, estiloPendente);
  });

  testWidgets('a largura da bolha não muda quando a hora do servidor chega', (
    tester,
  ) async {
    await tester.pumpWidget(_montar(_mensagem()));
    final larguraPendente = tester.getSize(find.byType(Wrap)).width;

    await tester.pumpWidget(
      _montar(_mensagem(criadoEm: DateTime(2026, 8, 15))),
    );
    expect(tester.getSize(find.byType(Wrap)).width, larguraPendente);
  });

  testWidgets('reações aparecem com a contagem agrupada por emoji', (
    tester,
  ) async {
    await tester.pumpWidget(
      _montar(
        Mensagem(
          id: 'm1',
          texto: 'boa',
          autorUid: 'eu',
          autorNome: 'Eu',
          criadoEm: DateTime(2026, 8, 15),
          reacoes: const {'a': '👍', 'b': '👍', 'c': '🔥'},
        ),
      ),
    );

    expect(find.text('👍'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('🔥'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  // ── Animação de entrada/saída do chip ───────────────────────────────────
  testWidgets('reação que já existia quando a bolha aparece não anima', (
    tester,
  ) async {
    // Sem isto, rolar o histórico para cima faria cada reação antiga "pipocar"
    // de novo toda vez que a bolha entra na tela — pareceria novidade, sem
    // ser.
    await tester.pumpWidget(_montar(_mensagemComReacoes(const {'eu': '👍'})));
    await tester.pump();

    expect(opacidadeDoChip(tester, '👍'), 1.0);
  });

  testWidgets('reagir com um emoji novo faz o chip entrar animado', (
    tester,
  ) async {
    await tester.pumpWidget(_montar(_mensagemComReacoes(const {})));
    await tester.pumpWidget(_montar(_mensagemComReacoes(const {'eu': '🔥'})));

    // No meio da animação de 220ms, ainda não chegou lá.
    await tester.pump(const Duration(milliseconds: 50));
    expect(opacidadeDoChip(tester, '🔥'), lessThan(1.0));

    await tester.pumpAndSettle();
    expect(opacidadeDoChip(tester, '🔥'), 1.0);
  });

  testWidgets('remover a última reação anima a saída antes do chip sumir', (
    tester,
  ) async {
    await tester.pumpWidget(_montar(_mensagemComReacoes(const {'eu': '🎉'})));
    await tester.pump();
    expect(find.text('🎉'), findsOneWidget);

    await tester.pumpWidget(_montar(_mensagemComReacoes(const {})));
    // Dentro da janela de saída: o chip continua na árvore, encolhendo.
    await tester.pump(const Duration(milliseconds: 40));
    expect(find.text('🎉'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('🎉'), findsNothing);
  });

  testWidgets(
    'reação que sai e volta rápido retoma a entrada, não reinicia do zero',
    (tester) async {
      await tester.pumpWidget(_montar(_mensagemComReacoes(const {'eu': '🎉'})));
      await tester.pump();

      // Começa a sair...
      await tester.pumpWidget(_montar(_mensagemComReacoes(const {})));
      await tester.pump(const Duration(milliseconds: 40));
      final opacidadeAoVoltar = opacidadeDoChip(tester, '🎉');
      expect(opacidadeAoVoltar, lessThan(1.0));

      // ...e volta antes de terminar.
      await tester.pumpWidget(_montar(_mensagemComReacoes(const {'eu': '🎉'})));
      await tester.pump();

      // Retomou da opacidade onde estava, não voltou pro zero.
      expect(
        opacidadeDoChip(tester, '🎉'),
        greaterThanOrEqualTo(opacidadeAoVoltar),
      );

      await tester.pumpAndSettle();
      expect(opacidadeDoChip(tester, '🎉'), 1.0);
    },
  );

  // ── Como se chega até a reação ──────────────────────────────────────────
  // Estes três fixam a razão da barra existir: antes, reagir só era possível
  // por toque longo ou botão direito num menu de contexto, sem nenhuma pista
  // na tela de que aquilo existia.
  testWidgets('a barra de reações NÃO fica na tela sem interação', (
    tester,
  ) async {
    await tester.pumpWidget(_montar(_mensagem()));
    expect(find.byType(BarraReacoes), findsNothing);
  });

  testWidgets('toque longo abre a barra de reações (mobile)', (tester) async {
    await tester.pumpWidget(_montar(_mensagem()));

    await tester.longPress(find.byType(TextoMensagem));
    await tester.pumpAndSettle();

    expect(find.byType(BarraReacoes), findsOneWidget);
  });

  testWidgets('sem permissão, nenhum gesto abre barra nem menu', (
    tester,
  ) async {
    await tester.pumpWidget(_montar(_mensagem(), podeInteragir: false));

    await tester.longPress(find.byType(TextoMensagem));
    await tester.pumpAndSettle();
    expect(find.byType(BarraReacoes), findsNothing);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byType(TextoMensagem)));
    await tester.pumpAndSettle();
    expect(find.byType(BarraReacoes), findsNothing);

    await tester.tap(
      find.byType(TextoMensagem),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    expect(find.text('Copiar texto'), findsNothing);
  });

  testWidgets('sem permissão, tocar no chip não reage', (tester) async {
    final reagidos = <String>[];
    await tester.pumpWidget(
      _montar(
        Mensagem(
          id: 'm1',
          texto: 'boa',
          autorUid: 'outro',
          autorNome: 'Outro',
          criadoEm: DateTime(2026, 8, 15),
          reacoes: const {'a': '👍'},
        ),
        onReagir: reagidos.add,
        podeInteragir: false,
      ),
    );

    await tester.tap(find.text('👍'));
    await tester.pumpAndSettle();

    expect(reagidos, isEmpty);
  });

  testWidgets('mouse por cima abre a barra de reações (desktop)', (
    tester,
  ) async {
    await tester.pumpWidget(_montar(_mensagem()));

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await tester.pump();

    await mouse.moveTo(tester.getCenter(find.byType(TextoMensagem)));
    await tester.pumpAndSettle();

    expect(find.byType(BarraReacoes), findsOneWidget);
  });

  testWidgets('só UMA barra fica aberta ao atravessar mensagens com o mouse', (
    tester,
  ) async {
    // Regressão: o fechamento por hover é adiado 140ms para o ponteiro
    // conseguir chegar na pílula. Sem um dono único, atravessar a lista rápido
    // empilhava a barra da mensagem anterior com a da nova.
    // Só a m1 tem reação sua. É o que permite dizer de QUEM é a barra na
    // tela: a da m1 nasce com `reacaoAtual` preenchido, a da m2 com null.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              for (final id in ['m1', 'm2'])
                BolhaMensagem(
                  mensagem: Mensagem(
                    id: id,
                    texto: 'mensagem $id',
                    autorUid: 'eu',
                    autorNome: 'Eu',
                    criadoEm: DateTime(2026, 8, 15),
                    reacoes: id == 'm1' ? const {'eu': '🔥'} : const {},
                  ),
                  isMinha: true,
                  iniciaBloco: true,
                  encerraBloco: true,
                  compacto: false,
                  uidAtual: 'eu',
                  isAdmin: false,
                  podeInteragir: true,
                  fixada: false,
                  onReagir: (_) {},
                  onFixar: () {},
                  onDesafixar: () {},
                  onApagar: () {},
                ),
            ],
          ),
        ),
      ),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await tester.pump();

    await mouse.moveTo(tester.getCenter(find.text('mensagem m1')));
    await tester.pumpAndSettle();
    expect(find.byType(BarraReacoes), findsOneWidget);
    expect(
      tester.widget<BarraReacoes>(find.byType(BarraReacoes)).reacaoAtual,
      '🔥',
      reason: 'a barra aberta deveria ser a da m1',
    );

    await mouse.moveTo(tester.getCenter(find.text('mensagem m2')));
    await tester.pump();
    // Dentro da janela dos 140ms: é exatamente aqui que a barra da m1 ainda
    // ficava na tela junto com a da m2. Depois do timer ela fecha sozinha e o
    // teste não provaria nada.
    await tester.pump(const Duration(milliseconds: 60));

    expect(find.byType(BarraReacoes), findsOneWidget);
    expect(
      tester.widget<BarraReacoes>(find.byType(BarraReacoes)).reacaoAtual,
      isNull,
      reason: 'a que sobrou deveria ser a da m2, sob o ponteiro',
    );

    await tester.pumpAndSettle();
  });

  testWidgets('escolher um emoji na barra reage e fecha a barra', (
    tester,
  ) async {
    final reagidos = <String>[];
    await tester.pumpWidget(_montar(_mensagem(), onReagir: reagidos.add));

    await tester.longPress(find.byType(TextoMensagem));
    await tester.pumpAndSettle();

    // O 🔥 da barra: o texto '🔥' só existe lá, já que esta mensagem não tem
    // reação nenhuma ainda (não há chip embaixo da bolha).
    await tester.tap(find.text('🔥'));
    await tester.pumpAndSettle();

    expect(reagidos, ['🔥']);
    expect(find.byType(BarraReacoes), findsNothing);
  });

  testWidgets('a barra marca o emoji com que você já reagiu', (tester) async {
    await tester.pumpWidget(
      _montar(
        Mensagem(
          id: 'm1',
          texto: 'boa',
          autorUid: 'eu',
          autorNome: 'Eu',
          criadoEm: DateTime(2026, 8, 15),
          reacoes: const {'eu': '🎉'},
        ),
      ),
    );

    await tester.longPress(find.byType(TextoMensagem));
    await tester.pumpAndSettle();

    final barra = tester.widget<BarraReacoes>(find.byType(BarraReacoes));
    expect(barra.reacaoAtual, '🎉');
  });

  testWidgets('reação vinda do catálogo ganha lugar próprio na barra', (
    tester,
  ) async {
    // Emoji fora das seis rápidas: sem o slot extra, ele sumiria da barra e
    // desfazer viraria adivinhação.
    await tester.pumpWidget(
      _montar(
        Mensagem(
          id: 'm1',
          texto: 'boa',
          autorUid: 'eu',
          autorNome: 'Eu',
          criadoEm: DateTime(2026, 8, 15),
          reacoes: const {'eu': '🤡'},
        ),
      ),
    );

    await tester.longPress(find.byType(TextoMensagem));
    await tester.pumpAndSettle();

    // Um na barra, um no chip embaixo da bolha.
    expect(find.text('🤡'), findsNWidgets(2));
  });

  testWidgets('o "+" da barra abre o catálogo e reage com o escolhido', (
    tester,
  ) async {
    final reagidos = <String>[];
    await tester.pumpWidget(_montar(_mensagem(), onReagir: reagidos.add));

    await tester.longPress(find.byType(TextoMensagem));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_reaction_outlined));
    await tester.pumpAndSettle();

    // Emoji que não está na barra rápida nem é ícone de aba, e que cai nas
    // primeiras linhas da grade (o GridView é preguiçoso: o que está fora da
    // folha ainda não existe para o finder).
    await tester.tap(find.text('😃'));
    await tester.pumpAndSettle();

    expect(reagidos, ['😃']);
  });

  testWidgets('o "⋯" da barra abre as ações da mensagem', (tester) async {
    await tester.pumpWidget(_montar(_mensagem()));

    await tester.longPress(find.byType(TextoMensagem));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();

    // Não-admin vê só copiar; fixar e apagar são do painel.
    expect(find.text('Copiar texto'), findsOneWidget);
    expect(find.text('Apagar'), findsNothing);
    // Sem reação nenhuma, não há lista para abrir.
    expect(find.text('Quem reagiu'), findsNothing);
  });

  testWidgets('o menu de ações abre junto da mensagem, não do outro lado', (
    tester,
  ) async {
    // Regressão: o alvo do showMenu era um PONTO na borda ESQUERDA da bolha.
    // O layout do Material cresce para o lado com mais espaço, então ele
    // encostava a DIREITA do menu naquele ponto e empurrava o resto para
    // fora — numa mensagem própria o menu ia parar longe, fora do painel do
    // chat. Agora o alvo é o retângulo da bolha, e o menu alinha pela borda
    // externa dela.
    await tester.pumpWidget(_montar(_mensagem()));
    final texto = tester.getRect(find.byType(TextoMensagem));

    await tester.longPress(find.byType(TextoMensagem));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();

    final menu = tester.getRect(
      find.byWidgetPredicate((w) => w is PopupMenuItem).first,
    );

    // Com o bug, a direita do menu caía na ESQUERDA da bolha — antes até do
    // começo do texto.
    expect(menu.right, greaterThan(texto.left));
    // E ele abre abaixo da mensagem, não por cima dela.
    expect(menu.top, greaterThanOrEqualTo(texto.top));
  });

  testWidgets('o menu de ações oferece "Quem reagiu" quando há reação', (
    tester,
  ) async {
    // Toque longo no chip também abre a lista, mas é gesto que ninguém
    // descobre sozinho — o item de menu é o caminho visível.
    await tester.pumpWidget(
      _montar(
        Mensagem(
          id: 'm1',
          texto: 'boa',
          autorUid: 'eu',
          autorNome: 'Eu',
          criadoEm: DateTime(2026, 8, 15),
          reacoes: const {'u1': '👍'},
        ),
      ),
    );

    await tester.longPress(find.byType(TextoMensagem));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Quem reagiu'), findsOneWidget);
  });

  // ── O chip como atalho de reação ────────────────────────────────────────
  testWidgets('tocar num chip dá aquela reação', (tester) async {
    final reagidos = <String>[];
    await tester.pumpWidget(
      _montar(
        Mensagem(
          id: 'm1',
          texto: 'boa',
          autorUid: 'eu',
          autorNome: 'Eu',
          criadoEm: DateTime(2026, 8, 15),
          reacoes: const {'u1': '🔥'},
        ),
        onReagir: reagidos.add,
      ),
    );

    await tester.tap(find.text('🔥'));
    await tester.pump();

    expect(reagidos, ['🔥']);
  });

  testWidgets('tocar no chip que já é o SEU tira a reação', (tester) async {
    // O serviço traduz "reagir com o emoji que já é o seu" em remover, então
    // a bolha manda o mesmo emoji nos dois casos — quem decide é o estado.
    final reagidos = <String>[];
    await tester.pumpWidget(
      _montar(
        Mensagem(
          id: 'm1',
          texto: 'boa',
          autorUid: 'eu',
          autorNome: 'Eu',
          criadoEm: DateTime(2026, 8, 15),
          reacoes: const {'eu': '🎉'},
        ),
        onReagir: reagidos.add,
      ),
    );

    await tester.tap(find.text('🎉'));
    await tester.pump();

    expect(reagidos, ['🎉']);
  });

  // ── Quem reagiu ─────────────────────────────────────────────────────────
  // A FOLHA em si não é montada aqui: ela desenha o avatar de cada pessoa, que
  // lê `usuarios/{uid}` no Firestore — a mesma limitação anotada no topo deste
  // arquivo. O que a folha mostra está coberto por quem_reagiu_test.dart, que
  // exercita a ordenação e o resumo sem widget nenhum.
  Tooltip tooltipDoChip(WidgetTester tester, String emoji) =>
      tester.widget<Tooltip>(
        find.ancestor(of: find.text(emoji), matching: find.byType(Tooltip)),
      );

  testWidgets('o chip diz quem reagiu no tooltip', (tester) async {
    await tester.pumpWidget(
      _montar(
        Mensagem(
          id: 'm1',
          texto: 'boa',
          autorUid: 'eu',
          autorNome: 'Eu',
          criadoEm: DateTime(2026, 8, 15),
          reacoes: const {'u1': '👍', 'u2': '👍'},
        ),
        nomesPorUid: const {'u1': 'Ana', 'u2': 'Bruno'},
      ),
    );

    expect(tooltipDoChip(tester, '👍').message, 'Ana e Bruno');
  });

  testWidgets('no tooltip você é "Você", não o seu nome', (tester) async {
    await tester.pumpWidget(
      _montar(
        Mensagem(
          id: 'm1',
          texto: 'boa',
          autorUid: 'eu',
          autorNome: 'Eu',
          criadoEm: DateTime(2026, 8, 15),
          reacoes: const {'eu': '🔥'},
        ),
        nomesPorUid: const {'eu': 'Arturo'},
      ),
    );

    expect(tooltipDoChip(tester, '🔥').message, 'Você');
  });

  testWidgets('quem não está mais na lista de apostas não fica sem nome', (
    tester,
  ) async {
    await tester.pumpWidget(
      _montar(
        Mensagem(
          id: 'm1',
          texto: 'boa',
          autorUid: 'outro',
          autorNome: 'Fulano',
          criadoEm: DateTime(2026, 8, 15),
          // 'outro' é o autor da mensagem: o nome dele vem do próprio doc.
          // 'sumido' não é ninguém conhecido.
          reacoes: const {'outro': '👍', 'sumido': '👍'},
        ),
      ),
    );

    expect(tooltipDoChip(tester, '👍').message, 'Alguém e Fulano');
  });

  testWidgets('no tooltip você vem antes do resto do grupo', (tester) async {
    await tester.pumpWidget(
      _montar(
        Mensagem(
          id: 'm1',
          texto: 'boa',
          autorUid: 'eu',
          autorNome: 'Eu',
          criadoEm: DateTime(2026, 8, 15),
          reacoes: const {'u1': '👍', 'eu': '👍'},
        ),
        nomesPorUid: const {'u1': 'Ana'},
      ),
    );

    expect(tooltipDoChip(tester, '👍').message, 'Você e Ana');
  });
}
