import 'package:bolao_bolado/core/app_tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // O AnimatedTheme de BolaoBolado compara `data` por `!=`. Enquanto claro()/
  // escuro() construíam um ThemeData novo a cada chamada, ele entendia que o
  // tema havia mudado a cada rebuild e reiniciava a animação de 450ms.
  test('claro() e escuro() devolvem sempre a MESMA instância', () {
    expect(identical(AppTema.claro(), AppTema.claro()), isTrue);
    expect(identical(AppTema.escuro(), AppTema.escuro()), isTrue);
    expect(identical(AppTema.claro(), AppTema.escuro()), isFalse);
  });

  testWidgets('AnimatedTheme assenta em vez de reanimar a cada rebuild', (
    tester,
  ) async {
    final rebuilds = ValueNotifier<int>(0);
    addTearDown(rebuilds.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<int>(
          valueListenable: rebuilds,
          builder: (context, _, _) => AnimatedTheme(
            data: AppTema.claro(),
            duration: const Duration(milliseconds: 450),
            child: const Scaffold(body: SizedBox()),
          ),
        ),
      ),
    );

    // Rebuilds sucessivos sem trocar de modo: com ThemeData novo a cada
    // chamada, a árvore ficava permanentemente animando e pumpAndSettle
    // estouraria o timeout.
    for (var i = 0; i < 5; i++) {
      rebuilds.value++;
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
  });
}
