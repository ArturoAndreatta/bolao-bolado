import 'dart:ui' as ui;

import 'package:bolao_bolado/components/shell/default_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// MAIOR caixa do logo na AppBar, em pixels de layout — a do desktop (a do
/// celular é menor, e portanto menos exigente). Multiplicada pelo
/// devicePixelRatio, é quantos pixels REAIS a arte precisa ter pra sair
/// nítida.
///
/// Sai da constante do layout, e não de um número escrito aqui: encolher o
/// logo é mudança legítima, e o que não pode acontecer junto é a arte deixar
/// de cobrir a caixa nova. Repetir o valor à mão fazia o teste quebrar por
/// estar desatualizado, e não por ter achado o problema.
const double _alturaCaixa = DefaultLayout.alturaLogoDesktop;

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
  // também, o logo continuou do mesmo tamanho mas a barra engordou de 56
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

  testWidgets('no desktop a barra acomoda o logo sem crescer', (tester) async {
    final appBar = await appBarEm(tester, 1440);
    expect(alturaDaCaixaDoLogo(tester), DefaultLayout.alturaLogoDesktop);
    expect(
      appBar.toolbarHeight,
      greaterThan(DefaultLayout.alturaLogoDesktop),
      reason: 'barra menor que o logo recorta o logo em cima e embaixo',
    );
    // 74 é escrito à mão de propósito, e é o único número deste arquivo que
    // não vem do layout: ele não descreve o logo, descreve o quanto a barra
    // pode ocupar da janela. Encolher o logo e deixar a barra encolher junto
    // não quebra nada visualmente, mas AUMENTAR aqui empurra o conteudo e faz
    // nascer o scroll de poucos pixels que ja apareceu em tela de notebook —
    // que e a regressao que este numero existe pra travar.
    expect(
      appBar.toolbarHeight,
      lessThanOrEqualTo(74),
      reason:
          'a barra do desktop passou de 74px: o excedente empurra o conteudo '
          'da pagina ate nascer scroll em tela de notebook',
    );
  });

  testWidgets('no celular a barra fica na altura padrão', (tester) async {
    final appBar = await appBarEm(tester, 500);
    expect(alturaDaCaixaDoLogo(tester), DefaultLayout.alturaLogoCompacto);
    expect(
      DefaultLayout.alturaLogoCompacto,
      lessThanOrEqualTo(kToolbarHeight),
      reason:
          'logo maior que o padrão do Material sai recortado, porque no '
          'celular a barra não recebe altura própria',
    );
    expect(
      appBar.toolbarHeight,
      isNull,
      reason:
          'null é o que deixa a AppBar no padrão (56) do Material; qualquer '
          'valor aqui engorda a barra do celular sem o logo crescer',
    );
  });

  // Telas que travam a altura do conteúdo na janela (o painel admin faz isso)
  // descontam a AppBar por DefaultLayout.alturaAppBar. Enquanto esse desconto
  // era kToolbarHeight (56) e a barra do desktop já valia 74, os 18px de
  // diferença sobravam para fora da janela e a página ganhava scroll — sem
  // que nada no logo tivesse mudado. Este teste amarra as duas pontas: o
  // número que a barra mede e o número que as telas descontam.
  testWidgets('alturaAppBar bate com a barra que o layout monta', (
    tester,
  ) async {
    for (final largura in <double>[500, 1440]) {
      late double descontada;
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = Size(largura, 900);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              descontada = DefaultLayout.alturaAppBar(context);
              return DefaultLayout(
                drawer: const Drawer(),
                child: const SizedBox(),
              );
            },
          ),
        ),
      );

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(
        appBar.toolbarHeight ?? kToolbarHeight,
        descontada,
        reason:
            'em $largura de largura a barra montada e o valor que as telas '
            'descontam da janela divergem — a diferença vira scroll',
      );
    }
  });
}
