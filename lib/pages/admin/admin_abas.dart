import 'package:bolao_bolado/components/formatters/formatters.dart';
import 'package:bolao_bolado/components/formatters/money_input_format.dart';
import 'package:bolao_bolado/components/shared/avatar_emoji.dart';
import 'package:bolao_bolado/components/shared/buttons.dart';
import 'package:bolao_bolado/components/shared/custom_fields.dart';
import 'package:bolao_bolado/components/shared/custom_show_dialog.dart';
import 'package:bolao_bolado/components/shared/skeletons.dart';
import 'package:bolao_bolado/components/shared/snackbar_deslizante.dart';
import 'package:bolao_bolado/core/app_radii.dart';
import 'package:bolao_bolado/core/debug_flags.dart';
import 'package:bolao_bolado/core/responsive.dart';
import 'package:bolao_bolado/pages/admin/widgets/admin_widgets.dart';
import 'package:bolao_bolado/services/avatar/avatar_service.dart';
import 'package:bolao_bolado/services/bet/bet_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Seções do painel admin, hoje renderizadas como cards independentes (sem
/// abas) no dashboard — o nome "aba" ficou do desenho anterior por navegação,
/// mas o enum ainda serve para identificar cada seção de forma estável.
enum AbaAdmin { visaoGeral, participantes, ranking, sala, config }

/// Metadados (rótulo + ícone) de cada seção. Fonte única para o cabeçalho de
/// cada card do dashboard.
class AbaAdminMeta {
  final AbaAdmin aba;
  final String texto;
  final IconData icone;

  const AbaAdminMeta({
    required this.aba,
    required this.texto,
    required this.icone,
  });
}

// Não inclui AbaAdmin.visaoGeral: essa seção virou dois cards próprios
// (stats + pendentes) montados à parte no topo do dashboard, não um card
// genérico como os demais — ver AdminCardStats/AdminCardPendentes.
//
// Config está aqui: voltou a ser um card da grade (e uma aba do fichário no
// mobile), no lugar do dialog que abria pelo botão de engrenagem. Um botão
// solto no cabeçalho escondia a seção atrás de um clique extra sem ganho —
// como card ela segue o mesmo padrão visual das outras e fica visível junto
// com o resto do painel.
const List<AbaAdminMeta> kAbasAdmin = [
  AbaAdminMeta(
    aba: AbaAdmin.participantes,
    texto: 'Participantes',
    icone: Icons.groups_outlined,
  ),
  AbaAdminMeta(
    aba: AbaAdmin.ranking,
    texto: 'Ranking',
    icone: Icons.leaderboard_outlined,
  ),
  AbaAdminMeta(
    aba: AbaAdmin.sala,
    texto: 'Sala',
    icone: Icons.meeting_room_outlined,
  ),
  AbaAdminMeta(
    aba: AbaAdmin.config,
    texto: 'Configurações',
    icone: Icons.settings_outlined,
  ),
];

// =============================================================================
// Visão geral: card de estatísticas (compacto) + card de pendentes (altura
// fixa própria, com scroll interno) — dois cards separados no dashboard em
// vez de um único bloco que crescia sem limite com a quantidade de
// pendentes, o que cortava esquisito no fim da página.
// =============================================================================

class AdminCardStats extends StatelessWidget {
  final List<Map<String, dynamic>> bets;
  final bool carregandoStats;
  final int totalPendentes;
  final double precoCota;
  // O bento grid (módulos de tamanhos diferentes preenchendo uma altura
  // fixa via Expanded) só funciona no layout desktop, onde o _CardSecao
  // reserva uma altura exata pro conteúdo. No fichário mobile a folha fica
  // dentro de um SingleChildScrollView (altura infinita) — Expanded nesse
  // contexto lança RenderFlex e o Flutter web engole a exceção, deixando a
  // aba inteira em branco. Por isso o mobile usa este modo simples: um tile
  // por linha, empilhado, encolhendo pro próprio conteúdo (como era antes
  // do bento grid existir).
  final bool bentoGrid;

  const AdminCardStats({
    super.key,
    required this.bets,
    required this.carregandoStats,
    required this.totalPendentes,
    required this.precoCota,
    this.bentoGrid = true,
  });

  @override
  Widget build(BuildContext context) {
    final cores = AdminCores.de(context);
    if (carregandoStats) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: SkeletonDashboardStats(),
      );
    }

    final totalApostado = bets.fold<double>(
      0,
      (soma, item) => soma + ((item['valor'] as num?)?.toDouble() ?? 0),
    );
    final totalPremios = bets.fold<double>(
      0,
      (soma, item) => soma + ((item['premio'] as num?)?.toDouble() ?? 0),
    );
    final totalCotas = bets.fold<int>(
      0,
      (soma, item) => soma + ((item['cotas'] as num?)?.toInt() ?? 0),
    );
    final apostasVerificadas = bets.where((b) => b['verificado'] == true);
    final verificados = apostasVerificadas.length;
    final totalVerificado = apostasVerificadas.fold<double>(
      0,
      (soma, item) => soma + ((item['valor'] as num?)?.toDouble() ?? 0),
    );

    // "Bento grid": módulos de tamanhos diferentes lado a lado (mesma ideia
    // do ícone de grade da própria seção "Visão geral"), não uma pilha de
    // retângulos iguais. Linha de cima é o bloco principal — prêmio (2/3 da
    // largura, o número que mais importa) ao lado das pendências (1/3, alto
    // e colorido por estado — a única informação aqui que pede ação do
    // admin). Linha de baixo divide o resto em 4 módulos menores e iguais.
    // As duas linhas usam Expanded (não LayoutBuilder+Wrap): a altura do
    // card já é sempre finita (sem scroll interno), e Row/Column com
    // Expanded direto é mais simples que calcular largura na mão.
    const espacamento = 12.0;
    final erroPendentes = totalPendentes == -1;
    // Sempre modo "verificado" (valor arrecadado + progresso), tenha ou não
    // pendência — antes o módulo virava vermelho e trocava o valor pela
    // CONTAGEM de pendentes assim que havia 1 sequer, escondendo o dado que
    // o admin queria ver (quanto já foi confirmado). Pendência agora é só
    // um badge pequeno no canto (ver AdminCardStats._ModuloPendencias),
    // sem tomar o lugar do número principal.
    final corVerificado = erroPendentes ? cores.textoSuave : cores.verde;
    final iconeVerificado = erroPendentes
        ? Icons.error_outline
        : Icons.task_alt;
    final valorVerificado = erroPendentes
        ? '—'
        : Formatters.moeda.format(totalVerificado);
    final fracaoVerificado = bets.isEmpty ? null : verificados / bets.length;

    if (!bentoGrid) {
      // Mobile: um tile por linha, empilhado — mesmo padrão de antes do
      // bento grid, sem Expanded/altura forçada.
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminStatDestaque(
              icon: Icons.emoji_events_outlined,
              label: 'Prêmio total',
              value: Formatters.moeda.format(totalPremios),
              color: cores.dourado,
              sublabel: '${Formatters.moeda.format(precoCota)} por cota',
            ),
            const SizedBox(height: espacamento),
            _ModuloPendencias(
              cor: corVerificado,
              icon: iconeVerificado,
              valor: valorVerificado,
              label: 'Verificado',
              fracaoVerificado: fracaoVerificado,
              totalPendentes: erroPendentes ? null : totalPendentes,
            ),
            const SizedBox(height: espacamento),
            AdminStatTile(
              icon: Icons.groups_outlined,
              label: 'Participantes',
              value: '${bets.length}',
              color: cores.azul,
            ),
            const SizedBox(height: espacamento),
            AdminStatTile(
              icon: Icons.payments_outlined,
              label: 'Total arrecadado',
              value: Formatters.moeda.format(totalApostado),
              color: cores.verde,
            ),
            const SizedBox(height: espacamento),
            AdminStatTile(
              icon: Icons.confirmation_number_outlined,
              label: 'Cotas vendidas',
              value: '$totalCotas',
              color: cores.dourado,
            ),
            const SizedBox(height: espacamento),
            AdminStatTile(
              icon: Icons.verified_outlined,
              label: 'Verificadas',
              value: '$verificados de ${bets.length}',
              color: cores.verdeAgua,
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 2,
                  child: AdminStatDestaque(
                    icon: Icons.emoji_events_outlined,
                    label: 'Prêmio total',
                    value: Formatters.moeda.format(totalPremios),
                    color: cores.dourado,
                    preencherAltura: true,
                    sublabel: '${Formatters.moeda.format(precoCota)} por cota',
                  ),
                ),
                const SizedBox(width: espacamento),
                Expanded(
                  child: _ModuloPendencias(
                    cor: corVerificado,
                    icon: iconeVerificado,
                    valor: valorVerificado,
                    label: 'Verificado',
                    // Progresso de verificação preenche o espaço vertical
                    // que sobrava no módulo com uma informação nova de
                    // verdade (não repete os números de cima): quanto da
                    // fila já foi conferida, sem precisar abrir a aba
                    // Participantes pra ter essa ideia.
                    fracaoVerificado: fracaoVerificado,
                    totalPendentes: erroPendentes ? null : totalPendentes,
                    preencherAltura: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: espacamento),
          Expanded(
            flex: 4,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: AdminStatTile(
                          icon: Icons.groups_outlined,
                          label: 'Participantes',
                          value: '${bets.length}',
                          color: cores.azul,
                          preencherAltura: true,
                        ),
                      ),
                      const SizedBox(height: espacamento),
                      Expanded(
                        child: AdminStatTile(
                          icon: Icons.confirmation_number_outlined,
                          label: 'Cotas',
                          value: '$totalCotas',
                          color: cores.dourado,
                          preencherAltura: true,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: espacamento),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: AdminStatTile(
                          icon: Icons.payments_outlined,
                          label: 'Total arrecadado',
                          value: Formatters.moeda.format(totalApostado),
                          color: cores.verde,
                          preencherAltura: true,
                        ),
                      ),
                      const SizedBox(height: espacamento),
                      Expanded(
                        child: AdminStatTile(
                          icon: Icons.verified_outlined,
                          label: 'Verificadas',
                          value: '$verificados de ${bets.length}',
                          color: cores.verdeAgua,
                          preencherAltura: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Módulo alto de "verificado" do bento grid da Visão geral — ao lado do
/// destaque de prêmio, mesma altura. Sempre mostra o valor arrecadado das
/// apostas verificadas (cor/ícone fixos, sem alternar pra vermelho): antes
/// o módulo virava "N Pendente(s)" assim que havia 1 pendência sequer,
/// escondendo o número que o admin queria ver. Pendência agora é só um
/// badge pequeno no canto superior direito — visível, mas sem tomar o
/// lugar do dado principal.
class _ModuloPendencias extends StatelessWidget {
  final Color cor;
  final IconData icon;
  final String valor;
  final String label;
  // Fração de apostas já verificadas (0 a 1) — null quando não há nenhuma
  // aposta ainda (não faz sentido mostrar 0% de nada). Preenche o espaço
  // vertical que sobrava no módulo com um dado novo (progresso da fila),
  // em vez de repetir os números que já aparecem nos tiles de baixo.
  final double? fracaoVerificado;
  // Null quando erro ao carregar (não desenha badge nenhum); 0 também não
  // desenha (nada pendente pra avisar); só aparece quando > 0.
  final int? totalPendentes;
  // Ver AdminStatTile.preencherAltura — mesma ideia: só true no bento grid
  // desktop, onde este módulo vive dentro de um Expanded com altura finita.
  // No mobile o Column ancestral não tem Expanded (fica num
  // SingleChildScrollView, altura infinita) — Column com mainAxisSize.max
  // nesse contexto lança RenderFlex, então lá o widget encolhe pro próprio
  // conteúdo (mainAxisSize.min) em vez de tentar preencher.
  final bool preencherAltura;

  const _ModuloPendencias({
    required this.cor,
    required this.icon,
    required this.valor,
    required this.label,
    this.fracaoVerificado,
    this.totalPendentes,
    this.preencherAltura = false,
  });

  @override
  Widget build(BuildContext context) {
    final cores = AdminCores.de(context);
    final temPendencia = (totalPendentes ?? 0) > 0;
    return Container(
      width: double.infinity,
      height: preencherAltura ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.1),
        borderRadius: AppRadii.circularLg,
        border: Border.all(color: cor.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: preencherAltura ? MainAxisSize.max : MainAxisSize.min,
        // stretch (não o center padrão): sem isso o Align do badge abaixo
        // encolhe pra própria largura mínima e "topRight" não tem espaço
        // sobrando pra empurrar o badge de verdade — os textos internos já
        // usam TextAlign.center, então esticar a Column não muda como eles
        // aparecem.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (temPendencia)
            Align(
              alignment: Alignment.topRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: cores.vermelho,
                  borderRadius: AppRadii.circularPill,
                ),
                child: Text(
                  totalPendentes == 1
                      ? '1 pendente'
                      : '$totalPendentes pendentes',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          if (temPendencia) const SizedBox(height: 10),
          Icon(icon, color: cor, size: 52),
          const SizedBox(height: 14),
          Text(
            valor,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w800,
              color: cor,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: cores.texto,
            ),
          ),
          if (fracaoVerificado != null) ...[
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: AppRadii.circularPill,
              child: LinearProgressIndicator(
                value: fracaoVerificado!.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: cor.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(cor),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${(fracaoVerificado! * 100).round()}% da fila verificada',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cores.textoSuave,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class AdminCardPendentes extends StatelessWidget {
  final AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> pendentesSnapshot;
  final List<Map<String, dynamic>>? fakePendentes;
  final Future<void> Function(DocumentReference<Map<String, dynamic>>)
  onConfirmar;
  final void Function(int) onConfirmarFake;
  final VoidCallback onLancarManual;
  final VoidCallback onSimular;
  final VoidCallback onLimparSimulacao;
  // Altura fixa do corpo da lista — o card nunca cresce além disso, sempre
  // rolando por dentro; evita o card esticar sem limite com a quantidade de
  // pendentes e cortar esquisito no fim da página.
  final double altura;

  const AdminCardPendentes({
    super.key,
    required this.pendentesSnapshot,
    required this.fakePendentes,
    required this.onConfirmar,
    required this.onConfirmarFake,
    required this.onLancarManual,
    required this.onSimular,
    required this.onLimparSimulacao,
    this.altura = 420,
  });

  @override
  Widget build(BuildContext context) {
    final cores = AdminCores.de(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Apostas pendentes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: cores.texto,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Lançar aposta manual',
                onPressed: onLancarManual,
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 20),
              ),
              if (fakePendentes == null)
                IconButton(
                  tooltip: 'Simular apostas (dev)',
                  onPressed: onSimular,
                  icon: const Icon(Icons.auto_awesome, size: 20),
                )
              else
                IconButton(
                  tooltip: 'Limpar simulação',
                  onPressed: onLimparSimulacao,
                  icon: const Icon(Icons.close, size: 20),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(height: altura, child: _corpoPendentes(context)),
        ],
      ),
    );
  }

  Widget _corpoPendentes(BuildContext context) {
    final cores = AdminCores.de(context);
    if (fakePendentes != null) {
      return _ListaPendentes(
        itens: [
          for (var i = 0; i < fakePendentes!.length; i++)
            _ItemPendente(
              nome: fakePendentes![i]['nome']?.toString() ?? '—',
              valor: (fakePendentes![i]['valor'] as num?)?.toDouble() ?? 0,
              tooltip: 'Confirmar aposta (simulada)',
              onConfirmar: () => onConfirmarFake(i),
            ),
        ],
      );
    }

    if (pendentesSnapshot.connectionState == ConnectionState.waiting) {
      return const SingleChildScrollView(
        child: SkeletonListaApostasPendentes(),
      );
    }

    if (pendentesSnapshot.hasError) {
      return AdminEstadoVazio(
        icon: Icons.error_outline,
        cor: cores.vermelho,
        mensagem:
            'Erro ao carregar apostas pendentes:\n${pendentesSnapshot.error}',
      );
    }

    // Ordenado no cliente: 'data-hora' usa serverTimestamp() e fica null no
    // snapshot otimista local antes da confirmação do servidor.
    final docs = [...pendentesSnapshot.data?.docs ?? []]
      ..sort((a, b) {
        final tsA = a.data()['data-hora'] as Timestamp?;
        final tsB = b.data()['data-hora'] as Timestamp?;
        if (tsA == null && tsB == null) return 0;
        if (tsA == null) return -1;
        if (tsB == null) return 1;
        return tsB.compareTo(tsA);
      });

    if (docs.isEmpty) {
      return AdminEstadoVazio(
        icon: Icons.check_circle_outline,
        cor: cores.verde,
        mensagem: 'Nenhuma aposta pendente de verificação.',
      );
    }

    return _ListaPendentes(
      itens: [
        for (final doc in docs)
          Builder(
            builder: (_) {
              final dados = doc.data();
              return _ItemPendente(
                nome: dados['nome']?.toString() ?? '—',
                valor: double.tryParse(dados['valor'].toString()) ?? 0,
                tooltip: 'Confirmar aposta',
                onConfirmar: () => onConfirmar(doc.reference),
              );
            },
          ),
      ],
    );
  }
}

// Lista de itens pendentes, sempre com scroll interno próprio — o card que
// a contém tem altura fixa (ver AdminCardPendentes.altura), então a lista
// nunca estica o card, só rola por dentro dele.
class _ListaPendentes extends StatelessWidget {
  final List<Widget> itens;

  const _ListaPendentes({required this.itens});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < itens.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            itens[i],
          ],
        ],
      ),
    );
  }
}

class _ItemPendente extends StatelessWidget {
  final String nome;
  final double valor;
  final String tooltip;
  final VoidCallback onConfirmar;

  const _ItemPendente({
    required this.nome,
    required this.valor,
    required this.tooltip,
    required this.onConfirmar,
  });

  @override
  Widget build(BuildContext context) {
    final cores = AdminCores.de(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cores.fundoCard,
        borderRadius: AppRadii.circularSmd,
        border: Border.all(color: cores.borda),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  nome,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: cores.texto,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  Formatters.moeda.format(valor),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cores.verde,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: tooltip,
            onPressed: onConfirmar,
            icon: const Text('✅', style: TextStyle(fontSize: 22)),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Aba: Participantes (gerenciamento — editar / remover / verificar)
// =============================================================================

class AbaParticipantes extends StatefulWidget {
  final List<Map<String, dynamic>> bets;
  final bool carregando;
  final VoidCallback onLancarManual;
  final Future<void> Function(Map<String, dynamic>) onEditarValor;
  final Future<void> Function(Map<String, dynamic>) onRemover;
  final Future<void> Function(Map<String, dynamic>) onAlternarVerificacao;

  const AbaParticipantes({
    super.key,
    required this.bets,
    required this.carregando,
    required this.onLancarManual,
    required this.onEditarValor,
    required this.onRemover,
    required this.onAlternarVerificacao,
  });

  @override
  State<AbaParticipantes> createState() => _AbaParticipantesState();
}

class _AbaParticipantesState extends State<AbaParticipantes> {
  // Linhas visíveis por página — o card tem altura fixa (padrão de todos os
  // cards da grade) e não rola mais internamente, então a lista precisa
  // caber sozinha: 6 linhas + o resto do cabeçalho (busca, filtros, paginação)
  // é o que fecha dentro dos 560px de _alturaCorpoPadrao.
  static const _porPagina = 6;

  String _busca = '';
  // 0=todos, 1=pendentes, 2=verificados
  int _filtro = 0;
  int _pagina = 0;

  List<Map<String, dynamic>> get _filtrados {
    final termo = _busca.trim().toLowerCase();
    return widget.bets.where((b) {
      final nome = (b['nome'] ?? '').toString().toLowerCase();
      if (termo.isNotEmpty && !nome.contains(termo)) return false;
      if (_filtro == 1 && b['verificado'] == true) return false;
      if (_filtro == 2 && b['verificado'] != true) return false;
      return true;
    }).toList();
  }

  void _mudarFiltro(int i) => setState(() {
    _filtro = i;
    _pagina = 0;
  });

  void _mudarBusca(String v) => setState(() {
    _busca = v;
    _pagina = 0;
  });

  @override
  Widget build(BuildContext context) {
    final cores = AdminCores.de(context);
    if (widget.carregando) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: SkeletonListaApostasPendentes(),
      );
    }

    final filtrados = _filtrados;
    final totalPaginas = filtrados.isEmpty
        ? 1
        : (filtrados.length / _porPagina).ceil();
    final pagina = _pagina.clamp(0, totalPaginas - 1);
    final inicio = pagina * _porPagina;
    final itensPagina = filtrados.skip(inicio).take(_porPagina).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Busca sozinha na primeira linha — é a ação mais comum (achar
          // alguém específico), então fica em destaque acima de tudo.
          _CampoBuscaAdmin(onChanged: _mudarBusca),
          const SizedBox(height: 12),
          Row(
            children: [
              _FiltroChips(selecionado: _filtro, onSelecionar: _mudarFiltro),
              const SizedBox(width: 12),
              // Divisor vertical separa visualmente "Lançar" dos filtros —
              // ele não filtra nada, é uma ação, e ficar colado nos chips
              // dava a entender que era mais uma opção de filtro. Sem
              // Expanded/Spacer nos chips: antes o Expanded esticava até o
              // botão e deixava o espaço vazio sobrando DEPOIS do divisor
              // (mais perto do botão do que dos chips) — aqui o respiro é o
              // mesmo (12px) dos dois lados do traço.
              Container(width: 1, height: 28, color: cores.borda),
              const SizedBox(width: 12),
              PrimaryButton(
                text: 'Lançar',
                width: 88,
                compact: true,
                onTap: widget.onLancarManual,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: filtrados.isEmpty
                ? AdminEstadoVazio(
                    icon: Icons.sentiment_dissatisfied_outlined,
                    cor: cores.textoSuave,
                    mensagem: 'Nenhum participante encontrado.',
                  )
                : AdminSecaoCard(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 6,
                    ),
                    // SingleChildScrollView como rede de segurança — ver o
                    // mesmo comentário em AbaRanking: Column sozinho não
                    // clipa overflow, então se a página não coubesse
                    // exatamente na altura disponível o conteúdo vazava por
                    // cima do rodapé (paginação/contagem) em vez de só
                    // rolar por dentro.
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          for (var i = 0; i < itensPagina.length; i++) ...[
                            if (i > 0)
                              Divider(
                                height: 1,
                                thickness: 1,
                                color: cores.borda,
                              ),
                            _LinhaParticipante(
                              aposta: itensPagina[i],
                              onEditar: () =>
                                  widget.onEditarValor(itensPagina[i]),
                              onRemover: () => widget.onRemover(itensPagina[i]),
                              onAlternarVerificacao: () =>
                                  widget.onAlternarVerificacao(itensPagina[i]),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 10),
          // Contagem no mesmo eixo da paginação (à direita, no lugar do
          // Spacer quando não há páginas): antes essa linha vinha sozinha
          // ACIMA da lista, tirando uma linha inteira de altura útil do
          // card — e como a altura do card é fixa, a última linha da
          // página perdia espaço e cortava baixinha, diferente das outras.
          Row(
            children: [
              if (totalPaginas > 1)
                Expanded(
                  child: _Paginador(
                    pagina: pagina,
                    totalPaginas: totalPaginas,
                    onAnterior: pagina > 0
                        ? () => setState(() => _pagina--)
                        : null,
                    onProximo: pagina < totalPaginas - 1
                        ? () => setState(() => _pagina++)
                        : null,
                  ),
                )
              else
                const Spacer(),
              Text(
                filtrados.length == widget.bets.length
                    ? '${widget.bets.length} participantes'
                    : '${filtrados.length} de ${widget.bets.length} participantes',
                style: TextStyle(fontSize: 12, color: cores.textoSuave),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Setas + "Página X de Y" — navegação da lista de participantes quando o
/// filtro atual tem mais que uma página. Substitui o scroll interno que o
/// card tinha antes: com altura fixa em todos os cards da grade, rolar por
/// dentro empilhava dois scrolls (o da página e o do card) e ficava confuso.
class _Paginador extends StatelessWidget {
  final int pagina;
  final int totalPaginas;
  final VoidCallback? onAnterior;
  final VoidCallback? onProximo;

  const _Paginador({
    required this.pagina,
    required this.totalPaginas,
    required this.onAnterior,
    required this.onProximo,
  });

  @override
  Widget build(BuildContext context) {
    final cores = AdminCores.de(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: onAnterior,
          icon: const Icon(Icons.chevron_left),
          visualDensity: VisualDensity.compact,
        ),
        Text(
          'Página ${pagina + 1} de $totalPaginas',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: cores.textoSuave,
          ),
        ),
        IconButton(
          onPressed: onProximo,
          icon: const Icon(Icons.chevron_right),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

class _FiltroChips extends StatelessWidget {
  final int selecionado;
  final void Function(int) onSelecionar;

  const _FiltroChips({required this.selecionado, required this.onSelecionar});

  @override
  Widget build(BuildContext context) {
    final cores = AdminCores.de(context);
    // Cor de cada chip combina com o que ele filtra: azul neutro pra "todos"
    // (não é um estado, é ausência de filtro), vermelho pra "pendentes"
    // (mesma cor de alerta usada no resto do painel pra apostas não
    // verificadas) e verde pra "verificados" (estado positivo/concluído).
    final opcoes = [
      ('Todos', cores.azul),
      ('Pendentes', cores.vermelho),
      ('Verificados', cores.verde),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < opcoes.length; i++)
          ChoiceChip(
            label: Text(opcoes[i].$1),
            selected: selecionado == i,
            onSelected: (_) => onSelecionar(i),
            showCheckmark: false,
            labelStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selecionado == i ? Colors.white : opcoes[i].$2,
            ),
            selectedColor: opcoes[i].$2,
            backgroundColor: opcoes[i].$2.withValues(alpha: 0.1),
            side: BorderSide(
              color: selecionado == i
                  ? opcoes[i].$2
                  : opcoes[i].$2.withValues(alpha: 0.35),
            ),
            shape: RoundedRectangleBorder(borderRadius: AppRadii.circularPill),
          ),
      ],
    );
  }
}

class _LinhaParticipante extends StatelessWidget {
  final Map<String, dynamic> aposta;
  final VoidCallback onEditar;
  final VoidCallback onRemover;
  final VoidCallback onAlternarVerificacao;

  const _LinhaParticipante({
    required this.aposta,
    required this.onEditar,
    required this.onRemover,
    required this.onAlternarVerificacao,
  });

  @override
  Widget build(BuildContext context) {
    final cores = AdminCores.de(context);
    final nome = aposta['nome']?.toString() ?? '—';
    final valor = (aposta['valor'] as num?)?.toDouble() ?? 0;
    final cotas = (aposta['cotas'] as num?)?.toInt() ?? 0;
    final verificado = aposta['verificado'] == true;
    final editado = aposta['editadoAposVerificacao'] == true;
    final manual = aposta['criadoPeloAdmin'] == true;
    final corAvatar = aposta['avatarColor'] is int
        ? Color(aposta['avatarColor'] as int)
        : cores.azul;
    final emojiAvatar = aposta['avatarEmoji'] is String
        ? aposta['avatarEmoji'] as String
        : kEmojiAvatarPadrao;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          AvatarEmoji(tamanho: 36, cor: corAvatar, emoji: emojiAvatar),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        nome,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: cores.texto,
                        ),
                      ),
                    ),
                    SizedBox(width: 6),
                    if (editado) _Badge(texto: 'alterada', cor: cores.dourado),
                    if (manual) ...[
                      if (editado) const SizedBox(width: 6),
                      _Badge(texto: 'manual', cor: cores.texto),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${Formatters.moeda.format(valor)}  ·  '
                  '$cotas ${cotas == 1 ? "cota" : "cotas"}',
                  style: TextStyle(fontSize: 12, color: cores.textoSuave),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: verificado ? 'Marcar como pendente' : 'Verificar',
            onPressed: onAlternarVerificacao,
            icon: Icon(
              verificado ? Icons.check_circle : Icons.check_circle_outline,
              color: verificado ? cores.verde : cores.textoSuave,
              size: 22,
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Mais ações',
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (v) {
              if (v == 'editar') onEditar();
              if (v == 'remover') onRemover();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'editar',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Editar valor'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'remover',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 18, color: cores.vermelho),
                    const SizedBox(width: 10),
                    Text('Remover', style: TextStyle(color: cores.vermelho)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String texto;
  final Color cor;
  const _Badge({required this.texto, required this.cor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.14),
        borderRadius: AppRadii.circularSm,
      ),
      child: Text(
        texto,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: cor),
      ),
    );
  }
}

// =============================================================================
// Aba: Ranking (top cotas + distribuição + export)
// =============================================================================

class AbaRanking extends StatefulWidget {
  final List<Map<String, dynamic>> bets;
  final bool carregando;

  const AbaRanking({super.key, required this.bets, required this.carregando});

  @override
  State<AbaRanking> createState() => _AbaRankingState();
}

class _AbaRankingState extends State<AbaRanking> {
  // 10 (não 6, como em Participantes): o Ranking não tem busca nem filtros
  // acima da lista, só o botão de exportar — sobra altura suficiente pro
  // pedido original de mostrar "os 10 primeiros" de cada vez, mesmo com o
  // card em altura fixa e sem scroll interno.
  static const _porPagina = 10;

  int _pagina = 0;

  @override
  Widget build(BuildContext context) {
    final cores = AdminCores.de(context);
    if (widget.carregando) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: SkeletonDashboardStats(),
      );
    }

    final rankingCompleto = [...widget.bets]
      ..sort((a, b) {
        final ca = (a['cotas'] as num?)?.toInt() ?? 0;
        final cb = (b['cotas'] as num?)?.toInt() ?? 0;
        return cb.compareTo(ca);
      });
    final maxCotas = rankingCompleto.isEmpty
        ? 0
        : (rankingCompleto.first['cotas'] as num?)?.toInt() ?? 0;
    final coresRanking = [cores.dourado, cores.azul, cores.verdeAgua];

    final totalPaginas = rankingCompleto.isEmpty
        ? 1
        : (rankingCompleto.length / _porPagina).ceil();
    final pagina = _pagina.clamp(0, totalPaginas - 1);
    final inicio = pagina * _porPagina;
    final itensPagina = rankingCompleto.skip(inicio).take(_porPagina).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: rankingCompleto.isEmpty
                ? AdminEstadoVazio(
                    icon: Icons.leaderboard_outlined,
                    cor: cores.textoSuave,
                    mensagem: 'Nenhuma aposta para ranquear ainda.',
                  )
                : AdminSecaoCard(
                    child: SingleChildScrollView(
                      // Column comum não clipa o próprio overflow — se a
                      // página (10 linhas no desktop, menos no mobile,
                      // conforme a altura real da folha) não couber
                      // exatamente na altura disponível, o conteúdo vazava
                      // por cima do rodapé de paginação em vez de só rolar
                      // por dentro. Isso não deveria acontecer no caminho
                      // normal (a altura já é dimensionada pra caber), mas é
                      // a rede de segurança pra não voltar a cortar visual.
                      child: Column(
                        children: [
                          for (var i = 0; i < itensPagina.length; i++) ...[
                            if (i > 0) const SizedBox(height: 16),
                            AdminBarraDistribuicao(
                              rotulo:
                                  '${inicio + i + 1}. ${itensPagina[i]['nome'] ?? "—"}',
                              valor:
                                  '${(itensPagina[i]['cotas'] as num?)?.toInt() ?? 0} cotas'
                                  '  ·  '
                                  '${Formatters.moeda.format((itensPagina[i]['premio'] as num?)?.toDouble() ?? 0)}',
                              fracao: maxCotas == 0
                                  ? 0
                                  : ((itensPagina[i]['cotas'] as num?)
                                                ?.toInt() ??
                                            0) /
                                        maxCotas,
                              cor:
                                  coresRanking[(inicio + i) %
                                      coresRanking.length],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
          ),
          if (totalPaginas > 1) ...[
            const SizedBox(height: 10),
            _Paginador(
              pagina: pagina,
              totalPaginas: totalPaginas,
              onAnterior: pagina > 0 ? () => setState(() => _pagina--) : null,
              onProximo: pagina < totalPaginas - 1
                  ? () => setState(() => _pagina++)
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// Aba: Sala (editar prêmio / data / chave PIX / valor máximo)
// =============================================================================

class AbaSala extends StatefulWidget {
  final String? salaId;
  final Map<String, dynamic> dadosSala;
  final bool carregando;
  final Future<void> Function() onSalvo;

  const AbaSala({
    super.key,
    required this.salaId,
    required this.dadosSala,
    required this.carregando,
    required this.onSalvo,
  });

  @override
  State<AbaSala> createState() => _AbaSalaState();
}

class _AbaSalaState extends State<AbaSala> {
  final _formKey = GlobalKey<FormState>();
  final _premioController = TextEditingController();
  final _valorMaximoController = TextEditingController();
  final _pixController = TextEditingController();
  final _dataController = TextEditingController();
  final _horaController = TextEditingController();
  DateTime? _dataSelecionada;
  TimeOfDay? _horaSelecionada;
  bool _salvando = false;
  bool _preenchido = false;

  @override
  void didUpdateWidget(covariant AbaSala oldWidget) {
    super.didUpdateWidget(oldWidget);
    _preencherSeNecessario();
  }

  @override
  void initState() {
    super.initState();
    _preencherSeNecessario();
  }

  // Só preenche os campos uma vez, quando os dados da sala chegam — não
  // sobrescreve o que o admin já digitou a cada rebuild do pai.
  void _preencherSeNecessario() {
    if (_preenchido || widget.carregando || widget.dadosSala.isEmpty) return;
    final d = widget.dadosSala;

    final premio = (d['premio'] as num?)?.toDouble();
    if (premio != null) {
      _premioController.text = Formatters.moedaSemSimbolo.format(premio).trim();
    }
    final valorMaximo = (d['valorMaximo'] as num?)?.toDouble();
    if (valorMaximo != null) {
      _valorMaximoController.text = Formatters.moedaSemSimbolo
          .format(valorMaximo)
          .trim();
    }
    _pixController.text = d['chavePix']?.toString() ?? '';

    final dataHora = d['dataHora'];
    if (dataHora is Timestamp) {
      final dt = dataHora.toDate();
      _dataSelecionada = dt;
      _horaSelecionada = TimeOfDay(hour: dt.hour, minute: dt.minute);
      _dataController.text = Formatters.data.format(dt);
      _horaController.text = CustomTimeField.format(_horaSelecionada!);
    }
    _preenchido = true;
  }

  @override
  void dispose() {
    _premioController.dispose();
    _valorMaximoController.dispose();
    _pixController.dispose();
    _dataController.dispose();
    _horaController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (widget.salaId == null) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _salvando = true);
    try {
      final dados = <String, Object?>{'chavePix': _pixController.text.trim()};
      final premio = MoneyInputFormat.parse(_premioController.text);
      if (premio != null) dados['premio'] = premio;
      final valorMaximo = MoneyInputFormat.parse(_valorMaximoController.text);
      if (valorMaximo != null) dados['valorMaximo'] = valorMaximo;

      if (_dataSelecionada != null && _horaSelecionada != null) {
        final dt = DateTime(
          _dataSelecionada!.year,
          _dataSelecionada!.month,
          _dataSelecionada!.day,
          _horaSelecionada!.hour,
          _horaSelecionada!.minute,
        );
        dados['dataHora'] = Timestamp.fromDate(dt);
      }

      await atualizarDadosSala(salaId: widget.salaId!, dados: dados);
      await widget.onSalvo();
      if (!mounted) return;
      setState(() => _salvando = false);
      mostrarSnackBarDeslizante(
        context,
        corFundo: AdminCores.de(context).verde,
        conteudo: const Text('Dados da sala atualizados'),
      );
    } catch (e) {
      debugPrint('Erro ao salvar sala: $e');
      if (!mounted) return;
      setState(() => _salvando = false);
      CustomShowDialog.show(context, 'Erro ao salvar. Tente novamente.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.carregando) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: SkeletonFormulario(
          maxWidth: double.infinity,
          linhas: [
            [double.infinity],
            [double.infinity],
            [double.infinity, double.infinity],
            [double.infinity],
          ],
        ),
      );
    }

    final cores = AdminCores.de(context);
    final nomeSala = widget.dadosSala['nome']?.toString() ?? 'Sala principal';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            AdminTituloSecao(
              texto: nomeSala,
              icone: Icons.meeting_room_outlined,
            ),
            const SizedBox(height: 4),
            Text(
              'Edite os dados principais da sala sem sair do painel.',
              style: TextStyle(fontSize: 13, color: cores.textoSuave),
            ),
            const SizedBox(height: 16),
            CustomField(
              hint: 'Prêmio total',
              icon: Icons.emoji_events_outlined,
              isNumeric: true,
              controller: _premioController,
              maxWidth: double.infinity,
              prefix: const Text('R\$ '),
            ),
            const SizedBox(height: 14),
            CustomField(
              hint: 'Valor máximo por aposta',
              icon: Icons.trending_up,
              isNumeric: true,
              controller: _valorMaximoController,
              maxWidth: double.infinity,
              prefix: const Text('R\$ '),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final dataField = CustomDateField(
                  hint: 'Data do sorteio',
                  controller: _dataController,
                  maxWidth: double.infinity,
                  initialDate: _dataSelecionada,
                  onPicked: (d) => _dataSelecionada = d,
                );
                final horaField = CustomTimeField(
                  hint: 'Hora',
                  controller: _horaController,
                  maxWidth: double.infinity,
                  initialTime: _horaSelecionada,
                  onPicked: (t) => _horaSelecionada = t,
                );

                // Lado a lado sobra pouco espaço pra cada campo (data
                // formatada + ícone) quando o card fica estreito, como no
                // mobile — empilha em Column abaixo de 340px em vez de
                // espremer os dois na mesma linha.
                if (constraints.maxWidth < 340) {
                  return Column(
                    children: [
                      dataField,
                      const SizedBox(height: 14),
                      horaField,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: dataField),
                    const SizedBox(width: 12),
                    Expanded(child: horaField),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            CustomField(
              hint: 'Chave PIX',
              icon: Icons.pix,
              controller: _pixController,
              maxWidth: double.infinity,
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: PrimaryButton(
                text: 'Salvar alterações',
                width: 170,
                compact: true,
                onTap: _salvar,
                loading: _salvando,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Aba: Config (toggles de dev + informações do admin logado)
// =============================================================================

class AbaConfig extends StatelessWidget {
  final User? adminUser;

  /// Nulo enquanto a sala principal ainda não foi descoberta — as ações de
  /// chat ficam desabilitadas até lá, já que ambas precisam do id da sala.
  final String? salaId;
  final VoidCallback onModerarChat;
  final VoidCallback onApagarMensagens;

  const AbaConfig({
    super.key,
    required this.adminUser,
    required this.salaId,
    required this.onModerarChat,
    required this.onApagarMensagens,
  });

  @override
  Widget build(BuildContext context) {
    final cores = AdminCores.de(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const AdminTituloSecao(
            texto: 'Chat da sala',
            icone: Icons.forum_outlined,
          ),
          const SizedBox(height: 12),
          AdminSecaoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _BotaoAcaoConfig(
                  icone: Icons.rate_review_outlined,
                  texto: 'Moderar mensagens',
                  descricao:
                      'Abre o chat com um botão de apagar em cada mensagem.',
                  cor: cores.azul,
                  onTap: salaId == null ? null : onModerarChat,
                ),
                const SizedBox(height: 10),
                _BotaoAcaoConfig(
                  icone: Icons.delete_sweep_outlined,
                  texto: 'Apagar Mensagens Chat',
                  descricao: 'Remove todo o histórico de mensagens da sala.',
                  cor: cores.vermelho,
                  onTap: salaId == null ? null : onApagarMensagens,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const AdminTituloSecao(
            texto: 'Ferramentas de desenvolvimento',
            icone: Icons.build_outlined,
          ),
          const SizedBox(height: 12),
          AdminSecaoCard(
            child: ValueListenableBuilder<bool>(
              valueListenable: forcarSkeletonGlobal,
              builder: (context, ativo, _) {
                return SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Forçar skeleton loading',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: cores.texto,
                    ),
                  ),
                  subtitle: Text(
                    'Trava o skeleton em Minha Aposta, Participantes e Chat '
                    '(dev)',
                    style: TextStyle(fontSize: 12, color: cores.textoSuave),
                  ),
                  value: ativo,
                  activeThumbColor: cores.azul,
                  onChanged: (novo) => forcarSkeletonGlobal.value = novo,
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          const AdminTituloSecao(
            texto: 'Administrador logado',
            icone: Icons.admin_panel_settings_outlined,
          ),
          const SizedBox(height: 12),
          AdminSecaoCard(
            child: Column(
              children: [
                _LinhaInfo(
                  icone: Icons.badge_outlined,
                  rotulo: 'Nome',
                  valor: adminUser?.displayName ?? '—',
                ),
                const SizedBox(height: 12),
                _LinhaInfo(
                  icone: Icons.email_outlined,
                  rotulo: 'E-mail',
                  valor: adminUser?.email ?? '—',
                ),
                const SizedBox(height: 12),
                _LinhaInfo(
                  icone: Icons.verified_user_outlined,
                  rotulo: 'Papel',
                  valor: 'Administrador',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'O acesso de administrador é controlado pelo campo isAdmin do '
            'usuário no Firestore e só pode ser concedido pelo console/Admin '
            'SDK — não é editável por aqui por segurança.',
            style: TextStyle(fontSize: 12, color: cores.textoSuave),
          ),
        ],
      ),
    );
  }
}

/// Botão de ação da aba Configurações: ícone colorido + título + descrição
/// curta do que a ação faz. Não usa [PrimaryButton] porque estas ações são
/// destrutivas/administrativas e precisam da linha de explicação ao lado —
/// um botão azul cheio e sem contexto convidaria ao clique distraído.
class _BotaoAcaoConfig extends StatelessWidget {
  final IconData icone;
  final String texto;
  final String descricao;
  final Color cor;
  final VoidCallback? onTap;

  const _BotaoAcaoConfig({
    required this.icone,
    required this.texto,
    required this.descricao,
    required this.cor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cores = AdminCores.de(context);
    final habilitado = onTap != null;
    final corEfetiva = habilitado ? cor : cor.withValues(alpha: 0.4);

    return Material(
      color: cores.fundoCard,
      borderRadius: AppRadii.circularMd,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: AppRadii.circularMd,
            border: Border.all(color: corEfetiva.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Icon(icone, size: 20, color: corEfetiva),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      texto,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: corEfetiva,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      descricao,
                      style: TextStyle(fontSize: 12, color: cores.textoSuave),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinhaInfo extends StatelessWidget {
  final IconData icone;
  final String rotulo;
  final String valor;

  const _LinhaInfo({
    required this.icone,
    required this.rotulo,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    final cores = AdminCores.de(context);
    return Row(
      children: [
        Icon(icone, size: 18, color: cores.textoSuave),
        const SizedBox(width: 12),
        SizedBox(
          width: 70,
          child: Text(
            rotulo,
            style: TextStyle(fontSize: 13, color: cores.textoSuave),
          ),
        ),
        Expanded(
          child: Text(
            valor,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: cores.texto,
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Widgets auxiliares compartilhados entre abas
// =============================================================================

class _CampoBuscaAdmin extends StatelessWidget {
  final void Function(String) onChanged;
  const _CampoBuscaAdmin({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cores = AdminCores.de(context);
    return TextField(
      onChanged: onChanged,
      style: TextStyle(fontSize: 15, color: cores.texto),
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Buscar por nome...',
        prefixIcon: const Icon(Icons.search, size: 20),
        filled: true,
        fillColor: cores.fundoTile,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: AppRadii.circularMd,
          borderSide: BorderSide(color: cores.borda),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.circularMd,
          borderSide: BorderSide(color: cores.borda),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.circularMd,
          borderSide: BorderSide(color: cores.azul, width: 1.5),
        ),
      ),
    );
  }
}

/// Moldura padrão de diálogo do painel (título + corpo + Cancelar/Salvar),
/// reaproveitada pelos formulários de aposta manual e edição de valor.
///
/// Cancelar usa [SecondaryButton] (contorno azul) e Salvar [PrimaryButton]
/// (azul cheio) — o par tem o mesmo peso visual, em vez de um TextButton
/// cru ao lado de um botão sólido.
class AdminDialogFrame extends StatelessWidget {
  final String titulo;
  final Widget corpo;
  final bool salvando;
  final Future<void> Function() onSalvar;

  const AdminDialogFrame({
    super.key,
    required this.titulo,
    required this.corpo,
    required this.salvando,
    required this.onSalvar,
  });

  @override
  Widget build(BuildContext context) {
    // 340 fixo estoura em celulares estreitos (com o padding padrão do
    // AlertDialog somado). Em mobile usa a largura da tela com respiro.
    final larguraTela = MediaQuery.sizeOf(context).width;
    final larguraConteudo = Responsive.isMobile(context)
        ? larguraTela - 80
        : 340.0;

    return AlertDialog(
      backgroundColor: AdminCores.de(context).fundoCard,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.circularXxl),
      title: Text(
        titulo,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
      ),
      content: SizedBox(width: larguraConteudo, child: corpo),
      // actionsPadding para o par de botões respirar da borda do card e do
      // conteúdo acima.
      actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      actions: [
        Row(
          children: [
            Expanded(
              child: _BotaoCancelar(
                onTap: salvando ? null : () => context.pop(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PrimaryButton(
                text: 'Salvar',
                width: double.infinity,
                onTap: onSalvar,
                loading: salvando,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// SecondaryButton só aceita onTap não-nulo; quando o diálogo está salvando o
// Cancelar precisa ficar desabilitado, então aqui é uma versão que suporta
// onTap null (aparência esmaecida) mantendo o mesmo visual de contorno.
class _BotaoCancelar extends StatelessWidget {
  final VoidCallback? onTap;
  const _BotaoCancelar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cores = AdminCores.de(context);
    final habilitado = onTap != null;
    final cor = habilitado ? cores.azul : cores.azul.withValues(alpha: 0.4);
    return Container(
      decoration: BoxDecoration(
        borderRadius: AppRadii.circularXl,
        border: Border.all(color: cor, width: 2),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadii.circularXl,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Text(
              'Cancelar',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
