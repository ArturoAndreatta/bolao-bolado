import 'dart:async';

import 'package:bolao_bolado/components/shared/custom_show_dialog.dart';
import 'package:bolao_bolado/components/shell/default_layout.dart';
import 'package:bolao_bolado/components/shared/buttons.dart';
import 'package:bolao_bolado/components/shared/custom_card.dart';
import 'package:bolao_bolado/components/shell/drawer.dart';
import 'package:bolao_bolado/components/shared/custom_fields.dart';
import 'package:bolao_bolado/components/shared/header_paginas.dart';
import 'package:bolao_bolado/services/bet/bet_service.dart';
import 'package:bolao_bolado/services/bet/preco_cota.dart';
import 'package:bolao_bolado/pages/participants.dart';
import 'package:bolao_bolado/services/authentication/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController valueController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  bool _saving = false;
  String? _salaId;

  static final _formatoMoeda = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
  );

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _salaSubscription;
  StreamSubscription<List<Map<String, Object?>>>? _betsSubscription;
  double _premioSala = 0;
  double _precoCota = kPrecoCotaMega;
  int _totalCotasOutros = 0;

  @override
  void initState() {
    super.initState();
    _carregarDados();
    valueController.addListener(_onValorAlterado);
    _iniciarStreams();
  }

  Future<void> _iniciarStreams() async {
    final salaId = await buscarSalaPrincipalId();
    if (!mounted) return;

    _salaSubscription = _firestore
        .collection('Salas')
        .doc(salaId)
        .snapshots()
        .listen((doc) {
          if (!mounted) return;
          setState(() {
            _premioSala = (doc.data()?['premio'] as num?)?.toDouble() ?? 0;
            _precoCota = precoCotaPara(doc.data()?['sorteio']?.toString());
          });
        });

    _betsSubscription = streamBets().listen((bets) {
      if (!mounted) return;
      final uid = FirebaseAuth.instance.currentUser?.uid;
      setState(() {
        _totalCotasOutros = bets
            .where((item) => item['uid'] != uid)
            .fold<int>(0, (soma, item) => soma + (item['cotas'] as int));
      });
    });
  }

  @override
  void dispose() {
    _salaSubscription?.cancel();
    _betsSubscription?.cancel();
    valueController.removeListener(_onValorAlterado);
    nameController.dispose();
    valueController.dispose();
    super.dispose();
  }

  void _onValorAlterado() => setState(() {});

  int get _minhasCotas {
    final valor = valueController.text.trim();
    final valorEditado = valor.replaceAll('.', '').replaceAll(',', '.');
    final valorNum = double.tryParse(valorEditado) ?? 0;
    return (valorNum / _precoCota).floor();
  }

  double get _meuPremio {
    final minhasCotas = _minhasCotas;
    final totalCotas = _totalCotasOutros + minhasCotas;
    if (totalCotas == 0 || minhasCotas == 0) return 0;
    return (minhasCotas / totalCotas) * _premioSala;
  }

  Future<void> _carregarDados() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      setState(() => _loading = false);
      return;
    }

    _salaId = await buscarSalaPrincipalId();

    final dadosUsuario = await _authService.getDadosUsuario(user.uid);
    if (dadosUsuario != null) {
      nameController.text = dadosUsuario['nome'] ?? '';
    }

    final apostaDoc = await _firestore
        .collection('Salas')
        .doc(_salaId)
        .collection('Participantes')
        .doc(user.uid)
        .get();

    if (apostaDoc.exists) {
      final dados = apostaDoc.data()!;
      final valor = dados['valor']?.toString() ?? '';
      if (valor.isNotEmpty) {
        valueController.text = _formatarValor(valor);
      }
    }

    setState(() => _loading = false);
  }

  String _formatarValor(String valor) {
    try {
      final numero = double.parse(valor);
      final inteiro = numero.toInt();
      final centavos = ((numero - inteiro) * 100).round();
      return '${inteiro.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')},${centavos.toString().padLeft(2, '0')}';
    } catch (_) {
      return valor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultLayout(
      drawer: AppDrawer(),
      child: Stack(
        children: [
          CustomCard(
            color: const Color(0xFFF3F1EF),
            children: [
              HeaderPaginas(
                text: 'Minha Aposta',
                subtitle: 'Informe seus palpites para os jogos',
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(
                    color: Color(0xFF7CC8B5),
                    strokeWidth: 5,
                  ),
                )
              else
                Form(
                  key: _formKey,
                  child: CustomCard(
                    isChild: true,
                    children: [
                      const SizedBox(height: 20),
                      CustomField(
                        hint: 'Nome',
                        icon: Icons.person_outline,
                        controller: nameController,
                        textInputAction: TextInputAction.next,
                        maxWidth: 480,
                        isRequired: true,
                      ),
                      const SizedBox(height: 15),
                      CustomField(
                        hint: 'Valor',
                        icon: Icons.attach_money,
                        isNumeric: true,
                        controller: valueController,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _confirmar(),
                        maxWidth: 480,
                        isRequired: true,
                        prefix: const Text('R\$ '),
                      ),
                      const SizedBox(height: 15),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: _DisplayInfo(
                                titulo: 'Prêmio estimado',
                                valor: _formatoMoeda.format(_meuPremio),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _DisplayInfo(
                                titulo: 'Cotas',
                                valor: _minhasCotas.toString(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _saving
                          ? const CircularProgressIndicator(
                              color: Color(0xFF7CC8B5),
                              strokeWidth: 5,
                            )
                          : PrimaryButton(
                              text: 'Confirmar',
                              width: 480,
                              onTap: _confirmar,
                            ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmar() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      CustomShowDialog.show(
        context,
        "Você precisa estar logado para registrar uma aposta.",
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      CustomShowDialog.show(context, "Preencha todos os campos!");
      return;
    }

    final nome = nameController.text.trim();
    final valor = valueController.text.trim();
    final valorEditado = valor.replaceAll('.', '').replaceAll(',', '.');
    final navigator = Navigator.of(context);

    final valorNum = double.tryParse(valorEditado) ?? 0;
    if (valorNum == 0 || valorNum % 6 != 0) {
      CustomShowDialog.show(context, "O valor deve ser divisível por 6!");
      return;
    }

    setState(() => _saving = true);

    try {
      final salaId = _salaId ?? await buscarSalaPrincipalId();

      if (nome != (user.displayName ?? '')) {
        await _authService.atualizarNome(nome);
      }

      final apostaRef = _firestore
          .collection('Salas')
          .doc(salaId)
          .collection('Participantes')
          .doc(user.uid);

      final apostaAnterior = await apostaRef.get(
        const GetOptions(source: Source.server),
      );
      final jaEstavaVerificada = apostaAnterior.data()?['verificado'] == true;
      final isAdmin = await _authService.isAdmin(user.uid);

      await apostaRef.set({
        'nome': nome,
        'valor': valorEditado,
        'uid': user.uid,
        'data-hora': FieldValue.serverTimestamp(),
        'verificado': isAdmin ? true : false,
        'editadoAposVerificacao': isAdmin ? false : jaEstavaVerificada,
      });

      navigator.push(
        PageRouteBuilder(
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (_, _, _) => const Participants(),
        ),
      );
    } catch (e) {
      debugPrint('Erro ao salvar aposta: $e');
      if (mounted) {
        CustomShowDialog.show(
          context,
          "Erro ao salvar aposta. Tente novamente.",
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _DisplayInfo extends StatelessWidget {
  final String titulo;
  final String valor;

  const _DisplayInfo({required this.titulo, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFEFEFE),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            titulo,
            softWrap: true,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            valor,
            softWrap: true,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }
}
