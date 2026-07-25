import 'package:bolao_bolado/components/shared/custom_card.dart';
import 'package:bolao_bolado/components/shared/header_paginas.dart';
import 'package:bolao_bolado/components/shared/skeletons.dart';
import 'package:bolao_bolado/components/shell/default_layout.dart';
import 'package:bolao_bolado/components/shell/drawer.dart';
import 'package:bolao_bolado/core/app_radii.dart';
import 'package:bolao_bolado/pages/admin/admin_abas.dart';
import 'package:bolao_bolado/pages/admin/painel_admin_base.dart';
import 'package:bolao_bolado/pages/admin/widgets/admin_widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Painel ADM em cards soltos (sem abas/navegação), todos agrupados dentro
/// de um card pai único com o cabeçalho da página — mesmo padrão de card
/// (colorido por fora, branco por dentro) usado no resto do app. Cada
/// seção — visão geral, pendentes, participantes, ranking, sala, config —
/// é o seu próprio card interno, visíveis ao mesmo tempo, reflindo em 1, 2
/// ou 3 colunas conforme a largura disponível.
///
/// Toda a lógica de estado/ações vive em [PainelAdminMixin] — este widget só
/// monta a grade de cards.
class PainelAdmin extends StatefulWidget {
  const PainelAdmin({super.key});

  @override
  State<PainelAdmin> createState() => _PainelAdminState();
}

class _PainelAdminState extends State<PainelAdmin> with PainelAdminMixin {
  @override
  Widget build(BuildContext context) {
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

    return DefaultLayout(
      drawer: AppDrawer(),
      child: CustomCard(
        color: AdminCores.fundoSecao,
        maxWidth: 1450,
        height: alturaCard,
        esticarLargura: true,
        mostrarAssinatura: true,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 730),
            child: HeaderPaginas(
              text: 'Painel ADM',
              subtitle: 'Gerencie apostas, participantes e a sala',
              trailing: IconButton(
                tooltip: 'Configurações',
                onPressed: _abrirConfig,
                icon: const Icon(Icons.settings_outlined),
                style: IconButton.styleFrom(
                  backgroundColor: AdminCores.fundoTile,
                  foregroundColor: AdminCores.textoSuave,
                ),
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
      ),
    );
  }

  Widget _skeleton() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: SkeletonDashboardStats(),
    );
  }

  // Config saiu da grade de cards e virou um dialog acessível pelo botão de
  // engrenagem no cabeçalho — não é uma seção operacional do dia a dia
  // (skeleton de dev + info do admin logado), então não precisa competir
  // por espaço com participantes/ranking/sala na tela principal.
  Future<void> _abrirConfig() {
    return showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AdminCores.fundoCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.circularXxl),
        title: const Text(
          'Configurações',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(child: AbaConfig(adminUser: adminUser)),
        ),
        actions: [
          TextButton(
            onPressed: () => dialogContext.pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
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
            // 1 coluna em telas estreitas (mobile), 2 a partir de ~760px,
            // 3 a partir de ~1180px — cada card mantém uma largura mínima
            // legível em vez de espremer texto/tabelas.
            final largura = constraints.maxWidth;
            final colunas = largura >= 1180 ? 3 : (largura >= 760 ? 2 : 1);
            const espacamento = 16.0;
            final larguraCard =
                (largura - espacamento * (colunas - 1)) / colunas;
            // Cor do cabeçalho por seção — cada uma com um tom próprio e um
            // porquê: azul para o resumo geral (ação primária/neutra),
            // verde-água para participantes (tom "de gente" do gradiente
            // do app), dourado para ranking (associação com prêmio/pódio)
            // e roxo para sala (administrativo/config, deliberadamente
            // fora da paleta "operacional" das outras). Config não entra
            // aqui: virou um dialog no botão de engrenagem do cabeçalho,
            // não uma seção da grade.
            const cores = {
              AbaAdmin.participantes: AdminCores.verdeAgua,
              AbaAdmin.ranking: AdminCores.dourado,
              AbaAdmin.sala: AdminCores.roxo,
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
