import 'package:bolao_bolado/components/shared/custom_show_dialog.dart';
import 'package:bolao_bolado/components/shared/header_paginas.dart';
import 'package:bolao_bolado/components/shell/default_layout.dart';
import 'package:bolao_bolado/components/shared/buttons.dart';
import 'package:bolao_bolado/components/shared/custom_card.dart';
import 'package:bolao_bolado/components/shared/google_sign_in_button.dart';
import 'package:bolao_bolado/components/shared/ou_divider.dart';
import 'package:bolao_bolado/components/shell/drawer.dart';
import 'package:bolao_bolado/components/shared/custom_fields.dart';
import 'package:bolao_bolado/core/responsive.dart';
import 'package:bolao_bolado/router/app_router.dart';
import 'package:bolao_bolado/services/authentication/auth_service.dart';
import 'package:bolao_bolado/core/app_cores.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _carregandoGoogle = false;
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
            color: AppCores.de(context).cardExterno,
            children: [
              HeaderPaginas(
                text: 'Criar conta',
                subtitle: 'Preencha seus dados para se cadastrar',
                onBack: () => context.go(AppRoutes.signup),
              ),
              Form(
                key: _formKey,
                // Mesmo grupo de autofill do login: é o que faz o navegador
                // oferecer pra salvar o par e-mail/senha ao criar a conta.
                child: AutofillGroup(
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
                        autofillHints: const [AutofillHints.name],
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
                        autofillHints: const [
                          AutofillHints.username,
                          AutofillHints.email,
                        ],
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
                        // 'newPassword' e não 'password': avisa o gerenciador que
                        // é conta nova, então ele sugere gerar uma senha em vez
                        // de tentar preencher uma já salva.
                        autofillHints: const [AutofillHints.newPassword],
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
                        autofillHints: const [AutofillHints.newPassword],
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
                      isMobile
                          ? Column(
                              children: [
                                PrimaryButton(
                                  text: 'Cadastrar',
                                  onTap: _cadastrar,
                                  loading: _loading,
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
                                  loading: _loading,
                                ),
                              ],
                            ),
                      const SizedBox(height: 20),
                      const OuDivider(),
                      const SizedBox(height: 20),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: GoogleSignInButton(
                          isLoading: _carregandoGoogle,
                          expanded: true,
                          onPressed: _entrarComGoogle,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
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

      // Só depois da conta existir de verdade é que faz sentido o navegador
      // guardar a credencial.
      TextInput.finishAutofillContext();

      if (mounted) {
        // Cadastro novo → vai direto pra tela de participantes (onde fica o
        // card "Minha Aposta").
        context.go(AppRoutes.participants);
      }
    } on Exception catch (e) {
      if (mounted) {
        CustomShowDialog.show(context, _traduzirErro(e.toString()));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _entrarComGoogle() async {
    setState(() => _carregandoGoogle = true);

    try {
      final credencial = await _authService.entrarComGoogle();
      TextInput.finishAutofillContext();

      // Nulo = a pessoa fechou a janela do Google antes de escolher a conta.
      // Não é erro, então nem diálogo nem navegação.
      if (credencial == null) return;

      if (mounted) context.go(AppRoutes.participants);
    } catch (e) {
      if (mounted) {
        CustomShowDialog.show(context, _traduzirErro(e.toString()));
      }
    } finally {
      if (mounted) setState(() => _carregandoGoogle = false);
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
    } else if (erro.contains('account-exists-with-different-credential')) {
      return 'Este e-mail já tem conta com senha. Entre com e-mail e senha.';
    } else if (erro.contains('popup-blocked')) {
      return 'O navegador bloqueou a janela do Google. Libere e tente de novo.';
    } else if (erro.contains('network-request-failed')) {
      return 'Sem conexão. Verifique a internet e tente de novo.';
    }
    return 'Erro ao cadastrar. Tente novamente.';
  }
}
