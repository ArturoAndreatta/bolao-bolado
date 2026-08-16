import 'dart:ui' as ui;

import 'package:bolao_bolado/components/shell/default_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// MAIOR caixa do logo na AppBar, em pixels de layout — a do desktop, o mesmo
/// número de `DefaultLayout` (no celular a caixa é 54, que é menos exigente).
/// Multiplicada pelo devicePixelRatio, é quantos pixels REAIS a arte precisa
/// ter pra sair nítida.
const double _alturaCaixa = 72;

/// O logo da AppBar já saiu borrado no desktop uma vez: existia um arquivo só,
/// de 160px de altura, feito pro celular (onde o DPR 3 rende 162). Num monitor
/// comum, de DPR 1, o app tinha que encolher aquilo pros 54 pixels da caixa, e
/// o traço fino não sobrevivia. O conserto foi a caixa maior no desktop mais
/// as variantes de resolução ao lado do arquivo, uma pra cada DPR.
///
/// O que este teste protege é o elo fácil de quebrar sem perceber: apagar ou
/// renomear um `Nx/logo_appbar.png` não quebra build nem análise — o Flutter
/// só cai calado numa variante menor, e a tela volta a borrar.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<int> alturaEmPixels(String chave) async {
    final bytes = await rootBundle.load(chave);
    final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
    final quadro = await codec.getNextFrame();
    final altura = quadro.image.height;
    quadro.image.dispose();
    codec.dispose();
    return altura;
  }

  // 1.0 é o caso que gerou o bug (monitor comum); 1.25 e 1.5 são o Windows com
  // escala de tela ligada; 2 e 3 são telas retina e celular.
  for (final dpr in <double>[1.0, 1.25, 1.5, 2.0, 3.0]) {
    test('em dpr $dpr a variante escolhida cobre a caixa do logo', () async {
      final chave = await const AssetImage(
        'images/logo_appbar.png',
      ).obtainKey(ImageConfiguration(devicePixelRatio: dpr));

      final necessario = (_alturaCaixa * dpr).ceil();
      expect(
        await alturaEmPixels(chave.name),
        greaterThanOrEqualTo(necessario),
        reason:
            'em dpr $dpr a AppBar desenha $necessario pixels de altura, mas '
            '${chave.name} tem menos que isso — o Flutter vai ampliar a arte '
            'e o logo sai borrado',
      );
    });
  }

  // A caixa maior é só do desktop. Quando ela passou a valer no celular
  // também, o logo continuou do mesmo tamanho (54) mas a barra engordou de 56
  // pra 66, e a tela toda desceu — regressão silenciosa, que só apareceu
  // porque o usuário reparou. Daí os dois casos abaixo.
  Future<AppBar> appBarEm(WidgetTester tester, double largura) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(largura, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: DefaultLayout(drawer: const Drawer(), child: const SizedBox()),
      ),
    );
    return tester.widget<AppBar>(find.byType(AppBar));
  }

  double alturaDaCaixaDoLogo(WidgetTester tester) {
    final caixa = find
        .ancestor(of: find.byType(Image), matching: find.byType(SizedBox))
        .first;
    return tester.widget<SizedBox>(caixa).height!;
  }

  testWidgets('no desktop a barra cresce junto com o logo', (tester) async {
    final appBar = await appBarEm(tester, 1440);
    expect(alturaDaCaixaDoLogo(tester), 72);
    expect(
      appBar.toolbarHeight,
      80,
      reason: 'barra menor que o logo recorta o logo em cima e embaixo',
    );
  });

  testWidgets('no celular a barra fica na altura padrão', (tester) async {
    final appBar = await appBarEm(tester, 500);
    expect(alturaDaCaixaDoLogo(tester), 54);
    expect(
      appBar.toolbarHeight,
      isNull,
      reason:
          'null é o que deixa a AppBar no padrão (56) do Material; qualquer '
          'valor aqui engorda a barra do celular sem o logo crescer',
    );
  });
}
