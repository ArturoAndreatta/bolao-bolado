import 'dart:async';

import 'package:bolao_bolado/components/shared/custom_show_dialog.dart';
import 'package:bolao_bolado/components/shell/default_layout.dart';
import 'package:bolao_bolado/components/shared/buttons.dart';
import 'package:bolao_bolado/components/shared/custom_card.dart';
import 'package:bolao_bolado/components/shell/drawer.dart';
import 'package:bolao_bolado/components/shared/custom_fields.dart';
import 'package:bolao_bolado/components/shared/header_paginas.dart';
import 'package:bolao_bolado/components/shared/skeletons.dart';
import 'package:bolao_bolado/router/app_router.dart';
import 'package:bolao_bolado/services/bet/bet_service.dart';
import 'package:bolao_bolado/services/bet/preco_cota.dart';
import 'package:bolao_bolado/services/authentication/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
  bool _apostaExistente = false;

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

    // Escuta a sala em tempo real: prêmio e sorteio podem mudar enquanto o usuário
    // está preenchendo o formulário, então o preço da cota é recalculado a cada emissão.
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

    // Soma as cotas de todos os outros participantes (exclui o próprio usuário) para
    // manter o cálculo de prêmio estimado atualizado em tempo real.
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

  // Converte o texto no formato pt_BR (ponto de milhar, vírgula decimal) para número
  // antes de calcular quantas cotas o valor informado compra.
  int get _minhasCotas {
    final valor = valueController.text.trim();
    final valorEditado = valor.replaceAll('.', '').replaceAll(',', '.');
    final valorNum = double.tryParse(valorEditado) ?? 0;
    return (valorNum / _precoCota).floor();
  }

  // Prêmio é proporcional à fração de cotas do usuário em relação ao total da sala
  // (minhas cotas + cotas de todos os outros participantes, vindas do stream em tempo real).
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
        _apostaExistente = true;
      }
    }

    setState(() => _loading = false);
  }

  // Formata o valor salvo (número puro) para o padrão pt_BR exibido no campo (1.234,56).
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
                CustomCard(
                  isChild: true,
                  children: [
                    const SizedBox(height: 20),
                    const Shimmer(
                      child: SkeletonCampoFormulario(maxWidth: 480),
                    ),
                    const SizedBox(height: 15),
                    const Shimmer(
                      child: SkeletonCampoFormulario(maxWidth: 480),
                    ),
                    const SizedBox(height: 15),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Shimmer(
                        child: Row(
                          children: [
                            const Expanded(
                              flex: 2,
                              child: SkeletonBox(
                                width: double.infinity,
                                height: 62,
                                radius: 10,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: SkeletonBox(
                                width: double.infinity,
                                height: 62,
                                radius: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Shimmer(
                      child: SkeletonBox(width: 480, height: 48, radius: 12),
                    ),
                    const SizedBox(height: 20),
                  ],
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
                        autofocus: !_apostaExistente,
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
                        autofocus: _apostaExistente,
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

    final valorNum = double.tryParse(valorEditado) ?? 0;
    // Regra de negócio: valor da aposta precisa ser múltiplo do preço da cota (6 números da Mega-Sena).
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

      // Busca direto do servidor (ignora cache local) para saber com certeza se a aposta
      // já havia sido verificada por um admin antes desta edição.
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
        // Apostas feitas/editadas por admin já entram verificadas; participantes comuns
        // sempre precisam de nova verificação manual.
        'verificado': isAdmin ? true : false,
        // Sinaliza para o admin que uma aposta já aprovada foi alterada e precisa ser revista.
        'editadoAposVerificacao': isAdmin ? false : jaEstavaVerificada,
      });

      if (mounted) context.go(AppRoutes.participants);
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
