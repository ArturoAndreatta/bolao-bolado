import 'package:bolao_bolado/components/shared/snackbar_deslizante.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _texto = 'Aposta verificada';

Widget _app({VoidCallback? aoDesfazer}) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => mostrarSnackBarDeslizante(
            context,
            conteudo: const Text(_texto),
            corFundo: Colors.green,
            aoDesfazer: aoDesfazer,
          ),
          child: const Text('mostrar'),
        ),
      ),
    ),
  );
}

/// Roda o ciclo até o fim para não deixar Timer pendente entre os testes.
Future<void> _encerrar(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('entra deslizando de baixo para cima', (tester) async {
    await tester.pumpWidget(_app(aoDesfazer: () {}));
    await tester.tap(find.text('mostrar'));
    await tester.pump();

    final alturas = <double>[];
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 70));
      alturas.add(tester.getTopLeft(find.text(_texto)).dy);
    }

    // Sobe (y diminui) monotonicamente e percorre um trajeto perceptível.
    for (var i = 1; i < alturas.length; i++) {
      expect(alturas[i], lessThanOrEqualTo(alturas[i - 1]));
    }
    expect(alturas.first - alturas.last, greaterThan(20));

    await _encerrar(tester);
  });

  testWidgets('o fundo colorido desce JUNTO com o texto na saída', (
    tester,
  ) async {
    await tester.pumpWidget(_app(aoDesfazer: () {}));
    await tester.tap(find.text('mostrar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // O Material colorido é a barra inteira; o texto está dentro dela. Se as
    // duas animações se separarem (o bug da versão anterior), a distância
    // entre o topo da barra e o topo do texto muda durante a saída.
    Finder barra() =>
        find.ancestor(of: find.text(_texto), matching: find.byType(Material));

    final distanciaParada =
        tester.getTopLeft(find.text(_texto)).dy -
        tester.getTopLeft(barra().first).dy;

    await tester.pump(const Duration(seconds: 4));

    var amostras = 0;
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 40));
      if (find.text(_texto).evaluate().isEmpty) break;
      final distancia =
          tester.getTopLeft(find.text(_texto)).dy -
          tester.getTopLeft(barra().first).dy;
      // Tolerância de 1px para arredondamento de subpixel.
      expect(
        (distancia - distanciaParada).abs(),
        lessThan(1),
        reason: 'texto e fundo se separaram durante a saída',
      );
      amostras++;
    }
    expect(amostras, greaterThan(0), reason: 'a saída não foi animada');

    await _encerrar(tester);
  });

  testWidgets('sai deslizando para baixo e some sozinha', (tester) async {
    await tester.pumpWidget(_app(aoDesfazer: () {}));
    await tester.tap(find.text('mostrar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final parada = tester.getTopLeft(find.text(_texto)).dy;
    await tester.pump(const Duration(seconds: 4));

    final descida = <double>[];
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 40));
      if (find.text(_texto).evaluate().isEmpty) break;
      descida.add(tester.getTopLeft(find.text(_texto)).dy);
    }

    expect(descida, isNotEmpty, reason: 'sumiu sem animar a saída');
    expect(descida.last, greaterThan(parada));

    await _encerrar(tester);
    expect(find.text(_texto), findsNothing);
  });

  testWidgets('Desfazer executa a ação e fecha a barra', (tester) async {
    var desfeitas = 0;
    await tester.pumpWidget(_app(aoDesfazer: () => desfeitas++));
    await tester.tap(find.text('mostrar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('Desfazer'));
    await tester.pump();
    expect(desfeitas, 1);

    await _encerrar(tester);
    expect(find.text(_texto), findsNothing);
  });

  testWidgets('sem ação não mostra botão e some sozinha', (tester) async {
    await tester.pumpWidget(_app());
    await tester.tap(find.text('mostrar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text(_texto), findsOneWidget);
    expect(find.text('Desfazer'), findsNothing);

    await _encerrar(tester);
    expect(find.text(_texto), findsNothing);
  });

  testWidgets('mostrar de novo substitui a barra anterior', (tester) async {
    await tester.pumpWidget(_app(aoDesfazer: () {}));
    await tester.tap(find.text('mostrar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('mostrar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // Nunca duas empilhadas no rodapé.
    expect(find.text(_texto), findsOneWidget);

    await _encerrar(tester);
  });
}
