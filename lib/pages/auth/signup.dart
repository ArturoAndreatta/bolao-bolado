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
import 'package:bolao_bolado/pages/informar_aposta.dart';
import 'package:bolao_bolado/pages/pages.dart';
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
  final _formKey = GlobalKey<FormState>();

  AuthService authService = .new();

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
              HeaderPaginas(text: 'Acesse sua conta'),
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
                      maxWidth: 500,
                    ),
                    const SizedBox(height: 15),
                    CustomField(
                      hint: 'Senha',
                      isRequired: true,
                      icon: Icons.lock_outline,
                      controller: senhaController,
                      textInputAction: TextInputAction.done,
                      maxWidth: 500,
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
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _recuperarSenha,
                          child: const Text('Esqueci minha senha'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    isMobile
                        ? Column(
                            children: [
                              PrimaryButton(text: 'Logar', onTap: _logar),
                              const SizedBox(height: 14),
                              SecondaryButton(
                                text: 'Cadastrar',
                                onTap: _cadastrar,
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
          BackScreenButton(),
        ],
      ),
    );
  }

  void _logar() {
    if (!_formKey.currentState!.validate()) {
      CustomShowDialog.show(context, "Preencha os campos obrigatórios!");
      return;
    }

    authService.logar(email: emailController.text, senha: senhaController.text);
  }

  void _cadastrar() {
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
}
