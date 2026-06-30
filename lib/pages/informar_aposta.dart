import 'package:bolao_bolado/components/shared/custom_show_dialog.dart';
import 'package:bolao_bolado/components/shell/default_layout.dart';
import 'package:bolao_bolado/components/shared/back_screen_button.dart';
import 'package:bolao_bolado/components/shared/buttons.dart';
import 'package:bolao_bolado/components/shared/custom_card.dart';
import 'package:bolao_bolado/components/shell/drawer.dart';
import 'package:bolao_bolado/components/shared/custom_fields.dart';
import 'package:bolao_bolado/components/shared/header_paginas.dart';
import 'package:bolao_bolado/models/bet.dart';
import 'package:bolao_bolado/pages/participants.dart';
import 'package:bolao_bolado/services/authentication/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  @override
  void dispose() {
    nameController.dispose();
    valueController.dispose();
    super.dispose();
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
              HeaderPaginas(text: 'Minha Aposta'),
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
                      const SizedBox(height: 20),
                      _saving
                          ? const CircularProgressIndicator(
                              color: Color(0xFF7CC8B5),
                              strokeWidth: 5,
                            )
                          : PrimaryButton(text: 'Confirmar', onTap: _confirmar),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
            ],
          ),
          BackScreenButton(),
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

      await _firestore
          .collection('Salas')
          .doc(salaId)
          .collection('Participantes')
          .doc(user.uid)
          .set({
            'nome': nome,
            'valor': valorEditado,
            'uid': user.uid,
            'data-hora': FieldValue.serverTimestamp(),
          });

      navigator.push(
        PageRouteBuilder(pageBuilder: (_, _, _) => const Participants()),
      );
    } catch (e) {
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
