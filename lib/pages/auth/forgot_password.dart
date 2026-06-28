import 'package:bolao_bolado/components/shared/custom_show_dialog.dart';
import 'package:bolao_bolado/components/shared/header_paginas.dart';
import 'package:bolao_bolado/components/shell/default_layout.dart';
import 'package:bolao_bolado/components/shared/buttons.dart';
import 'package:bolao_bolado/components/shared/custom_card.dart';
import 'package:bolao_bolado/components/shell/drawer.dart';
import 'package:bolao_bolado/components/shared/custom_fields.dart';
import 'package:bolao_bolado/components/shared/back_screen_button.dart';
import 'package:bolao_bolado/services/authentication/auth_service.dart';
import 'package:flutter/material.dart';

class RecuperarSenha extends StatefulWidget {
  final String? email;
  const RecuperarSenha({super.key, this.email});

  @override
  State<RecuperarSenha> createState() => _RecuperarSenhaState();
}

class _RecuperarSenhaState extends State<RecuperarSenha> {
  late final emailController = TextEditingController(text: widget.email);
  bool _loading = false;
  bool _enviado = false;
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();

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
                    if (_enviado)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.mark_email_read_outlined,
                              size: 60,
                              color: Color(0xFF7CC8B5),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'E-mail enviado para\n${emailController.text}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Verifique sua caixa de entrada e spam.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      CustomField(
                        hint: 'E-mail',
                        isRequired: true,
                        icon: Icons.alternate_email,
                        keyboardType: TextInputType.emailAddress,
                        controller: emailController,
                        textInputAction: TextInputAction.done,
                        maxWidth: 480,
                      ),
                      const SizedBox(height: 20),
                      _loading
                          ? const CircularProgressIndicator()
                          : PrimaryButton(text: 'Enviar', onTap: _enviar),
                    ],
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

  void _enviar() async {
    if (!_formKey.currentState!.validate()) {
      CustomShowDialog.show(context, "Preencha o e-mail!");
      return;
    }

    setState(() => _loading = true);

    try {
      await _authService.recuperarSenha(emailController.text.trim());
      if (mounted) setState(() => _enviado = true);
    } on Exception catch (e) {
      if (mounted) {
        final msg = e.toString().contains('user-not-found')
            ? 'E-mail não encontrado.'
            : 'Erro ao enviar e-mail. Tente novamente.';
        CustomShowDialog.show(context, msg);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
