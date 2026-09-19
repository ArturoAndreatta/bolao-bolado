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
                  builder: (context, pedido, child) => Visibility(
                    visible:
                        item.indice == (resolverAtiva?.call(pedido) ?? pedido),
                    maintainState: true,
                    child: child!,
                  ),
                ),
            ],
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
            child: Row(
              // stretch: cada item ocupa a altura toda da barra. Sem isto a
              // cápsula do item ativo encolhia para a altura do ícone e virava
              // uma tarja fina no meio da pílula.
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final item in itens)
                  _ItemBarra(
                    item: item,
                    ativo: item.indice == ativa,
                    onTap: () => onSelecionar(item.indice),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ItemBarra extends StatelessWidget {
  final ItemSecaoMobile item;
  final bool ativo;
  final VoidCallback onTap;

  const _ItemBarra({
    required this.item,
    required this.ativo,
    required this.onTap,
  });

  // Curta de propósito: a cápsula crescendo é o charme da barra, mas as
  // abas antigas já mostraram que troca de seção animada acima de ~200ms lê
  // como atraso do toque.
  static const _duracao = Duration(milliseconds: 180);

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    final corConteudo = ativo ? cores.textoSobreAcao : cores.textoSuave;

    return Expanded(
      // O item ativo pega mais largura para caber o rótulo; os outros
      // dividem o resto.
      flex: ativo ? 5 : 3,
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
            child: AnimatedContainer(
              duration: _duracao,
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: ativo
                    ? cores.acaoPrimaria
                    : cores.acaoPrimaria.withValues(alpha: 0),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _IconeComContador(
                    icone: item.icone,
                    cor: corConteudo,
                    contador: item.contador,
                  ),
                  // Rótulo só no ativo, entrando com a largura da cápsula.
                  Flexible(
                    child: AnimatedSize(
                      duration: _duracao,
                      curve: Curves.easeOutCubic,
                      child: ativo
                          ? Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(
                                item.rotulo,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: corConteudo,
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
