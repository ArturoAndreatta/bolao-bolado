import 'dart:math' as math;

import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/core/app_radii.dart';
import 'package:bolao_bolado/core/area_segura.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Layout de seções do celular, compartilhado pelas telas que no desktop
// mostram tudo lado a lado e no celular mostram uma seção por vez
// (Participantes e Painel ADM): a folha com o conteúdo da seção ativa
// ([FolhaSecoesMobile]) e a barra flutuante que troca de seção
// ([BarraSecoesMobile]). Substituiu o antigo fichário de abas coloridas, que
// não tinha nada a ver com o visual do desktop.
//
// A tela que usa monta o DefaultLayout com `bottomNavigationBar:` a barra e
// `extendBody: true` — a barra flutua sobre o conteúdo, e a folha desconta a
// altura dela (ver [_RespiroDaBarra]).

/// Largura máxima do conteúdo e da barra no tablet/janela estreita: o
/// conteúdo fica centrado em vez de esticar uma tela de celular por 1300px.
const double kLarguraMaximaSecoesMobile = 730;

/// Uma seção: [indice] é o valor que a tela guarda como seção ativa, e a
/// ORDEM da lista passada à barra é a ordem visual.
class ItemSecaoMobile {
  final int indice;
  final String rotulo;
  final IconData icone;

  /// Número num selo vermelho sobre o ícone (ex: apostas pendentes). 0 = sem
  /// selo.
  final int contador;

  const ItemSecaoMobile({
    required this.indice,
    required this.rotulo,
    required this.icone,
    this.contador = 0,
  });
}

/// Conteúdo das seções, sobre uma folha de ponta a ponta com os cantos de
/// cima arredondados, na cor [AppCores.fundoConteudoMobile] — a do card nos
/// temas claros, transparente nos escuros (ver o campo na paleta). Nos
/// claros ela faz o papel do card branco do desktop e o gradiente fica só em
/// volta do logo; nos escuros o conteúdo segue direto sobre o gradiente.
///
/// Todas as seções ficam montadas o tempo todo e só a ativa aparece: trocar
/// de seção não pode reabrir streams, perder a rolagem da lista nem apagar o
/// que foi digitado. A seção ativa vem de um [ValueListenable], e não do
/// setState da tela: o toque na barra reconstrói só os Visibility e a
/// própria barra, e não o conteúdo pesado das seções.
class FolhaSecoesMobile extends StatelessWidget {
  final List<ItemSecaoMobile> itens;
  final ValueListenable<int> ativa;

  /// Converte o índice pedido no que de fato aparece (ex: deep link para uma
  /// seção que o usuário não tem cai numa padrão). Null = o próprio índice.
  final int Function(int pedido)? resolverAtiva;

  /// Respiro em volta do conteúdo de cada seção. O padrão serve a conteúdo
  /// sem margem própria; seções que já trazem o próprio respiro por dentro
  /// (as do Painel ADM, pensadas também para os cards do desktop) passam
  /// menos, senão as duas margens somam e o conteúdo fica mais estreito que
  /// o das outras telas.
  final EdgeInsets respiro;

  /// Conteúdo de uma seção. Recebe a altura disponível: listas e
  /// formulários rolam por dentro dela, e nada passa do fim da tela.
  final Widget Function(
    BuildContext context,
    ItemSecaoMobile item,
    double altura,
  )
  construir;

  const FolhaSecoesMobile({
    super.key,
    required this.itens,
    required this.ativa,
    required this.construir,
    this.resolverAtiva,
    this.respiro = const EdgeInsets.fromLTRB(12, 4, 12, 12),
  });

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    // Respiro extra no topo só com folha visível (cantos arredondados): nos
    // temas escuros a posição do conteúdo fica a de sempre.
    final temFolha = cores.fundoConteudoMobile.a > 0;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kLarguraMaximaSecoesMobile),
        child: Container(
          margin: EdgeInsets.only(top: temFolha ? 4 : 0),
          padding: EdgeInsets.only(top: temFolha ? 10 : 0),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: cores.fundoConteudoMobile,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Stack(
            children: [
              for (final item in itens)
                ValueListenableBuilder<int>(
                  // Key estável: a lista pode mudar (seção que entra e sai
                  // com o login) sem o Flutter trocar uma seção por outra.
                  key: ValueKey(item.indice),
                  valueListenable: ativa,
                  child: _RespiroDaBarra(
                    child: Padding(
                      padding: respiro,
                      child: LayoutBuilder(
                        builder: (context, constraints) =>
                            construir(context, item, constraints.maxHeight),
                      ),
                    ),
                  ),
                  builder: (context, pedido, child) {
                    final indiceAtivo = resolverAtiva?.call(pedido) ?? pedido;
                    return _SecaoAnimada(
                      ativa: item.indice == indiceAtivo,
                      posicao: itens.indexOf(item),
                      posicaoAtiva: itens.indexWhere(
                        (i) => i.indice == indiceAtivo,
                      ),
                      child: child!,
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Troca de seção com transição: a que entra aparece esmaecendo e deslizando
/// um pouco a partir do lado da barra em que o dedo tocou — tocar numa seção
/// à direita traz o conteúdo da direita. O deslize é curto (4% da largura):
/// o bastante para o olho ler direção, sem a tela inteira se mexer.
///
/// A que SAI some na hora, sem animação. Já saiu animando também, e as duas
/// seções semitransparentes na tela ao mesmo tempo (lista e chat inteiros,
/// cada um numa camada própria) pesavam a ponto de a troca parecer lenta no
/// celular, sobretudo na web. Com uma só animando, o custo cai pela metade e
/// a resposta ao toque é imediata: a seção antiga já não está lá.
///
/// Fora da transição, a seção inativa sai do layout e da pintura (Visibility
/// com maintainState): continua montada, com streams, rolagem e texto
/// digitado intactos, mas não custa nada por quadro.
class _SecaoAnimada extends StatefulWidget {
  final bool ativa;
  final int posicao;
  final int posicaoAtiva;
  final Widget child;

  const _SecaoAnimada({
    required this.ativa,
    required this.posicao,
    required this.posicaoAtiva,
    required this.child,
  });

  @override
  State<_SecaoAnimada> createState() => _SecaoAnimadaState();
}

class _SecaoAnimadaState extends State<_SecaoAnimada>
    with SingleTickerProviderStateMixin {
  // Curta: animação longa, mesmo lisa, é sentida como espera pelo toque.
  static const _duracao = Duration(milliseconds: 200);
  static const _deslize = 0.04;

  late final AnimationController _controle = AnimationController(
    vsync: this,
    duration: _duracao,
    value: widget.ativa ? 1 : 0,
  );
  late final CurvedAnimation _curva = CurvedAnimation(
    parent: _controle,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  // Lado de onde a seção entra (ou para onde sai): -1 esquerda, 1 direita.
  double _lado = 1;

  @override
  void didUpdateWidget(covariant _SecaoAnimada antiga) {
    super.didUpdateWidget(antiga);
    if (widget.ativa == antiga.ativa) return;
    if (widget.ativa) {
      // Entrando: vem do lado em que ela está em relação à que saiu.
      _lado = widget.posicao >= antiga.posicaoAtiva ? 1 : -1;
      _controle.forward(from: 0);
    } else {
      // Saindo: some no ato (ver a documentação da classe).
      _controle.value = 0;
    }
  }

  @override
  void initState() {
    super.initState();
    // Reconstrói só nas pontas da animação (começo e fim), que é quando a
    // visibilidade muda. Os quadros do meio ficam por conta das transições
    // abaixo, sem rebuild.
    _controle.addStatusListener(_aoMudarStatus);
  }

  void _aoMudarStatus(AnimationStatus status) {
    if (status.isDismissed || status == AnimationStatus.forward) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controle.removeStatusListener(_aoMudarStatus);
    _curva.dispose();
    _controle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Visibility(
      // Totalmente fora (inativa e parada em 0): some do layout e da
      // pintura, mantendo o estado.
      visible: widget.ativa || !_controle.isDismissed,
      maintainState: true,
      child: IgnorePointer(
        // A que está saindo não pode receber o toque que era para a nova.
        ignoring: !widget.ativa,
        // FadeTransition e não Opacity: a transparência vai para a camada de
        // composição, em vez de repintar a seção inteira (lista, chat) a cada
        // quadro da troca.
        child: FadeTransition(
          opacity: _curva,
          child: SlideTransition(
            position: _curva.drive(
              Tween(begin: Offset(_lado * _deslize, 0), end: Offset.zero),
            ),
            // RepaintBoundary: a seção é desenhada UMA vez e a transição só
            // move e esmaece a camada pronta. Sem ela, cada quadro do deslize
            // redesenhava a lista (ou o chat) inteira.
            child: RepaintBoundary(child: widget.child),
          ),
        ),
      ),
    );
  }
}

/// Desconta da seção a altura da barra flutuante, que passa por cima do
/// conteúdo (extendBody): o Scaffold informa essa altura no padding de baixo.
///
/// Com o teclado aberto a barra fica escondida atrás dele, e o desconto
/// sobraria como um vão entre o conteúdo e o teclado — bem em cima do campo
/// do chat. Por isso aí ele zera.
///
/// Widget próprio, e não conta feita no build da tela: ler `viewInsets` cria
/// dependência do teclado, e na tela isso reconstruiria todas as seções a
/// cada abrir/fechar dele (ver responsive.dart). Aqui só este padding
/// reconstrói; o conteúdo entra pronto por [child].
class _RespiroDaBarra extends StatelessWidget {
  final Widget child;

  const _RespiroDaBarra({required this.child});

  @override
  Widget build(BuildContext context) {
    final tecladoAberto = MediaQuery.viewInsetsOf(context).bottom > 0;
    final alturaBarra = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: tecladoAberto ? 0 : alturaBarra),
      child: child,
    );
  }
}

/// Barra que troca a seção: uma pílula FLUTUANTE, solta das bordas da tela,
/// no estilo das barras do Google (google_nav_bar). O item ativo vira uma
/// cápsula na cor de ação do tema (a do botão Confirmar) com ícone e rótulo;
/// os outros mostram só o ícone.
///
/// Feita à mão, e não com pacote: toda cor sai de [AppCores] (a cápsula usa
/// o par [AppCores.acaoPrimaria]/[AppCores.textoSobreAcao], que já garante
/// contraste em todos os temas), e nenhum pacote do gênero expõe a paleta
/// inteira sem reescrever metade dele.
class BarraSecoesMobile extends StatelessWidget {
  final List<ItemSecaoMobile> itens;
  final int ativa;
  final ValueChanged<int> onSelecionar;

  const BarraSecoesMobile({
    super.key,
    required this.itens,
    required this.ativa,
    required this.onSelecionar,
  });

  // No tablet a pílula não atravessa a tela inteira: fica do tamanho de uma
  // barra de celular, centrada.
  static const double _larguraMaxima = 420;

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    // Área da barrinha de gestos do iPhone. Fora da web o Flutter já informa
    // em MediaQuery.padding; na web ele entrega zero, e quem sabe é o CSS
    // (ver area_segura.dart). O maior dos dois, para não somar duas vezes.
    final areaSegura = math.max(
      MediaQuery.paddingOf(context).bottom,
      margemInferiorNavegador(),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 6, 16, 10 + areaSegura),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _larguraMaxima),
          child: Container(
            height: 60,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: cores.cardExterno,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: cores.borda),
              boxShadow: [
                BoxShadow(
                  color: cores.sombra,
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            // A cápsula é UMA peça só, que desliza de um item para o outro
            // (e muda de largura no caminho) — antes cada item pintava a
            // própria, e trocar de seção só apagava uma e acendia outra.
            // Para ela saber aonde ir, as larguras dos itens são calculadas
            // aqui (o ativo pesa 5, os outros 3) em vez de deixadas a um
            // Expanded, e itens e cápsula animam juntos, com a mesma curva.
            child: LayoutBuilder(
              builder: (context, constraints) {
                const pesoAtivo = 5.0;
                const pesoInativo = 3.0;
                final posicaoAtiva = itens.indexWhere((i) => i.indice == ativa);
                final pesoTotal = pesoAtivo + pesoInativo * (itens.length - 1);
                final unidade = constraints.maxWidth / pesoTotal;
                double larguraDe(int posicao) =>
                    (posicao == posicaoAtiva ? pesoAtivo : pesoInativo) *
                    unidade;
                var esquerdaCapsula = 0.0;
                for (var p = 0; p < posicaoAtiva; p++) {
                  esquerdaCapsula += larguraDe(p);
                }

                return Stack(
                  children: [
                    if (posicaoAtiva >= 0)
                      AnimatedPositioned(
                        duration: _duracaoBarra,
                        curve: _curvaBarra,
                        top: 0,
                        bottom: 0,
                        left: esquerdaCapsula + 2,
                        width: larguraDe(posicaoAtiva) - 4,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: cores.acaoPrimaria,
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                    Row(
                      // stretch: cada item ocupa a altura toda da barra.
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var p = 0; p < itens.length; p++)
                          _ItemBarra(
                            item: itens[p],
                            ativo: p == posicaoAtiva,
                            largura: larguraDe(p),
                            onTap: () => onSelecionar(itens[p].indice),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// Duração e curva da troca na barra, iguais para a cápsula, a largura dos
// itens, a cor do ícone e a entrada do rótulo — tudo precisa chegar junto,
// senão a cápsula termina antes do texto caber nela.
const Duration _duracaoBarra = Duration(milliseconds: 240);
const Curve _curvaBarra = Curves.easeOutCubic;

class _ItemBarra extends StatelessWidget {
  final ItemSecaoMobile item;
  final bool ativo;
  final double largura;
  final VoidCallback onTap;

  const _ItemBarra({
    required this.item,
    required this.ativo,
    required this.largura,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    final corConteudo = ativo ? cores.textoSobreAcao : cores.textoSuave;

    return AnimatedContainer(
      duration: _duracaoBarra,
      curve: _curvaBarra,
      width: largura,
      child: Semantics(
        button: true,
        selected: ativo,
        label: item.contador > 0
            ? '${item.rotulo}, ${item.contador} pendentes'
            : item.rotulo,
        excludeSemantics: true,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            // Cor do ícone e do rótulo acompanha a cápsula: clareia enquanto
            // ela chega, escurece enquanto ela sai.
            child: TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: corConteudo),
              duration: _duracaoBarra,
              curve: _curvaBarra,
              builder: (context, cor, _) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _IconeComContador(
                    icone: item.icone,
                    cor: cor ?? corConteudo,
                    contador: item.contador,
                  ),
                  // Rótulo só no ativo, entrando com a largura da cápsula.
                  Flexible(
                    child: AnimatedSize(
                      duration: _duracaoBarra,
                      curve: _curvaBarra,
                      child: ativo
                          ? Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(
                                item.rotulo,
                                maxLines: 1,
                                overflow: TextOverflow.clip,
                                softWrap: false,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: cor ?? corConteudo,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ícone do item com o selo vermelho de contagem no canto — o mesmo selo do
/// item Painel ADM no Drawer.
class _IconeComContador extends StatelessWidget {
  final IconData icone;
  final Color cor;
  final int contador;

  const _IconeComContador({
    required this.icone,
    required this.cor,
    required this.contador,
  });

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    final icon = Icon(icone, size: 22, color: cor);
    if (contador <= 0) return icon;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        Positioned(
          top: -6,
          right: -10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            constraints: const BoxConstraints(minWidth: 16),
            decoration: BoxDecoration(
              color: cores.vermelho,
              borderRadius: AppRadii.circularPill,
            ),
            child: Text(
              contador > 99 ? '99+' : '$contador',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
