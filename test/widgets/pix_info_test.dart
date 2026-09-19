import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/services/pix/pix_payload.dart';
import 'package:bolao_bolado/widgets/pix_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

const _chave = 'pix@bolao.com';

Future<void> montar(WidgetTester tester, {double? valor}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: [AppCores.claro]),
      home: Scaffold(
        body: SizedBox(
          width: 460,
          child: PixInfo(chavePix: _chave, valor: valor),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('no computador mostra o QR code', (tester) async {
    await montar(tester, valor: 12);

    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('Copiar código PIX'), findsNothing);
  }, variant: TargetPlatformVariant.desktop());

  testWidgets(
    'no celular troca o QR pelo Copia e Cola',
    (tester) async {
      await montar(tester, valor: 12);

      expect(find.byType(QrImageView), findsNothing);
      expect(find.text('Copiar código PIX'), findsOneWidget);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets(
    'Copia e Cola copia o código com o valor, não só a chave',
    (tester) async {
      String? copiado;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (chamada) async {
          if (chamada.method == 'Clipboard.setData') {
            copiado = (chamada.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await montar(tester, valor: 12);
      await tester.tap(find.text('Copiar código PIX'));
      await tester.pump();

      expect(copiado, PixPayload.gerar(chave: _chave, valor: 12));
      expect(find.text('Código copiado!'), findsOneWidget);

      // Deixa o timer que volta o rótulo ao normal terminar.
      await tester.pump(const Duration(seconds: 2));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
