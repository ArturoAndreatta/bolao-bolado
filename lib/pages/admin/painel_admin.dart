import 'package:bolao_bolado/components/shared/custom_card.dart';
import 'package:bolao_bolado/components/shared/header_paginas.dart';
import 'package:bolao_bolado/components/shared/skeletons.dart';
import 'package:bolao_bolado/components/shell/default_layout.dart';
import 'package:bolao_bolado/components/shell/drawer.dart';
import 'package:bolao_bolado/components/shell/secoes_mobile.dart';
import 'package:bolao_bolado/core/responsive.dart';
import 'package:bolao_bolado/pages/admin/admin_abas.dart';
import 'package:bolao_bolado/pages/admin/painel_admin_base.dart';
import 'package:bolao_bolado/pages/admin/widgets/admin_widgets.dart';
import 'package:bolao_bolado/pages/admin/widgets/menu_secoes_admin.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Painel ADM com dois layouts conforme o espaço disponível:
///
/// - **Desktop/janela larga:** faixa de números fixa no topo + menu lateral de
///   seções + a seção escolhida ocupando todo o resto da tela. Uma coisa por
///   vez, em tamanho de gente.
/// - **Mobile/janela estreita** ([Responsive.isCompact]): uma seção por vez,
///   com a barra flutuante embaixo — o mesmo layout da tela de Participantes
///   (ver secoes_mobile.dart).
///
/// O desktop já foi uma GRADE de cards (visão geral em cima, participantes,
/// ranking e sala lado a lado embaixo), e trocou por isto por três motivos
/// que se somavam:
///
/// - **Não cabia.** Os cards somavam ~950px de altura numa área de ~700, então
///   a página inteira rolava dentro do card — justamente o que a altura
///   travada na tela existia para evitar.
/// - **Cada card ficava com ~450px de largura** numa tela de 1450. A lista de
///   participantes (avatar, nome, selos, valor, dois botões) e as barras do
///   ranking viviam espremidas enquanto sobrava espaço vazio na vertical.
/// - **Quatro barras coloridas de cabeçalho** competindo entre si na mesma
///   tela, com cada card ainda trazendo seu botão de recolher. Hoje a cor de
///   cada seção aparece só no menu lateral: um ícone e um traço de 3px.
///
/// Os números da sala não viraram uma seção do menu: eles são a faixa do topo,
/// visível por cima de QUALQUER seção. É o dado que o admin quer de relance o
/// tempo todo — escondê-lo atrás de um clique seria trocar um problema pelo
/// outro.
///
/// Toda a lógica de estado/ações vive em [PainelAdminMixin] — este widget só
/// monta o layout.
class PainelAdmin extends StatefulWidget {
  const PainelAdmin({super.key});

  @override
  State<PainelAdmin> createState() => _PainelAdminState();
}

class _PainelAdminState extends State<PainelAdmin> with PainelAdminMixin {
  // Seção ativa no mobile, pelo índice de [AbaAdmin]. ValueNotifier e não
  // setState: ver [FolhaSecoesMobile].
  final ValueNotifier<int> _secaoMobile = ValueNotifier(
    AbaAdmin.visaoGeral.index,
  );

  /// Seção aberta no desktop. Abre em Participantes, e não num resumo: os
  /// números já estão na faixa do topo, e o que se vem fazer aqui é conferir
  /// aposta.
  ///
  /// ValueNotifier pelo mesmo motivo do mobile: trocar de seção reconstrói só
  /// o menu e o cabeçalho do painel, não o conteúdo das seções (que continuam
  /// todas montadas, ver [_painelSecao]).
  final ValueNotifier<AbaAdmin> _secaoDesktop = ValueNotifier(
    AbaAdmin.participantes,
  );

  bool _atualizando = false;

  /// Largura do menu lateral. Cabe "Participantes" inteiro ao lado do ícone
  /// com o selo de pendências no fim da linha — abaixo disso o rótulo mais
  /// comprido começa a elipsar, e um menu com reticências não serve de menu.
  static const double _larguraMenu = 224;

  @override
  void dispose() {
    _secaoMobile.dispose();
    _secaoDesktop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = Responsive.isCompact(context);
    // A barra só existe quando há painel para navegar: carregando ou sem
    // permissão, a tela mostra o skeleton/aviso sozinha.
    final comBarra = compact && !loading && autorizado;

    return DefaultLayout(
      drawer: AppDrawer(),
      esticarLarguraCompact: compact,
      bottomNavigationBar: comBarra ? _barraSecoesMobile() : null,
      // A barra flutua sobre o conteúdo; a folha desconta a altura dela.
      extendBody: comBarra,
      child: compact ? _layoutMobile() : _layoutDesktop(context),
    );
  }

  // ── Layout mobile: uma seção por vez + barra flutuante ──────────────────

  // Rótulos curtos de propósito: são cinco seções dividindo a pílula, e o
  // rótulo do item ativo precisa caber inteiro ao lado do ícone.
  List<ItemSecaoMobile> _itensMobile() => [
    ItemSecaoMobile(
      indice: AbaAdmin.visaoGeral.index,
      rotulo: 'Resumo',
      icone: Icons.dashboard_outlined,
    ),
    ItemSecaoMobile(
      indice: AbaAdmin.participantes.index,
      rotulo: 'Apostas',
      icone: Icons.groups_outlined,
      // Selo com as apostas esperando verificação — as mesmas do selo do
      // item Painel ADM no Drawer.
      contador: quantidadePendentes,
    ),
    ItemSecaoMobile(
      indice: AbaAdmin.ranking.index,
      rotulo: 'Ranking',
      icone: Icons.leaderboard_outlined,
    ),
    ItemSecaoMobile(
      indice: AbaAdmin.sala.index,
      rotulo: 'Sala',
      icone: Icons.meeting_room_outlined,
    ),
    ItemSecaoMobile(
      indice: AbaAdmin.config.index,
      rotulo: 'Ajustes',
      icone: Icons.settings_outlined,
    ),
  ];

  Widget _barraSecoesMobile() {
    return ValueListenableBuilder<int>(
      valueListenable: _secaoMobile,
      builder: (context, ativa, _) => BarraSecoesMobile(
        itens: _itensMobile(),
        ativa: ativa,
        onSelecionar: (indice) => _secaoMobile.value = indice,
      ),
    );
  }

  Widget _layoutMobile() {
    if (loading) return _skeleton();
    if (!autorizado) return mensagemAcessoNegado();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: apostasPendentesStream,
      builder: (context, pendentesSnapshot) {
        if (pendentesSnapshot.hasError) {
          debugPrint(
            'Erro ao carregar apostas pendentes: ${pendentesSnapshot.error}',
          );
        }

        return FolhaSecoesMobile(
          itens: _itensMobile(),
          ativa: _secaoMobile,
          // Cada seção do painel já tem 16px de respiro por dentro (é o
          // mesmo conteúdo do painel do desktop). Somados aos 12 da folha,
          // o conteúdo ficava a 28px da borda, bem mais estreito que o das
          // outras telas, e a logo parecia fora do eixo dos cards.
          respiro: EdgeInsets.zero,
          construir: (context, item, altura) {
            final aba = AbaAdmin.values[item.indice];
            // Participantes e Ranking preenchem a altura sozinhos (lista
            // paginada com Expanded) — a folha já entrega altura limitada, e
            // envolver em SingleChildScrollView reintroduz altura infinita
            // bem em cima do Expanded deles, o que no Flutter web não estoura
            // visivelmente: só deixa a seção em branco. Visão geral, Sala e
            // Configurações são conteúdo empilhado (Column mainAxisSize.min,
            // sem Expanded) e precisam de scroll em telas baixas — Visão
            // geral no celular usa faixa:false por isso (ver
            // AdminCardStats.faixa).
            final conteudo = aba == AbaAdmin.visaoGeral
                ? conteudoStats(pendentesSnapshot, faixa: false)
                : conteudoAba(aba, pendentesSnapshot);
            final precisaScroll =
                aba == AbaAdmin.visaoGeral ||
                aba == AbaAdmin.sala ||
                aba == AbaAdmin.config;
            return SizedBox(
              height: altura,
              child: precisaScroll
                  ? SingleChildScrollView(child: conteudo)
                  : conteudo,
            );
          },
        );
      },
    );
  }

  // ── Layout desktop: faixa de números + menu lateral + seção ─────────────

  Widget _layoutDesktop(BuildContext context) {
    // Altura do card pai travada na tela (viewport menos AppBar/rodapé/
    // respiro), calculada na mão em vez de esticarAltura/Expanded: o
    // DefaultLayout só dá altura finita ao body na faixa "compact"
    // (< 1440px) — em telas mais largas o body é um SingleChildScrollView
    // com altura infinita. esticarAltura do CustomCard usa Expanded
    // internamente (ver custom_card.dart), que lança "RenderFlex... but
    // incoming height constraints are unbounded" nessa faixa — exceção que
    // o Flutter web engole, deixando a tela em branco sem aviso (já
    // aconteceu duas vezes nesta página). Por isso aqui a altura é sempre
    // um SizedBox com valor numérico explícito, nunca Expanded/esticarAltura.
    //
    // O desconto vem de DefaultLayout.alturaAppBar e NÃO de kToolbarHeight:
    // no desktop a barra tem 74px para caber o logo, e descontar os 56 do
    // padrão do Material deixava 18px de card para fora da janela — a página
    // inteira ganhava scroll por causa disso, não por causa do tamanho do
    // logo. Os 40 restantes cobrem os paddings do CustomCard em volta (30) e
    // deixam 10px de respiro.
    final alturaCard =
        (MediaQuery.sizeOf(context).height -
                DefaultLayout.alturaAppBar(context) -
                40)
            .clamp(560.0, 819.0);
    // Área de conteúdo do card interno: altura do card menos o espaço do
    // cabeçalho colorido do CustomCard pai (HeaderPaginas + paddings).
    const alturaCabecalho = 90.0;
    final alturaConteudo = alturaCard - alturaCabecalho;

    return CustomCard(
      color: AdminCores.de(context).fundoSecao,
      maxWidth: 1450,
      height: alturaCard,
      esticarLargura: true,
      children: [
        HeaderPaginas(
          text: 'Painel ADM',
          subtitle: 'Gerencie apostas, participantes e a sala',
          // O painel é uma tela de destino (chega-se pelo menu), não um
          // passo de um fluxo: não há "de onde voltar", e o menu continua
          // no canto para sair dele.
          showBackButton: false,
          trailing: _botaoAtualizar(),
        ),
        CustomCard(
          isChild: true,
          maxWidth: double.infinity,
          height: alturaConteudo,
          esticarLargura: true,
          children: [
            SizedBox(
              // -20: os 10px de respiro que o CustomCard interno põe em cima
              // e embaixo do conteúdo.
              height: alturaConteudo - 20,
              child: loading
                  ? _skeleton(faixa: true)
                  : !autorizado
                  ? mensagemAcessoNegado()
                  : _painelDesktop(),
            ),
          ],
        ),
      ],
    );
  }

  /// Recarrega os números da sala sob demanda.
  ///
  /// As apostas vêm de um Future avulso (ver `getBets` em
  /// [PainelAdminMixin]), não de um stream: elas só se atualizam sozinhas
  /// depois de uma ação do próprio admin. Sem este botão, quem deixa o painel
  /// aberto enquanto a galera aposta fica olhando número velho sem ter como
  /// saber disso.
  Widget _botaoAtualizar() {
    final cores = AdminCores.de(context);
    return IconButton(
      onPressed: _atualizando ? null : _atualizar,
      tooltip: 'Atualizar dados',
      color: cores.azul,
      icon: _atualizando
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: cores.azul,
              ),
            )
          : const Icon(Icons.refresh),
    );
  }

  Future<void> _atualizar() async {
    setState(() => _atualizando = true);
    try {
      await recarregarStats();
    } finally {
      if (mounted) setState(() => _atualizando = false);
    }
  }

  Widget _painelDesktop() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: apostasPendentesStream,
      builder: (context, pendentesSnapshot) {
        if (pendentesSnapshot.hasError) {
          debugPrint(
            'Erro ao carregar apostas pendentes: ${pendentesSnapshot.error}',
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Faixa encolhe pro próprio conteúdo e o resto da altura vai
            // inteiro para a seção — é ela que precisa de espaço.
            conteudoStats(pendentesSnapshot),
            const SizedBox(height: 14),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: _larguraMenu, child: _menuSecoes()),
                  const SizedBox(width: 14),
                  Expanded(child: _painelSecao(pendentesSnapshot)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _menuSecoes() {
    return ValueListenableBuilder<AbaAdmin>(
      valueListenable: _secaoDesktop,
      builder: (context, ativa, _) => MenuSecoesAdmin(
        ativa: ativa,
        pendentes: quantidadePendentes,
        onSelecionar: (aba) => _secaoDesktop.value = aba,
      ),
    );
  }

  Widget _painelSecao(
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> pendentesSnapshot,
  ) {
    final cores = AdminCores.de(context);
    return ValueListenableBuilder<AbaAdmin>(
      valueListenable: _secaoDesktop,
      builder: (context, ativa, _) {
        final indice = kAbasAdmin
            .indexWhere((m) => m.aba == ativa)
            .clamp(0, kAbasAdmin.length - 1);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CabecalhoSecaoAdmin(
              meta: kAbasAdmin[indice],
              acao: ativa == AbaAdmin.ranking ? _botaoCopiarCsv() : null,
            ),
            Divider(height: 1, thickness: 1, color: cores.borda),
            // IndexedStack, e não só a seção ativa: trocar de seção não pode
            // apagar o que já foi digitado no formulário da Sala nem zerar a
            // busca/página da lista de Participantes. É o mesmo arranjo da
            // folha do celular, onde todas as seções ficam montadas.
            Expanded(
              child: IndexedStack(
                index: indice,
                sizing: StackFit.expand,
                children: [
                  for (final m in kAbasAdmin)
                    _conteudoSecaoDesktop(m.aba, pendentesSnapshot),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Exporta a planilha das apostas pela seção Ranking, que é onde já se
  /// olha quem tem quanto. É a mesma lista da tela, no formato que o Excel e
  /// o Sheets abrem colando.
  Widget _botaoCopiarCsv() {
    final cores = AdminCores.de(context);
    return TextButton.icon(
      onPressed: copiarCsvApostas,
      icon: const Icon(Icons.copy_all_outlined, size: 18),
      label: const Text('Copiar planilha'),
      style: TextButton.styleFrom(foregroundColor: cores.azul),
    );
  }

  Widget _conteudoSecaoDesktop(
    AbaAdmin aba,
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> pendentesSnapshot,
  ) {
    final conteudo = conteudoAba(
      aba,
      pendentesSnapshot,
      // Participantes e Ranking mostram a lista inteira rolando por dentro:
      // aqui a lista é a única coisa que rola na tela.
      rolarLista: true,
      // O cabeçalho da seção logo acima já diz onde a pessoa está.
      cabecalhoInterno: false,
    );

    // Sala e Configurações são conteúdo empilhado que passa da altura do
    // painel (formulário inteiro, lista de ferramentas de dev) e rolam por
    // dentro. Participantes e Ranking já se limitam sozinhos à altura
    // recebida — envolvê-los em scroll reintroduziria altura infinita em
    // cima do Expanded deles e deixaria a seção em branco.
    final precisaScroll = aba == AbaAdmin.sala || aba == AbaAdmin.config;
    return precisaScroll ? SingleChildScrollView(child: conteudo) : conteudo;
  }

  /// Placeholder do painel enquanto a permissão e os dados carregam.
  ///
  /// [faixa] escolhe entre o painel do desktop inteiro (faixa + menu + a
  /// seção de Participantes, que é a que abre) e a pilha de números do
  /// celular, que é a seção Resumo. Os dois desenham o conteúdo NO LUGAR em
  /// que ele vai aparecer — antes o desktop mostrava só a régua de
  /// indicadores, esticada no meio de um card vazio, e a tela inteira se
  /// reorganizava quando os dados chegavam.
  Widget _skeleton({bool faixa = false}) {
    if (faixa) {
      return const SkeletonPainelAdmin(larguraMenu: _larguraMenu);
    }
    // Scroll no celular: a pilha de números passa da altura da tela em
    // aparelhos baixos, e Column sozinho não rola nem clipa.
    return const SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: SkeletonDashboardStats(),
    );
  }
}
