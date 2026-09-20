import 'package:bolao_bolado/components/formatters/formatters.dart';
import 'package:bolao_bolado/components/formatters/money_input_format.dart';
import 'package:bolao_bolado/components/shared/avatar_emoji.dart';
import 'package:bolao_bolado/components/shared/buttons.dart';
import 'package:bolao_bolado/components/shared/combos.dart';
import 'package:bolao_bolado/components/shared/custom_fields.dart';
import 'package:bolao_bolado/components/shared/custom_show_dialog.dart';
import 'package:bolao_bolado/components/shared/skeletons.dart';
import 'package:bolao_bolado/components/shared/snackbar_deslizante.dart';
import 'package:bolao_bolado/core/app_radii.dart';
import 'package:bolao_bolado/core/debug_flags.dart';
import 'package:bolao_bolado/pages/participants/participants_estilo_entrada.dart';
import 'package:bolao_bolado/core/responsive.dart';
import 'package:bolao_bolado/pages/admin/widgets/admin_widgets.dart';
import 'package:bolao_bolado/services/avatar/avatar_service.dart';
import 'package:bolao_bolado/services/bet/bet_service.dart';
import 'package:bolao_bolado/services/configuracoes/configuracoes_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Seções do painel admin. O nome "aba" ficou de um desenho antigo, em que a
/// navegação era um fichário de abas; hoje elas são itens do menu lateral no
/// desktop e da barra de baixo no celular, mas o enum continua servindo para
/// identificar cada seção de forma estável.
enum AbaAdmin { visaoGeral, participantes, ranking, sala, config }

/// Metadados (rótulo, ícone, descrição) de cada seção. Fonte única para o
/// menu lateral e para o cabeçalho do painel.
class AbaAdminMeta {
  final AbaAdmin aba;
  final String texto;
  final IconData icone;

  /// Uma linha dizendo o que dá pra fazer na seção, mostrada sob o título no
  /// cabeçalho do painel (desktop). Fica no metadado, e não no widget da
  /// seção, porque quem desenha o cabeçalho é o painel — a seção nem sabe
  /// que está dentro dele.
  final String descricao;

  const AbaAdminMeta({
    required this.aba,
    required this.texto,
    required this.icone,
    this.descricao = '',
  });
}

// Esta é a lista que o menu lateral do desktop percorre, na ordem em que
// aparece. Não inclui AbaAdmin.visaoGeral: no desktop os números da sala não
// são mais uma seção que se escolhe, e sim a faixa fixa no topo (ver
// AdminCardStats), visível o tempo todo por cima de qualquer seção. No
// celular ela continua sendo uma seção da barra de baixo, montada à parte
// (ver painel_admin.dart).
//
// Configurações é uma seção como as outras, não um botão de engrenagem no
// cabeçalho: como dialog ela ficava escondida atrás de um clique e abria
// numa janela com regras de rolagem próprias, diferente do resto do painel.
const List<AbaAdminMeta> kAbasAdmin = [
  AbaAdminMeta(
    aba: AbaAdmin.participantes,
    texto: 'Participantes',
    icone: Icons.groups_outlined,
    descricao: 'Verifique, edite e lance apostas',
  ),
  AbaAdminMeta(
    aba: AbaAdmin.ranking,
    texto: 'Ranking',
    icone: Icons.leaderboard_outlined,
    descricao: 'Quem tem mais cotas e quanto leva',
  ),
  AbaAdminMeta(
    aba: AbaAdmin.sala,
    texto: 'Sala',
    icone: Icons.meeting_room_outlined,
    descricao: 'Prêmio, sorteio, chave PIX e limite por aposta',
  ),
  AbaAdminMeta(
    aba: AbaAdmin.config,
    texto: 'Configurações',
    icone: Icons.settings_outlined,
    descricao: 'Chat, apostas da sala e ferramentas de dev',
  ),
];

// =============================================================================
// Visão geral: os números da sala (prêmio, arrecadado, participantes, cotas,
// fila de verificação). No desktop eles são a faixa fixa do topo do painel,
// acima de qualquer seção; no celular são a seção "Resumo" da barra de baixo,
// com um tile por linha.
// =============================================================================

class AdminCardStats extends StatelessWidget {
  final List<Map<String, dynamic>> bets;
  final bool carregandoStats;
  final int totalPendentes;
  final double precoCota;

  /// `true` desenha a régua de indicadores do desktop (uma peça só, sempre
  /// visível acima da seção ativa); `false` desenha a pilha do celular, um
  /// tile por linha, encolhendo pro próprio conteúdo.
  ///
  /// A pilha NÃO pode usar Expanded: no celular a seção fica dentro de um
  /// SingleChildScrollView (altura infinita), e Expanded nesse contexto lança
  /// RenderFlex — exceção que o Flutter web engole, deixando a seção inteira
  /// em branco.
  final bool faixa;

  const AdminCardStats({
    super.key,
    required this.bets,
    required this.carregandoStats,
    required this.totalPendentes,
    required this.precoCota,
    this.faixa = true,
  });

  @override
  Widget build(BuildContext context) {
    final cores = AdminCores.de(context);
    if (carregandoStats) {
      return faixa
          ? const SkeletonFaixaIndicadores()
          : const Padding(
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

    // -1 é o sinal de que a consulta de pendências falhou (regra recusando,
    // índice faltando). Mostrar "0 pendentes" nesse caso teria a mesma cara
    // de "está tudo verificado", que é o oposto do que o admin precisa saber.
    final erroPendentes = totalPendentes == -1;
    final fracaoVerificado = bets.isEmpty ? null : verificados / bets.length;

    if (faixa) {
      return AdminFaixaIndicadores(
        itens: [
          AdminIndicador(
            icone: Icons.emoji_events_outlined,
            rotulo: 'Prêmio total',
            valor: Formatters.moeda.format(totalPremios),
            cor: cores.dourado,
            apoio: '${Formatters.moeda.format(precoCota)} por cota',
          ),
          AdminIndicador(
            icone: Icons.payments_outlined,
            rotulo: 'Arrecadado',
            valor: Formatters.moeda.format(totalApostado),
            cor: cores.verde,
            apoio: '${Formatters.moeda.format(totalVerificado)} já verificado',
          ),
          AdminIndicador(
            icone: Icons.groups_outlined,
            rotulo: 'Participantes',
            valor: '${bets.length}',
            cor: cores.azul,
            apoio: '$totalCotas ${totalCotas == 1 ? "cota" : "cotas"} vendidas',
          ),
          AdminIndicador(
            icone: Icons.verified_outlined,
            rotulo: 'Verificadas',
            valor: '$verificados de ${bets.length}',
            cor: cores.verdeAgua,
            // Sem barra quando não há aposta nenhuma: 0% de nada não é
            // informação, é uma barra vazia pedindo interpretação.
            progresso: fracaoVerificado,
            apoio: 'nenhuma aposta ainda',
          ),
          AdminIndicador(
            icone: erroPendentes
                ? Icons.error_outline
                : totalPendentes > 0
                ? Icons.pending_actions_outlined
                : Icons.task_alt,
            rotulo: 'Pendentes',
            valor: erroPendentes ? '—' : '$totalPendentes',
            // Vermelho só quando há fila de verdade: pintar de alerta um
            // painel sem pendência nenhuma gasta a cor à toa e, no dia em que
            // ela aparece de verdade, ninguém nota.
            cor: erroPendentes
                ? cores.textoSuave
                : totalPendentes > 0
                ? cores.vermelho
                : cores.verde,
            apoio: erroPendentes
                ? 'erro ao carregar'
                : totalPendentes > 0
                ? 'aguardando conferência'
                : 'tudo conferido',
          ),
        ],
      );
    }

    // Celular: um tile por linha, empilhado, sem Expanded (ver [faixa]).
    const espacamento = 12.0;
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
            cor: erroPendentes ? cores.textoSuave : cores.verde,
            icon: erroPendentes ? Icons.error_outline : Icons.task_alt,
            valor: erroPendentes
                ? '—'
                : Formatters.moeda.format(totalVerificado),
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
}

/// Módulo de "verificado" da seção Resumo do celular — logo abaixo do
/// destaque de prêmio, mesmo desenho deitado. Sempre mostra o valor
/// arrecadado das apostas verificadas (cor/ícone fixos, sem alternar pra
/// vermelho): antes o módulo virava "N Pendente(s)" assim que havia 1
/// pendência sequer, escondendo o número que o admin queria ver. Pendência
/// hoje é um badge pequeno no fim da linha do valor — visível, mas sem tomar
/// o lugar do dado principal nem empurrar o resto do módulo para baixo.
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

  const _ModuloPendencias({
    required this.cor,
    required this.icon,
    required this.valor,
    required this.label,
    this.fracaoVerificado,
    this.totalPendentes,
  });

  @override
  Widget build(BuildContext context) {
    final cores = AdminCores.de(context);
    final temPendencia = (totalPendentes ?? 0) > 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.1),
        borderRadius: AppRadii.circularLg,
        border: Border.all(color: cor.withValues(alpha: 0.3)),
      ),
      // Deitado, como o destaque de prêmio ao lado, e não mais empilhado e
      // centralizado: era a pilha (ícone grande, valor grande, rótulo, barra)
      // que sozinha definia a altura do bloco inteiro. Na horizontal o mesmo
      // conteúdo cabe em pouco mais da metade da altura, e os dois módulos da
      // linha de cima passam a ler como um par.
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        // mainAxisSize.min obrigatoriamente: este módulo vive num
        // SingleChildScrollView (altura infinita) e "max" ali lança
        // RenderFlex — exceção que o Flutter web engole, apagando a seção.
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.18),
                  borderRadius: AppRadii.circularSmd,
                ),
                child: Icon(icon, color: cor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      valor,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: cor,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cores.textoSuave,
                      ),
                    ),
                  ],
                ),
              ),
              // O badge sai da pilha e vira o fim da linha: ele avisa, não
              // compete. Empilhado ele empurrava todo o resto para baixo, e
              // com pendência o módulo ficava mais alto do que sem.
              if (temPendencia) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    // Mesma razão da barra de seção: o vermelho é claro no
                    // tema escuro e o branco por cima dele sumia.
                    color: cores.barraDeSecao(cores.vermelho),
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
              ],
            ],
          ),
          if (fracaoVerificado != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: AppRadii.circularPill,
              child: LinearProgressIndicator(
                value: fracaoVerificado!.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: cor.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(cor),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '${(fracaoVerificado! * 100).round()}% da fila verificada',
              style: TextStyle(
                fontSize: 11,
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

  /// `true` mostra a lista INTEIRA rolando por dentro, sem paginação. Ligado
  /// só no painel do desktop.
  ///
  /// A paginação existe porque, na grade de cards antiga, o card tinha altura
  /// fixa e a página inteira já rolava — rolar também por dentro do card
  /// empilhava dois scrolls e confundia. No painel de hoje nada mais rola:
  /// a lista é a única coisa rolável da tela, e aí paginar só atrapalha (com
  /// 300 apostas seriam 50 páginas). No celular a paginação continua, que é
  /// onde a página inteira ainda rola.
  final bool rolarLista;

  const AbaParticipantes({
    super.key,
    required this.bets,
    required this.carregando,
    required this.onLancarManual,
    required this.onEditarValor,
    required this.onRemover,
    required this.onAlternarVerificacao,
    this.rolarLista = false,
  });

  @override
  State<AbaParticipantes> createState() => _AbaParticipantesState();
}

class _AbaParticipantesState extends State<AbaParticipantes> {
  /// Linhas por página quando a lista é paginada (celular).
  static const int _porPagina = 6;

  String _busca = '';
  // 0=todos, 1=pendentes, 2=verificados
  int _filtro = 0;
  int _pagina = 0;
  final ScrollController _rolagem = ScrollController();

  @override
  void dispose() {
    _rolagem.dispose();
    super.dispose();
  }

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
    if (widget.carregando) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: SkeletonListaApostasPendentes(),
      );
    }

    if (!widget.rolarLista) return _conteudo(context, largo: false);

    // A largura decide o formato da linha, e quem sabe dela é quem está
    // dentro: o painel do desktop encolhe quando a janela encolhe.
    return LayoutBuilder(
      builder: (context, restricoes) =>
          _conteudo(context, largo: restricoes.maxWidth >= 640),
    );
  }

  Widget _conteudo(BuildContext context, {required bool largo}) {
    final cores = AdminCores.de(context);
    final filtrados = _filtrados;
    final rolando = widget.rolarLista;
    final totalPaginas = filtrados.isEmpty
        ? 1
        : (filtrados.length / _porPagina).ceil();
    final pagina = _pagina.clamp(0, totalPaginas - 1);
    final inicio = pagina * _porPagina;
    final visiveis = rolando
        ? filtrados
        : filtrados.skip(inicio).take(_porPagina).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _barraFerramentas(cores),
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
                    child: _lista(cores, visiveis, largo: largo),
                  ),
          ),
          const SizedBox(height: 10),
          // Contagem no mesmo eixo da paginação (à direita, no lugar do
          // Spacer quando não há páginas): antes essa linha vinha sozinha
          // ACIMA da lista, tirando uma linha inteira de altura útil da
          // seção.
          Row(
            children: [
              if (!rolando && totalPaginas > 1)
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

  Widget _lista(
    AdminCores cores,
    List<Map<String, dynamic>> itens, {
    required bool largo,
  }) {
    Widget linha(int i) => _LinhaParticipante(
      aposta: itens[i],
      largo: largo,
      onEditar: () => widget.onEditarValor(itens[i]),
      onRemover: () => widget.onRemover(itens[i]),
      onAlternarVerificacao: () => widget.onAlternarVerificacao(itens[i]),
    );
    final divisor = Divider(height: 1, thickness: 1, color: cores.borda);

    if (widget.rolarLista) {
      // ListView (e não Column num scroll): a lista inteira pode ter centenas
      // de apostas e só as visíveis precisam existir.
      return Scrollbar(
        controller: _rolagem,
        child: ListView.separated(
          controller: _rolagem,
          padding: EdgeInsets.zero,
          itemCount: itens.length,
          separatorBuilder: (_, _) => divisor,
          itemBuilder: (_, i) => linha(i),
        ),
      );
    }

    // Paginado: a página já é dimensionada pra caber, e o scroll aqui é só
    // rede de segurança — Column sozinho não clipa o próprio overflow, então
    // sem ele uma linha a mais vazaria por cima do rodapé em vez de rolar.
    return SingleChildScrollView(
      child: Column(
        children: [
          for (var i = 0; i < itens.length; i++) ...[
            if (i > 0) divisor,
            linha(i),
          ],
        ],
      ),
    );
  }

  /// Busca + filtro de estado + botão de lançar aposta.
  ///
  /// Numa faixa larga (o painel do desktop) os três cabem na MESMA linha e
  /// viram uma barra de ferramentas só — a linha economizada vira mais uma
  /// aposta visível na lista, que é o que se quer ver ali. Estreito, a busca
  /// volta a ficar sozinha em cima: é a ação mais comum (achar alguém) e
  /// espremida entre o filtro e o botão ela não serve para digitar nome.
  Widget _barraFerramentas(AdminCores cores) {
    final busca = _CampoBuscaAdmin(onChanged: _mudarBusca);
    // Divisor vertical separa visualmente "Lançar" do filtro — ele não filtra
    // nada, é uma ação, e colado dava a entender que era mais uma opção.
    final acoes = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 1, height: 28, color: cores.borda),
        const SizedBox(width: 12),
        PrimaryButton(
          text: 'Lançar',
          width: 88,
          compact: true,
          onTap: widget.onLancarManual,
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, restricoes) {
        // Combobox em vez de chips: os chips usavam Wrap sem largura própria
        // e, junto do divisor e do botão na mesma linha, estouravam a largura
        // em layouts estreitos. Um dropdown tem largura fixa e nunca quebra.
        final largo = restricoes.maxWidth >= 640;
        final filtro = ComboFiltro<int>(
          selecionado: _filtro,
          opcoes: _opcoesFiltro(cores),
          onSelecionar: _mudarFiltro,
          // Na linha única ele sobe de 36 para 44 para alinhar com a altura
          // do campo de busca ao lado.
          altura: largo ? 44 : 36,
        );

        if (largo) {
          return Row(
            children: [
              Expanded(child: busca),
              const SizedBox(width: 12),
              SizedBox(width: 190, child: filtro),
              const SizedBox(width: 12),
              acoes,
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            busca,
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: filtro),
                const SizedBox(width: 12),
                acoes,
              ],
            ),
          ],
        );
      },
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

/// Opções do filtro de estado da lista de participantes. Os índices são a
/// posição na lista — é esse int que `_filtro` guarda.
///
/// Cor de cada opção combina com o que ela filtra: azul neutro pra "todos"
/// (não é um estado, é ausência de filtro), vermelho pra "pendentes" (mesma
/// cor de alerta usada no resto do painel pra apostas não verificadas) e verde
/// pra "verificados" (estado positivo/concluído).
List<OpcaoCombo<int>> _opcoesFiltro(AdminCores cores) => [
  OpcaoCombo(0, 'Todos', cor: cores.azul),
  OpcaoCombo(1, 'Pendentes', cor: cores.vermelho),
  OpcaoCombo(2, 'Verificados', cor: cores.verde),
];

class _LinhaParticipante extends StatelessWidget {
  final Map<String, dynamic> aposta;
  final VoidCallback onEditar;
  final VoidCallback onRemover;
  final VoidCallback onAlternarVerificacao;

  /// Na faixa larga do desktop, valor e cotas saem de baixo do nome e viram
  /// duas colunas alinhadas à direita. É o mesmo dado, mas na horizontal ele
  /// usa o espaço que sobra em vez de deixar 600px vazios no meio da linha — e
  /// os valores ficam um embaixo do outro, que é como se compara quantia.
  final bool largo;

  const _LinhaParticipante({
    required this.aposta,
    required this.onEditar,
    required this.onRemover,
    required this.onAlternarVerificacao,
    required this.largo,
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
    // Sem fallback "chutado" quando há uid: como em ListaParticipantes, um
    // fallback que diverge do avatar real faz o ícone trocar assim que o doc
    // de usuarios/{uid} chega. Só a aposta manual (sem uid) usa um fixo, já
    // que para ela nunca existirá avatar de verdade.
    final corAvatar = aposta['avatarColor'] is int
        ? Color(aposta['avatarColor'] as int)
        : (aposta['uid'] == null ? cores.azul : null);
    final emojiAvatar = aposta['avatarEmoji'] is String
        ? aposta['avatarEmoji'] as String
        : (aposta['uid'] == null ? kEmojiAvatarPadrao : null);

    final linhaNome = Row(
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
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          AvatarDoParticipante(
            uid: aposta['uid']?.toString(),
            tamanho: 36,
            corFallback: corAvatar,
            emojiFallback: emojiAvatar,
          ),
          SizedBox(width: 12),
          Expanded(
            child: largo
                ? linhaNome
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      linhaNome,
                      const SizedBox(height: 2),
                      Text(
                        '${Formatters.moeda.format(valor)}  ·  '
                        '$cotas ${cotas == 1 ? "cota" : "cotas"}',
                        style: TextStyle(fontSize: 12, color: cores.textoSuave),
                      ),
                    ],
                  ),
          ),
          if (largo) ...[
            const SizedBox(width: 12),
            SizedBox(
              width: 110,
              child: Text(
                Formatters.moeda.format(valor),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: cores.texto,
                ),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 76,
              child: Text(
                '$cotas ${cotas == 1 ? "cota" : "cotas"}',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 13, color: cores.textoSuave),
              ),
            ),
            const SizedBox(width: 8),
          ],
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

  /// Ver [AbaParticipantes.rolarLista] — mesma ideia aqui.
  final bool rolarLista;

  const AbaRanking({
    super.key,
    required this.bets,
    required this.carregando,
    this.rolarLista = false,
  });

  @override
  State<AbaRanking> createState() => _AbaRankingState();
}

class _AbaRankingState extends State<AbaRanking> {
  // 10 (não 6, como em Participantes): o Ranking não tem busca nem filtro
  // acima da lista, então sobra altura para o pedido original de mostrar "os
  // 10 primeiros" de cada vez.
  static const int _porPagina = 10;

  int _pagina = 0;
  final ScrollController _rolagem = ScrollController();

  @override
  void dispose() {
    _rolagem.dispose();
    super.dispose();
  }

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
    final inicio = widget.rolarLista ? 0 : pagina * _porPagina;
    final itensPagina = widget.rolarLista
        ? rankingCompleto
        : rankingCompleto.skip(inicio).take(_porPagina).toList();

    Widget posicao(int i) {
      final item = itensPagina[i];
      final cotas = (item['cotas'] as num?)?.toInt() ?? 0;
      return AdminBarraDistribuicao(
        rotulo: '${inicio + i + 1}. ${item['nome'] ?? "—"}',
        valor:
            '$cotas cotas'
            '  ·  '
            '${Formatters.moeda.format((item['premio'] as num?)?.toDouble() ?? 0)}',
        fracao: maxCotas == 0 ? 0 : cotas / maxCotas,
        cor: coresRanking[(inicio + i) % coresRanking.length],
      );
    }

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
                    child: widget.rolarLista
                        ? Scrollbar(
                            controller: _rolagem,
                            child: ListView.separated(
                              controller: _rolagem,
                              padding: EdgeInsets.zero,
                              itemCount: itensPagina.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 16),
                              itemBuilder: (_, i) => posicao(i),
                            ),
                          )
                        // Paginado: a página já cabe na altura, e o scroll é
                        // rede de segurança — Column comum não clipa o
                        // próprio overflow, e sem ele o conteúdo vazava por
                        // cima do rodapé de paginação.
                        : SingleChildScrollView(
                            child: Column(
                              children: [
                                for (
                                  var i = 0;
                                  i < itensPagina.length;
                                  i++
                                ) ...[
                                  if (i > 0) const SizedBox(height: 16),
                                  posicao(i),
                                ],
                              ],
                            ),
                          ),
                  ),
          ),
          if (!widget.rolarLista && totalPaginas > 1) ...[
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

  /// Mostra o nome da sala e a linha de explicação acima do formulário.
  /// Desligado no painel do desktop, onde o cabeçalho da seção já diz o mesmo
  /// logo acima — dois títulos empilhados só empurram os campos para baixo.
  final bool mostrarCabecalho;

  const AbaSala({
    super.key,
    required this.salaId,
    required this.dadosSala,
    required this.carregando,
    required this.onSalvo,
    this.mostrarCabecalho = true,
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
      // Campo de texto não fica bom com 1100px de largura: no painel do
      // desktop o formulário para em 680 e encosta à esquerda, alinhado com o
      // cabeçalho da seção. Num espaço menor que isso (celular) o limite não
      // tem efeito nenhum.
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.mostrarCabecalho) ...[
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
                ],
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

  /// Nulo enquanto a sala principal ainda não foi descoberta — as ações
  /// ficam desabilitadas até lá, já que todas precisam do id da sala.
  final String? salaId;
  final VoidCallback onModerarChat;
  final VoidCallback onApagarMensagens;
  final VoidCallback onApagarApostas;

  const AbaConfig({
    super.key,
    required this.adminUser,
    required this.salaId,
    required this.onModerarChat,
    required this.onApagarMensagens,
    required this.onApagarApostas,
  });

  @override
  Widget build(BuildContext context) {
    final cores = AdminCores.de(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      // Ver o mesmo limite em AbaSala: no painel largo do desktop os blocos
      // esticavam por 1100px e a descrição de cada ação ficava perdida do
      // rótulo. No celular o limite não tem efeito.
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const AdminTituloSecao(
                texto: 'Apostas da sala',
                icone: Icons.receipt_long_outlined,
              ),
              const SizedBox(height: 12),
              AdminSecaoCard(
                child: _BotaoAcaoConfig(
                  icone: Icons.delete_forever_outlined,
                  texto: 'Apagar Todas as Apostas',
                  descricao:
                      'Zera a sala: remove todas as apostas, inclusive as já '
                      'verificadas.',
                  cor: cores.vermelho,
                  onTap: salaId == null ? null : onApagarApostas,
                ),
              ),
              const SizedBox(height: 20),
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
                      descricao:
                          'Remove todo o histórico de mensagens da sala.',
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ValueListenableBuilder<bool>(
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
                            'Trava o skeleton em Minha Aposta, Participantes e '
                            'Chat (dev)',
                            style: TextStyle(
                              fontSize: 12,
                              color: cores.textoSuave,
                            ),
                          ),
                          value: ativo,
                          activeThumbColor: cores.azul,
                          onChanged: (novo) =>
                              forcarSkeletonGlobal.value = novo,
                        );
                      },
                    ),
                    Divider(height: 20, thickness: 1, color: cores.borda),
                    const _RitmoSimulacao(),
                    Divider(height: 20, thickness: 1, color: cores.borda),
                    const _RajadaSimulacao(),
                    Divider(height: 20, thickness: 1, color: cores.borda),
                    const _GravarSimulacaoFirestore(),
                    Divider(height: 20, thickness: 1, color: cores.borda),
                    const _EstiloEntradaAposta(),
                  ],
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
                'usuário no Firestore e só pode ser concedido pelo '
                'console/Admin SDK — não é editável por aqui por segurança.',
                style: TextStyle(fontSize: 12, color: cores.textoSuave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Slider do intervalo entre passos do simulador de apostas.
///
/// O simulador roda na tela de Participantes, não aqui — o valor vai para
/// [intervaloSimulacaoMsGlobal] (lido de lá) e é PERSISTIDO no campo
/// `configuracoes` da sala principal via [salvarRitmoSimulacao]. Como a
/// leitura vem de um `snapshots()` (ver [ouvirConfiguracoesGlobais]), o
/// ritmo muda para qualquer um com o app aberto no momento — não só entre
/// abas do mesmo
/// admin, e não só até a próxima recarga.
class _RitmoSimulacao extends StatefulWidget {
  const _RitmoSimulacao();

  @override
  State<_RitmoSimulacao> createState() => _RitmoSimulacaoState();
}

class _RitmoSimulacaoState extends State<_RitmoSimulacao> {
  /// Valor exibido ENQUANTO o dedo arrasta o slider, sem esperar o Firestore.
  ///
  /// `null` quando ninguém está arrastando — nesse estado o slider segue
  /// [intervaloSimulacaoMsGlobal] direto. Sem isto, mostrar sempre o valor
  /// global faria o dedo "descolar" da bolinha: o global só muda quando
  /// `ouvirConfiguracoesGlobais()` recebe a confirmação do Firestore, que não
  /// acompanha a velocidade do gesto.
  double? _valorArrastando;

  /// Rótulo do valor atual. Abaixo de 1s milissegundo é a unidade natural;
  /// acima, "1,5s" lê melhor que "1500 ms".
  static String _rotulo(int ms) {
    if (ms < 1000) return '$ms ms';
    final segundos = ms / 1000;
    final texto = segundos.toStringAsFixed(segundos % 1 == 0 ? 0 : 1);
    return '${texto.replaceAll('.', ',')}s';
  }

  @override
  Widget build(BuildContext context) {
    final cores = AdminCores.de(context);
    return ValueListenableBuilder<int>(
      valueListenable: intervaloSimulacaoMsGlobal,
      builder: (context, valorGlobal, _) {
        final valor =
            _valorArrastando?.round() ??
            valorGlobal.clamp(
              kIntervaloSimulacaoMinMs,
              kIntervaloSimulacaoMaxMs,
            );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Ritmo da simulação',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: cores.texto,
                    ),
                  ),
                ),
                Text(
                  _rotulo(valor),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: cores.azul,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Tempo entre uma aposta simulada e a próxima. Fica salvo e vale '
              'para todo mundo, inclusive com a simulação já rodando.',
              style: TextStyle(fontSize: 12, color: cores.textoSuave),
            ),
            Slider(
              value: valor.toDouble(),
              min: kIntervaloSimulacaoMinMs.toDouble(),
              max: kIntervaloSimulacaoMaxMs.toDouble(),
              // Passos de 100ms: com o slider contínuo o valor parava em
              // números como 837ms, que não dizem nada a mais e deixam o
              // rótulo difícil de reproduzir depois.
              divisions:
                  (kIntervaloSimulacaoMaxMs - kIntervaloSimulacaoMinMs) ~/ 100,
              label: _rotulo(valor),
              activeColor: cores.azul,
              // Só atualiza o estado LOCAL enquanto arrasta — nada de rede
              // aqui. Escrever a cada pixel arrastado (o que este widget
              // fazia antes) disparava uma escrita no Firestore a cada
              // frame do gesto, dezenas por segundo, e cada uma delas
              // reabre round-trip até `ouvirConfiguracoesGlobais()`
              // confirmar: era isso que deixava o arrasto lento/travado.
              onChanged: (novo) => setState(() => _valorArrastando = novo),
              // Só ao SOLTAR o dedo é que grava — uma escrita por gesto, não
              // uma por pixel. Não escreve o notifier direto: quem faz isso
              // é o listener de ouvirConfiguracoesGlobais(), reagindo à
              // confirmação do Firestore. Escrever os dois arriscaria
              // divergir se a escrita remota falhasse — o slider volta ao
              // valor salvo assim que o Firestore confirmar ou rejeitar.
              onChangeEnd: (novo) {
                salvarRitmoSimulacao(novo.round());
                setState(() => _valorArrastando = null);
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_rotulo(kIntervaloSimulacaoMinMs)} (rápido)',
                  style: TextStyle(fontSize: 11, color: cores.textoSuave),
                ),
                Text(
                  '${_rotulo(kIntervaloSimulacaoMaxMs)} (lento)',
                  style: TextStyle(fontSize: 11, color: cores.textoSuave),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Controle de "rajada": quantas apostas o simulador cria de uma vez em cada
/// inclusão ([quantidadeRajadaSimulacaoGlobal], lido pelo simulador em
/// [SimuladorApostas._inserir]) e o atraso entre cada uma delas dentro da
/// rajada ([atrasoRajadaSimulacaoMsGlobal]). Mesmo arranjo do
/// [_RitmoSimulacao]: PERSISTIDO no campo `configuracoes` da sala principal
/// via [salvarQuantidadeRajada]/[salvarAtrasoRajada].
class _RajadaSimulacao extends StatefulWidget {
  const _RajadaSimulacao();

  @override
  State<_RajadaSimulacao> createState() => _RajadaSimulacaoState();
}

class _RajadaSimulacaoState extends State<_RajadaSimulacao> {
  /// Valor do atraso exibido ENQUANTO o dedo arrasta o slider, sem esperar o
  /// Firestore — mesma razão do `_valorArrastando` de [_RitmoSimulacaoState].
  double? _atrasoArrastando;

  static String _rotuloAtraso(int ms) {
    if (ms < 1000) return '$ms ms';
    final segundos = ms / 1000;
    final texto = segundos.toStringAsFixed(segundos % 1 == 0 ? 0 : 1);
    return '${texto.replaceAll('.', ',')}s';
  }

  @override
  Widget build(BuildContext context) {
    final cores = AdminCores.de(context);
    return ValueListenableBuilder<int>(
      valueListenable: quantidadeRajadaSimulacaoGlobal,
      builder: (context, quantidade, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Apostas por rajada',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: cores.texto,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  iconSize: 26,
                  color: cores.azul,
                  visualDensity: VisualDensity.compact,
                  onPressed: quantidade > 1
                      ? () => salvarQuantidadeRajada(quantidade - 1)
                      : null,
                ),
                SizedBox(
                  width: 24,
                  child: Text(
                    '$quantidade',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: cores.azul,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  iconSize: 26,
                  color: cores.azul,
                  visualDensity: VisualDensity.compact,
                  onPressed: quantidade < kQuantidadeRajadaSimulacaoMax
                      ? () => salvarQuantidadeRajada(quantidade + 1)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Quantas apostas cada inclusão do simulador cria de uma vez, '
              'como se várias pessoas apostassem em sequência. 1 desliga a '
              'rajada.',
              style: TextStyle(fontSize: 12, color: cores.textoSuave),
            ),
            // O atraso só faz sentido com rajada de 2+; com 1 aposta por vez
            // não há "entre uma e outra" para configurar.
            if (quantidade > 1) ...[
              const SizedBox(height: 12),
              ValueListenableBuilder<int>(
                valueListenable: atrasoRajadaSimulacaoMsGlobal,
                builder: (context, atrasoGlobal, _) {
                  final atraso =
                      _atrasoArrastando?.round() ??
                      atrasoGlobal.clamp(0, kAtrasoRajadaSimulacaoMaxMs);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Atraso entre apostas da rajada',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: cores.texto,
                              ),
                            ),
                          ),
                          Text(
                            _rotuloAtraso(atraso),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: cores.azul,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tempo entre uma aposta e a próxima DENTRO da mesma '
                        'rajada. 0 faz todas saírem no mesmo instante.',
                        style: TextStyle(fontSize: 12, color: cores.textoSuave),
                      ),
                      Slider(
                        value: atraso.toDouble(),
                        min: 0,
                        max: kAtrasoRajadaSimulacaoMaxMs.toDouble(),
                        divisions: kAtrasoRajadaSimulacaoMaxMs ~/ 100,
                        label: _rotuloAtraso(atraso),
                        activeColor: cores.azul,
                        onChanged: (novo) =>
                            setState(() => _atrasoArrastando = novo),
                        onChangeEnd: (novo) {
                          salvarAtrasoRajada(novo.round());
                          setState(() => _atrasoArrastando = null);
                        },
                      ),
                    ],
                  );
                },
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Switch "Gravar no Firestore": liga [gravarSimulacaoFirestoreGlobal], lido
/// pelo simulador em [SimuladorApostas._inserirUm] (e nas demais ações) para
/// decidir se escreve no banco de verdade ou só mantém as apostas fake em
/// memória ([SimuladorApostas.apostasLocais]). Mesmo arranjo do
/// [_RitmoSimulacao]: PERSISTIDO no campo `configuracoes` da sala principal
/// via [salvarGravarSimulacaoFirestore].
class _GravarSimulacaoFirestore extends StatelessWidget {
  const _GravarSimulacaoFirestore();

  @override
  Widget build(BuildContext context) {
    final cores = AdminCores.de(context);
    return ValueListenableBuilder<bool>(
      valueListenable: gravarSimulacaoFirestoreGlobal,
      builder: (context, ativo, _) {
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Gravar no Firestore',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: cores.texto,
            ),
          ),
          subtitle: Text(
            ativo
                ? 'Apostas simuladas são gravadas de verdade, como hoje: '
                      'podem ser conferidas e apagadas depois.'
                : 'Apostas simuladas ficam só na tela desta sessão, sem '
                      'tocar no banco — somem ao sair de Participantes.',
            style: TextStyle(fontSize: 12, color: cores.textoSuave),
          ),
          value: ativo,
          activeThumbColor: cores.azul,
          // Não escreve o notifier direto: quem faz isso é o listener de
          // ouvirConfiguracoesGlobais(), reagindo à confirmação do
          // Firestore — mesma observação do ritmo/rajada/estilo.
          onChanged: (novo) => salvarGravarSimulacaoFirestore(novo),
        );
      },
    );
  }
}

/// Seletor do estilo da animação de entrada de uma aposta nova.
///
/// Mesmo arranjo do [_RitmoSimulacao]: PERSISTIDO no campo `configuracoes`
/// da sala principal via [salvarEstiloEntrada], e refletido em
/// [estiloEntradaGlobal] (que a tabela lê) por [ouvirConfiguracoesGlobais].
/// Vale para qualquer um com o app aberto, a partir da próxima aposta — uma
/// linha a meio caminho não muda de animação no ar.
class _EstiloEntradaAposta extends StatelessWidget {
  const _EstiloEntradaAposta();

  @override
  Widget build(BuildContext context) {
    final cores = AdminCores.de(context);
    return ValueListenableBuilder<EstiloEntrada>(
      valueListenable: estiloEntradaGlobal,
      builder: (context, atual, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Animação de entrada',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: cores.texto,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Como uma aposta nova entra na tabela de Participantes. Fica '
              'salvo e vale para todo mundo, a partir da próxima aposta.',
              style: TextStyle(fontSize: 12, color: cores.textoSuave),
            ),
            const SizedBox(height: 8),
            RadioGroup<EstiloEntrada>(
              groupValue: atual,
              // Mesma observação do ritmo do simulador: não escreve o
              // notifier direto, quem faz isso é o listener reagindo à
              // confirmação do Firestore.
              onChanged: (novo) {
                if (novo != null) salvarEstiloEntrada(novo);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final estilo in EstiloEntrada.values)
                    InkWell(
                      onTap: () => salvarEstiloEntrada(estilo),
                      borderRadius: AppRadii.circularSmd,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Radio<EstiloEntrada>(
                              value: estilo,
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    estilo.rotulo,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: estilo == atual
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                      color: cores.texto,
                                    ),
                                  ),
                                  Text(
                                    estilo.descricao,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: cores.textoSuave,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
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

    final cores = AdminCores.de(context);
    return AlertDialog(
      backgroundColor: cores.fundoCard,
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.circularXxl),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      title: Text(
        titulo,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: cores.texto,
        ),
      ),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      content: SizedBox(width: larguraConteudo, child: corpo),
      // actionsPadding para o par de botões respirar da borda do card e do
      // conteúdo acima.
      actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
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
