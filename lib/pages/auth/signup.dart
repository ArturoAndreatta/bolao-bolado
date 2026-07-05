import 'package:bolao_bolado/components/shared/back_screen_button.dart';
import 'package:bolao_bolado/components/shared/custom_show_dialog.dart';
import 'package:bolao_bolado/components/shared/header_paginas.dart';
import 'package:bolao_bolado/components/shell/default_layout.dart';
import 'package:bolao_bolado/components/shared/buttons.dart';
import 'package:bolao_bolado/components/shared/custom_card.dart';
import 'package:bolao_bolado/components/shell/drawer.dart';
import 'package:bolao_bolado/components/shared/custom_fields.dart';
import 'package:bolao_bolado/pages/auth/forgot_password.dart';
import 'package:bolao_bolado/pages/auth/register.dart';
import 'package:bolao_bolado/pages/pages.dart';
import 'package:bolao_bolado/pages/participants.dart';
import 'package:bolao_bolado/core/responsive.dart';
import 'package:bolao_bolado/services/authentication/auth_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class Signup extends StatefulWidget {
  const Signup({super.key});

  @override
  State<Signup> createState() => _SignupState();
}

class _SignupState extends State<Signup> {
  final emailController = TextEditingController();
  final senhaController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();

  @override
  void dispose() {
    emailController.dispose();
    senhaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktopWeb = kIsWeb && width >= 900;
    final isMobile = Responsive.isMobile(context);

    return DefaultLayout(
      drawer: AppDrawer(),
      child: Stack(
        children: [
          CustomCard(
            color: const Color(0xFFF3F1EF),
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
                      text: 'Acesse sua conta',
                      subtitle: 'Entre para continuar',
                    ),
                  ),
                ],
              ),
              Form(
                key: _formKey,
                child: CustomCard(
                  isChild: true,
                  children: [
                    const SizedBox(height: 20),
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
                      // Enter no campo senha → chama _logar
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _logar(),
                      maxWidth: 480,
                      obscure: _obscure,
                      suffix: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _recuperarSenha,
                          child: const Text('Esqueci minha senha'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _loading
                        ? const CircularProgressIndicator()
                        : isMobile
                        ? Column(
                            children: [
                              PrimaryButton(text: 'Logar', onTap: _logar),
                              const SizedBox(height: 14),
                              SecondaryButton(
                                text: 'Cadastrar',
                                onTap: _irParaCadastro,
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              PrimaryButton(
                                text: 'Logar',
                                width: 233,
                                onTap: _logar,
                              ),
                              const SizedBox(width: 14),
                              SecondaryButton(
                                text: 'Cadastrar',
                                width: 233,
                                onTap: _irParaCadastro,
                              ),
                            ],
                          ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            top: 10,
            left: isDesktopWeb ? 500 : 250,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () {
                  Navigator.of(context).push(
                    PageRouteBuilder(
                      transitionDuration: Duration.zero,
                      reverseTransitionDuration: Duration.zero,
                      pageBuilder: (_, _, _) => Pages(),
                    ),
                  );
                },
                child: Container(padding: const EdgeInsets.all(20)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _logar() async {
    if (!_formKey.currentState!.validate()) {
      CustomShowDialog.show(context, "Preencha os campos obrigatórios!");
      return;
    }

    setState(() => _loading = true);

    try {
      await _authService.logar(
        email: emailController.text.trim(),
        senha: senhaController.text,
      );

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder(
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
            pageBuilder: (_, _, _) => const Participants(),
          ),
          (route) => false,
        );
      }
    } on Exception catch (e) {
      if (mounted) {
        CustomShowDialog.show(context, _traduzirErro(e.toString()));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _irParaCadastro() {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, _, _) => Register(email: emailController.text),
      ),
    );
  }

  void _recuperarSenha() {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, _, _) => RecuperarSenha(email: emailController.text),
      ),
    );
  }

  String _traduzirErro(String erro) {
    if (erro.contains('user-not-found') ||
        erro.contains('wrong-password') ||
        erro.contains('invalid-credential')) {
      return 'E-mail ou senha incorretos.';
    } else if (erro.contains('user-disabled')) {
      return 'Conta desativada. Entre em contato com o suporte.';
    } else if (erro.contains('too-many-requests')) {
      return 'Muitas tentativas. Tente novamente mais tarde.';
    }
    return 'Erro ao fazer login. Tente novamente.';
  }
}
