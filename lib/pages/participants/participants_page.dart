import 'dart:async';

import 'package:bolao_bolado/components/shared/custom_card.dart';
import 'package:bolao_bolado/components/shared/header_paginas.dart';
import 'package:bolao_bolado/components/shell/default_layout.dart';
import 'package:bolao_bolado/components/shell/drawer.dart';
import 'package:bolao_bolado/core/responsive.dart';
import 'package:bolao_bolado/dev/simulador_apostas.dart';
import 'package:bolao_bolado/pages/participants/participants_painel.dart';
import 'package:bolao_bolado/pages/participants/participants_simulacao_dialog.dart';
import 'package:bolao_bolado/pages/participants/participants_skeletons.dart';
import 'package:bolao_bolado/router/app_router.dart';
import 'package:bolao_bolado/services/authentication/auth_service.dart';
import 'package:bolao_bolado/services/bet/bet_service.dart';
import 'package:bolao_bolado/widgets/chat_sala.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class Participants extends StatefulWidget {
  const Participants({super.key});

  @override
  State<Participants> createState() => _ParticipantsState();
}

class _ParticipantsState extends State<Participants> {
  List<Map<String, dynamic>> _rowsData = [];
  bool _loading = true;
  String? _salaId;
  bool _isAdmin = false;
  String? _sorteio;
  DateTime? _dataSorteio;
  double _premioSala = 0;

  StreamSubscription<List<Map<String, Object?>>>? _betsSubscription;
  final SimuladorApostas _simulador = SimuladorApostas();

  // Aba ativa no mobile: 0 = Participantes, 1 = Chat
  int _abaAtiva = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _betsSubscription?.cancel();
    _simulador.parar();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final salaId = await buscarSalaPrincipalId();
      final user = FirebaseAuth.instance.currentUser;
      // Usuário anônimo nunca é admin: evita checagem desnecessária no Firestore
      final isAdmin = user != null && !user.isAnonymous
          ? await AuthService().isAdmin(user.uid)
          : false;
      final salaDoc = await FirebaseFirestore.instance
          .collection('Salas')
          .doc(salaId)
          .get();
      final sorteio = salaDoc.data()?['sorteio']?.toString();
      final dataSorteio = (salaDoc.data()?['dataHora'] as Timestamp?)?.toDate();
      final premioSala = (salaDoc.data()?['premio'] as num?)?.toDouble() ?? 0;

      if (!mounted) return;
      setState(() {
        _salaId = salaId;
        _isAdmin = isAdmin;
        _sorteio = sorteio;
        _dataSorteio = dataSorteio;
        _premioSala = premioSala;
      });

      // Cancela stream anterior antes de reabrir (ex: troca de sala via _load())
      unawaited(_betsSubscription?.cancel());
      _betsSubscription = streamBets().listen(
        (dataBets) {
          if (!mounted) return;
          setState(() {
            _rowsData = dataBets;
            _loading = false;
          });
        },
        onError: (_) {
          // Erro no stream de apostas apenas encerra o loading; mantém a
          // última lista carregada em vez de quebrar a tela.
          if (!mounted) return;
          setState(() => _loading = false);
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isLoggedIn = AuthService().isLoggedIn;

    return DefaultLayout(
      drawer: AppDrawer(onAvatarChanged: (_) => _load()),
      child: isMobile
          ? _layoutMobile(currentUid)
          : _layoutDesktop(currentUid, isLoggedIn),
    );
  }

  // ── Layout Desktop: card de participantes + chat lateral ────────────────
  Widget _layoutDesktop(String? currentUid, bool isLoggedIn) {
    // Altura fixa para alinhar painel de participantes e chat lado a lado
    const double chatHeight = 510;

    return CustomCard(
      color: const Color(0xFFF3F1EF),
      maxWidth: 1112,
      children: [
        HeaderPaginas(
          text: 'Participantes',
          subtitle: 'Visualize quem está participando',
          trailing: _isAdmin ? _botoesAdminDesktop() : null,
          // Participants é sempre acessada via context.go (login ou
          // "Visualizar" na Home), nunca empilhada. Usuário logado não tem
          // para onde voltar; visitante (deslogado ou sessão anônima) veio da Home.
          showBackButton: !isLoggedIn,
          onBack: () => context.go(AppRoutes.home),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
          child: SizedBox(
            height: chatHeight,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 7,
                    child: PainelParticipantes(
                      currentUid: currentUid,
                      loading: _loading,
                      rowsData: _rowsData,
                      isAdmin: _isAdmin,
                      sorteio: _sorteio,
                      dataSorteio: _dataSorteio,
                      premioSala: _premioSala,
                      onEditarSala: _botaoEditarSala,
                      mobile: false,
                      expandirConteudo: true,
                      mostrarCabecalho: false,
                    ),
                  ),
                  if (_salaId != null || _loading) const SizedBox(width: 16),
                  if (_loading)
                    const Expanded(flex: 3, child: SkeletonChatSala())
                  else if (_salaId != null)
                    Expanded(flex: 3, child: ChatSala(salaId: _salaId!)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _layoutMobile(String? currentUid) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: SeletorAbas(
            abaAtiva: _abaAtiva,
            onSelecionar: (i) => setState(() => _abaAtiva = i),
          ),
        ),
        if (_abaAtiva == 0)
          PainelParticipantes(
            currentUid: currentUid,
            loading: _loading,
            rowsData: _rowsData,
            isAdmin: _isAdmin,
            sorteio: _sorteio,
            dataSorteio: _dataSorteio,
            premioSala: _premioSala,
            onEditarSala: _botaoEditarSala,
            onSimularApostas: _isAdmin ? _abrirDialogoSimulacao : null,
            mobile: true,
          )
        else if (_salaId != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.62,
              child: ChatSala(salaId: _salaId!),
            ),
          ),
      ],
    );
  }

  Widget _botaoEditarSala() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: IconButton(
        tooltip: 'Editar sala',
        icon: const Icon(Icons.edit_outlined, color: Color(0xFF487DE5)),
        onPressed: _salaId == null
            ? null
            : () async {
                await context.push(
                  Uri(
                    path: AppRoutes.cadastrarSala,
                    queryParameters: {'salaId': _salaId},
                  ).toString(),
                );
                if (mounted) _load();
              },
      ),
    );
  }

  Widget _botoesAdminDesktop() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [_botaoSimularApostas(), _botaoEditarSala()],
    );
  }

  Widget _botaoSimularApostas() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: IconButton(
        tooltip: 'Simular apostas',
        icon: const Icon(Icons.groups_2_outlined, color: Color(0xFF7C5CD9)),
        onPressed: _salaId == null ? null : _abrirDialogoSimulacao,
      ),
    );
  }

  void _abrirDialogoSimulacao() {
    if (_salaId == null) return;
    showDialog(
      context: context,
      builder: (_) =>
          DialogoSimulacaoApostas(simulador: _simulador, salaId: _salaId!),
    );
  }
}
