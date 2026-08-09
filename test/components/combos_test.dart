import 'package:bolao_bolado/components/shared/combos.dart';
import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/core/app_tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _opcoes = [
  OpcaoCombo('mega', 'Mega-Sena'),
  OpcaoCombo('lotofacil', 'Lotofácil'),
];

Widget _app(Widget filho) => MaterialApp(
  theme: AppTema.de(AppCores.claro),
  home: Scaffold(body: Center(child: filho)),
);

/// Encontra o texto dentro do MENU (o duplicado que aparece depois de abrir),
/// não o rótulo desenhado na casca do combo.
Finder _textoNoMenu(String texto) => find.descendant(
  of: find.byType(PopupMenuItem<String>),
  matching: find.text(texto),
);

void main() {
  group('ComboCampo', () {
    testWidgets('sem valor mostra só o rótulo do campo', (tester) async {
      await tester.pumpWidget(
        _app(
          ComboCampo<String>(
            hint: 'Sorteio',
            valor: null,
            opcoes: _opcoes,
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Sorteio'), findsOneWidget);
      expect(find.text('Mega-Sena'), findsNothing);
    });

    testWidgets('escolher uma opção devolve o valor e marca o check', (
      tester,
    ) async {
      String? escolhido;
      await tester.pumpWidget(
        _app(
          ComboCampo<String>(
            hint: 'Sorteio',
            valor: 'mega',
            opcoes: _opcoes,
            onChanged: (v) => escolhido = v,
          ),
        ),
      );

      // Opção ativa aparece na casca antes mesmo de abrir o menu — era o que
      // faltava no dropdown antigo, que não marcava a selecionada de forma
      // nenhuma.
      expect(find.text('Mega-Sena'), findsOneWidget);

      await tester.tap(find.byType(ComboCampo<String>));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check), findsOneWidget);
      await tester.tap(_textoNoMenu('Lotofácil'));
      await tester.pumpAndSettle();

      expect(escolhido, 'lotofacil');
    });

    testWidgets('menu abre ABAIXO do campo, não por cima dele', (tester) async {
      await tester.pumpWidget(
        _app(
          // Segunda opção selecionada: é exatamente o caso em que o
          // DropdownButton do Material jogava o menu pra cima, alinhando o
          // item ativo com o campo.
          ComboCampo<String>(
            hint: 'Sorteio',
            valor: 'lotofacil',
            opcoes: _opcoes,
            onChanged: (_) {},
          ),
        ),
      );

      final baseDoCampo = tester
          .getBottomLeft(find.byType(ComboCampo<String>))
          .dy;
      await tester.tap(find.byType(ComboCampo<String>));
      await tester.pumpAndSettle();

      final topoDoMenu = tester.getTopLeft(_textoNoMenu('Mega-Sena')).dy;
      expect(topoDoMenu, greaterThan(baseDoCampo));
    });

    testWidgets('validator obrigatório reprova enquanto está vazio', (
      tester,
    ) async {
      final chave = GlobalKey<FormState>();
      await tester.pumpWidget(
        _app(
          Form(
            key: chave,
            child: ComboCampo<String>(
              hint: 'Sorteio',
              valor: null,
              opcoes: _opcoes,
              onChanged: (_) {},
              validator: (v) => v == null ? 'Campo obrigatório' : null,
            ),
          ),
        ),
      );

      expect(chave.currentState!.validate(), isFalse);
    });

    testWidgets('valor trocado por fora passa a valer na validação', (
      tester,
    ) async {
      final chave = GlobalKey<FormState>();
      Widget comValor(String? valor) => _app(
        Form(
          key: chave,
          child: ComboCampo<String>(
            hint: 'Sorteio',
            valor: valor,
            opcoes: _opcoes,
            onChanged: (_) {},
            validator: (v) => v == null ? 'Campo obrigatório' : null,
          ),
        ),
      );

      await tester.pumpWidget(comValor(null));
      // É o caso do formulário carregando uma sala existente: o valor chega
      // depois, sem passar pelo menu. Sem o sincronismo interno, o Form
      // continuaria validando contra o null inicial.
      await tester.pumpWidget(comValor('mega'));
      await tester.pumpAndSettle();

      expect(chave.currentState!.validate(), isTrue);
    });
  });

  group('ComboFiltro', () {
    testWidgets('opção com cor tinge a casca; sem cor fica neutra', (
      tester,
    ) async {
      const cor = Color(0xFF2E7D32);
      Widget combo(Color? corDaOpcao) => _app(
        ComboFiltro<int>(
          selecionado: 0,
          opcoes: [OpcaoCombo(0, 'Verificados', cor: corDaOpcao)],
          onSelecionar: (_) {},
        ),
      );

      await tester.pumpWidget(combo(cor));
      final tingida = tester.widget<Container>(
        // .first é a casca; o Container seguinte é o disco de cor.
        find
            .descendant(
              of: find.byType(ComboFiltro<int>),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(
        (tingida.decoration as BoxDecoration).color,
        cor.withValues(alpha: 0.1),
      );

      await tester.pumpWidget(combo(null));
      await tester.pumpAndSettle();
      final neutra = tester.widget<Container>(
        // .first é a casca; o Container seguinte é o disco de cor.
        find
            .descendant(
              of: find.byType(ComboFiltro<int>),
              matching: find.byType(Container),
            )
            .first,
      );
      expect((neutra.decoration as BoxDecoration).color, AppCores.claro.card);
    });
  });
}
