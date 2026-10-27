import 'dart:async';

import 'package:bolao_bolado/components/shared/buttons.dart';
import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/core/app_radii.dart';
import 'package:bolao_bolado/core/atualizacao_app.dart';
import 'package:flutter/material.dart';

/// Quanto o botão espera o download antes de liberar de qualquer jeito. O
/// aviso não tem outra saída: um botão girando para sempre prenderia a pessoa.
const kPacienciaDownloadVersao = Duration(seconds: 20);

/// O aviso de "versão nova", no meio da tela, com fundo escurecido.
///
/// **Obrigatório de propósito.** Um botão só, "Atualizar agora"; tocar fora,
/// Esc e voltar não fecham. Aviso com saída se ignora, e quem ignora continua
/// apostando e conversando pela versão velha — e aqui a versão velha pode
/// gravar aposta num formato que as regras do Firestore já não aceitam.
///
/// **Abre na descoberta, não no fim do download**, com o botão girando;
/// quando o download termina (ou passa [kPacienciaDownloadVersao]), libera.
///
/// Montado no `builder` do `MaterialApp` ([BolaoBolado]), acima do
/// `Navigator`, para cobrir todas as rotas, login incluso. Por isso não usa
/// `showDialog` (não há contexto de página aqui): desenha a própria barreira
/// e embrulha tudo em `Overlay.wrap`, porque acima do `Navigator` ainda não há
/// `Overlay`.
class AvisoVersaoNova extends StatefulWidget {
  const AvisoVersaoNova({
    required this.child,
    this.ponte = const PonteAtualizacao(),
    super.key,
  });

  /// O app inteiro, que o aviso cobre por cima.
  final Widget child;

  final PonteAtualizacao ponte;

  @override
  State<AvisoVersaoNova> createState() => _AvisoVersaoNovaState();
}

class _AvisoVersaoNovaState extends State<AvisoVersaoNova> {
  /// Existe versão nova (descoberta ou já baixada).
  bool _encontrada = false;

  /// A versão nova terminou de baixar e assumiu.
  bool _pronta = false;

  /// Passou o tempo de espera sem o aviso de pronto: o botão libera.
  bool _cansouDeEsperar = false;

  bool _recarregando = false;
  Timer? _paciencia;
  final _assinaturas = <StreamSubscription<void>>[];

  @override
  void initState() {
    super.initState();
    final ponte = widget.ponte;
    if (!ponte.suportado) return;

    if (ponte.pronta) {
      _encontrada = true;
      _pronta = true;
    } else if (ponte.encontrada) {
      _marcarEncontrada();
    }
    _assinaturas
      ..add(ponte.aoEncontrar.listen((_) => setState(_marcarEncontrada)))
      ..add(
        ponte.aoFicarPronta.listen((_) {
          setState(() {
            _encontrada = true;
            _pronta = true;
          });
        }),
      );
  }

  /// Chamado dentro de `setState` pelo ouvinte, e direto no `initState`.
  void _marcarEncontrada() {
    if (_encontrada) return;
    _encontrada = true;
    _paciencia = Timer(kPacienciaDownloadVersao, () {
      if (mounted) setState(() => _cansouDeEsperar = true);
    });
  }

  @override
  void dispose() {
    for (final assinatura in _assinaturas) {
      unawaited(assinatura.cancel());
    }
    _paciencia?.cancel();
    super.dispose();
  }

  void _recarregar() {
    setState(() => _recarregando = true);
    widget.ponte.recarregar();
  }

  @override
  Widget build(BuildContext context) {
    final movimento = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 280);

    return Overlay.wrap(
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          // Escondido, o filho é um `SizedBox` vazio: não pinta e deixa o
          // toque passar para o app embaixo.
          AnimatedSwitcher(
            duration: movimento,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeOutCubic,
            child: _encontrada
                ? _CaixaVersaoNova(
                    key: const ValueKey('aviso-versao-nova'),
                    ocupado: _recarregando || (!_pronta && !_cansouDeEsperar),
                    movimento: movimento,
                    aoAtualizar: _recarregar,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

/// Barreira e cartão. Só desenho: o estado mora em [AvisoVersaoNova].
class _CaixaVersaoNova extends StatelessWidget {
  const _CaixaVersaoNova({
    required this.ocupado,
    required this.movimento,
    required this.aoAtualizar,
    super.key,
  });

  /// Download em curso ou recarga já pedida: o botão gira e não aceita toque.
  final bool ocupado;
  final Duration movimento;
  final VoidCallback aoAtualizar;

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);

    // `PopScope` segura o voltar do Android e o Esc do teclado, que chegam
    // como pedido de pop ao `Navigator` embaixo.
    return PopScope(
      canPop: false,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Engole o toque (tocar fora não fecha) e esconde o app do leitor
          // de tela enquanto o aviso está de pé.
          BlockSemantics(
            child: ModalBarrier(
              color: cores.sombra.withValues(alpha: 0.55),
              dismissible: false,
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  // Cresce um pouco ao entrar, junto do fade do
                  // `AnimatedSwitcher`: o aviso chega, não aparece.
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.92, end: 1),
                    duration: movimento,
                    curve: Curves.easeOutCubic,
                    builder: (context, escala, child) =>
                        Transform.scale(scale: escala, child: child),
                    // Acima do `Navigator` não há `Material`: sem ele o
                    // `Text` herda o estilo de erro do `WidgetsApp`
                    // (sublinhado amarelo).
                    child: Material(
                      color: cores.card,
                      elevation: 18,
                      shadowColor: cores.sombra,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadii.circularXxl,
                        side: BorderSide(color: cores.borda),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Bloco de ícone na cor de AÇÃO do tema, a mesma
                            // do botão logo abaixo. Com o par azul da paleta
                            // (fundoAzul/bordaAzul) ele destoava nos temas
                            // cujo CTA não é azul: no Cyber virava um
                            // quadrado azul apagado ao lado de um botão
                            // magenta. A bola do 7 também foi tentada aqui e
                            // repetia a marca que já está na barra de cima.
                            // Tinta a 18% e borda a 45%: a faixa em que o
                            // alphaBlend ainda recorta sobre o card nos
                            // temas escuros (ver CLAUDE.md, cores).
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: Color.alphaBlend(
                                  cores.acaoPrimaria.withValues(alpha: 0.18),
                                  cores.card,
                                ),
                                borderRadius: AppRadii.circularLg,
                                border: Border.all(
                                  color: cores.acaoPrimaria.withValues(
                                    alpha: 0.45,
                                  ),
                                ),
                              ),
                              // Desenhado à mão, e não com `Icon`: o ícone do
                              // Material vem de uma fonte que o build monta só
                              // com os glifos usados, e este aviso é
                              // justamente o que aparece na fronteira entre
                              // duas versões. O código velho na tela pode
                              // acabar com a fonte de outro build (cópia velha
                              // no cache, ou a do worker novo que assumiu no
                              // meio da subida), e aí o glifo some e sobra o
                              // quadrado vazio, uma vez sim, outra não. Um
                              // desenho no próprio código não depende de
                              // arquivo nenhum.
                              child: CustomPaint(
                                size: const Size.square(28),
                                painter: _SetaDownload(cores.acaoPrimaria),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Versão nova!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: cores.texto,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Atualize antes de qualquer ação.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                height: 1.35,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: cores.textoSuave,
                              ),
                            ),
                            const SizedBox(height: 22),
                            Semantics(
                              button: true,
                              enabled: !ocupado,
                              label: ocupado
                                  ? 'Baixando a versão nova'
                                  : 'Atualizar agora',
                              excludeSemantics: true,
                              child: PrimaryButton(
                                text: 'Atualizar agora',
                                width: double.infinity,
                                compact: false,
                                loading: ocupado,
                                onTap: aoAtualizar,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A seta de download (seta para baixo sobre uma bandeja), no traço do
/// `download_rounded` do Material: linhas de ponta redonda numa caixa de 24,
/// escalada para o tamanho pedido. Ver o comentário em [_CaixaVersaoNova] para
/// o porquê de não usar a fonte de ícones aqui.
class _SetaDownload extends CustomPainter {
  const _SetaDownload(this.cor);

  final Color cor;

  @override
  void paint(Canvas canvas, Size size) {
    final escala = size.shortestSide / 24;
    canvas.scale(escala);
    final traco = Paint()
      ..color = cor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas
      // Haste da seta.
      ..drawLine(const Offset(12, 4), const Offset(12, 15), traco)
      // Ponta.
      ..drawPath(
        Path()
          ..moveTo(7, 10.5)
          ..lineTo(12, 15.5)
          ..lineTo(17, 10.5),
        traco,
      )
      // Bandeja.
      ..drawLine(const Offset(5.5, 19.5), const Offset(18.5, 19.5), traco);
  }

  @override
  bool shouldRepaint(_SetaDownload antigo) => antigo.cor != cor;
}
