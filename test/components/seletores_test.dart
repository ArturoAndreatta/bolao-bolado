import 'package:bolao_bolado/components/shared/custom_fields.dart';
import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/core/app_tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Monta a tela com as mesmas localizações e o mesmo tema do app. As
/// localizações não são detalhe de teste: é o GlobalMaterialLocalizations que
/// registra os símbolos de data do `intl` sob o nome 'pt_BR', e é esse nome que
/// o seletor usa para escrever mês e dia da semana. Sem isso ele levanta
/// LocaleDataException ao abrir.
Widget _app(Widget filho) => MaterialApp(
  theme: AppTema.de(AppCores.claro),
  locale: const Locale('pt', 'BR'),
  supportedLocales: const [Locale('pt', 'BR')],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Scaffold(body: Center(child: filho)),
);

/// A janela padrão do flutter_test é 800x600, deitada e baixa — um tamanho que
/// não existe em celular nem em desktop, e onde qualquer folha modal alta
/// estoura. Os testes rodam num retrato de celular comum (a tela mais apertada
/// em que o seletor precisa caber).
void _telaDeCelular(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('CustomDateField', () {
    testWidgets('abre o calendário em português, sem estourar layout', (
      tester,
    ) async {
      _telaDeCelular(tester);
      final controlador = TextEditingController();
      addTearDown(controlador.dispose);

      await tester.pumpWidget(
        _app(
          CustomDateField(
            hint: 'Data do Sorteio',
            controller: controlador,
            initialDate: DateTime(2026, 12, 10),
            firstDate: DateTime(2026),
            lastDate: DateTime(2027),
          ),
        ),
      );
      await tester.tap(find.byType(CustomDateField));
      await tester.pumpAndSettle();

      expect(find.text('Data do sorteio'), findsOneWidget);
      // Mês por extenso vindo do intl com locale pt_BR.
      expect(find.textContaining('ezembro'), findsWidgets);
      // Atalho traduzido pelas opções do app (o pacote traz 'TODAY').
      expect(find.text('Hoje'), findsOneWidget);
    });

    testWidgets('escolher um dia escreve dd/MM/yyyy no campo', (tester) async {
      _telaDeCelular(tester);
      final controlador = TextEditingController();
      addTearDown(controlador.dispose);
      DateTime? avisada;

      await tester.pumpWidget(
        _app(
          CustomDateField(
            hint: 'Data do Sorteio',
            controller: controlador,
            initialDate: DateTime(2026, 12, 10),
            firstDate: DateTime(2026),
            lastDate: DateTime(2027),
            onPicked: (d) => avisada = d,
          ),
        ),
      );
      await tester.tap(find.byType(CustomDateField));
      await tester.pumpAndSettle();

      await tester.tap(find.text('25').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.check_circle_rounded));
      await tester.pumpAndSettle();

      expect(controlador.text, '25/12/2026');
      expect(avisada?.day, 25);
      expect(avisada?.month, 12);
    });
  });

  group('CustomTimeField', () {
    testWidgets('abre o relógio em 24h, sem AM/PM', (tester) async {
      _telaDeCelular(tester);
      final controlador = TextEditingController();
      addTearDown(controlador.dispose);

      await tester.pumpWidget(
        _app(
          CustomTimeField(
            hint: 'Hora do Sorteio',
            controller: controlador,
            initialTime: const TimeOfDay(hour: 20, minute: 30),
          ),
        ),
      );
      await tester.tap(find.byType(CustomTimeField));
      await tester.pumpAndSettle();

      expect(find.text('Horário do sorteio'), findsOneWidget);
      // Regressão: com o viewMode do calendário aplicado também aqui, o
      // relógio abria mostrando um mês inteiro de dias.
      expect(find.text('dom.'), findsNothing);
      expect(find.text('20'), findsWidgets);
      expect(find.text('30'), findsWidgets);
      // Em 12h a roleta traria AM/PM e 20:30 viraria 08:30 — o campo grava
      // HH:mm, então 24h não é preferência e sim proteção contra erro de 12h.
      expect(find.text('AM'), findsNothing);
      expect(find.text('PM'), findsNothing);
    });

    testWidgets('confirmar escreve HH:mm no campo', (tester) async {
      _telaDeCelular(tester);
      final controlador = TextEditingController();
      addTearDown(controlador.dispose);
      TimeOfDay? avisada;

      await tester.pumpWidget(
        _app(
          CustomTimeField(
            hint: 'Hora do Sorteio',
            controller: controlador,
            initialTime: const TimeOfDay(hour: 20, minute: 30),
            onPicked: (t) => avisada = t,
          ),
        ),
      );
      await tester.tap(find.byType(CustomTimeField));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.check_circle_rounded));
      await tester.pumpAndSettle();

      expect(controlador.text, '20:30');
      expect(avisada, const TimeOfDay(hour: 20, minute: 30));
    });
  });
}
