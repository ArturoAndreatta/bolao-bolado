import 'dart:async';

import 'package:bolao_bolado/components/formatters/formatters.dart';
import 'package:bolao_bolado/components/shared/custom_field_decoration.dart';
import 'package:bolao_bolado/components/shared/custom_show_dialog.dart';
import 'package:bolao_bolado/components/shared/buttons.dart';
import 'package:bolao_bolado/components/shared/custom_card.dart';
import 'package:bolao_bolado/components/shared/custom_fields.dart';
import 'package:bolao_bolado/components/shared/header_paginas.dart';
import 'package:bolao_bolado/components/shared/skeletons.dart';
import 'package:bolao_bolado/services/bet/bet_service.dart';
import 'package:bolao_bolado/services/bet/preco_cota.dart';
import 'package:bolao_bolado/services/authentication/auth_service.dart';
// import 'package:bolao_bolado/widgets/money_rain.dart'; // comentado junto com moneyRain em build()
import 'package:bolao_bolado/widgets/como_funciona.dart';
import 'package:bolao_bolado/widgets/pix_info.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Card "Minha Aposta": formulário de valor/cotas + chuva de emojis de
// dinheiro proporcional ao valor apostado. Usado dentro da tela de
// Participantes, lado a lado com o painel de participantes.
class MinhaApostaCard extends StatefulWidget {
  final VoidCallback? onApostaConfirmada;

  // No mobile o card ocupa a largura/altura total da tela (mesmo padrão
  // usado pelas seções Participantes e Chat), em vez do tamanho fixo usado
  // lado a lado com o painel de participantes no desktop.
  final bool mobile;
  final double? alturaMobile;
  // Repassado ao CustomCard externo: faz o card ocupar toda a largura
  // disponível do pai (até maxWidth), em vez de encolher para o conteúdo.
  final bool esticarLargura;
  // Esconde o título "Minha Aposta" e o subtítulo: usado no layout de
  // seções (mobile/tablet com Fichario), onde a própria seção selecionada
  // já identifica o conteúdo — o título ficaria redundante.
  final bool mostrarCabecalho;
  // Quando true (usado dentro do Fichario), renderiza só o conteúdo (sem
  // nenhum CustomCard) — o Fichario já monta o cartão branco e a barra de
  // destaque ao redor, então um CustomCard aqui dentro duplicaria a moldura.
  final bool apenasConteudo;

  const MinhaApostaCard({
    super.key,
    this.onApostaConfirmada,
    this.mobile = false,
    this.alturaMobile,
    this.esticarLargura = false,
    this.mostrarCabecalho = true,
    this.apenasConteudo = false,
  });

  @override
  State<MinhaApostaCard> createState() => _MinhaApostaCardState();
}

class _MinhaApostaCardState extends State<MinhaApostaCard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController valueController = TextEditingController();
  final _nomeFocusNode = FocusNode();
  final _valorFocusNode = FocusNode();
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  bool _saving = false;
  String? _salaId;
  bool _apostaExistente = false;
  // Valor exibido no campo assim que a aposta gravada é carregada, usado
  // para restaurar o campo se o usuário sair sem confirmar uma edição.
  String _valorOriginal = '';
  // Atraso antes de restaurar o valor original ao perder foco: clicar no
  // botão "Confirmar" tira o foco do campo ANTES de _confirmar() rodar, e
  // sem esse atraso a restauração corria primeiro, apagando a edição que o
  // usuário estava tentando salvar. _confirmar() cancela este timer assim
  // que é chamado.
  Timer? _restaurarValorTimer;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _salaSubscription;
  StreamSubscription<List<Map<String, Object?>>>? _betsSubscription;
  double _premioSala = 0;
  double _precoCota = kPrecoCotaMega;
  int _totalCotasOutros = 0;
  String _chavePix = '';

  @override
  void initState() {
    super.initState();
    _carregarDados();
    valueController.addListener(_onValorAlterado);
    _valorFocusNode.addListener(_onValorFocusChange);
    _iniciarStreams();
  }

  // Perdeu o foco do campo Valor sem confirmar: restaura o valor gravado
  // (se já existir aposta), descartando a edição em andamento.
  void _onValorFocusChange() {
    if (_valorFocusNode.hasFocus) return;
    if (!_apostaExistente) return;
    _restaurarValorTimer?.cancel();
    _restaurarValorTimer = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      valueController.text = _valorOriginal;
    });
  }

  Future<void> _iniciarStreams() async {
    if (!mounted) return;

    _salaSubscription = streamSalaPrincipal().listen((doc) {
      if (!mounted) return;
      setState(() {
        _premioSala = (doc.data()?['premio'] as num?)?.toDouble() ?? 0;
        _precoCota = precoCotaPara(doc.data()?['sorteio']?.toString());
        _chavePix = doc.data()?['chavePix']?.toString() ?? '';
      });
    });

    _betsSubscription = streamBets().listen((bets) {
      if (!mounted) return;
      final uid = FirebaseAuth.instance.currentUser?.uid;
      setState(() {
        _totalCotasOutros = bets
            .where((item) => item['uid'] != uid)
            .fold<int>(0, (soma, item) => soma + (item['cotas'] as int));
      });
    });
  }

  @override
  void dispose() {
    _restaurarValorTimer?.cancel();
    _salaSubscription?.cancel();
    _betsSubscription?.cancel();
    valueController.removeListener(_onValorAlterado);
    _valorFocusNode.removeListener(_onValorFocusChange);
    nameController.dispose();
    valueController.dispose();
    _nomeFocusNode.dispose();
    _valorFocusNode.dispose();
    super.dispose();
  }

  void _onValorAlterado() => setState(() {});

  double get _valorApostado {
    final valor = valueController.text.trim();
    final valorEditado = valor.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(valorEditado) ?? 0;
  }

  // Botões +/- ao lado do campo Valor: sobem/descem de 6 em 6 (mesmo
  // degrau exigido por _confirmar, que só aceita múltiplos de 6), sempre
  // arredondando para o múltiplo de 6 mais próximo antes de aplicar o
  // passo — assim funciona mesmo se o usuário tiver digitado um valor
  // "quebrado" manualmente.
  static const _passoValor = 6;

  void _ajustarValor(int delta) {
    final atual = _valorApostado.round();
    final baseArredondada = delta > 0
        ? (atual ~/ _passoValor) * _passoValor
        : ((atual + _passoValor - 1) ~/ _passoValor) * _passoValor;
    final novoValor = (baseArredondada + delta).clamp(0, 1 << 30);
    final inteiro = novoValor == 0 ? '' : novoValor.toString();
    valueController.value = TextEditingValue(
      text: _formatarValor(inteiro.isEmpty ? '0' : inteiro),
      selection: TextSelection.collapsed(
        offset: _formatarValor(inteiro.isEmpty ? '0' : inteiro).length,
      ),
    );
  }

  int get _minhasCotas => (_valorApostado / _precoCota).floor();

  // Comentado junto com moneyRain em build() — reativar quando a
  // animação de emojis voltar a ser usada na aba Minha Aposta.
  // Quantidade repassada a MoneyRain: cresce com o valor apostado e satura
  // em maxQuantidade (a partir daí só a raridade dos emojis muda, ver
  // MoneyRain._indiceEmojiPara). R$500 já enche a pilha visualmente.
  // static const _valorSaturacaoEmojis = 500.0;
  //
  // int get _quantidadeEmojis {
  //   final proporcao = (_valorApostado / _valorSaturacaoEmojis).clamp(0.0, 1.0);
  //   return (proporcao * MoneyRain.maxQuantidade).round();
  // }

  double get _meuPremio {
    final minhasCotas = _minhasCotas;
    final totalCotas = _totalCotasOutros + minhasCotas;
    if (totalCotas == 0 || minhasCotas == 0) return 0;
    return (minhasCotas / totalCotas) * _premioSala;
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
        _valorOriginal = valueController.text;
        _apostaExistente = true;
      }
    }

    setState(() => _loading = false);
  }

  String _formatarValor(String valor) {
    try {
      final numero = double.parse(valor);
      final inteiro = numero.toInt();
      final inteiroFormatado = inteiro.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]}.',
      );
      // Sem centavos (cota inteira, ex: Mega R$6): mostra só a parte
      // inteira, no mesmo formato que o campo produz ao digitar do zero.
      if (_precoCota % 1 == 0) return inteiroFormatado;

      final centavos = ((numero - inteiro) * 100).round();
      return '$inteiroFormatado,${centavos.toString().padLeft(2, '0')}';
    } catch (_) {
      return valor;
    }
  }

  // Mais estreito que o padrão (730), mas com folga suficiente para o
  // texto de "Prêmio estimado" e o valor em R$ não cortarem. Alargado um
  // pouco (420->460) para a chave PIX completa não cortar ao lado do QR code.
  static const double _larguraCard = 460;
  // Largura dos campos/botão dentro do card (descontando padding interno).
  static const double _larguraConteudo = 420;

  @override
  Widget build(BuildContext context) {
    // No mobile o card ocupa a altura total calculada pela página (mesma
    // usada pelas abas Participantes/Chat); no desktop mantém a altura
    // fixa histórica que casa com o painel de participantes ao lado.
    final alturaCard = widget.mobile ? widget.alturaMobile : 486.0;
    // Largura dos campos/botão: no mobile acompanha a largura maior do
    // card (730, igual Participantes); no desktop mantém a largura
    // estreita histórica (380) que cabe ao lado do painel de participantes.
    final larguraConteudo = widget.mobile ? 730.0 : _larguraConteudo;

    // Campos do form: extraídos numa lista simples para poderem ser usados
    // tanto soltos (apenasConteudo, dentro do Fichario) quanto envoltos num
    // CustomCard(isChild:true) (desktop / uso fora do Fichario).
    // camposTopo fica com o formulário (nome/valor/prêmio/botão); o bloco
    // Pix + Como Funciona é montado à parte para poder ser empurrado até o
    // fim do card (ver `blocoPixEComoFunciona` mais abaixo).
    final camposTopo = [
      const SizedBox(height: 12),
      FocusTraversalOrder(
        order: const NumericFocusOrder(1),
        child: CustomField(
          hint: 'Nome',
          icon: Icons.person_outline,
          controller: nameController,
          focusNode: _nomeFocusNode,
          textInputAction: TextInputAction.next,
          onFieldSubmitted: (_) => _valorFocusNode.requestFocus(),
          maxWidth: larguraConteudo,
          isRequired: true,
          autofocus: !_apostaExistente,
        ),
      ),
      const SizedBox(height: 10),
      FocusTraversalOrder(
        order: const NumericFocusOrder(2),
        child: CustomField(
          hint: 'Valor',
          icon: Icons.attach_money,
          isNumeric: true,
          // Cota inteira (Mega, R$6) não precisa de centavos; cota
          // fracionada (Lotofácil, R$3,50) precisa aceitar ",50".
          semCentavos: _precoCota % 1 == 0,
          controller: valueController,
          focusNode: _valorFocusNode,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _confirmar(),
          maxWidth: larguraConteudo,
          isRequired: true,
          prefix: const Text('R\$ '),
          autofocus: _apostaExistente,
          suffix: _StepperValorButtons(
            onIncrementar: () => _ajustarValor(_passoValor),
            onDecrementar: () => _ajustarValor(-_passoValor),
          ),
        ),
      ),
      const SizedBox(height: 10),
      ConstrainedBox(
        constraints: BoxConstraints(maxWidth: larguraConteudo),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DisplayInfo(
              titulo: 'Prêmio estimado',
              valor: Formatters.moeda.format(_meuPremio),
            ),
            const SizedBox(height: 8),
            _DisplayInfo(titulo: 'Cotas', valor: _minhasCotas.toString()),
          ],
        ),
      ),
      const SizedBox(height: 12),
      FocusTraversalOrder(
        order: const NumericFocusOrder(3),
        child: _BotaoConfirmar(
          saving: _saving,
          width: larguraConteudo,
          onTap: _confirmar,
        ),
      ),
    ];

    // Bloco Pix + Como Funciona (altura natural, sem forçar tamanho igual
    // entre os dois): usado no mobile (apenasConteudo), logo abaixo do
    // botão Confirmar.
    final blocoPixEComoFunciona = _chavePix.isNotEmpty
        ? Builder(
            builder: (context) {
              final pixInfo = PixInfo(
                chavePix: _chavePix,
                valor: _valorApostado,
              );
              const comoFunciona = ComoFunciona();
              // Lado a lado (50/50) só a partir de 850px de largura de tela;
              // abaixo disso empilha (ComoFunciona embaixo), como era antes.
              final ladoALado = MediaQuery.of(context).size.width >= 850;
              if (ladoALado) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: pixInfo),
                    const SizedBox(width: 12),
                    const Expanded(child: comoFunciona),
                  ],
                );
              }
              return ConstrainedBox(
                constraints: BoxConstraints(maxWidth: larguraConteudo),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [pixInfo, const SizedBox(height: 12), comoFunciona],
                ),
              );
            },
          )
        : ConstrainedBox(
            constraints: BoxConstraints(maxWidth: larguraConteudo),
            child: const ComoFunciona(),
          );

    // Card do Pix isolado (sem o ComoFunciona ao lado), altura natural:
    // usado no desktop, onde só o QR code/chave aparece — "Como funciona" é
    // exclusivo do layout mobile (apenasConteudo).
    final blocoApenasPix = _chavePix.isEmpty
        ? null
        : ConstrainedBox(
            constraints: BoxConstraints(maxWidth: larguraConteudo),
            child: PixInfo(chavePix: _chavePix, valor: _valorApostado),
          );

    // Chuva de emojis: some no fim do card, empurrada para baixo pelo
    // Spacer e ocupando toda a altura restante do card (até onde o PixInfo
    // termina hoje) — em vez de somar altura extra ao conteúdo do form.
    // Comentado por ora — reativar quando a animação de emojis voltar a
    // ser usada na aba Minha Aposta.
    // final moneyRain = widget.mobile && _chavePix.isNotEmpty
    //     ? Expanded(
    //         child: ValueListenableBuilder<MoneyRainEstiloAnimacao>(
    //           valueListenable: moneyRainEstiloGlobal,
    //           builder: (context, estilo, _) {
    //             return MoneyRain(
    //               quantidade: _quantidadeEmojis,
    //               valorReais: _valorApostado,
    //               estiloAnimacao: estilo,
    //             );
    //           },
    //         ),
    //       )
    //     : null;

    final form = Form(
      key: _formKey,
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: widget.apenasConteudo
            // Ocupa a altura cedida pelo Fichario (alturaCard): quando o
            // conteúdo é mais curto que isso, MainAxisAlignment.spaceBetween
            // empurra o bloco Pix/Como Funciona para o fim do card — usa
            // minHeight (não uma altura fixa) para não quebrar quando o
            // conteúdo é mais alto (nomes longos etc.), caso em que apenas
            // rola dentro do card em vez de estourar por baixo dele.
            ? LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ...camposTopo,
                              const SizedBox(height: 12),
                            ],
                          ),
                          blocoPixEComoFunciona,
                        ],
                      ),
                    ),
                  );
                },
              )
            // Form dentro do MESMO CustomCard(isChild: true). No desktop só
            // o card do Pix aparece (com QR code) — "Como funciona" é
            // exclusivo do layout mobile (apenasConteudo).
            : CustomCard(
                isChild: true,
                height: alturaCard,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ...camposTopo,
                          if (blocoApenasPix != null) ...[
                            const SizedBox(height: 12),
                            blocoApenasPix,
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );

    if (widget.apenasConteudo) {
      // Sem altura fixa: o card encolhe para o tamanho real do conteúdo (o
      // bloco Pix + Como Funciona variam de altura conforme a sala), em vez
      // de reservar sempre a altura total da aba e sobrar espaço em branco
      // embaixo quando o conteúdo é mais curto que isso.
      return Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? SizedBox(
                height: alturaCard,
                child: _buildSkeletonConteudo(larguraConteudo),
              )
            : form,
      );
    }

    return CustomCard(
      color: const Color(0xFFF3F1EF),
      // No mobile usa a mesma largura (730) do card de Participantes, para
      // que ambas as seções ocupem a tela até a mesma margem — 420
      // (desktop, lado a lado com o painel) é mais estreito que a tela do
      // celular e deixava o card centralizado com sobra visível dos dois
      // lados. Com esticarLargura, não há teto: o card acompanha a largura
      // real do pai (SizedBox largura infinita dentro do ConstrainedBox).
      maxWidth: widget.esticarLargura
          ? double.infinity
          : (widget.mobile ? 730 : _larguraCard),
      esticarLargura: widget.esticarLargura,
      children: [
        if (widget.mostrarCabecalho)
          const HeaderPaginas(
            text: 'Minha Aposta',
            subtitle: 'Informe seu valor de aposta',
            showBackButton: false,
          ),
        if (_loading) _buildSkeleton(alturaCard, larguraConteudo) else form,
      ],
    );
  }

  List<Widget> _camposSkeleton(double largura) {
    return [
      const SizedBox(height: 12),
      Shimmer(child: SkeletonCampoFormulario(maxWidth: largura)),
      const SizedBox(height: 10),
      Shimmer(child: SkeletonCampoFormulario(maxWidth: largura)),
      const SizedBox(height: 10),
      ConstrainedBox(
        constraints: BoxConstraints(maxWidth: largura),
        child: Shimmer(
          child: Column(
            children: [
              const SkeletonBox(width: double.infinity, height: 48, radius: 10),
              const SizedBox(height: 8),
              const SkeletonBox(width: double.infinity, height: 48, radius: 10),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Shimmer(child: SkeletonBox(width: largura, height: 48, radius: 12)),
      const SizedBox(height: 12),
    ];
  }

  Widget _buildSkeleton(double? altura, double largura) {
    return CustomCard(
      isChild: true,
      height: altura,
      children: _camposSkeleton(largura),
    );
  }

  Widget _buildSkeletonConteudo(double largura) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _camposSkeleton(largura),
    );
  }

  Future<void> _confirmar() async {
    _restaurarValorTimer?.cancel();
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

      final apostaRef = _firestore
          .collection('Salas')
          .doc(salaId)
          .collection('Participantes')
          .doc(user.uid);

      final apostaAnterior = await apostaRef.get(
        const GetOptions(source: Source.server),
      );
      final jaEstavaVerificada = apostaAnterior.data()?['verificado'] == true;
      final isAdmin = await _authService.isAdmin(user.uid);

      await apostaRef.set({
        'nome': nome,
        'valor': valorEditado,
        'uid': user.uid,
        'data-hora': FieldValue.serverTimestamp(),
        'verificado': isAdmin ? true : false,
        'editadoAposVerificacao': isAdmin ? false : jaEstavaVerificada,
      });

      _apostaExistente = true;
      _valorOriginal = valueController.text;
      widget.onApostaConfirmada?.call();
    } catch (e) {
      debugPrint('Erro ao salvar aposta: $e');
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

// Botão "Confirmar" do formulário: vira um spinner enquanto a aposta está
// sendo salva no Firestore.
class _BotaoConfirmar extends StatelessWidget {
  final bool saving;
  final double width;
  final VoidCallback onTap;

  const _BotaoConfirmar({
    required this.saving,
    required this.width,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (saving) {
      return const CircularProgressIndicator(
        color: Color(0xFF7CC8B5),
        strokeWidth: 5,
      );
    }
    return PrimaryButton(text: 'Confirmar', width: width, onTap: onTap);
  }
}

// Botões +/- exibidos dentro do campo Valor (suffix), para subir/descer o
// valor apostado de 6 em 6 sem precisar digitar — mesmo degrau exigido na
// confirmação da aposta (múltiplo de 6).
class _StepperValorButtons extends StatelessWidget {
  final VoidCallback onIncrementar;
  final VoidCallback onDecrementar;

  const _StepperValorButtons({
    required this.onIncrementar,
    required this.onDecrementar,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepperButton(icon: Icons.remove, onTap: onDecrementar),
        _StepperButton(icon: Icons.add, onTap: onIncrementar),
      ],
    );
  }
}

class _StepperButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _StepperButton({required this.icon, required this.onTap});

  @override
  State<_StepperButton> createState() => _StepperButtonState();
}

// Segurar o botão repete onTap continuamente: começa devagar e acelera,
// para permitir tanto ajustes finos (toque único) quanto variações
// grandes de valor (segurar) sem precisar de muitos cliques.
class _StepperButtonState extends State<_StepperButton> {
  Timer? _repeatTimer;
  int _repeticoes = 0;
  final _focusNode = FocusNode(skipTraversal: true, canRequestFocus: false);

  void _iniciarRepeticao() {
    widget.onTap();
    _repeticoes = 0;
    _agendarProximaRepeticao();
  }

  void _agendarProximaRepeticao() {
    final atraso = _repeticoes < 5
        ? const Duration(milliseconds: 350)
        : const Duration(milliseconds: 80);
    _repeatTimer = Timer(atraso, () {
      widget.onTap();
      _repeticoes++;
      _agendarProximaRepeticao();
    });
  }

  void _pararRepeticao() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }

  @override
  void dispose() {
    _pararRepeticao();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _iniciarRepeticao(),
      onTapUp: (_) => _pararRepeticao(),
      onTapCancel: _pararRepeticao,
      child: IconButton(
        icon: Icon(widget.icon, size: 20),
        color: Colors.grey.shade700,
        splashRadius: 20,
        focusNode: _focusNode,
        onPressed: () {},
      ),
    );
  }
}

class _DisplayInfo extends StatelessWidget {
  final String titulo;
  final String valor;

  const _DisplayInfo({required this.titulo, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(CustomFieldDecoration.radius),
        border: const Border.fromBorderSide(
          BorderSide(color: Color(0xFFDDDDDD), width: 1.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            titulo,
            softWrap: true,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              valor,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
