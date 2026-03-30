import 'package:bolao_bolado/components/shared/dialogs/custom_show_dialog.dart';
import 'package:bolao_bolado/components/shared/header_paginas.dart';
import 'package:bolao_bolado/components/shell/default_layout.dart';
import 'package:bolao_bolado/components/shared/buttons.dart';
import 'package:bolao_bolado/components/shared/custom_card.dart';
import 'package:bolao_bolado/components/shell/drawer.dart';
import 'package:bolao_bolado/components/shared/custom_fields.dart';
import 'package:bolao_bolado/components/shared/back_screen_button.dart';
import 'package:bolao_bolado/core/responsive.dart';
import 'package:flutter/material.dart';

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
  final _formKey = GlobalKey<FormState>();

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
              HeaderPaginas(text: 'Criar conta'),
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
                      maxWidth: 500,
                    ),
                    const SizedBox(height: 15),
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
                      textInputAction: TextInputAction.next,
                      maxWidth: 500,
                      obscure: _obscureSenha,
                      suffix: IconButton(
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
                      maxWidth: 500,
                      obscure: _obscureConfirmar,
                      suffix: IconButton(
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
          BackScreenButton(),
        ],
      ),
    );
  }

  void _cadastrar() {
    if (!_formKey.currentState!.validate()) {
      CustomShowDialog.show(context, "Preencha os campos obrigatórios!");
      return;
    }
    if (senhaController.text != confirmarSenhaController.text) {
      CustomShowDialog.show(context, "As senhas não coincidem!");
      return;
    }
    // TODO: implementar cadastro
  }
}
