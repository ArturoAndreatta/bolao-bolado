import 'package:bolao_bolado/widgets/pix_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// Réplica da técnica de _alturaDe em MinhaApostaCard (que é privado): mede a
// altura de um widget fora da árvore visível. Se esta medição quebrar, a do
// card quebra junto e o Pix silenciosamente para de esticar.
class _RaizDeMedicao extends RenderBox
    with RenderObjectWithChildMixin<RenderBox> {
  _RaizDeMedicao({required this.largura});

  final double largura;

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => Size(largura, 0);

  @override
  void performLayout() {
    child?.layout(BoxConstraints(maxWidth: largura), parentUsesSize: true);
  }

  @override
  void paint(PaintingContext context, Offset offset) {}
}

double _alturaDe(BuildContext context, Widget widget, double largura) {
  final pipelineOwner = PipelineOwner();
  final buildOwner = BuildOwner(focusManager: FocusManager());
  final raiz = _RaizDeMedicao(largura: largura);
  final elemento = RenderObjectToWidgetAdapter<RenderBox>(
    container: raiz,
    child: Directionality(
      textDirection: Directionality.of(context),
      child: MediaQuery(
        data: MediaQuery.of(context),
        child: Theme(data: Theme.of(context), child: widget),
      ),
    ),
  ).attachToRenderTree(buildOwner);
  buildOwner
    ..buildScope(elemento)
    ..finalizeTree();
  pipelineOwner.rootNode = raiz;
  raiz.scheduleInitialLayout();
  pipelineOwner.flushLayout();
  final medido = raiz.child;
  return medido == null || !medido.hasSize ? 0 : medido.size.height;
}

void main() {
  testWidgets('PixInfo cresce proporcionalmente com escala', (tester) async {
    tester.view.physicalSize = const Size(500, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    late double alturaNormal;
    late double alturaEsticada;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              alturaNormal = _alturaDe(
                context,
                const PixInfo(chavePix: 'teste@exemplo.com', valor: 300),
                420,
              );
              alturaEsticada = _alturaDe(
                context,
                const PixInfo(
                  chavePix: 'teste@exemplo.com',
                  valor: 300,
                  escala: 1.4,
                ),
                420,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    // A medição fora da árvore precisa devolver algo útil (é dela que sai a
    // escala; zero faria o card cair silenciosamente no tamanho antigo).
    expect(alturaNormal, greaterThan(0));
    // Escala maior => card mais alto. Não se exige proporção exata: quem
    // fecha a folga é a busca binária de MinhaApostaCard, que mede a altura
    // real a cada passo justamente porque ela não é linear na escala.
    expect(alturaEsticada, greaterThan(alturaNormal));
  });

  // A busca binária de MinhaApostaCard é o que fecha a folga; aqui se replica
  // o laço sobre o PixInfo isolado para garantir que ele converge — ou seja,
  // que existe escala capaz de preencher um alvo maior que a altura natural.
  testWidgets('busca binária acha escala que preenche a folga', (tester) async {
    tester.view.physicalSize = const Size(500, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    late double alturaFinal;
    late double alvo;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              const chave = 'arturoandreatta@gmail.com';
              Widget pix(double escala) =>
                  PixInfo(chavePix: chave, valor: 108, escala: escala);

              final natural = _alturaDe(context, pix(1), 420);
              // Folga hipotética de 60px acima do card, como a da tela real.
              alvo = natural + 60;

              var min = 1.0;
              var max = 1.6;
              for (var i = 0; i < 6; i++) {
                final meio = (min + max) / 2;
                if (_alturaDe(context, pix(meio), 420) <= alvo) {
                  min = meio;
                } else {
                  max = meio;
                }
              }
              alturaFinal = _alturaDe(context, pix(min), 420);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    // Nunca ultrapassa o alvo (senão o card empurraria o conteúdo e criaria
    // scroll onde antes não havia)...
    expect(alturaFinal, lessThanOrEqualTo(alvo));
    // ...e chega perto o bastante dele para a folga sumir de fato.
    expect(alturaFinal, greaterThan(alvo - 25));
  });

  // Documenta a armadilha que fez o Pix não esticar: medir fora da árvore um
  // widget cuja GlobalKey já está montada devolve altura ABSURDA em vez de
  // lançar exceção. Por isso o bloco de campos (que tem _formKey/FocusNodes)
  // é medido pelo layout real (_MedidorDeAltura), e só o bloco Pix — sem
  // estado compartilhado — passa por _alturaDe.
  testWidgets('medir widget com GlobalKey montada devolve lixo', (
    tester,
  ) async {
    final chave = GlobalKey();
    late double altura;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SizedBox(key: chave, height: 40, child: const Text('montado')),
              Builder(
                builder: (context) {
                  altura = _alturaDe(
                    context,
                    SizedBox(key: chave, height: 40, child: const Text('x')),
                    400,
                  );
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ),
    );

    // A duplicação de GlobalKey também reporta erro ao framework de teste;
    // consome-se aqui para o teste não falhar por causa dele. Em produção
    // esse mesmo erro é engolido pelo try/catch de _alturaDe — o que torna a
    // altura inválida silenciosa, e é exatamente o ponto deste teste.
    expect(tester.takeException(), isNotNull);
    // Se algum dia o Flutter passar a medir certo aqui, este expect quebra e
    // o _MedidorDeAltura pode ser reavaliado.
    expect(altura, isNot(closeTo(40, 1)));
  });

  testWidgets('PixInfo com escala renderiza sem overflow', (tester) async {
    tester.view.physicalSize = const Size(500, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: PixInfo(
              chavePix: 'arturoandreatta@gmail.com',
              valor: 108,
              escala: 1.5,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Copiar chave PIX'), findsOneWidget);
  });
}
