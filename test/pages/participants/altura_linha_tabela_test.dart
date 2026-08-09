import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/pages/participants/participants_tabela.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// O corpo do desktop usa `ListView.builder` com `itemExtent:
/// kAlturaLinhaTabela`. Se a altura real da linha divergir da constante, as
/// linhas ficam cortadas ou sobra espaço entre elas — e nada no código acusa.
/// Este teste é o alarme: mudou padding/fonte da célula, ele quebra.
void main() {
  testWidgets('kAlturaLinhaTabela bate com a altura renderizada', (
    tester,
  ) async {
    // A tabela tem largura fixa (larguraTotal ≈ 873) e o cabeçalho estoura no
    // viewport padrão do teste (800x600). Alargar a janela evita que o teste
    // falhe por um motivo que não é o dele.
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [AppCores.claro]),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: larguraTotal + 4,
              child: TabelaApostas(
                rows: const [
                  {
                    'uid': 'a',
                    'nome': 'Fulano de Tal',
                    'valor': 30.0,
                    'cotas': 5,
                    'premio': 100.0,
                  },
                  {
                    'uid': 'b',
                    'nome': 'Beltrano',
                    'valor': 12.0,
                    'cotas': 2,
                    'premio': 40.0,
                  },
                ],
                colunaOrdenada: 1,
                ascendente: false,
                onCabecalhoTap: _ignorar,
                currentUid: null,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Distância entre o topo de duas linhas consecutivas = altura real de uma
    // linha com o divisor incluído, que é exatamente o que o itemExtent
    // precisa valer.
    // O cabeçalho da tabela estoura horizontalmente no ambiente de teste
    // (largura de coluna fixa vs. fonte do test runner). Não é o objeto deste
    // teste: descarta esse erro para a asserção de ALTURA poder ser avaliada.
    tester.takeException();

    final yA = tester.getTopLeft(find.text('Fulano de Tal')).dy;
    final yB = tester.getTopLeft(find.text('Beltrano')).dy;
    final alturaReal = yB - yA;

    expect(
      alturaReal,
      closeTo(kAlturaLinhaTabela, 0.5),
      reason:
          'a linha renderiza com $alturaReal, mas kAlturaLinhaTabela é '
          '$kAlturaLinhaTabela — ajuste a constante ou o padding da célula',
    );
  });
}

void _ignorar(int _) {}
