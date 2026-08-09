import 'package:bolao_bolado/pages/participants/participants_reordenacao.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Cada "linha" tem altura fixa e conhecida, para a distancia percorrida ser
// verificavel em pixels.
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

void main() {
  testWidgets('linha que muda de posicao desliza em vez de teleportar', (
    tester,
  ) async {
    await tester.pumpWidget(_montar(['a', 'b', 'c']));
    await tester.pumpAndSettle();

    final yInicialC = tester.getTopLeft(find.text('c')).dy;
    expect(yInicialC, kAlturaLinha * 2);

    // 'c' sobe para o topo — a reordenacao que acontece ao editar a aposta.
    await tester.pumpWidget(_montar(['c', 'a', 'b']));
    // Um frame para o layout novo + o post-frame que mede e dispara.
    await tester.pump();
    await tester.pump();

    // No PRIMEIRO frame da animacao 'c' ainda precisa estar perto de onde
    // estava, nao no destino: e isso que prova que ela desliza.
    final yDuranteC = tester.getTopLeft(find.text('c')).dy;
    expect(
      yDuranteC,
      greaterThan(kAlturaLinha),
      reason: 'c nao pode aparecer no destino imediatamente',
    );

    // No meio da animacao, ja deve ter andado parte do caminho.
    await tester.pump(const Duration(milliseconds: 200));
    final yMeioC = tester.getTopLeft(find.text('c')).dy;
    expect(yMeioC, lessThan(yDuranteC), reason: 'c deve estar subindo');

    // Terminada a animacao, pousa exatamente no topo.
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('c')).dy, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lista estavel nao dispara nenhum deslocamento', (tester) async {
    await tester.pumpWidget(_montar(['a', 'b', 'c']));
    await tester.pumpAndSettle();

    // Reconstroi com a MESMA ordem: ninguem pode se mexer.
    await tester.pumpWidget(_montar(['a', 'b', 'c']));
    await tester.pump();
    await tester.pump();

    expect(tester.getTopLeft(find.text('a')).dy, 0);
    expect(tester.getTopLeft(find.text('b')).dy, kAlturaLinha);
    expect(tester.getTopLeft(find.text('c')).dy, kAlturaLinha * 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('linha nova nao desliza (quem cuida dela e a animacao de '
      'entrada)', (tester) async {
    await tester.pumpWidget(_montar(['a', 'b']));
    await tester.pumpAndSettle();

    // 'z' entra no fim: nao tem posicao anterior, entao nasce parada.
    await tester.pumpWidget(_montar(['a', 'b', 'z']));
    await tester.pump();
    await tester.pump();

    expect(tester.getTopLeft(find.text('z')).dy, kAlturaLinha * 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('remocao de uma linha faz as de baixo subirem deslizando', (
    tester,
  ) async {
    await tester.pumpWidget(_montar(['a', 'b', 'c']));
    await tester.pumpAndSettle();

    // Remove 'a': 'b' e 'c' sobem uma posicao cada.
    await tester.pumpWidget(_montar(['b', 'c']));
    await tester.pump();
    await tester.pump();

    expect(
      tester.getTopLeft(find.text('c')).dy,
      greaterThan(kAlturaLinha),
      reason: 'c deve estar deslizando, nao ja no lugar',
    );

    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('b')).dy, 0);
    expect(tester.getTopLeft(find.text('c')).dy, kAlturaLinha);
    expect(tester.takeException(), isNull);
  });
}
