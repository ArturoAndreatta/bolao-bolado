import 'package:bolao_bolado/components/shared/custom_show_dialog.dart';
import 'package:bolao_bolado/components/shared/header_paginas.dart';
import 'package:bolao_bolado/components/shell/default_layout.dart';
import 'package:bolao_bolado/components/shared/buttons.dart';
import 'package:bolao_bolado/components/shared/custom_card.dart';
import 'package:bolao_bolado/components/shell/drawer.dart';
import 'package:bolao_bolado/components/shared/custom_fields.dart';
import 'package:bolao_bolado/components/shared/back_screen_button.dart';
import 'package:flutter/material.dart';

class RecuperarSenha extends StatefulWidget {
  final String? email;
  const RecuperarSenha({super.key, this.email});

  @override
  State<RecuperarSenha> createState() => _RecuperarSenhaState();
}

class _RecuperarSenhaState extends State<RecuperarSenha> {
  late final emailController = TextEditingController(text: widget.email);
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
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
              HeaderPaginas(text: 'Recuperar senha'),
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
                      textInputAction: TextInputAction.done,
                      maxWidth: 500,
                    ),
                    const SizedBox(height: 20),
                    PrimaryButton(text: 'Enviar', onTap: _enviar),
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

  void _enviar() {
    if (!_formKey.currentState!.validate()) {
      CustomShowDialog.show(context, "Preencha o e-mail!");
      return;
    }
    // TODO: implementar envio de recuperação de senha
  }
}
