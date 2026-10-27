import 'package:bolao_bolado/components/formatters/formatters.dart';
import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/core/debug_flags.dart';
import 'package:bolao_bolado/pages/participants/participants_estilo_entrada.dart';
import 'package:bolao_bolado/pages/participants/participants_lista.dart';
import 'package:bolao_bolado/pages/participants/participants_tabela.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Edição e chegada são encenações diferentes, e as duas precisam sobreviver
/// a outras apostas acontecendo ao mesmo tempo.
///
/// - Aposta NOVA: a linha inteira entra (pela esquerda, no estilo padrão).
/// - Aposta EDITADA: a linha fica onde está; só a célula do nome ou do valor
///   troca de texto. A versão anterior tratava valor diferente como aposta
///   nova e reencenava a entrada inteira.
///
/// A ordem dos testes segue o que a tela faz de verdade: ordenada pela
/// última alteração, uma edição também SOBE a linha para o topo, e uma
/// aposta nova empurra todas as outras um índice para baixo.
String moeda(num v) => Formatters.moeda.format(v);

void main() {
  Map<String, dynamic> aposta(String uid, double valor, {String? nome}) => {
    'uid': uid,
    'nome': nome ?? uid,
    'valor': valor,
    'cotas': 1,
    'premio': 999.0,
  };

  setUp(() => estiloEntradaGlobal.value = EstiloEntrada.batida);

  Widget tabela(List<Map<String, dynamic>> rows) => MaterialApp(
    theme: ThemeData(extensions: [AppCores.claro]),
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: larguraTotal + 4,
          height: 400,
          child: TabelaApostas(
            rows: rows,
            colunaOrdenada: 4,
            ascendente: false,
            onCabecalhoTap: (_) {},
            currentUid: null,
            alturaFixa: true,
          ),
        ),
      ),
    ),
  );

  Widget lista(List<Map<String, dynamic>> rows) => MaterialApp(
    theme: ThemeData(extensions: [AppCores.claro]),
    home: Scaffold(
      body: SizedBox(
        width: 400,
        height: 600,
        child: ListaParticipantes(rows: rows, currentUid: null),
      ),
    ),
  );

  Future<void> preparar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  // Bombeia e engole o overflow do cabeçalho, que só existe no ambiente de
  // teste (fonte Ahem mais larga que a real).
  Future<void> pump(WidgetTester tester, [Duration? d]) async {
    await tester.pump(d);
    tester.takeException();
  }

  Future<void> assentar(WidgetTester tester) async {
    await tester.pumpAndSettle();
    tester.takeException();
  }

  group('edição na tabela', () {
    testWidgets('o valor troca alinhado à direita, como fica parado', (
      tester,
    ) async {
      // Durante a troca o texto encolhia para o próprio tamanho e encostava
      // à esquerda da célula; só voltava para a direita no fim.
      await preparar(tester);
      await tester.pumpWidget(tabela([aposta('ana', 30), aposta('bia', 20)]));
      await assentar(tester);
      final direitaParado = tester.getTopRight(find.text(moeda(20))).dx;

      // Valor CURTO de propósito: a fonte de teste é larga, e um texto que
      // já ocupa a célula inteira fica alinhado de qualquer jeito.
      await tester.pumpWidget(tabela([aposta('ana', 6), aposta('bia', 20)]));
      await pump(tester);
      await pump(tester, const Duration(milliseconds: 300));

      expect(
        tester.getTopRight(find.text(moeda(6))).dx,
        closeTo(direitaParado, 0.5),
        reason: 'o valor novo entrou fora da coluna alinhada à direita',
      );
      await assentar(tester);
    });

    testWidgets(
      'aposta gravada e ainda sem hora do servidor não mostra traço',
      (tester) async {
        await preparar(tester);
        await tester.pumpWidget(tabela([aposta('ana', 30)]));
        await assentar(tester);

        // Escrita local: `data-hora` ainda é null até o servidor carimbar.
        await tester.pumpWidget(
          tabela([
            {...aposta('ana', 42), 'data-hora': null, 'pendente': true},
          ]),
        );
        await pump(tester);

        expect(find.text('—'), findsNothing);
        await assentar(tester);
      },
    );

    testWidgets('mudar o VALOR troca só a célula, sem entrada da linha', (
      tester,
    ) async {
      await preparar(tester);
      await tester.pumpWidget(tabela([aposta('ana', 30), aposta('bia', 20)]));
      await assentar(tester);
      final xNome = tester.getTopLeft(find.text('ana')).dx;

      await tester.pumpWidget(tabela([aposta('ana', 42), aposta('bia', 20)]));
      await pump(tester);
      await pump(tester, const Duration(milliseconds: 60));

      // A linha não se mexe: o nome continua exatamente no lugar.
      expect(tester.getTopLeft(find.text('ana')).dx, closeTo(xNome, 0.01));
      // E o valor está no meio da troca: o antigo saindo, o novo entrando.
      expect(find.text(moeda(30)), findsOneWidget);
      expect(find.text(moeda(42)), findsOneWidget);

      await assentar(tester);
      expect(find.text(moeda(30)), findsNothing);
      expect(find.text(moeda(42)), findsOneWidget);
    });

    testWidgets('mudar o NOME troca só o nome; o valor fica quieto', (
      tester,
    ) async {
      await preparar(tester);
      await tester.pumpWidget(tabela([aposta('a', 30, nome: 'Ana')]));
      await assentar(tester);
      final xValor = tester.getTopLeft(find.text(moeda(30)).first).dx;

      await tester.pumpWidget(tabela([aposta('a', 30, nome: 'Ana Paula')]));
      await pump(tester);
      await pump(tester, const Duration(milliseconds: 60));

      expect(find.text('Ana'), findsOneWidget, reason: 'nome antigo saindo');
      expect(find.text('Ana Paula'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text(moeda(30)).first).dx,
        closeTo(xValor, 0.01),
        reason: 'o valor não foi editado e não pode se mexer',
      );
      await assentar(tester);
      expect(find.text('Ana'), findsNothing);
    });

    testWidgets('edição que SOBE a linha não reencena a entrada', (
      tester,
    ) async {
      // Ordenada pela última alteração, editar leva a aposta para o topo. Era
      // nesse caso que o bug aparecia: a linha mudava de índice, o ListView
      // a montava do zero e ela entrava de novo pela esquerda.
      await preparar(tester);
      await tester.pumpWidget(
        tabela([aposta('ana', 30), aposta('bia', 20), aposta('caio', 10)]),
      );
      await assentar(tester);
      final xFinal = tester.getTopLeft(find.text('caio')).dx;

      await tester.pumpWidget(
        tabela([aposta('caio', 60), aposta('ana', 30), aposta('bia', 20)]),
      );
      await pump(tester);
      await pump(tester, const Duration(milliseconds: 60));

      expect(
        tester.getTopLeft(find.text('caio')).dx,
        closeTo(xFinal, 0.01),
        reason: 'a linha editada não pode entrar pela esquerda',
      );
      expect(find.text(moeda(10)), findsOneWidget, reason: 'valor trocando');
      await assentar(tester);
    });

    testWidgets('reemissão do servidor não reinicia a troca', (tester) async {
      await preparar(tester);
      await tester.pumpWidget(tabela([aposta('ana', 30)]));
      await assentar(tester);

      await tester.pumpWidget(tabela([aposta('ana', 42)]));
      await pump(tester);
      await pump(tester, const Duration(milliseconds: 600));
      // Confirmação do servidor: mesmos dados, objetos novos.
      await tester.pumpWidget(tabela([aposta('ana', 42)]));
      await pump(tester);

      expect(
        find.text(moeda(30)),
        findsNothing,
        reason: 'a troca já tinha terminado e não pode recomeçar',
      );
      await assentar(tester);
    });
  });

  group('chegada na tabela com outras apostas acontecendo', () {
    testWidgets('segunda aposta chegando não corta a entrada da primeira', (
      tester,
    ) async {
      // A primeira desce um índice quando a segunda entra no topo. Sem as
      // linhas seguirem a chave, ela era montada do zero nesse instante — já
      // sem animação — e saltava para o lugar final.
      await preparar(tester);
      await tester.pumpWidget(tabela([aposta('a', 30)]));
      await assentar(tester);
      final xFinal = tester.getTopLeft(find.text('a')).dx;

      await tester.pumpWidget(tabela([aposta('n1', 50), aposta('a', 30)]));
      await pump(tester);
      await pump(tester, const Duration(milliseconds: 100));
      final xAntes = tester.getTopLeft(find.text('n1')).dx;
      expect(xAntes, lessThan(xFinal - 1), reason: 'n1 está entrando');

      await tester.pumpWidget(
        tabela([aposta('n2', 70), aposta('n1', 50), aposta('a', 30)]),
      );
      await pump(tester);
      await pump(tester, const Duration(milliseconds: 30));

      final xDepois = tester.getTopLeft(find.text('n1')).dx;
      expect(
        xDepois,
        lessThan(xFinal - 1),
        reason: 'n1 saltou para o destino ($xDepois) quando n2 chegou',
      );
      expect(
        xDepois,
        greaterThanOrEqualTo(xAntes - 0.01),
        reason: 'n1 recomeçou a entrada em vez de continuar',
      );
      expect(
        tester.getTopLeft(find.text('n2')).dx,
        lessThan(xFinal - 1),
        reason: 'n2 também entra',
      );

      await assentar(tester);
      expect(tester.getTopLeft(find.text('n1')).dx, closeTo(xFinal, 0.01));
      expect(tester.getTopLeft(find.text('n2')).dx, closeTo(xFinal, 0.01));
    });

    testWidgets('chegada e edição no mesmo quadro: cada uma com a sua', (
      tester,
    ) async {
      await preparar(tester);
      await tester.pumpWidget(tabela([aposta('ana', 30), aposta('bia', 20)]));
      await assentar(tester);
      final xFinal = tester.getTopLeft(find.text('ana')).dx;

      await tester.pumpWidget(
        tabela([aposta('nova', 12), aposta('ana', 36), aposta('bia', 20)]),
      );
      await pump(tester);
      await pump(tester, const Duration(milliseconds: 60));

      expect(tester.getTopLeft(find.text('nova')).dx, lessThan(xFinal - 1));
      expect(tester.getTopLeft(find.text('ana')).dx, closeTo(xFinal, 0.01));
      expect(find.text(moeda(30)), findsOneWidget);
      await assentar(tester);
    });

    testWidgets('rajada de apostas termina com tudo no lugar', (tester) async {
      await preparar(tester);
      var rows = [aposta('base', 6)];
      await tester.pumpWidget(tabela(rows));
      await assentar(tester);
      final xFinal = tester.getTopLeft(find.text('base')).dx;

      // Oito apostas a cada 80ms, todas na tela, entradas sobrepostas.
      for (var i = 0; i < 8; i++) {
        rows = [aposta('r$i', 6.0 * (i + 2)), ...rows];
        await tester.pumpWidget(tabela(rows));
        await pump(tester);
        await pump(tester, const Duration(milliseconds: 80));
      }
      await assentar(tester);

      for (final row in rows) {
        final finder = find.text(row['uid'] as String);
        expect(finder, findsOneWidget);
        expect(tester.getTopLeft(finder).dx, closeTo(xFinal, 0.01));
      }
      // Grade intacta: cada linha no índice dela, sem sobra de deslize.
      for (var i = 1; i < rows.length; i++) {
        final acima = tester.getTopLeft(
          find.text(rows[i - 1]['uid'] as String),
        );
        final abaixo = tester.getTopLeft(find.text(rows[i]['uid'] as String));
        expect(abaixo.dy - acima.dy, closeTo(kAlturaLinhaTabela, 0.01));
      }
    });
  });

  group('lista mobile', () {
    testWidgets('edição troca só o valor; chegada continua entrando', (
      tester,
    ) async {
      await preparar(tester);
      await tester.pumpWidget(lista([aposta('ana', 30)]));
      await assentar(tester);
      final xNome = tester.getTopLeft(find.text('ana')).dx;

      await tester.pumpWidget(lista([aposta('nova', 6), aposta('ana', 42)]));
      await pump(tester);
      await pump(tester, const Duration(milliseconds: 60));

      expect(tester.getTopLeft(find.text('ana')).dx, closeTo(xNome, 0.01));
      expect(find.text(moeda(30)), findsOneWidget);
      expect(find.text(moeda(42)), findsOneWidget);
      expect(tester.getTopLeft(find.text('nova')).dx, lessThan(xNome - 1));

      await assentar(tester);
      expect(find.text(moeda(30)), findsNothing);
      expect(tester.getTopLeft(find.text('nova')).dx, closeTo(xNome, 0.01));
    });
  });
}
