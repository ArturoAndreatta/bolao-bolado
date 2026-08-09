import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/pages/participants/participants_lista.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A lista mobile usa `ListView.builder` com `itemExtent: kAlturaLinhaLista`.
///
/// No modo padrão (`semScrollProprio: false`, usado em participants_painel.dart
/// quando `alturaMobile` está definido — o caso real da tela de Participantes)
/// a lista rola por conta própria dentro de uma altura finita: é essa
/// viewport que permite ao ListView reciclar de verdade.
///
/// Todas as linhas de teste usam `uid: null` (como uma aposta manual, sem
/// usuário por trás): com um uid presente, `AvatarDoParticipante` tenta abrir
/// um `StreamBuilder` sobre `FirebaseFirestore.instance`, que não existe
/// neste ambiente de teste (sem `Firebase.initializeApp()`) e lança
/// `FirebaseException` — sem relação nenhuma com o que estes testes cobrem.
Widget _montarComAlturaFinita(Widget lista, {double altura = 600}) =>
    MaterialApp(
      theme: ThemeData(extensions: [AppCores.claro]),
      home: Scaffold(
        body: SizedBox(height: altura, child: lista),
      ),
    );

Map<String, Object?> _linha(String uid, String nome, double valor) => {
  'uid': null, // ver nota de FirebaseException acima
  'nome': nome,
  'valor': valor,
  'cotas': 1,
  'premio': 10.0,
};

void main() {
  testWidgets('kAlturaLinhaLista bate com a altura renderizada', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _montarComAlturaFinita(
        ListaParticipantes(
          rows: [
            {
              ..._linha('a', 'Fulano de Tal da Silva Sauro Comprido', 30.0),
              'criadoPeloAdmin': true,
            },
            _linha('b', 'Beltrano', 12.0),
          ],
          currentUid: null,
        ),
        altura: 300,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.takeException(),
      isNull,
      reason: 'nome longo + selo manual não pode estourar a linha',
    );

    // Distância entre o topo de duas linhas consecutivas = altura real de uma
    // linha com o divisor incluído — exatamente o que o itemExtent precisa
    // valer.
    final yPrimeira = tester
        .getTopLeft(find.text('Fulano de Tal da Silva Sauro Comprido'))
        .dy;
    final ySegunda = tester.getTopLeft(find.text('Beltrano')).dy;
    final alturaReal = ySegunda - yPrimeira;

    expect(
      alturaReal,
      closeTo(kAlturaLinhaLista, 0.5),
      reason:
          'a linha renderiza com $alturaReal, mas kAlturaLinhaLista é '
          '$kAlturaLinhaLista — ajuste a constante ou o padding da linha',
    );
  });

  testWidgets('1000 linhas montam sem overflow, com viewport própria', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final rows = List.generate(
      1000,
      (i) => _linha('u$i', 'Participante $i', (i + 1).toDouble()),
    );

    await tester.pumpWidget(
      _montarComAlturaFinita(ListaParticipantes(rows: rows, currentUid: null)),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Participante 0'), findsOneWidget);
  });

  testWidgets(
    'com 1000 linhas e viewport própria, só uma fração pequena é montada '
    '(reciclagem)',
    (tester) async {
      // Esta é a prova de que a lentidão de verdade foi resolvida. Uma
      // primeira tentativa desta correção usava `shrinkWrap: true` para a
      // lista caber dentro de um `SingleChildScrollView` externo — e isso
      // fazia o ListView.builder construir TODOS os itens para medir a
      // altura total, mesmo com `itemExtent` fixo. A reciclagem só existe
      // quando o ListView tem uma viewport PRÓPRIA e finita, que é o que
      // `semScrollProprio: false` (o padrão) garante.
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final rows = List.generate(
        1000,
        (i) => _linha('u$i', 'Participante $i', (i + 1).toDouble()),
      );

      await tester.pumpWidget(
        _montarComAlturaFinita(
          ListaParticipantes(rows: rows, currentUid: null),
          altura: 600,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final montadas = find.byType(LinhaParticipante).evaluate().length;

      // 600px de viewport / 63px por linha ≈ 9 linhas, + alguma margem de
      // cache do ListView. Bem longe das 1000 que o Column anterior montava.
      expect(
        montadas,
        lessThan(60),
        reason: 'montou $montadas de 1000 linhas — não está reciclando',
      );
      expect(montadas, greaterThan(0));
    },
  );

  testWidgets('semScrollProprio: true monta tudo (modo sem altura definida)', (
    tester,
  ) async {
    // Cobre o outro modo do widget: quando o chamador não tem altura para
    // oferecer, a lista cede o scroll a um ancestral e aceita montar tudo
    // (é o preço documentado em ListaParticipantes.semScrollProprio). O
    // que este teste garante é que ESSE modo continua funcionando sem
    // estourar, não que ele recicla.
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final rows = List.generate(
      30,
      (i) => _linha('u$i', 'Participante $i', (i + 1).toDouble()),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [AppCores.claro]),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ListaParticipantes(
              rows: rows,
              currentUid: null,
              semScrollProprio: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(LinhaParticipante).evaluate().length, 30);
  });
}
