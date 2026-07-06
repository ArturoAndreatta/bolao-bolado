import 'package:bolao_bolado/components/shared/back_screen_button.dart';
import 'package:bolao_bolado/components/shared/custom_card.dart';
import 'package:bolao_bolado/components/shared/header_paginas.dart';
import 'package:bolao_bolado/components/shell/default_layout.dart';
import 'package:bolao_bolado/components/shell/drawer.dart';
import 'package:bolao_bolado/core/responsive.dart';
import 'package:bolao_bolado/models/bet.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PainelAdmin extends StatefulWidget {
  const PainelAdmin({super.key});

  @override
  State<PainelAdmin> createState() => _PainelAdminState();
}

class _PainelAdminState extends State<PainelAdmin> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _loading = true;
  bool _autorizado = false;
  String? _salaId;
  List<Map<String, dynamic>> _bets = [];
  bool _carregandoStats = true;

  // Apostas fake para testar o layout sem tocar no Firestore.
  // Ative pelo botão "Simular apostas" no painel.
  List<Map<String, dynamic>>? _fakePendentes;

  void _gerarApostasFake([int quantidade = 12]) {
    final nomes = [
      'João Silva',
      'Maria Oliveira',
      'Pedro Santos',
      'Ana Costa',
      'Lucas Pereira',
      'Beatriz Souza',
      'Rafael Lima',
      'Camila Alves',
      'Gustavo Rocha',
      'Fernanda Dias',
      'Thiago Martins',
      'Juliana Ribeiro',
      'Bruno Carvalho',
      'Larissa Gomes',
      'Diego Barbosa',
    ];
    final random = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      _fakePendentes = List.generate(quantidade, (index) {
        final nome = nomes[(random + index) % nomes.length];
        final valor = 6.0 * (1 + (index % 5));
        return {
          'id': 'fake_$index',
          'nome': nome,
          'uid': 'fake_uid_$index',
          'valor': valor,
        };
      });
    });
  }

  void _limparApostasFake() {
    setState(() => _fakePendentes = null);
  }

  @override
  void initState() {
    super.initState();
    _verificarAcesso();
  }

  Future<void> _verificarAcesso() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      setState(() {
        _autorizado = false;
        _loading = false;
      });
      return;
    }

    final doc = await _firestore.collection('usuarios').doc(user.uid).get();
    final isAdmin = doc.data()?['isAdmin'] == true;
    final salaId = await buscarSalaPrincipalId();

    setState(() {
      _autorizado = isAdmin;
      _salaId = salaId;
      _loading = false;
    });

    if (isAdmin) {
      _carregarStats();
    }
  }

  Future<void> _carregarStats() async {
    final bets = await getBets();
    if (!mounted) return;
    setState(() {
      _bets = bets;
      _carregandoStats = false;
    });
  }

  Future<void> _confirmarAposta(String notificacaoId, String uid) async {
    if (_salaId == null) return;
    await verificarAposta(
      salaId: _salaId!,
      uid: uid,
      notificacaoId: notificacaoId,
    );
    _carregarStats();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultLayout(
      drawer: AppDrawer(),
      child: Stack(
        children: [
          CustomCard(
            color: const Color(0xFFF3F1EF),
            // maxWidth: 900,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 730),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 20),
                      child: BackScreenButton(floating: false),
                    ),
                    Expanded(
                      child: HeaderPaginas(
                        text: 'Painel ADM',
                        subtitle: 'Gerencie apostas e verificações',
                      ),
                    ),
                  ],
                ),
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(
                    color: Color(0xFF7CC8B5),
                    strokeWidth: 5,
                  ),
                )
              else if (!_autorizado)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Text(
                    'Você não tem permissão para acessar esta página.',
                    style: TextStyle(color: Color(0xFF1F2937), fontSize: 16),
                  ),
                )
              else
                _conteudoPainel(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dashboardStats() {
    if (_carregandoStats) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: CircularProgressIndicator(
          color: Color(0xFF7CC8B5),
          strokeWidth: 5,
        ),
      );
    }

    final formatoMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    final totalApostado = _bets.fold<double>(
      0,
      (soma, item) => soma + ((item['valor'] as num?)?.toDouble() ?? 0),
    );
    final totalPremios = _bets.fold<double>(
      0,
      (soma, item) => soma + ((item['premio'] as num?)?.toDouble() ?? 0),
    );
    final totalParticipantes = _bets.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatTile(
          icon: Icons.groups_outlined,
          label: 'Participantes',
          value: '$totalParticipantes',
          color: const Color(0xFF487DE5),
        ),
        const SizedBox(height: 12),
        _StatTile(
          icon: Icons.payments_outlined,
          label: 'Total Arrecadado',
          value: formatoMoeda.format(totalApostado),
          color: const Color(0xFF2E7D32),
        ),
        const SizedBox(height: 12),
        _StatTile(
          icon: Icons.emoji_events_outlined,
          label: 'Prêmio Total',
          value: formatoMoeda.format(totalPremios),
          color: const Color(0xFF487DE5),
        ),
        const SizedBox(height: 12),
        _cardPendentesStat(),
      ],
    );
  }

  // Conta direto da coleção 'notificacoes' (mesma fonte usada pela lista de
  // apostas pendentes) para o número deste card nunca divergir da lista.
  Widget _cardPendentesStat() {
    if (_fakePendentes != null) {
      final totalPendentes = _fakePendentes!.length;
      return _StatTile(
        icon: Icons.pending_actions_outlined,
        label: totalPendentes > 0
            ? 'Aguardando verificação'
            : 'Tudo verificado',
        value: '$totalPendentes pendentes',
        color: totalPendentes > 0
            ? const Color(0xFFEF4444)
            : const Color(0xFF2E7D32),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('notificacoes')
          .where('verificado', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        final totalPendentes = snapshot.data?.docs.length ?? 0;
        return _StatTile(
          icon: Icons.pending_actions_outlined,
          label: totalPendentes > 0
              ? 'Aguardando verificação'
              : 'Tudo verificado',
          value: '$totalPendentes pendentes',
          color: totalPendentes > 0
              ? const Color(0xFFEF4444)
              : const Color(0xFF2E7D32),
        );
      },
    );
  }

  Widget _conteudoPainel() {
    final isMobile = Responsive.isMobile(context);

    return CustomCard(
      isChild: true,
      color: const Color(0xFFFEFEFE),
      children: [
        const SizedBox(height: 10),
        if (isMobile)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _dashboardStats(),
              const SizedBox(height: 24),
              SizedBox(height: 520, child: _cardApostasPendentes()),
            ],
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              const espacamento = 20.0;
              final larguraStats = (constraints.maxWidth - espacamento) * 3 / 5;
              const alturaTiles = 640.0;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: larguraStats, child: _dashboardStats()),
                  const SizedBox(width: espacamento),
                  Expanded(
                    child: SizedBox(
                      height: alturaTiles,
                      child: _cardApostasPendentes(),
                    ),
                  ),
                ],
              );
            },
          ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _cardApostasPendentes() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F1EF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Apostas pendentes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
              if (_fakePendentes == null)
                IconButton(
                  tooltip: 'Simular apostas (dev)',
                  onPressed: () => _gerarApostasFake(),
                  icon: const Icon(Icons.auto_awesome, size: 20),
                )
              else
                IconButton(
                  tooltip: 'Limpar simulação',
                  onPressed: _limparApostasFake,
                  icon: const Icon(Icons.close, size: 20),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_fakePendentes != null)
            Expanded(child: _listaApostasFake(_fakePendentes!))
          else
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _firestore
                    .collection('notificacoes')
                    .where('verificado', isEqualTo: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF7CC8B5),
                        strokeWidth: 5,
                      ),
                    );
                  }

                  // Ordenado no cliente: 'data-hora' usa serverTimestamp() e
                  // fica null no snapshot otimista local antes da confirmação
                  // do servidor. Ordenar via query nesse campo fazia docs
                  // recém-criados sumirem da lista até o valor sincronizar.
                  final docs = [...snapshot.data?.docs ?? []]
                    ..sort((a, b) {
                      final tsA = a.data()['data-hora'] as Timestamp?;
                      final tsB = b.data()['data-hora'] as Timestamp?;
                      if (tsA == null && tsB == null) return 0;
                      if (tsA == null) return -1;
                      if (tsB == null) return 1;
                      return tsB.compareTo(tsA);
                    });

                  if (docs.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 40,
                            color: Color(0xFF2E7D32),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Nenhuma aposta pendente de verificação.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  final formatoMoeda = NumberFormat.currency(
                    locale: 'pt_BR',
                    symbol: 'R\$',
                  );

                  return SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var index = 0; index < docs.length; index++) ...[
                          if (index > 0) const SizedBox(height: 12),
                          Builder(
                            builder: (context) {
                              final doc = docs[index];
                              final dados = doc.data();
                              final nome = dados['nome']?.toString() ?? '—';
                              final uid = dados['uid']?.toString() ?? '';
                              final valor =
                                  double.tryParse(dados['valor'].toString()) ??
                                  0;

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEFEFE),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFE5E7EB),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            nome,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF1F2937),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            formatoMoeda.format(valor),
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF2E7D32),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Confirmar aposta',
                                      onPressed: () =>
                                          _confirmarAposta(doc.id, uid),
                                      icon: const Text(
                                        '✅',
                                        style: TextStyle(fontSize: 22),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _listaApostasFake(List<Map<String, dynamic>> apostas) {
    final formatoMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < apostas.length; index++) ...[
            if (index > 0) const SizedBox(height: 12),
            Builder(
              builder: (context) {
                final aposta = apostas[index];
                final nome = aposta['nome']?.toString() ?? '—';
                final valor = (aposta['valor'] as num?)?.toDouble() ?? 0;

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEFEFE),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
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
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              formatoMoeda.format(valor),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Confirmar aposta (simulada)',
                        onPressed: () {
                          setState(() {
                            _fakePendentes?.removeAt(index);
                          });
                        },
                        icon: const Text('✅', style: TextStyle(fontSize: 22)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
