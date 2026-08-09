import 'package:bolao_bolado/widgets/pix_info.dart';
import 'package:bolao_bolado/widgets/como_funciona.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _rowLadoALado() {
  final pixInfo = PixInfo(chavePix: 'teste@exemplo.com', valor: 300);
  const comoFunciona = ComoFunciona();
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: SizedBox(height: 260, child: pixInfo)),
      const SizedBox(width: 12),
      const Expanded(child: SizedBox(height: 260, child: comoFunciona)),
    ],
  );
}

void main() {
  testWidgets(
    'mobile: card encolhe pro conteudo, sem SizedBox de altura fixa',
    (tester) async {
      tester.view.physicalSize = const Size(1006, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [_rowLadoALado()],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
    },
  );
}
