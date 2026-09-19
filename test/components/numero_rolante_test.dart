import 'package:bolao_bolado/components/shared/numero_rolante.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _montar(String texto, double valor) => MaterialApp(
  home: Scaffold(
    body: NumeroRolante(
      texto: texto,
      valor: valor,
      estilo: const TextStyle(fontSize: 18),
    ),
  ),
);

/// Algarismos visíveis em cada rolo, da esquerda para a direita. Cada rolo é
/// um Stack com um algarismo invisível (só para dar o tamanho) e um ou dois
/// visíveis, posicionados por cima.
List<List<String>> _rolos(WidgetTester tester) => [
  for (final rolo
      in find
          .descendant(
            of: find.byType(NumeroRolante),
            matching: find.byType(Stack),
          )
          .evaluate())
    [
      for (final texto
          in find
              .descendant(
                of: find.byWidget(rolo.widget),
                matching: find.descendant(
                  of: find.byType(Positioned),
                  matching: find.byType(Text),
                ),
              )
              .evaluate())
        (texto.widget as Text).data!,
    ],
];

void main() {
  testWidgets('dígito que muda gira por outros números e para no novo', (
    tester,
  ) async {
    await tester.pumpWidget(_montar('126', 126));
    await tester.pumpWidget(_montar('132', 132));

    // Durante o giro a unidade passa por algarismos que não são nem o 6
    // antigo nem o 2 novo: é a volta da roleta.
    final vistosNaUnidade = <String>{};
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 30));
      vistosNaUnidade.addAll(_rolos(tester).last);
    }
    expect(vistosNaUnidade.difference({'6', '2'}), isNotEmpty);

    await tester.pumpAndSettle();
    expect(_rolos(tester), [
      ['1'],
      ['3'],
      ['2'],
    ]);
    expect(find.bySemanticsLabel('132'), findsOneWidget);
  });

  testWidgets('dígito que não muda não gira', (tester) async {
    await tester.pumpWidget(_montar('126', 126));
    await tester.pumpWidget(_montar('127', 127));
    await tester.pump(const Duration(milliseconds: 100));

    final rolos = _rolos(tester);
    expect(rolos[0], ['1']);
    expect(rolos[1], ['2']);
    await tester.pumpAndSettle();
  });

  testWidgets('número que ganha uma casa mantém unidade na unidade', (
    tester,
  ) async {
    await tester.pumpWidget(_montar('9', 9));
    await tester.pumpWidget(_montar('10', 10));
    await tester.pumpAndSettle();

    expect(_rolos(tester), [
      ['1'],
      ['0'],
    ]);
  });
}
