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
            maxWidth: 900,
            children: [
              Row(
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
    final totalVerificados = _bets
        .where((item) => item['verificado'] == true)
        .length;
    final totalPendentes = totalParticipantes - totalVerificados;

    final isMobile = Responsive.isMobile(context);

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isMobile ? 2 : 4,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: isMobile ? 1.3 : 1.4,
      children: [
        _StatTile(
          icon: Icons.groups_outlined,
          label: 'Participantes',
          value: '$totalParticipantes',
          color: const Color(0xFF487DE5),
        ),
        _StatTile(
          icon: Icons.payments_outlined,
          label: 'Total Arrecadado',
          value: formatoMoeda.format(totalApostado),
          color: const Color(0xFF2E7D32),
        ),
        _StatTile(
          icon: Icons.emoji_events_outlined,
          label: 'Prêmio Total',
          value: formatoMoeda.format(totalPremios),
          color: const Color(0xFF487DE5),
        ),
        _StatTile(
          icon: Icons.pending_actions_outlined,
          label: '$totalVerificados verificadas',
          value: '$totalPendentes pendentes',
          color: totalPendentes > 0
              ? const Color(0xFFEF4444)
              : const Color(0xFF2E7D32),
        ),
      ],
    );
  }

  Widget _conteudoPainel() {
    return CustomCard(
      isChild: true,
      color: const Color(0xFFFEFEFE),
      children: [
        const SizedBox(height: 8),
        _dashboardStats(),
        const SizedBox(height: 24),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Apostas não verificadas',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _firestore
              .collection('notificacoes')
              .where('verificado', isEqualTo: false)
              .orderBy('data-hora', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: CircularProgressIndicator(
                  color: Color(0xFF7CC8B5),
                  strokeWidth: 5,
                ),
              );
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 40,
                      color: Color(0xFF2E7D32),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Nenhuma aposta pendente de verificação.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            final isMobile = Responsive.isMobile(context);
            final formatoMoeda = NumberFormat.currency(
              locale: 'pt_BR',
              symbol: 'R\$',
            );

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 8),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isMobile ? 1 : 2,
                mainAxisExtent: 88,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final dados = doc.data();
                final nome = dados['nome']?.toString() ?? '—';
                final uid = dados['uid']?.toString() ?? '';
                final valor = double.tryParse(dados['valor'].toString()) ?? 0;

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
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
                        tooltip: 'Confirmar aposta',
                        onPressed: () => _confirmarAposta(doc.id, uid),
                        icon: const Text(
                          '✅',
                          style: TextStyle(fontSize: 22),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 12),
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
