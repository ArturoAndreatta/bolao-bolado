import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/dev/simulador_apostas.dart';
import 'package:bolao_bolado/pages/participants/participants_simulacao_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _montar(SimuladorApostas simulador) => MaterialApp(
  theme: ThemeData(extensions: [AppCores.claro]),
  home: Scaffold(
    body: DialogoSimulacaoApostas(simulador: simulador, salaId: 'sala-teste'),
  ),
);

void main() {
  group('ModoSimulacao', () {
    test('todo modo tem rótulo e descrição preenchidos', () {
      for (final modo in ModoSimulacao.values) {
        expect(modo.rotulo, isNotEmpty, reason: 'rótulo de $modo');
        expect(modo.descricao, isNotEmpty, reason: 'descrição de $modo');
      }
    });

    test('cobre os quatro tipos de simulação pedidos', () {
      expect(ModoSimulacao.values, hasLength(4));
      expect(
        ModoSimulacao.values,
        containsAll([
          ModoSimulacao.inclusoes,
          ModoSimulacao.alteracoes,
          ModoSimulacao.exclusoes,
          ModoSimulacao.aleatorio,
        ]),
      );
    });
  });

  group('MotivoParada', () {
    test('todo motivo tem mensagem para exibir', () {
      for (final motivo in MotivoParada.values) {
        expect(motivo.mensagem, isNotEmpty, reason: 'mensagem de $motivo');
      }
    });
  });

  group('SimuladorApostas', () {
    test('começa parado e no modo aleatório', () {
      final simulador = SimuladorApostas();
      expect(simulador.rodando, isFalse);
      expect(simulador.modo, ModoSimulacao.aleatorio);
    });

    test('parar() não dispara o aviso de parada sozinha', () {
      // O aviso é só para quando a simulação se esgota; parar na mão não
      // pode mostrar "Simulação encerrada" na tela.
      final simulador = SimuladorApostas();
      var avisou = false;
      simulador.aoPararSozinho = (_) => avisou = true;

      simulador.parar();

      expect(avisou, isFalse);
    });
  });

  group('DialogoSimulacaoApostas', () {
    testWidgets('lista os quatro modos', (tester) async {
      await tester.pumpWidget(_montar(SimuladorApostas()));

      for (final modo in ModoSimulacao.values) {
        expect(
          find.text(modo.rotulo),
          findsOneWidget,
          reason: 'modo ${modo.rotulo} deveria aparecer',
        );
      }
    });

    testWidgets('seleciona um modo ao tocar nele', (tester) async {
      await tester.pumpWidget(_montar(SimuladorApostas()));

      await tester.tap(find.text(ModoSimulacao.exclusoes.rotulo));
      await tester.pump();

      final radio = tester.widget<Radio<ModoSimulacao>>(
        find.byWidgetPredicate(
          (w) =>
              w is Radio<ModoSimulacao> && w.value == ModoSimulacao.exclusoes,
        ),
      );
      expect(radio.enabled, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('mostra o aviso quando a simulação para sozinha', (
      tester,
    ) async {
      final simulador = SimuladorApostas();
      await tester.pumpWidget(_montar(simulador));

      // Nenhum aviso antes de acontecer nada.
      expect(find.textContaining('Simulação encerrada'), findsNothing);

      // O simulador avisa que ficou sem alvo (o que aconteceria num ciclo
      // "apenas exclusões" que zerou as apostas fake).
      simulador.aoPararSozinho?.call(MotivoParada.semApostasParaExcluir);
      await tester.pump();

      expect(find.textContaining('Simulação encerrada'), findsOneWidget);
      expect(
        find.textContaining(MotivoParada.semApostasParaExcluir.mensagem),
        findsOneWidget,
      );
    });

    testWidgets('limpa o callback ao ser descartado', (tester) async {
      // Sem isso o simulador (que vive na página, não no diálogo) seguraria
      // um State morto e chamaria setState nele.
      final simulador = SimuladorApostas();
      await tester.pumpWidget(_montar(simulador));
      expect(simulador.aoPararSozinho, isNotNull);

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      expect(simulador.aoPararSozinho, isNull);
    });
  });
}
