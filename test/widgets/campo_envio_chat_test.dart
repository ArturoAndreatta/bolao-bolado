import 'package:bolao_bolado/widgets/chat/campo_envio_chat.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Monta só o rodapé do chat, com a lista de menção aberta ou fechada.
///
/// O widget do chat inteiro depende de Firebase; o rodapé não, e é nele que
/// mora o comportamento de teclado do autocomplete.
Widget _montar({
  required bool sugestoesAbertas,
  required TextEditingController controller,
  required FocusNode focusNode,
  VoidCallback? onEnviar,
  VoidCallback? onSubir,
  VoidCallback? onDescer,
  VoidCallback? onFechar,
}) {
  return MaterialApp(
    home: Scaffold(
      body: CampoEnvioChat(
        verificandoPermissao: false,
        podeEnviar: true,
        controller: controller,
        focusNode: focusNode,
        onEnviar: onEnviar ?? () {},
        sugestoesAbertas: sugestoesAbertas,
        onSubir: onSubir ?? () {},
        onDescer: onDescer ?? () {},
        onFechar: onFechar ?? () {},
      ),
    ),
  );
}

void main() {
  testWidgets('o botão de enviar é sempre o avião, sem estado de carregando', (
    tester,
  ) async {
    // A escrita cai no cache local e a bolha aparece na hora; um spinner
    // anunciava uma espera que não existe, e fazia o ícone sumir e voltar a
    // cada mensagem enviada.
    final controller = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      _montar(
        sugestoesAbertas: false,
        controller: controller,
        focusNode: focusNode,
      ),
    );

    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('o campo NÃO é remontado ao abrir e fechar as sugestões', (
    tester,
  ) async {
    // Regressão: os atalhos de teclado eram montados só com a lista aberta, o
    // que trocava o pai do TextField. O elemento era descartado e recriado, e
    // o campo ficava vivo na tela mas surdo — depois de aceitar a menção com
    // Tab não dava mais para digitar nem apagar.
    final controller = TextEditingController(text: 'oi @an');
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      _montar(
        sugestoesAbertas: false,
        controller: controller,
        focusNode: focusNode,
      ),
    );
    final estadoInicial = tester.state(find.byType(EditableText));

    await tester.pumpWidget(
      _montar(
        sugestoesAbertas: true,
        controller: controller,
        focusNode: focusNode,
      ),
    );
    expect(
      tester.state(find.byType(EditableText)),
      same(estadoInicial),
      reason: 'abrir a lista não pode recriar o campo',
    );

    await tester.pumpWidget(
      _montar(
        sugestoesAbertas: false,
        controller: controller,
        focusNode: focusNode,
      ),
    );
    expect(
      tester.state(find.byType(EditableText)),
      same(estadoInicial),
      reason: 'fechar a lista (aceitar a menção) não pode recriar o campo',
    );
  });

  testWidgets('digitar e apagar continuam funcionando depois da menção', (
    tester,
  ) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      _montar(
        sugestoesAbertas: false,
        controller: controller,
        focusNode: focusNode,
      ),
    );
    await tester.enterText(find.byType(TextField), 'oi @an');

    // Lista abre...
    await tester.pumpWidget(
      _montar(
        sugestoesAbertas: true,
        controller: controller,
        focusNode: focusNode,
      ),
    );
    // ...e fecha, como quando a sugestão é aceita.
    await tester.pumpWidget(
      _montar(
        sugestoesAbertas: false,
        controller: controller,
        focusNode: focusNode,
      ),
    );

    await tester.enterText(find.byType(TextField), 'oi @Ana Paula');
    expect(controller.text, 'oi @Ana Paula');
    await tester.enterText(find.byType(TextField), 'oi @Ana Paul');
    expect(controller.text, 'oi @Ana Paul');
  });

  group('atalhos', () {
    testWidgets('setas e Esc só respondem com a lista aberta', (tester) async {
      final controller = TextEditingController(text: 'oi @an');
      final focusNode = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      var desceu = 0;
      var subiu = 0;
      var fechou = 0;

      await tester.pumpWidget(
        _montar(
          sugestoesAbertas: true,
          controller: controller,
          focusNode: focusNode,
          onSubir: () => subiu++,
          onDescer: () => desceu++,
          onFechar: () => fechou++,
        ),
      );
      focusNode.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect([desceu, subiu, fechou], [1, 1, 1]);

      await tester.pumpWidget(
        _montar(
          sugestoesAbertas: false,
          controller: controller,
          focusNode: focusNode,
          onSubir: () => subiu++,
          onDescer: () => desceu++,
          onFechar: () => fechou++,
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(
        [desceu, subiu, fechou],
        [1, 1, 1],
        reason: 'com a lista fechada as teclas voltam a ser do campo de texto',
      );
    });

    testWidgets('Tab aceita a sugestão em vez de pular de campo', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'oi @an');
      final focusNode = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      var aceitou = 0;
      await tester.pumpWidget(
        _montar(
          sugestoesAbertas: true,
          controller: controller,
          focusNode: focusNode,
          onEnviar: () => aceitou++,
        ),
      );
      focusNode.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(aceitou, 1);
      expect(
        focusNode.hasFocus,
        isTrue,
        reason: 'o foco continua no campo depois do Tab',
      );
    });
  });
}
