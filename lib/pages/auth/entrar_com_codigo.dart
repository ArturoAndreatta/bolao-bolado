import 'dart:async';

import 'package:bolao_bolado/components/shared/buttons.dart';
import 'package:bolao_bolado/components/shared/custom_card.dart';
import 'package:bolao_bolado/components/shared/custom_fields.dart';
import 'package:bolao_bolado/components/shared/custom_show_dialog.dart';
import 'package:bolao_bolado/components/shared/header_paginas.dart';
import 'package:bolao_bolado/components/shell/default_layout.dart';
import 'package:bolao_bolado/components/shell/drawer.dart';
import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/router/app_router.dart';
import 'package:bolao_bolado/services/authentication/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Login sem senha: a pessoa informa o e-mail, recebe um código de 6 dígitos
/// e entra com ele. Só vale para conta que já existe — quem não tem conta
/// simplesmente não recebe o código (o backend não revela qual é o caso).
class EntrarComCodigo extends StatefulWidget {
  final String? email;
  const EntrarComCodigo({super.key, this.email});

  @override
  State<EntrarComCodigo> createState() => _EntrarComCodigoState();
}

class _EntrarComCodigoState extends State<EntrarComCodigo> {
  late final emailController = TextEditingController(text: widget.email);
  final codigoController = TextEditingController();
  final _formEmailKey = GlobalKey<FormState>();
  final _formCodigoKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();

  bool _loading = false;
  // Troca o formulário de e-mail pelo de código depois do primeiro envio.
  bool _codigoEnviado = false;

  // Espera para reenviar. O backend já limita a 3 códigos por hora; isto só
  // evita que a pessoa gaste esses 3 em segundos tocando "reenviar" antes de
  // o primeiro e-mail ter tempo de chegar.
  static const _esperaReenvio = 60;
  int _segundosParaReenviar = 0;
  Timer? _contagem;

  static final _regexCodigo = RegExp(r'^\d{6}$');

  @override
  void dispose() {
    _contagem?.cancel();
    emailController.dispose();
    codigoController.dispose();
    super.dispose();
  }

  // Quem copia o código do e-mail às vezes traz espaço junto (o e-mail mostra
  // os dígitos espaçados); tirar aqui evita recusar um código certo.
  String get _codigoDigitado => codigoController.text.replaceAll(' ', '');

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);

    return DefaultLayout(
      drawer: AppDrawer(),
      child: Stack(
        children: [
          CustomCard(
            color: cores.cardExterno,
            children: [
              HeaderPaginas(
                text: 'Entrar com código',
                subtitle: _codigoEnviado
                    ? 'Digite o código que enviamos por e-mail'
                    : 'Receba um código de acesso no seu e-mail',
                onBack: () => context.go(AppRoutes.signup),
              ),
              if (_codigoEnviado)
                _formularioCodigo(cores)
              else
                _formularioEmail(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _formularioEmail() {
    return Form(
      key: _formEmailKey,
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
            onFieldSubmitted: (_) => _enviarCodigo(),
            maxWidth: 480,
            autofocus: true,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            text: 'Enviar código',
            onTap: _enviarCodigo,
            loading: _loading,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _formularioCodigo(AppCores cores) {
    return Form(
      key: _formCodigoKey,
      child: CustomCard(
        isChild: true,
        children: [
          const SizedBox(height: 20),
          Text(
            'Se ${emailController.text.trim()} tiver conta, o código chega '
            'em instantes. Confira também o spam.',
            textAlign: TextAlign.center,
            style: TextStyle(color: cores.textoSuave),
          ),
          const SizedBox(height: 20),
          CustomField(
            hint: 'Código de 6 dígitos',
            isRequired: true,
            icon: Icons.pin_outlined,
            keyboardType: TextInputType.number,
            controller: codigoController,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _entrar(),
            maxWidth: 480,
            autofocus: true,
            // oneTimeCode: o teclado do celular oferece o código recebido.
            autofillHints: const [AutofillHints.oneTimeCode],
            validator: (_) =>
                _regexCodigo.hasMatch(_codigoDigitado) ? null : '',
          ),
          const SizedBox(height: 20),
          PrimaryButton(text: 'Entrar', onTap: _entrar, loading: _loading),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: TextButton(
                    onPressed: _trocarEmail,
                    child: const Text('Trocar e-mail'),
                  ),
                ),
                Flexible(
                  child: TextButton(
                    onPressed: _segundosParaReenviar > 0 || _loading
                        ? null
                        : _enviarCodigo,
                    child: Text(
                      _segundosParaReenviar > 0
                          ? 'Reenviar em ${_segundosParaReenviar}s'
                          : 'Reenviar código',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _enviarCodigo() async {
    if (!_codigoEnviado && !_formEmailKey.currentState!.validate()) {
      CustomShowDialog.show(context, 'Preencha o e-mail!');
      return;
    }

    setState(() => _loading = true);

    try {
      await _authService.enviarCodigoLogin(emailController.text.trim());
      if (!mounted) return;
      setState(() => _codigoEnviado = true);
      _iniciarContagemReenvio();
    } on FalhaLoginPorCodigo catch (e) {
      if (mounted) CustomShowDialog.show(context, e.mensagem);
    } catch (_) {
      if (mounted) {
        CustomShowDialog.show(
          context,
          'Sem conexão. Verifique a internet e tente de novo.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _entrar() async {
    if (_loading) return;
    if (!_formCodigoKey.currentState!.validate()) {
      CustomShowDialog.show(context, 'Digite os 6 dígitos do código.');
      return;
    }

    setState(() => _loading = true);

    try {
      await _authService.entrarComCodigo(
        email: emailController.text.trim(),
        codigo: _codigoDigitado,
      );
      if (mounted) context.go(AppRoutes.participants);
    } on FalhaLoginPorCodigo catch (e) {
      if (mounted) CustomShowDialog.show(context, e.mensagem);
    } catch (_) {
      if (mounted) {
        CustomShowDialog.show(context, 'Erro ao entrar. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _trocarEmail() {
    _contagem?.cancel();
    codigoController.clear();
    setState(() {
      _codigoEnviado = false;
      _segundosParaReenviar = 0;
    });
  }

  void _iniciarContagemReenvio() {
    _contagem?.cancel();
    setState(() => _segundosParaReenviar = _esperaReenvio);
    _contagem = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _segundosParaReenviar--);
      if (_segundosParaReenviar <= 0) timer.cancel();
    });
  }
}
