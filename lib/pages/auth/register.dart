import 'package:bolao_bolado/components/shared/custom_show_dialog.dart';
import 'package:bolao_bolado/components/shared/header_paginas.dart';
import 'package:bolao_bolado/components/shell/default_layout.dart';
import 'package:bolao_bolado/components/shared/buttons.dart';
import 'package:bolao_bolado/components/shared/custom_card.dart';
import 'package:bolao_bolado/components/shell/drawer.dart';
import 'package:bolao_bolado/components/shared/custom_fields.dart';
import 'package:bolao_bolado/core/responsive.dart';
import 'package:bolao_bolado/router/app_router.dart';
import 'package:bolao_bolado/services/authentication/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class Register extends StatefulWidget {
  final String? email;
  const Register({super.key, this.email});

  @override
  State<Register> createState() => _RegisterState();
}

class _RegisterState extends State<Register> {
  final nomeController = TextEditingController();
  late final emailController = TextEditingController(text: widget.email);
  final senhaController = TextEditingController();
  final confirmarSenhaController = TextEditingController();
  bool _obscureSenha = true;
  bool _obscureConfirmar = true;
  bool _loading = false;
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();

  @override
  void dispose() {
    nomeController.dispose();
    emailController.dispose();
    senhaController.dispose();
    confirmarSenhaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return DefaultLayout(
      drawer: AppDrawer(),
      child: Stack(
        children: [
          CustomCard(
            color: const Color(0xFFF3F1EF),
            children: [
              HeaderPaginas(
                text: 'Criar conta',
                subtitle: 'Preencha seus dados para se cadastrar',
                onBack: () => context.go(AppRoutes.signup),
              ),
              Form(
                key: _formKey,
                child: CustomCard(
                  isChild: true,
                  children: [
                    const SizedBox(height: 20),
                    CustomField(
                      hint: 'Nome',
                      isRequired: true,
                      icon: Icons.person_outline,
                      controller: nomeController,
                      textInputAction: TextInputAction.next,
                      maxWidth: 480,
                      autofocus: true,
                    ),
                    const SizedBox(height: 15),
                    CustomField(
                      hint: 'E-mail',
                      isRequired: true,
                      icon: Icons.alternate_email,
                      keyboardType: TextInputType.emailAddress,
                      controller: emailController,
                      textInputAction: TextInputAction.next,
                      maxWidth: 480,
                    ),
                    const SizedBox(height: 15),
                    CustomField(
                      hint: 'Senha',
                      isRequired: true,
                      icon: Icons.lock_outline,
                      controller: senhaController,
                      textInputAction: TextInputAction.next,
                      maxWidth: 480,
                      obscure: _obscureSenha,
                      suffix: IconButton(
                        focusNode: FocusNode(skipTraversal: true),
                        onPressed: () =>
                            setState(() => _obscureSenha = !_obscureSenha),
                        icon: Icon(
                          _obscureSenha
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    CustomField(
                      hint: 'Confirmar senha',
                      isRequired: true,
                      icon: Icons.lock_outline,
                      controller: confirmarSenhaController,
                      textInputAction: TextInputAction.done,
                      maxWidth: 480,
                      obscure: _obscureConfirmar,
                      suffix: IconButton(
                        focusNode: FocusNode(skipTraversal: true),
                        onPressed: () => setState(
                          () => _obscureConfirmar = !_obscureConfirmar,
                        ),
                        icon: Icon(
                          _obscureConfirmar
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _loading
                        ? const CircularProgressIndicator()
                        : isMobile
                        ? Column(
                            children: [
                              PrimaryButton(
                                text: 'Cadastrar',
                                onTap: _cadastrar,
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              PrimaryButton(
                                text: 'Cadastrar',
                                width: 233,
                                onTap: _cadastrar,
                              ),
                            ],
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

  void _cadastrar() async {
    if (!_formKey.currentState!.validate()) {
      CustomShowDialog.show(context, "Preencha os campos obrigatórios!");
      return;
    }
    // Validação de igualdade não é feita pelo Form, então é checada manualmente aqui
    if (senhaController.text != confirmarSenhaController.text) {
      CustomShowDialog.show(context, "As senhas não coincidem!");
      return;
    }

    setState(() => _loading = true);

    try {
      await _authService.cadastrar(
        email: emailController.text.trim(),
        senha: senhaController.text,
        nome: nomeController.text.trim(),
      );

      if (mounted) {
        // Cadastro novo → vai pra tela de login/aposta
        context.go(AppRoutes.informarAposta);
      }
    } on Exception catch (e) {
      if (mounted) {
        CustomShowDialog.show(context, _traduzirErro(e.toString()));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Traduz os códigos de erro do FirebaseAuth para mensagens em português
  String _traduzirErro(String erro) {
    if (erro.contains('email-already-in-use')) {
      return 'Este e-mail já está cadastrado.';
    } else if (erro.contains('weak-password')) {
      return 'Senha muito fraca. Use pelo menos 6 caracteres.';
    } else if (erro.contains('invalid-email')) {
      return 'E-mail inválido.';
    }
    return 'Erro ao cadastrar. Tente novamente.';
  }
}
