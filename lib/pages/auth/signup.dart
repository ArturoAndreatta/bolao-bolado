import 'dart:math' as math;

import 'package:bolao_bolado/components/shared/custom_show_dialog.dart';
import 'package:bolao_bolado/components/shared/header_paginas.dart';
import 'package:bolao_bolado/components/shell/default_layout.dart';
import 'package:bolao_bolado/components/shared/buttons.dart';
import 'package:bolao_bolado/components/shared/custom_card.dart';
import 'package:bolao_bolado/components/shared/google_sign_in_button.dart';
import 'package:bolao_bolado/components/shared/ou_divider.dart';
import 'package:bolao_bolado/components/shell/drawer.dart';
import 'package:bolao_bolado/components/shared/custom_fields.dart';
import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/core/responsive.dart';
import 'package:bolao_bolado/router/app_router.dart';
import 'package:bolao_bolado/services/authentication/auth_service.dart';
import 'package:bolao_bolado/services/authentication/autofill_navegador.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class Signup extends StatefulWidget {
  const Signup({super.key});

  @override
  State<Signup> createState() => _SignupState();
}

class _SignupState extends State<Signup> with SingleTickerProviderStateMixin {
  final emailController = TextEditingController();
  final senhaController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  bool _carregandoGoogle = false;
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  late final VigiaAutofill _vigiaAutofill;

  // Duração do preenchimento INTEIRO — e-mail e senha juntos —, não de cada
  // caractere. Assim credencial curta e credencial longa terminam no mesmo
  // tempo: o que muda é quantas letras entram por quadro, não a espera.
  static const _duracaoDigitacao = Duration(milliseconds: 160);

  // A animação é tocada por um controller em vez de um laço de espera porque
  // ela precisa andar junto com os quadros da tela: abaixo de ~16ms nenhuma
  // espera vira letra visível, e um laço de 8ms só gastaria trabalho pintando
  // duas vezes o mesmo quadro.
  late final AnimationController _digitacao =
      AnimationController(vsync: this, duration: _duracaoDigitacao)
        ..addListener(_pintarDigitacao)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) _encerrarDigitacao();
        });

  // O que o gerenciador mandou. Nulo = campo que não faz parte desta rodada.
  String? _alvoEmail;
  String? _alvoSenha;
  // Último texto que a animação escreveu. Se o campo deixar de bater com isso,
  // foi alguém digitando por cima — e quem digita tem preferência.
  String _escritoEmail = '';
  String _escritoSenha = '';

  @override
  void initState() {
    super.initState();
    // Gerenciador de senhas que abre lista em janela à parte (Chaveiro do
    // iCloud) escreve nos campos depois que o Flutter já encerrou a sessão de
    // edição, então o texto não chega sozinho. Ver autofill_navegador.dart.
    _vigiaAutofill = observarAutofillDoNavegador(_preencherDigitando);
  }

  @override
  void dispose() {
    _vigiaAutofill.parar();
    _digitacao.dispose();
    emailController.dispose();
    senhaController.dispose();
    super.dispose();
  }

  // Escreve o que o gerenciador de senhas mandou letra por letra, e-mail e
  // depois senha. O clique na credencial acontece fora da página (a lista do
  // iCloud é outra janela), então preencher de uma vez fazia o texto surgir do
  // nada; entrando, dá para ver que veio de fora e qual campo foi preenchido.
  void _preencherDigitando(String? email, String? senha) {
    // Descarta o que é ECO DA PRÓPRIA DIGITAÇÃO.
    //
    // A vigia lê os inputs do DOM de 200 em 200ms e não tem como saber quem
    // escreveu neles. No celular o Flutter web espelha cada tecla nesses
    // mesmos inputs, então cada letra digitada chegava aqui como se fosse um
    // preenchimento novo: o campo era limpo e reescrito letra por letra por
    // cima de quem estava digitando.
    //
    // O que separa um caso do outro é a DIREÇÃO. Digitação (ou o espelho
    // atrasado dela) só produz valor igual ao que o campo já tem, ou um
    // pedaço dele — por isso `startsWith`, que cobre os dois. Preenchimento
    // de verdade vem do outro lado: o campo tem "" (ou "art") e chega
    // "arturo@exemplo.com", que NÃO é começo do que está lá. Assim continua
    // funcionando o caso comum de digitar três letras e tocar na sugestão.
    if (email != null && emailController.text.startsWith(email)) email = null;
    if (senha != null && senhaController.text.startsWith(senha)) senha = null;
    if (email == null && senha == null) return;

    // O Flutter espelha o texto dos campos de volta nos inputs do DOM que a
    // vigia observa. Sem a pausa, cada letra escrita voltava como se fosse um
    // preenchimento novo e reiniciava a animação — o e-mail parava nas
    // primeiras letras, as únicas que cabiam entre duas leituras.
    _vigiaAutofill.pausar();

    _alvoEmail = email;
    _alvoSenha = senha;
    _escritoEmail = '';
    _escritoSenha = '';
    if (email != null) emailController.text = '';
    if (senha != null) senhaController.text = '';

    _digitacao.forward(from: 0);
  }

  void _pintarDigitacao() {
    final email = _alvoEmail;
    final senha = _alvoSenha;
    final total = (email?.length ?? 0) + (senha?.length ?? 0);
    if (total == 0) return;

    // easeOut: a maior parte do texto entra no começo, e o fim desacelera —
    // lido como uma rajada que assenta, não como digitação mecânica.
    final letras = (Curves.easeOut.transform(_digitacao.value) * total).round();

    if (email != null) {
      if (emailController.text != _escritoEmail) return _abortarDigitacao();
      final parte = email.substring(0, math.min(letras, email.length));
      if (parte != _escritoEmail) {
        _escritoEmail = parte;
        emailController.text = parte;
      }
    }

    if (senha != null) {
      if (senhaController.text != _escritoSenha) return _abortarDigitacao();
      final sobra = math.max(letras - (email?.length ?? 0), 0);
      final parte = senha.substring(0, math.min(sobra, senha.length));
      if (parte != _escritoSenha) {
        _escritoSenha = parte;
        senhaController.text = parte;
      }
    }
  }

  void _abortarDigitacao() {
    _digitacao.stop();
    _encerrarDigitacao();
  }

  void _encerrarDigitacao() {
    _alvoEmail = null;
    _alvoSenha = null;
    _vigiaAutofill.retomar();
    // Os campos ficam com a borda vermelha de quando estavam vazios: a
    // validação só roda por interação, e preenchimento de fora não conta como
    // uma. Revalidar aqui apaga o erro de algo que já foi resolvido.
    if (emailController.text.isNotEmpty && senhaController.text.isNotEmpty) {
      _formKey.currentState?.validate();
    }
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
                text: 'Acesse sua conta',
                subtitle: 'Entre para continuar',
              ),
              Form(
                key: _formKey,
                // AutofillGroup: é ele que faz e-mail e senha serem tratados
                // como UM login pelo gerenciador de senhas. Sem o grupo, cada
                // campo seria um formulário solto e o par salvo não casaria.
                child: AutofillGroup(
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
                        autofocus: true,
                        // 'username' (e não só 'email') porque é o nome que os
                        // gerenciadores usam pra casar com a credencial salva.
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
                        // Enter no campo senha → chama _logar
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _logar(),
                        maxWidth: 480,
                        obscure: _obscure,
                        autofillHints: const [AutofillHints.password],
                        suffix: IconButton(
                          focusNode: FocusNode(skipTraversal: true),
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
                      isMobile
                          ? Column(
                              children: [
                                PrimaryButton(
                                  text: 'Logar',
                                  onTap: _logar,
                                  loading: _loading,
                                ),
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
                                  loading: _loading,
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

      // Fecha o contexto de autofill só depois do login dar certo: é isso que
      // faz o navegador oferecer "salvar/atualizar senha". Chamar antes faria
      // ele guardar credencial errada a cada tentativa falha.
      TextInput.finishAutofillContext();

      if (mounted) {
        context.go(AppRoutes.participants);
      }
    } catch (e) {
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
      // Fecha o contexto de autofill mesmo aqui: mantê-lo aberto depois de um
      // login bem-sucedido por outro caminho podia deixar o navegador
      // sugerindo salvar um par e-mail/senha vazio.
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

  void _irParaCadastro() {
    context.go(
      Uri(
        path: AppRoutes.register,
        queryParameters: {'email': emailController.text},
      ).toString(),
    );
  }

  void _recuperarSenha() {
    context.go(
      Uri(
        path: AppRoutes.forgotPassword,
        queryParameters: {'email': emailController.text},
      ).toString(),
    );
  }

  // Traduz os códigos de erro do FirebaseAuth para mensagens em português
  String _traduzirErro(String erro) {
    if (erro.contains('user-not-found') ||
        erro.contains('wrong-password') ||
        erro.contains('invalid-credential')) {
      return 'E-mail ou senha incorretos.';
    } else if (erro.contains('user-disabled')) {
      return 'Conta desativada. Entre em contato com o suporte.';
    } else if (erro.contains('too-many-requests')) {
      return 'Muitas tentativas. Tente novamente mais tarde.';
    } else if (erro.contains('account-exists-with-different-credential')) {
      return 'Este e-mail já tem conta com senha. Entre com e-mail e senha.';
    } else if (erro.contains('popup-blocked')) {
      return 'O navegador bloqueou a janela do Google. Libere e tente de novo.';
    } else if (erro.contains('network-request-failed')) {
      return 'Sem conexão. Verifique a internet e tente de novo.';
    }
    return 'Erro ao fazer login. Tente novamente.';
  }
}
