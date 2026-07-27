import 'package:bolao_bolado/components/formatters/formatters.dart';
import 'package:bolao_bolado/components/formatters/money_input_format.dart';
import 'package:bolao_bolado/components/shared/avatar_emoji.dart';
import 'package:bolao_bolado/components/shared/buttons.dart';
import 'package:bolao_bolado/components/shared/custom_fields.dart';
import 'package:bolao_bolado/components/shared/custom_show_dialog.dart';
import 'package:bolao_bolado/components/shared/skeletons.dart';
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

  const AdminCardStats({
    super.key,
    required this.bets,
    required this.carregandoStats,
    required this.totalPendentes,
  });

  @override
  Widget build(BuildContext context) {
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
    final verificados = bets.where((b) => b['verificado'] == true).length;

    // Um tile por linha: cada card ocupa a largura toda em vez de disputar
    // espaço lado a lado, ficando legível mesmo em telas estreitas.
    const espacamento = 12.0;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminStatTile(
            icon: Icons.groups_outlined,
            label: 'Participantes',
            value: '${bets.length}',
            color: AdminCores.azul,
          ),
          const SizedBox(height: espacamento),
          AdminStatTile(
            icon: Icons.payments_outlined,
            label: 'Total arrecadado',
            value: Formatters.moeda.format(totalApostado),
            color: AdminCores.verde,
          ),
          const SizedBox(height: espacamento),
          AdminStatTile(
            icon: Icons.emoji_events_outlined,
            label: 'Prêmio total',
            value: Formatters.moeda.format(totalPremios),
            color: AdminCores.azul,
          ),
          const SizedBox(height: espacamento),
          AdminStatTile(
            icon: Icons.confirmation_number_outlined,
            label: 'Cotas vendidas',
            value: '$totalCotas',
            color: AdminCores.dourado,
          ),
          const SizedBox(height: espacamento),
          AdminStatTile(
            icon: Icons.verified_outlined,
            label: 'Apostas verificadas',
            value: '$verificados de ${bets.length}',
            color: AdminCores.verdeAgua,
          ),
          const SizedBox(height: espacamento),
          AdminStatTile(
            icon: Icons.pending_actions_outlined,
            label: totalPendentes == -1
                ? 'Erro ao carregar'
                : totalPendentes > 0
                ? 'Aguardando verificação'
                : 'Tudo verificado',
            value: totalPendentes == -1 ? '—' : '$totalPendentes pendentes',
            color: totalPendentes > 0 ? AdminCores.vermelho : AdminCores.verde,
          ),
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Apostas pendentes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AdminCores.texto,
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
          SizedBox(height: altura, child: _corpoPendentes()),
        ],
      ),
    );
  }

  Widget _corpoPendentes() {
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
        cor: AdminCores.vermelho,
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
      return const AdminEstadoVazio(
        icon: Icons.check_circle_outline,
        cor: AdminCores.verde,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AdminCores.fundoCard,
        borderRadius: AppRadii.circularSmd,
        border: Border.all(color: AdminCores.borda),
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
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AdminCores.texto,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  Formatters.moeda.format(valor),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AdminCores.verde,
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
  String _busca = '';
  // 0=todos, 1=pendentes, 2=verificados
  int _filtro = 0;

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

  @override
  Widget build(BuildContext context) {
    if (widget.carregando) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: SkeletonListaApostasPendentes(),
      );
    }

    final filtrados = _filtrados;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: AdminTituloSecao(
                  texto: '${widget.bets.length} participantes',
                  icone: Icons.groups_outlined,
                ),
              ),
              PrimaryButton(
                text: 'Lançar',
                width: 88,
                compact: true,
                onTap: widget.onLancarManual,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _CampoBuscaAdmin(onChanged: (v) => setState(() => _busca = v)),
          const SizedBox(height: 12),
          _FiltroChips(
            selecionado: _filtro,
            onSelecionar: (i) => setState(() => _filtro = i),
          ),
          const SizedBox(height: 14),
          if (filtrados.isEmpty)
            const AdminEstadoVazio(
              icon: Icons.sentiment_dissatisfied_outlined,
              cor: AdminCores.textoSuave,
              mensagem: 'Nenhum participante encontrado.',
            )
          else
            AdminSecaoCard(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
              child: Column(
                children: [
                  for (var i = 0; i < filtrados.length; i++) ...[
                    if (i > 0)
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: AdminCores.borda,
                      ),
                    _LinhaParticipante(
                      aposta: filtrados[i],
                      onEditar: () => widget.onEditarValor(filtrados[i]),
                      onRemover: () => widget.onRemover(filtrados[i]),
                      onAlternarVerificacao: () =>
                          widget.onAlternarVerificacao(filtrados[i]),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FiltroChips extends StatelessWidget {
  final int selecionado;
  final void Function(int) onSelecionar;

  const _FiltroChips({required this.selecionado, required this.onSelecionar});

  @override
  Widget build(BuildContext context) {
    final labels = ['Todos', 'Pendentes', 'Verificados'];
    return Wrap(
      spacing: 8,
      children: [
        for (var i = 0; i < labels.length; i++)
          ChoiceChip(
            label: Text(labels[i]),
            selected: selecionado == i,
            onSelected: (_) => onSelecionar(i),
            showCheckmark: false,
            labelStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selecionado == i ? Colors.white : AdminCores.textoSuave,
            ),
            selectedColor: AdminCores.azul,
            backgroundColor: AdminCores.fundoTile,
            side: BorderSide(
              color: selecionado == i ? AdminCores.azul : AdminCores.borda,
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
    final nome = aposta['nome']?.toString() ?? '—';
    final valor = (aposta['valor'] as num?)?.toDouble() ?? 0;
    final cotas = (aposta['cotas'] as num?)?.toInt() ?? 0;
    final verificado = aposta['verificado'] == true;
    final editado = aposta['editadoAposVerificacao'] == true;
    final manual = aposta['criadoPeloAdmin'] == true;
    final corAvatar = aposta['avatarColor'] is int
        ? Color(aposta['avatarColor'] as int)
        : AdminCores.azul;
    final emojiAvatar = aposta['avatarEmoji'] is String
        ? aposta['avatarEmoji'] as String
        : kEmojiAvatarPadrao;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          AvatarEmoji(tamanho: 36, cor: corAvatar, emoji: emojiAvatar),
          const SizedBox(width: 12),
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
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AdminCores.texto,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (editado)
                      const _Badge(texto: 'alterada', cor: AdminCores.dourado),
                    if (manual) ...[
                      if (editado) const SizedBox(width: 6),
                      const _Badge(texto: 'manual', cor: AdminCores.texto),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${Formatters.moeda.format(valor)}  ·  '
                  '$cotas ${cotas == 1 ? "cota" : "cotas"}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AdminCores.textoSuave,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: verificado ? 'Marcar como pendente' : 'Verificar',
            onPressed: onAlternarVerificacao,
            icon: Icon(
              verificado ? Icons.check_circle : Icons.check_circle_outline,
              color: verificado ? AdminCores.verde : AdminCores.textoSuave,
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
            itemBuilder: (_) => const [
              PopupMenuItem(
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
                    Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: AdminCores.vermelho,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Remover',
                      style: TextStyle(color: AdminCores.vermelho),
                    ),
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

class AbaRanking extends StatelessWidget {
  final List<Map<String, dynamic>> bets;
  final bool carregando;
  final VoidCallback onExportar;

  const AbaRanking({
    super.key,
    required this.bets,
    required this.carregando,
    required this.onExportar,
  });

  @override
  Widget build(BuildContext context) {
    if (carregando) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: SkeletonDashboardStats(),
      );
    }

    final ranking = [...bets]
      ..sort((a, b) {
        final ca = (a['cotas'] as num?)?.toInt() ?? 0;
        final cb = (b['cotas'] as num?)?.toInt() ?? 0;
        return cb.compareTo(ca);
      });
    final maxCotas = ranking.isEmpty
        ? 0
        : (ranking.first['cotas'] as num?)?.toInt() ?? 0;
    const cores = [AdminCores.dourado, AdminCores.azul, AdminCores.verdeAgua];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(
                child: AdminTituloSecao(
                  texto: 'Ranking de cotas',
                  icone: Icons.leaderboard_outlined,
                ),
              ),
              TextButton.icon(
                onPressed: bets.isEmpty ? null : onExportar,
                icon: const Icon(Icons.copy_all_outlined, size: 18),
                label: const Text('Exportar CSV'),
                style: TextButton.styleFrom(foregroundColor: AdminCores.azul),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (ranking.isEmpty)
            const AdminEstadoVazio(
              icon: Icons.leaderboard_outlined,
              cor: AdminCores.textoSuave,
              mensagem: 'Nenhuma aposta para ranquear ainda.',
            )
          else
            AdminSecaoCard(
              child: Column(
                children: [
                  for (var i = 0; i < ranking.length; i++) ...[
                    if (i > 0) const SizedBox(height: 16),
                    AdminBarraDistribuicao(
                      rotulo: '${i + 1}. ${ranking[i]['nome'] ?? "—"}',
                      valor:
                          '${(ranking[i]['cotas'] as num?)?.toInt() ?? 0} cotas'
                          '  ·  '
                          '${Formatters.moeda.format((ranking[i]['premio'] as num?)?.toDouble() ?? 0)}',
                      fracao: maxCotas == 0
                          ? 0
                          : ((ranking[i]['cotas'] as num?)?.toInt() ?? 0) /
                                maxCotas,
                      cor: cores[i % cores.length],
                    ),
                  ],
                ],
              ),
            ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dados da sala atualizados'),
          backgroundColor: AdminCores.verde,
          behavior: SnackBarBehavior.floating,
        ),
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
            const Text(
              'Edite os dados principais da sala sem sair do painel.',
              style: TextStyle(fontSize: 13, color: AdminCores.textoSuave),
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
                  cor: AdminCores.azul,
                  onTap: salaId == null ? null : onModerarChat,
                ),
                const SizedBox(height: 10),
                _BotaoAcaoConfig(
                  icone: Icons.delete_sweep_outlined,
                  texto: 'Apagar Mensagens Chat',
                  descricao: 'Remove todo o histórico de mensagens da sala.',
                  cor: AdminCores.vermelho,
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
                  title: const Text(
                    'Forçar skeleton loading',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AdminCores.texto,
                    ),
                  ),
                  subtitle: const Text(
                    'Trava o skeleton em Minha Aposta, Participantes e Chat '
                    '(dev)',
                    style: TextStyle(
                      fontSize: 12,
                      color: AdminCores.textoSuave,
                    ),
                  ),
                  value: ativo,
                  activeThumbColor: AdminCores.azul,
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
          const Text(
            'O acesso de administrador é controlado pelo campo isAdmin do '
            'usuário no Firestore e só pode ser concedido pelo console/Admin '
            'SDK — não é editável por aqui por segurança.',
            style: TextStyle(fontSize: 12, color: AdminCores.textoSuave),
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
    final habilitado = onTap != null;
    final corEfetiva = habilitado ? cor : cor.withValues(alpha: 0.4);

    return Material(
      color: AdminCores.fundoCard,
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
                      style: const TextStyle(
                        fontSize: 12,
                        color: AdminCores.textoSuave,
                      ),
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
    return Row(
      children: [
        Icon(icone, size: 18, color: AdminCores.textoSuave),
        const SizedBox(width: 12),
        SizedBox(
          width: 70,
          child: Text(
            rotulo,
            style: const TextStyle(fontSize: 13, color: AdminCores.textoSuave),
          ),
        ),
        Expanded(
          child: Text(
            valor,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AdminCores.texto,
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
    return TextField(
      onChanged: onChanged,
      style: const TextStyle(fontSize: 15, color: AdminCores.texto),
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Buscar por nome...',
        prefixIcon: const Icon(Icons.search, size: 20),
        filled: true,
        fillColor: AdminCores.fundoTile,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: AppRadii.circularMd,
          borderSide: const BorderSide(color: AdminCores.borda),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.circularMd,
          borderSide: const BorderSide(color: AdminCores.borda),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.circularMd,
          borderSide: const BorderSide(color: AdminCores.azul, width: 1.5),
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
      backgroundColor: AdminCores.fundoCard,
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
    final habilitado = onTap != null;
    final cor = habilitado
        ? AdminCores.azul
        : AdminCores.azul.withValues(alpha: 0.4);
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
