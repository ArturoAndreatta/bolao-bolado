import 'package:bolao_bolado/components/shared/custom_card.dart';
import 'package:bolao_bolado/components/shared/header_paginas.dart';
import 'package:bolao_bolado/components/shared/skeletons.dart';
import 'package:bolao_bolado/components/shell/default_layout.dart';
import 'package:bolao_bolado/components/shell/drawer.dart';
import 'package:bolao_bolado/components/shell/secoes_mobile.dart';
import 'package:bolao_bolado/core/app_radii.dart';
import 'package:bolao_bolado/core/responsive.dart';
import 'package:bolao_bolado/pages/admin/admin_abas.dart';
import 'package:bolao_bolado/pages/admin/painel_admin_base.dart';
import 'package:bolao_bolado/pages/admin/widgets/admin_widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Painel ADM com dois layouts conforme o espaço disponível:
/// - Desktop/tablet largo: cards soltos lado a lado (grade), todos visíveis
///   ao mesmo tempo, dentro de um card pai com o cabeçalho da página.
/// - Mobile/janela estreita ([Responsive.isCompact]): uma seção por vez, com
///   a barra flutuante embaixo — o mesmo layout da tela de Participantes (ver
///   secoes_mobile.dart). Cada seção já era um conteúdo independente, então
///   virou uma seção sem duplicar nada.
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

  @override
  void dispose() {
    _secaoMobile.dispose();
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
          // mesmo conteúdo dos cards do desktop). Somados aos 12 da folha,
          // o conteúdo ficava a 28px da borda, bem mais estreito que o das
          // outras telas, e a logo parecia fora do eixo dos cards.
          respiro: EdgeInsets.zero,
          construir: (context, item, altura) {
            final aba = AbaAdmin.values[item.indice];
            // Participantes e Ranking preenchem a altura sozinhos (lista
            // paginada com Expanded) — a folha já entrega altura limitada, e
            // envolver em SingleChildScrollView reintroduz altura infinita
            // bem em cima do Expanded deles, o que no Flutter web não estoura
            // visivelmente: só deixa a seção em branco (mesma armadilha do
            // RenderFlex documentada em _layoutDesktop). Visão geral, Sala e
            // Configurações são conteúdo empilhado (Column mainAxisSize.min,
            // sem Expanded) e precisam de scroll em telas baixas — Visão geral
            // em mobile usa bentoGrid:false por isso (ver
            // AdminCardStats.bentoGrid).
            final conteudo = aba == AbaAdmin.visaoGeral
                ? conteudoStats(pendentesSnapshot, bentoGrid: false)
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

  // Config só existe como dialog no desktop (engrenagem no header) — no
  // mobile é a seção Ajustes (ver _layoutMobile).
  void _abrirConfiguracoes(BuildContext context) {
    final cores = AdminCores.de(context);
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 700),
          child: Container(
            decoration: BoxDecoration(
              color: cores.fundoCard,
              borderRadius: AppRadii.circularXl,
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  // Escurecida no escuro para o branco continuar legível.
                  color: cores.barraDeSecao(cores.coral),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.settings_outlined, color: Colors.white),
                      const SizedBox(width: 10),
                      const Text(
                        'Configurações',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    child: AbaConfig(
                      adminUser: adminUser,
                      salaId: salaId,
                      onModerarChat: abrirModeracaoChat,
                      onApagarMensagens: confirmarApagarMensagensChat,
                      onApagarApostas: confirmarApagarTodasApostas,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Layout desktop: grade de cards ──────────────────────────────────────
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
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 730),
          child: HeaderPaginas(
            text: 'Painel ADM',
            subtitle: 'Gerencie apostas, participantes e a sala',
            // O painel é uma tela de destino (chega-se pelo menu), não um
            // passo de um fluxo: não há "de onde voltar", e o menu continua
            // no canto para sair dele.
            showBackButton: false,
            trailing: IconButton(
              onPressed: () => _abrirConfiguracoes(context),
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Configurações',
              color: AdminCores.de(context).coral,
            ),
          ),
        ),
        CustomCard(
          isChild: true,
          maxWidth: double.infinity,
          height: alturaConteudo,
          esticarLargura: true,
          children: [
            SizedBox(
              height: alturaConteudo - 20,
              child: loading
                  ? _skeleton()
                  : !autorizado
                  ? mensagemAcessoNegado()
                  : SingleChildScrollView(child: _grade()),
            ),
          ],
        ),
      ],
    );
  }

  Widget _skeleton() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: SkeletonDashboardStats(),
    );
  }

  Widget _grade() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: apostasPendentesStream,
      builder: (context, pendentesSnapshot) {
        if (pendentesSnapshot.hasError) {
          debugPrint(
            'Erro ao carregar apostas pendentes: ${pendentesSnapshot.error}',
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            // 2 colunas a partir de ~760px, 3 a partir de ~1180px — cada
            // card mantém uma largura mínima legível em vez de espremer
            // texto/tabelas. Este layout só roda fora da faixa "compact"
            // (>= 1440px), então a largura mínima real aqui já garante 2+.
            final largura = constraints.maxWidth;
            final colunas = largura >= 1180 ? 3 : (largura >= 760 ? 2 : 1);
            const espacamento = 16.0;
            final larguraCard =
                (largura - espacamento * (colunas - 1)) / colunas;
            // Cor do cabeçalho por seção — cada uma com um tom próprio e um
            // porquê: azul para o resumo geral (ação primária/neutra),
            // verde-água para participantes (tom "de gente" do gradiente
            // do app), dourado para ranking (associação com prêmio/pódio),
            // roxo para sala (administrativo, deliberadamente fora da
            // paleta "operacional" das outras). Config não tem mais card na
            // grade — vive num dialog aberto pela engrenagem do header.
            final admin = AdminCores.de(context);
            final cores = {
              AbaAdmin.participantes: admin.verdeAgua,
              AbaAdmin.ranking: admin.dourado,
              AbaAdmin.sala: admin.roxo,
            };

            Widget card(AbaAdmin aba, {double? larguraExtra}) {
              return SizedBox(
                width: larguraExtra ?? larguraCard,
                child: _CardSecao(
                  meta: kAbasAdmin.firstWhere((m) => m.aba == aba),
                  cor: cores[aba] ?? admin.azul,
                  child: conteudoAba(aba, pendentesSnapshot),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CardSecao(
                  meta: const AbaAdminMeta(
                    aba: AbaAdmin.visaoGeral,
                    texto: 'Visão geral',
                    icone: Icons.dashboard_outlined,
                  ),
                  cor: admin.azul,
                  // Ver [_CardSecao.alturaCorpo]: aqui são seis números e uma
                  // barra de progresso, não uma lista paginada.
                  alturaCorpo: kAlturaVisaoGeral,
                  child: conteudoStats(pendentesSnapshot),
                ),
                const SizedBox(height: espacamento),
                Wrap(
                  spacing: espacamento,
                  runSpacing: espacamento,
                  children: [
                    card(AbaAdmin.participantes),
                    card(AbaAdmin.ranking),
                    card(AbaAdmin.sala),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Moldura de um card de seção do dashboard: cabeçalho colorido (ícone +
/// título + botão de recolher) + corpo branco abaixo, mesmo par de cores
/// usado nos outros cards do app (CustomCard colorido por fora, branco por
/// dentro). A cor vem de fora (não do enum) porque duas seções podem
/// compartilhar o mesmo [AbaAdmin] com cores diferentes — caso da Visão
/// geral, que virou dois cards (stats azul, pendentes vermelho).
class _CardSecao extends StatefulWidget {
  final AbaAdminMeta meta;
  final Color cor;
  final Widget child;

  /// Altura do corpo, quando esta seção não quer a padrão.
  ///
  /// Só a Visão geral usa: ela é a faixa de largura inteira ACIMA da grade,
  /// então a altura dela não precisa casar com a de ninguém — o motivo de
  /// [_alturaCorpoPadrao] existir vale para os três cards lado a lado do
  /// Wrap, que ficariam desencontrados. Reservar 560px para seis números
  /// obrigava o bento grid a inflar ícone e valor só para não sobrar vazio.
  final double? alturaCorpo;

  const _CardSecao({
    required this.meta,
    required this.cor,
    required this.child,
    this.alturaCorpo,
  });

  @override
  State<_CardSecao> createState() => _CardSecaoState();
}

class _CardSecaoState extends State<_CardSecao> {
  bool _recolhido = false;

  // Altura padrão do corpo de TODOS os cards da grade — mesma altura pra
  // Visão geral, Participantes, Ranking e Sala, pra grade não ficar com
  // cards de tamanhos desencontrados. Sem scroll interno: cada conteúdo
  // paginado (Participantes, Ranking) se limita sozinho a essa altura.
  static const double _alturaCorpoPadrao = 560;

  @override
  Widget build(BuildContext context) {
    final cores = AdminCores.de(context);
    return Container(
      decoration: BoxDecoration(
        color: cores.fundoCard,
        borderRadius: AppRadii.circularXl,
        border: Border.all(color: cores.borda),
        boxShadow: [
          BoxShadow(
            // Sombra quase imperceptível no escuro: sobre superfície escura
            // ela só sujaria a borda do card, que já se separa do fundo pela
            // diferença de luminosidade.
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            // Escurecida no tema escuro para o título branco continuar
            // legível — ver [AdminCores.barraDeSecao].
            color: cores.barraDeSecao(widget.cor),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Icon(widget.meta.icone, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.meta.texto,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: InkWell(
                    onTap: () => setState(() => _recolhido = !_recolhido),
                    borderRadius: AppRadii.circularSmd,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: AnimatedRotation(
                        turns: _recolhido ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(
                          Icons.keyboard_arrow_up,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: SizedBox(
              height: widget.alturaCorpo ?? _alturaCorpoPadrao,
              child: widget.child,
            ),
            crossFadeState: _recolhido
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 200),
            sizeCurve: Curves.easeOutCubic,
          ),
        ],
      ),
    );
  }
}
