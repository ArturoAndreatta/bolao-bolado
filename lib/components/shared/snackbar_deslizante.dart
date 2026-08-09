// Notificação que entra deslizando de baixo e sai deslizando para baixo.
//
// NÃO usa SnackBar. A primeira versão disto envolvia o `content` do SnackBar
// num SlideTransition, e o resultado era visivelmente errado: o Material
// continua rodando a transição DELE por fora (fade + heightFactor), então na
// saída o texto descia primeiro e a barra colorida ficava para trás — duas
// animações independentes disputando o mesmo elemento.
//
// Animar a barra inteira exigiria controlar a animação do SnackBar, e isso o
// Material não permite: o ScaffoldMessenger reatribui a animação ao enfileirar
// (`SnackBar.withAnimation`, scaffold.dart), descartando qualquer `animation`
// passada de fora, e não expõe a interna ao conteúdo.
//
// Com um OverlayEntry próprio a barra inteira — fundo, texto e ação — é um só
// widget nosso, e um único controller move tudo junto.

import 'dart:async';

import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/core/app_radii.dart';
import 'package:flutter/material.dart';

/// Entrada: 420ms com desaceleração forte dá tempo do olho pegar o movimento
/// sem parecer arrastado.
const Duration _duracaoEntrada = Duration(milliseconds: 420);

/// Saída: mesma duração da entrada. Encurtá-la (a primeira versão usava
/// 280ms) parecia atalho — a barra ia embora antes de o olho acompanhar o
/// trajeto de volta. Simétrico, o movimento lê como o mesmo gesto desfeito.
const Duration _duracaoSaida = _duracaoEntrada;

/// Quanto tempo a barra fica parada, legível, entre entrar e sair.
const Duration _tempoDeLeitura = Duration(seconds: 4);

/// Controla uma notificação já visível.
class NotificacaoDeslizante {
  final VoidCallback fechar;
  const NotificacaoDeslizante._(this.fechar);
}

/// Mostra [conteudo] numa barra que sobe de baixo, aguarda a leitura e desce.
///
/// [aoDesfazer], quando informado, vira um botão "Desfazer" que fecha a barra
/// antes de executar a ação.
NotificacaoDeslizante mostrarSnackBarDeslizante(
  BuildContext context, {
  required Widget conteudo,
  required Color corFundo,
  String? rotuloAcao,
  VoidCallback? aoDesfazer,
  Duration tempoDeLeitura = _tempoDeLeitura,
}) {
  final overlay = Overlay.of(context);

  // Uma notificação por vez: marcando várias apostas em sequência, as barras
  // se empilhariam sobrepostas no rodapé.
  _atual?.call();

  late OverlayEntry entrada;
  final chave = GlobalKey<_BarraDeslizanteState>();

  void remover() {
    if (entrada.mounted) entrada.remove();
    if (_atual == remover) _atual = null;
  }

  void fechar() => chave.currentState?.sair() ?? remover();

  entrada = OverlayEntry(
    builder: (_) => _BarraDeslizante(
      key: chave,
      corFundo: corFundo,
      tempoDeLeitura: tempoDeLeitura,
      rotuloAcao: rotuloAcao,
      aoDesfazer: aoDesfazer,
      aoTerminar: remover,
      child: conteudo,
    ),
  );

  _atual = fechar;
  overlay.insert(entrada);
  return NotificacaoDeslizante._(fechar);
}

/// Fecha a notificação em exibição, se houver.
VoidCallback? _atual;

class _BarraDeslizante extends StatefulWidget {
  final Widget child;
  final Color corFundo;
  final String? rotuloAcao;
  final VoidCallback? aoDesfazer;
  final VoidCallback aoTerminar;
  final Duration tempoDeLeitura;

  const _BarraDeslizante({
    super.key,
    required this.child,
    required this.corFundo,
    required this.rotuloAcao,
    required this.aoDesfazer,
    required this.aoTerminar,
    required this.tempoDeLeitura,
  });

  @override
  State<_BarraDeslizante> createState() => _BarraDeslizanteState();
}

class _BarraDeslizanteState extends State<_BarraDeslizante>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controlador = AnimationController(
    vsync: this,
    duration: _duracaoEntrada,
    reverseDuration: _duracaoSaida,
  );

  // easeOutCubic desacelerando até parar: a barra chega "pesando" no fim do
  // trajeto em vez de travar seco. Overshoot (easeOutBack) foi testado e
  // descartado — num elemento que carrega texto, o repique atrapalha a
  // leitura logo no momento em que ela começa.
  late final Animation<Offset> _posicao =
      Tween<Offset>(begin: const Offset(0, 1.4), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _controlador,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        ),
      );

  // O fade fica na frente do deslize na entrada (termina em 60% do trajeto)
  // para a barra já estar legível enquanto ainda se acomoda; na saída ele
  // atrasa, para o movimento ser percebido antes de a barra sumir.
  late final Animation<double> _opacidade = CurvedAnimation(
    parent: _controlador,
    curve: const Interval(0, 0.6, curve: Curves.easeOut),
    reverseCurve: const Interval(0.4, 1, curve: Curves.easeIn),
  );

  // Timer guardado (e não `Future.delayed`): o usuário pode fechar a barra ou
  // sair da tela durante a leitura, e uma espera não cancelável seguiria viva
  // depois do widget morrer.
  Timer? _esperaLeitura;

  @override
  void initState() {
    super.initState();
    _entrar();
  }

  Future<void> _entrar() async {
    await _controlador.forward();
    if (!mounted) return;
    _esperaLeitura = Timer(widget.tempoDeLeitura, sair);
  }

  /// Roda a saída e só então remove do overlay.
  Future<void> sair() async {
    _esperaLeitura?.cancel();
    if (!mounted) return;
    await _controlador.reverse();
    if (!mounted) return;
    widget.aoTerminar();
  }

  @override
  void dispose() {
    _esperaLeitura?.cancel();
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    final media = MediaQuery.of(context);
    // Acompanha o rodapé do sistema (barra de gestos no Android, home
    // indicator no iPhone) em vez de ficar por baixo dele.
    final margemInferior = 16 + media.padding.bottom;

    return Positioned(
      left: 16,
      right: 16,
      bottom: margemInferior,
      child: SlideTransition(
        position: _posicao,
        child: FadeTransition(
          opacity: _opacidade,
          child: Center(
            child: ConstrainedBox(
              // Em telas largas uma barra de ponta a ponta obriga o olho a
              // atravessar a tela para ler uma frase curta.
              constraints: const BoxConstraints(maxWidth: 560),
              child: Material(
                color: widget.corFundo,
                elevation: 6,
                borderRadius: AppRadii.circularSm,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    14,
                    widget.aoDesfazer == null ? 16 : 8,
                    14,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: DefaultTextStyle.merge(
                          // `textoSobreCor` (e não branco literal): a barra é
                          // uma superfície colorida forte, e nos dois temas é
                          // esse o papel semântico do texto por cima dela.
                          style: TextStyle(
                            color: cores.textoSobreCor,
                            fontSize: 14,
                          ),
                          child: widget.child,
                        ),
                      ),
                      if (widget.aoDesfazer != null)
                        TextButton(
                          onPressed: () {
                            // Fecha primeiro para a barra não ficar na tela
                            // durante o round-trip da ação.
                            sair();
                            widget.aoDesfazer!();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: cores.textoSobreCor,
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: Text(widget.rotuloAcao ?? 'Desfazer'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
