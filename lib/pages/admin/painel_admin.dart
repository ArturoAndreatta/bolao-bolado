import 'package:bolao_bolado/components/shared/custom_card.dart';
import 'package:bolao_bolado/components/shared/ficharios.dart';
import 'package:bolao_bolado/components/shared/header_paginas.dart';
import 'package:bolao_bolado/components/shared/skeletons.dart';
import 'package:bolao_bolado/components/shell/default_layout.dart';
import 'package:bolao_bolado/components/shell/drawer.dart';
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
/// - Mobile/janela estreita ([Responsive.isCompact]): fichário de abas
///   (mesmo padrão visual de Participantes/Minha Aposta/Chat) — cada seção
///   já era um card independente, então virou uma folha do fichário sem
///   precisar duplicar nenhum conteúdo.
///
/// Toda a lógica de estado/ações vive em [PainelAdminMixin] — este widget só
/// monta o layout.
class PainelAdmin extends StatefulWidget {
  const PainelAdmin({super.key});

  @override
  State<PainelAdmin> createState() => _PainelAdminState();
}

class _PainelAdminState extends State<PainelAdmin> with PainelAdminMixin {
  // Aba ativa no fichário mobile.
  AbaAdmin _abaAtiva = AbaAdmin.visaoGeral;

  @override
  Widget build(BuildContext context) {
    final compact = Responsive.isCompact(context);

    return DefaultLayout(
      drawer: AppDrawer(),
      esticarLarguraCompact: compact,
      child: compact ? _layoutMobile() : _layoutDesktop(context),
    );
  }

  // ── Layout mobile: fichário de abas ─────────────────────────────────────
  Widget _layoutMobile() {
    if (loading) return _skeleton();
    if (!autorizado) return mensagemAcessoNegado();

    // Ordem visual da fileira de abas — define também a cor automática do
    // Fichario (1ª verde-água, 2ª azul, 3ª dourado, 4ª roxo, 5ª coral: a
    // paleta cobre as cinco seções sem repetir cor). Config é a última aba,
    // não mais um dialog no botão de engrenagem.
    const abas = [
      AbaFichario(
        texto: 'Visão geral',
        icone: Icons.dashboard_outlined,
        indice: 0,
      ),
      AbaFichario(
        texto: 'Participantes',
        icone: Icons.groups_outlined,
        indice: 1,
      ),
      AbaFichario(
        texto: 'Ranking',
        icone: Icons.leaderboard_outlined,
        indice: 2,
      ),
      AbaFichario(texto: 'Sala', icone: Icons.meeting_room_outlined, indice: 3),
      AbaFichario(
        texto: 'Configurações',
        icone: Icons.settings_outlined,
        indice: 4,
      ),
    ];

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: apostasPendentesStream,
      builder: (context, pendentesSnapshot) {
        if (pendentesSnapshot.hasError) {
          debugPrint(
            'Erro ao carregar apostas pendentes: ${pendentesSnapshot.error}',
          );
        }

        return Fichario(
          abaAtiva: _abaAtiva.index,
          onSelecionar: (i) => setState(() => _abaAtiva = AbaAdmin.values[i]),
          abas: abas,
          semMargem: true,
          esticarAltura: true,
          mostrarAssinatura: false,
          builder: (context, aba) {
            final abaSelecionada = AbaAdmin.values[aba.indice];
            return SingleChildScrollView(
              child: abaSelecionada == AbaAdmin.visaoGeral
                  ? conteudoStats(pendentesSnapshot)
                  : conteudoAba(abaSelecionada, pendentesSnapshot),
            );
          },
        );
      },
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
    final alturaCard = (MediaQuery.sizeOf(context).height - kToolbarHeight - 40)
        .clamp(560.0, 819.0);
    // Área de conteúdo do card interno: altura do card menos o espaço do
    // cabeçalho colorido do CustomCard pai (HeaderPaginas + paddings).
    const alturaCabecalho = 90.0;
    final alturaConteudo = alturaCard - alturaCabecalho;

    return CustomCard(
      color: AdminCores.fundoSecao,
      maxWidth: 1450,
      height: alturaCard,
      esticarLargura: true,
      mostrarAssinatura: true,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 730),
          child: const HeaderPaginas(
            text: 'Painel ADM',
            subtitle: 'Gerencie apostas, participantes e a sala',
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
            // paleta "operacional" das outras) e coral para configurações.
            //
            // Mesma sequência (e mesmos valores) da paleta automática do
            // Fichario em ficharios.dart, na mesma ordem: no mobile estas
            // seções viram abas e recebem a cor pela posição na fileira, então
            // manter os dois alinhados é o que faz uma seção ter a MESMA cor
            // nos dois layouts. Ao mexer aqui, mexa lá também.
            const cores = {
              AbaAdmin.participantes: AdminCores.verdeAgua,
              AbaAdmin.ranking: AdminCores.dourado,
              AbaAdmin.sala: AdminCores.roxo,
              AbaAdmin.config: AdminCores.coral,
            };

            Widget card(AbaAdmin aba, {double? larguraExtra}) {
              return SizedBox(
                width: larguraExtra ?? larguraCard,
                child: _CardSecao(
                  meta: kAbasAdmin.firstWhere((m) => m.aba == aba),
                  cor: cores[aba] ?? AdminCores.azul,
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
                  cor: AdminCores.azul,
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
                    card(AbaAdmin.config),
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
/// título) + corpo branco abaixo, mesmo par de cores usado nos outros cards
/// do app (CustomCard colorido por fora, branco por dentro). A cor vem de
/// fora (não do enum) porque duas seções podem compartilhar o mesmo
/// [AbaAdmin] com cores diferentes — caso da Visão geral, que virou dois
/// cards (stats azul, pendentes vermelho).
class _CardSecao extends StatelessWidget {
  final AbaAdminMeta meta;
  final Color cor;
  final Widget child;

  const _CardSecao({
    required this.meta,
    required this.cor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AdminCores.fundoCard,
        borderRadius: AppRadii.circularXl,
        border: Border.all(color: AdminCores.borda),
        boxShadow: [
          BoxShadow(
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
            color: cor,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Icon(meta.icone, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(
                  meta.texto,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}
