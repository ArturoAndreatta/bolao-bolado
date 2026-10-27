import 'package:bolao_bolado/core/app_cores.dart';
import 'package:flutter/material.dart';

/// Texto de uma célula que anima a TROCA quando a aposta é editada: o texto
/// antigo sai pelo alto, o novo entra por baixo (ou o contrário, quando o
/// valor desce), e um realce na cor de linha nova acende atrás e se apaga.
///
/// É a encenação da EDIÇÃO, de propósito bem menor que a da chegada (ver
/// `LinhaEntrandoAnimada`): quem editou continua na mesma linha, só a
/// informação dela mudou, então só a célula que mudou se mexe. Animar a linha
/// inteira, como acontecia antes, fazia uma edição parecer uma aposta nova.
///
/// O disparo vem de [anterior], que a tela só preenche no quadro em que a
/// edição chegou (ver `RastreadorDeLinhas.mudancaDe`). Por isso este widget
/// não reage a qualquer troca de [texto]: rebuild por outro motivo — tema,
/// busca, reemissão do servidor — não anima nada.
class TextoAlterado extends StatefulWidget {
  final String texto;

  /// O que a célula mostrava antes da edição deste quadro. Não-nulo = a
  /// edição acabou de chegar e a troca deve ser encenada.
  final String? anterior;

  /// O texto novo entra por baixo e empurra o antigo para cima. Falso no
  /// valor que DESCEU: aí o movimento se inverte, como um contador voltando.
  final bool subindo;

  /// Monta o texto — a célula decide fonte, cor, alinhamento e reticências,
  /// e os dois textos da troca saem iguais ao que ela desenha parada.
  final Widget Function(String texto) construir;

  /// Quanto o realce passa das bordas do texto, para não colar nas letras.
  final EdgeInsets folgaRealce;

  const TextoAlterado({
    super.key,
    required this.texto,
    required this.construir,
    this.anterior,
    this.subindo = true,
    this.folgaRealce = const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
  });

  @override
  State<TextoAlterado> createState() => _TextoAlteradoState();
}

class _TextoAlteradoState extends State<TextoAlterado>
    with SingleTickerProviderStateMixin {
  static const _duracao = Duration(milliseconds: 1100);

  // Criado sob demanda: quase toda célula passa a vida sem ser editada, e a
  // tabela tem duas destas por linha visível. Nada de `late final` com
  // inicializador — ele seria criado no dispose() da célula que nunca
  // animou, e montar ticker em elemento desativado lança.
  AnimationController? _controller;

  // Texto que está SAINDO na troca em andamento. Null fora da animação.
  String? _saindo;
  bool _subindo = true;

  @override
  void initState() {
    super.initState();
    // A célula pode nascer já editada: a linha editada que sobe de uma
    // posição fora da tela para dentro dela é montada do zero neste quadro.
    final anterior = widget.anterior;
    if (anterior != null && anterior != widget.texto) {
      _iniciar(anterior);
    }
  }

  @override
  void didUpdateWidget(covariant TextoAlterado oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.anterior != null && widget.texto != oldWidget.texto) {
      // Parte do texto que estava NA TELA, e não do `anterior` informado:
      // se duas edições chegarem em sequência, a troca continua de onde o
      // usuário está vendo, sem piscar um valor intermediário.
      _iniciar(oldWidget.texto);
    }
  }

  void _iniciar(String de) {
    _saindo = de;
    _subindo = widget.subindo;
    final controller = _controller ??= AnimationController(
      vsync: this,
      duration: _duracao,
    )..addStatusListener(_aoTerminar);
    controller.forward(from: 0);
  }

  void _aoTerminar(AnimationStatus status) {
    // Volta ao caminho barato (só o texto) quando a troca termina, em vez de
    // manter Stack, recorte e realce transparente montados para sempre.
    if (status == AnimationStatus.completed && mounted) {
      setState(() => _saindo = null);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final saindo = _saindo;
    final atual = widget.construir(widget.texto);
    if (controller == null || saindo == null) return atual;

    final corRealce = AppCores.de(context).linhaNova;
    // Com redução de movimento, a troca vira só um cruzamento de opacidade:
    // o realce continua dizendo "isto mudou", sem nada se deslocar.
    final semMovimento = MediaQuery.disableAnimationsOf(context);
    final sentido = _subindo ? 1.0 : -1.0;
    final antigo = widget.construir(saindo);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        // A troca ocupa o começo (~380ms) e termina com o realce ainda
        // aceso: o olho vê o número novo assentar ANTES de a cor sair.
        final troca = Curves.easeOutCubic.transform((t / 0.35).clamp(0.0, 1.0));
        // Acende rápido (~110ms) e apaga devagar.
        final realce = t < 0.1
            ? Curves.easeOut.transform(t / 0.1)
            : 1 - Curves.easeInOutCubic.transform((t - 0.1) / 0.9);
        final passo = semMovimento ? 0.0 : 0.7 * sentido;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: -widget.folgaRealce.left,
              right: -widget.folgaRealce.right,
              top: -widget.folgaRealce.top,
              bottom: -widget.folgaRealce.bottom,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: corRealce.withValues(alpha: realce),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            // O recorte é a "janela" da célula: o texto que sai e o que entra
            // somem na borda dela em vez de invadir a linha de cima ou de
            // baixo.
            ClipRect(
              child: Stack(
                children: [
                  // O novo é quem dá o tamanho; o antigo corre por cima dele.
                  FractionalTranslation(
                    translation: Offset(0, passo * (1 - troca)),
                    child: Opacity(opacity: troca, child: atual),
                  ),
                  if (troca < 1)
                    Positioned.fill(
                      child: FractionalTranslation(
                        translation: Offset(0, -passo * troca),
                        child: Opacity(opacity: 1 - troca, child: antigo),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
