import 'dart:async';

import 'package:bolao_bolado/components/formatters/formatters.dart';
import 'package:bolao_bolado/components/shared/custom_field_decoration.dart';
import 'package:bolao_bolado/components/shared/custom_show_dialog.dart';
import 'package:bolao_bolado/components/shared/numero_rolante.dart';
import 'package:bolao_bolado/components/shared/buttons.dart';
import 'package:bolao_bolado/components/shared/custom_card.dart';
import 'package:bolao_bolado/components/shared/custom_fields.dart';
import 'package:bolao_bolado/components/shared/header_paginas.dart';
import 'package:bolao_bolado/components/shared/skeletons.dart';
import 'package:bolao_bolado/components/shared/snackbar_deslizante.dart';
import 'package:bolao_bolado/core/aparelho.dart';
import 'package:bolao_bolado/core/app_radii.dart';
import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/core/debug_flags.dart';
import 'package:bolao_bolado/services/bet/bet_service.dart';
import 'package:bolao_bolado/services/bet/jogos_aposta.dart';
import 'package:bolao_bolado/services/bet/preco_cota.dart';
import 'package:bolao_bolado/services/bet/valor_maximo.dart';
import 'package:bolao_bolado/services/authentication/auth_service.dart';
import 'package:bolao_bolado/widgets/pix_info.dart';
import 'package:bolao_bolado/widgets/selecao_jogos_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Card "Minha Aposta": formulário onde o usuário informa nome e valor,
// vê quantas cotas aquilo compra e o prêmio estimado, e confirma a aposta.
// No desktop aparece lado a lado com o painel de Participantes; no mobile é
// uma das seções da barra inferior (ver [apenasConteudo]).
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
  // Esconde o título "Minha Aposta" e o subtítulo, para quando quem monta o
  // card em volta já desenha o próprio cabeçalho.
  final bool mostrarCabecalho;
  // Quando true (mobile), renderiza só o conteúdo, sem nenhum CustomCard nem
  // cabeçalho: no celular as seções ficam direto sobre o fundo da página.
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
  String? _sorteio;
  int _totalCotasOutros = 0;
  String _chavePix = '';
  // Teto por aposta configurado na sala; null quando a sala não tem limite.
  double? _valorMaximo;
  // Jogos escolhidos pelo participante, opcional (números próprios em vez de
  // deixar por conta de quem compra os bilhetes). Vazio = não escolheu.
  // Cada jogo consome cotas conforme o tamanho — ver jogos_aposta.dart.
  List<List<int>> _jogos = [];
  // Data do sorteio e situação da aposta deste usuário, para o bloco do topo
  // no celular (ver _SituacaoAposta). Os dois vêm das streams que o card já
  // escuta — sala e apostas —, sem leitura extra.
  DateTime? _dataSorteio;
  _Situacao _situacao = _Situacao.semAposta;
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
    if (!_apostaExistente) {
      // Sem aposta gravada pra restaurar: nunca deixa o campo vazio/zerado,
      // pra não disparar o erro "Campo obrigatório" (que cresce o card e
      // gera scroll indevido) — volta pro mínimo apostável, que é UMA cota
      // da sala (R$6 na Mega, R$3,50 na Lotofácil).
      _restaurarValorTimer?.cancel();
      _restaurarValorTimer = Timer(const Duration(milliseconds: 200), () {
        if (!mounted) return;
        if (_valorApostado < _precoCota) {
          valueController.text = _formatarValor(_precoCota.toString());
        }
      });
      return;
    }
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
        _sorteio = doc.data()?['sorteio']?.toString();
        _dataSorteio = (doc.data()?['dataHora'] as Timestamp?)?.toDate();
        _precoCota = precoCotaPara(_sorteio);
        _chavePix = doc.data()?['chavePix']?.toString() ?? '';
        // Sai do mesmo snapshot já em uso: o teto acompanha edições do admin
        // sem custar nenhuma leitura extra.
        _valorMaximo = valorMaximoDe(doc.data()?['valorMaximo']);
      });
    });

    _betsSubscription = streamBets().listen(
      (bets) {
        if (!mounted) return;
        final uid = FirebaseAuth.instance.currentUser?.uid;
        final minha = bets.where((item) => item['uid'] == uid).firstOrNull;
        final situacao = _Situacao.de(minha);
        final totalCotasOutros = bets
            .where((item) => item['uid'] != uid)
            .fold<int>(0, (soma, item) => soma + (item['cotas'] as int));
        // A stream compartilhada emite muito mais do que este card precisa:
        // qualquer aposta de outra pessoa, e a lista inteira de novo a cada
        // leva de avatares que chega do Firestore. Das emissões, o card só
        // usa esses dois números — reconstruir o formulário inteiro quando
        // nenhum deles mudou era trabalho jogado fora, repetido várias vezes
        // na primeira carga.
        if (situacao == _situacao && totalCotasOutros == _totalCotasOutros) {
          return;
        }
        setState(() {
          _situacao = situacao;
          _totalCotasOutros = totalCotasOutros;
        });
      },
      // Falha na stream de apostas só congela o "Prêmio estimado" no último
      // valor conhecido; sem este onError, o erro subia como exceção
      // assíncrona não tratada e derrubava o zone de erro do app.
      onError: (_) {},
    );
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

  // O controller avisa também quando só o cursor ou a seleção mudam (clicar
  // no campo, arrastar o mouse, cada seta do teclado). O card depende só do
  // TEXTO, então reconstruí-lo nesses casos não mudava nada na tela.
  String _ultimoTextoValor = '';

  void _onValorAlterado() {
    final texto = valueController.text;
    if (texto == _ultimoTextoValor) return;
    _ultimoTextoValor = texto;
    setState(() {});
  }

  double get _valorApostado {
    final valor = valueController.text.trim();
    final valorEditado = valor.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(valorEditado) ?? 0;
  }

  /// Move o valor apostado em [deltaCotas] cotas (+1 / -1 pelos botões),
  /// respeitando o preço de cota e o teto da sala — ver [ajustarValorEmCotas].
  ///
  /// O passo era 6 fixo (preço da Mega-Sena): em sala de Lotofácil o stepper
  /// andava de 6 em 6, valores que não fecham cota de R$3,50, e a confirmação
  /// recusava tudo que viesse dos botões.
  void _ajustarValor(int deltaCotas) {
    final novoValor = ajustarValorEmCotas(
      valor: _valorApostado,
      deltaCotas: deltaCotas,
      precoCota: _precoCota,
      valorMaximo: _valorMaximo,
    );
    final texto = _formatarValor(novoValor.toString());
    valueController.value = TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }

  int get _minhasCotas => (_valorApostado / _precoCota).floor();

  // Cotas já comprometidas com os jogos escolhidos. Pode passar de
  // _minhasCotas se o usuário montar os jogos e DEPOIS reduzir o valor — daí
  // o aviso no botão e o bloqueio em _confirmar().
  int get _cotasDosJogos => cotasDosJogos(_jogos, _sorteio);

  Future<void> _abrirSelecaoJogos() async {
    final resultado = await mostrarSelecaoJogos(
      context,
      sorteio: _sorteio,
      cotasDisponiveis: _minhasCotas,
      jogosIniciais: _jogos,
    );
    if (resultado == null || !mounted) return;
    setState(() => _jogos = resultado);
  }

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

    // Nome do usuário e ID da sala principal não dependem um do outro, então
    // as duas leituras saem juntas em vez de uma esperar a outra. Só a busca
    // da aposta precisa vir depois (precisa do salaId).
    final (dadosUsuario, salaId) = await (
      _authService.perfil(user.uid),
      buscarSalaPrincipalId(),
    ).wait;

    if (!mounted) return;
    _salaId = salaId;
    if (dadosUsuario != null) {
      nameController.text = dadosUsuario['nome'] ?? '';
    }

    final apostaDoc = await _firestore
        .collection('Salas')
        .doc(salaId)
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
      // jogosDeDados também entende o campo legado `numeros` (jogo único na
      // raiz do doc), para apostas gravadas antes dos vários jogos.
      _jogos = jogosDeDados(dados);
    }

    if (!mounted) return;
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
    // forcarSkeletonGlobal (toggle do Painel ADM) força o skeleton mesmo já
    // carregado; ValueListenableBuilder rebuilda ao alternar o switch.
    return ValueListenableBuilder<bool>(
      valueListenable: forcarSkeletonGlobal,
      builder: (context, forcarSkeleton, _) =>
          _buildConteudo(context, _loading || forcarSkeleton),
    );
  }

  Widget _buildConteudo(BuildContext context, bool mostrarSkeleton) {
    // No mobile o card ocupa a altura total calculada pela página (mesma
    // usada pelas abas Participantes/Chat); no desktop mantém a altura
    // fixa histórica que casa com o painel de participantes ao lado.
    final alturaCard = widget.mobile ? widget.alturaMobile : 538.0;
    // Largura dos campos/botão: no mobile acompanha a largura maior do card
    // (730, igual Participantes); no desktop usa [_larguraConteudo], estreita
    // o bastante para caber ao lado do painel de participantes.
    final larguraConteudo = widget.mobile ? 730.0 : _larguraConteudo;

    // Campos do form: extraídos numa lista simples para poderem ser usados
    // tanto soltos (apenasConteudo, na seção do mobile) quanto
    // envoltos num CustomCard(isChild:true) (desktop).
    // camposTopo fica com o formulário (nome/valor/prêmio/botão); o bloco
    // Pix é montado à parte para poder ser empurrado até o fim do card
    // (ver `blocoPix` mais abaixo).
    // No celular o formulário é a tela inteira, então os blocos ganham
    // altura de alvo de toque (~48px) e mais respiro entre si; no desktop
    // ficam compactos para caber ao lado da tabela.
    final espaco = widget.mobile ? _espacoMobile : 10.0;

    final resumo = _ResumoAposta(premio: _meuPremio, cotas: _minhasCotas);

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
      SizedBox(height: espaco),
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
            // Uma cota por toque, seja ela R$6 ou R$3,50.
            onIncrementar: () => _ajustarValor(1),
            onDecrementar: () => _ajustarValor(-1),
          ),
        ),
      ),
      if (widget.mobile) ...[
        SizedBox(height: espaco),
        resumo,
      ] else ...[
        SizedBox(height: espaco),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: larguraConteudo),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DisplayInfo(
                titulo: 'Prêmio estimado',
                valor: Formatters.moeda.format(_meuPremio),
                dinheiro: true,
              ),
              const SizedBox(height: 6),
              _DisplayInfo(titulo: 'Cotas', valor: _minhasCotas.toString()),
            ],
          ),
        ),
      ],
      SizedBox(height: espaco),
      ConstrainedBox(
        constraints: BoxConstraints(maxWidth: larguraConteudo),
        child: _BotaoEscolherJogos(
          jogos: _jogos,
          cotasUsadas: _cotasDosJogos,
          cotasDisponiveis: _minhasCotas,
          onTap: _abrirSelecaoJogos,
        ),
      ),
      SizedBox(height: widget.mobile ? _espacoMobile : 12),
      FocusTraversalOrder(
        order: const NumericFocusOrder(3),
        child: PrimaryButton(
          text: 'Confirmar',
          width: larguraConteudo,
          onTap: _confirmar,
          loading: _saving,
        ),
      ),
    ];

    // Card do Pix, altura natural, logo abaixo do botão Confirmar.
    final blocoApenasPix = _chavePix.isEmpty
        ? null
        : ConstrainedBox(
            constraints: BoxConstraints(maxWidth: larguraConteudo),
            child: PixInfo(chavePix: _chavePix, valor: _valorApostado),
          );

    // Três blocos no celular: situação do sorteio, formulário e Pix. Os
    // campos do formulário ficam sempre juntos, e a altura que sobra na tela
    // é repartida em partes iguais entre as TRÊS folgas que separam esses
    // blocos: situação→formulário, Confirmar→Pix e Pix→barra inferior. As
    // duas do Pix saem iguais (o card fica centrado no espaço abaixo do
    // Confirmar).
    //
    // Espaço extra só entre blocos, nunca dentro do formulário: já se tentou
    // esticar o bloco do prêmio (caixa grande e vazia) e espalhar a sobra
    // entre os campos (formulário esparramado).
    //
    // Só no celular/tablet de verdade (Pix em Copia e Cola): repartir exige
    // medir a altura natural da coluna, e o Pix do computador escolhe o
    // layout com um LayoutBuilder, que não permite essa medição. Numa janela
    // estreita do computador as folgas ficam no mínimo.
    final preencherAltura = aparelhoMovel;
    Widget folga() =>
        preencherAltura ? const Spacer() : const SizedBox.shrink();

    final colunaMobile = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SituacaoAposta(
          sorteio: _sorteio,
          dataSorteio: _dataSorteio,
          situacao: _situacao,
          premio: _premioSala,
        ),
        // Somada aos 12 do topo do formulário, dá a mesma folga mínima que
        // separa o Confirmar do Pix: os três blocos da tela ficam com o mesmo
        // respiro entre si.
        const SizedBox(height: _folgaPix - 12),
        folga(),
        const SeparadorBlocosAposta(),
        folga(),
        ...camposTopo,
        if (blocoApenasPix != null) ...[
          const SizedBox(height: _folgaPix),
          folga(),
          const SeparadorBlocosAposta(),
          folga(),
          blocoApenasPix,
          // Menor que a de cima porque a seção já tem 12px de respiro no pé;
          // somadas, as duas folgas do Pix ficam iguais.
          const SizedBox(height: _folgaPix - 12),
          folga(),
        ],
      ],
    );

    final form = Form(
      key: _formKey,
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: widget.apenasConteudo
            // SliverFillRemaining dá à coluna no mínimo a altura da tela (é o
            // que deixa as folgas crescerem) e, se ela for mais alta que isso
            // (tela baixa, teclado aberto), rola.
            ? preencherAltura
                  ? CustomScrollView(
                      slivers: [
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: colunaMobile,
                        ),
                      ],
                    )
                  : SingleChildScrollView(child: colunaMobile)
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
                            // Respiro entre o botão Confirmar e o card do Pix.
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
      // Sem padding próprio: a página já dá o respiro das bordas, e somar
      // outro aqui deixava os campos mais estreitos que a lista da seção
      // Participantes.
      return mostrarSkeleton
          ? SizedBox(
              height: alturaCard,
              child: _buildSkeletonConteudo(larguraConteudo),
            )
          : form;
    }

    return CustomCard(
      color: AppCores.de(context).cardExterno,
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
        if (mostrarSkeleton)
          _buildSkeleton(alturaCard, larguraConteudo)
        else
          form,
      ],
    );
  }

  /// Placeholder do formulário, bloco a bloco, nas MESMAS alturas do
  /// conteúdo real: dois campos, o resumo do prêmio (um campo no celular,
  /// dois mostradores no computador), o campo de jogos e o botão.
  ///
  /// O campo de jogos faltava aqui, e o botão vinha 6px mais baixo que o
  /// real — o formulário inteiro pulava para cima quando os dados chegavam.
  List<Widget> _camposSkeleton(double largura, {required bool mobile}) {
    final espaco = mobile ? _espacoMobile : 10.0;
    Widget campo() =>
        Shimmer(child: SkeletonCampoFormulario(maxWidth: largura));

    return [
      const SizedBox(height: 12),
      campo(),
      SizedBox(height: espaco),
      campo(),
      SizedBox(height: espaco),
      if (mobile)
        // _ResumoAposta é um InputDecorator com a mesma decoração dos
        // campos, então tem a mesma altura deles.
        campo()
      else
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: largura),
          child: Shimmer(
            child: Column(
              children: const [
                SkeletonBox(
                  width: double.infinity,
                  height: _alturaDisplayInfo,
                  radius: 10,
                ),
                SizedBox(height: 6),
                SkeletonBox(
                  width: double.infinity,
                  height: _alturaDisplayInfo,
                  radius: 10,
                ),
              ],
            ),
          ),
        ),
      SizedBox(height: espaco),
      // Campo "Meus jogos" — também um InputDecorator de 54.
      campo(),
      SizedBox(height: mobile ? _espacoMobile : 12),
      Shimmer(
        child: SkeletonBox(width: largura, height: _alturaBotao, radius: 12),
      ),
      const SizedBox(height: 12),
    ];
  }

  /// O card do Pix, que no conteúdo real vem logo abaixo do Confirmar. É o
  /// bloco mais alto da tela depois do formulário: sem reservá-lo, a tela
  /// ficava com um vazio embaixo do botão e o Pix caía nele de uma vez.
  Widget _pixSkeleton(double largura) => ConstrainedBox(
    constraints: BoxConstraints(maxWidth: largura),
    child: _SkeletonPix(mobile: widget.mobile),
  );

  Widget _buildSkeleton(double? altura, double largura) {
    return CustomCard(
      isChild: true,
      height: altura,
      children: [
        ..._camposSkeleton(largura, mobile: widget.mobile),
        _pixSkeleton(largura),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildSkeletonConteudo(double largura) {
    // Mesma montagem da coluna real do celular (ver colunaMobile): situação
    // do sorteio, formulário e Pix, com a sobra da tela repartida em folgas
    // elásticas entre os três blocos. Sem elas o placeholder empilhava tudo
    // no topo e deixava metade da tela vazia — e no instante em que os dados
    // chegavam, os blocos se espalhavam de uma vez.
    final preencherAltura = aparelhoMovel;
    Widget folga() =>
        preencherAltura ? const Spacer() : const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.mobile) ...[
          const Shimmer(
            child: SkeletonBox(
              width: double.infinity,
              height: _alturaSituacao,
              radius: 14,
            ),
          ),
          const SizedBox(height: _folgaPix - 12),
          folga(),
          const SeparadorBlocosAposta(),
          folga(),
        ],
        ..._camposSkeleton(largura, mobile: widget.mobile),
        const SizedBox(height: _folgaPix - 12),
        folga(),
        const SeparadorBlocosAposta(),
        folga(),
        _pixSkeleton(largura),
        const SizedBox(height: _folgaPix - 12),
        folga(),
      ],
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
    if (nome.length > kTamanhoMaximoNome) {
      CustomShowDialog.show(
        context,
        'O nome pode ter no máximo $kTamanhoMaximoNome caracteres.',
      );
      return;
    }
    final valor = valueController.text.trim();
    final valorEditado = valor.replaceAll('.', '').replaceAll(',', '.');

    final valorNum = double.tryParse(valorEditado) ?? 0;
    // O valor precisa fechar cotas inteiras do sorteio da sala. O preço da
    // cota varia (Mega R$6, Lotofácil R$3,50), então usa _precoCota em vez
    // de um "6" fixo — senão salas de Lotofácil rejeitariam valores válidos.
    if (!valorFechaCotasInteiras(valorNum, _precoCota)) {
      CustomShowDialog.show(
        context,
        'O valor deve ser múltiplo de '
        'R\$ ${precoCotaFormatado(_precoCota)}!',
      );
      return;
    }

    // Teto por aposta da sala (campo `valorMaximo`). Até aqui esse limite era
    // só informativo: aparecia no cadastro da sala e na tela de detalhes, mas
    // nada impedia apostar acima dele.
    if (!valorRespeitaMaximo(valorNum, _valorMaximo)) {
      CustomShowDialog.show(
        context,
        'O valor máximo por aposta nesta sala é '
        '${Formatters.moeda.format(_valorMaximo)}.',
      );
      return;
    }

    // Jogos custando mais cotas do que o valor pago: acontece ao montar os
    // jogos e depois baixar o valor. Gravar assim geraria uma aposta que
    // ninguém consegue comprar — e a regra do Firestore recusaria de todo
    // jeito, com um erro genérico bem menos útil que este aviso.
    final cotasEmJogos = cotasDosJogos(_jogos, _sorteio);
    final cotasPagas = (valorNum / _precoCota).floor();
    if (cotasEmJogos > cotasPagas) {
      CustomShowDialog.show(
        context,
        'Seus jogos usam $cotasEmJogos cotas, mas o valor apostado compra '
        'só $cotasPagas. Remova jogos ou aumente o valor.',
      );
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
      // Aposta que já perdeu a aprovação por edição continua marcada nas
      // edições seguintes: sem isto a segunda edição gravava `false`, e o
      // admin via uma aposta "nova" em vez de uma alterada depois de aprovada
      // (a regra agora também recusa tirar a marca).
      final jaEstavaMarcada =
          apostaAnterior.data()?['editadoAposVerificacao'] == true;
      final isAdmin = await _authService.isAdmin(user.uid);

      await apostaRef.set({
        'nome': nome,
        'valor': valorEditado,
        'uid': user.uid,
        'data-hora': FieldValue.serverTimestamp(),
        'verificado': isAdmin ? true : false,
        'editadoAposVerificacao': isAdmin
            ? false
            : jaEstavaVerificada || jaEstavaMarcada,
        'jogos': jogosParaDados(_jogos),
      });

      final eraEdicao = apostaAnterior.exists;
      // Editar aposta JÁ verificada zera a aprovação (campo
      // `editadoAposVerificacao` acima) e ela sai do rateio até o admin
      // revisar de novo. Isso era totalmente silencioso: o usuário mexia no
      // valor e não tinha como saber que tinha perdido a verificação.
      final perdeuVerificacao = jaEstavaVerificada && !isAdmin;

      _apostaExistente = true;
      _valorOriginal = valueController.text;
      widget.onApostaConfirmada?.call();

      if (mounted) {
        final cores = AppCores.de(context);
        mostrarSnackBarDeslizante(
          context,
          corFundo: perdeuVerificacao ? cores.dourado : cores.verde,
          conteudo: Text(
            perdeuVerificacao
                ? 'Aposta atualizada — precisa ser verificada de novo'
                : eraEdicao
                ? 'Aposta atualizada'
                : isAdmin
                ? 'Aposta registrada'
                : 'Aposta registrada — aguardando verificação',
          ),
        );
      }
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

// Botões +/- exibidos dentro do campo Valor (suffix), para ajustar o valor
// apostado sem precisar digitar. Cada toque vale UMA cota da sala — ver
// _MinhaApostaCardState._ajustarValor.
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
  // Evita disparo duplicado: onTapDown pode chegar de novo antes do
  // onTapUp/onTapCancel do toque anterior processar em cliques muito
  // rápidos (double-tap), o que reiniciava a repetição sem parar a antiga.
  bool _repetindo = false;

  void _iniciarRepeticao() {
    if (_repetindo) return;
    _repetindo = true;
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
    _repetindo = false;
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }

  @override
  void dispose() {
    _pararRepeticao();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _iniciarRepeticao(),
        onTapUp: (_) => _pararRepeticao(),
        onTapCancel: _pararRepeticao,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            widget.icon,
            size: 20,
            color: AppCores.de(context).textoSuave,
          ),
        ),
      ),
    );
  }
}

// Botão que abre o modal de montagem dos jogos (ver selecao_jogos_dialog).
//
// O resumo muda com a quantidade: um jogo só cabe inteiro na linha, então
// mostra os números; a partir de dois, o que interessa é quanto do dinheiro
// virou jogo, e os números ficam para o modal. Jogos acima das cotas pagas
// (valor reduzido depois de montá-los) aparecem em vermelho, porque é o único
// estado que impede confirmar a aposta.
class _BotaoEscolherJogos extends StatelessWidget {
  final List<List<int>> jogos;
  final int cotasUsadas;
  final int cotasDisponiveis;
  final VoidCallback onTap;

  const _BotaoEscolherJogos({
    required this.jogos,
    required this.cotasUsadas,
    required this.cotasDisponiveis,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    final excedeu = cotasUsadas > cotasDisponiveis;
    final resumo = switch (jogos.length) {
      0 => 'Escolher números (opcional)',
      1 => jogos.first.map((n) => n.toString().padLeft(2, '0')).join(' · '),
      final total => '$total jogos',
    };

    // Mesma decoração do CustomField (rótulo "Meus jogos" na borda, ícone,
    // altura e raio): sem rótulo, os números apareciam soltos no meio do
    // formulário, sem dizer o que eram, enquanto Nome e Valor têm o seu.
    // O rótulo fica sempre no alto (isEmpty: false) porque o campo sempre
    // mostra alguma coisa, nem que seja o convite para escolher.
    final decoracao = CustomFieldDecoration.build(
      context,
      hint: 'Meus jogos',
      icon: Icons.casino_outlined,
      suffix: Icon(Icons.chevron_right, size: 20, color: cores.textoFraco),
    );
    final bordaErro = OutlineInputBorder(
      borderRadius: BorderRadius.circular(CustomFieldDecoration.radius),
      borderSide: BorderSide(color: cores.vermelho, width: 1.5),
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: InputDecorator(
          isEmpty: false,
          decoration: excedeu
              ? decoracao.copyWith(
                  enabledBorder: bordaErro,
                  prefixIcon: Icon(Icons.error_outline, color: cores.vermelho),
                )
              : decoracao,
          child: Text(
            excedeu
                ? 'Jogos passam do valor ($cotasUsadas de '
                      '$cotasDisponiveis cotas)'
                : resumo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: jogos.length == 1 && !excedeu ? 16 : 15,
              fontWeight: jogos.isEmpty ? FontWeight.w500 : FontWeight.w600,
              color: excedeu
                  ? cores.vermelho
                  : (jogos.isEmpty ? cores.textoSuave : cores.texto),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bloco de LEITURA (prêmio estimado, cotas) — o app não recebe nada por aqui.
///
/// Mesma caixa de sempre, com uma diferença que é o ponto todo: **não tem
/// borda**. Neste app o que anuncia "dá para digitar aqui" é a borda de 1.5 do
/// [CustomField] ao redor do fundo claro; sem ela, o mesmo retângulo passa a
/// ler como painel embutido no card — o fundo continua sendo o do campo, mas
/// nada nele promete um cursor.
///
/// O rótulo também encolheu (13.5 contra os 14 do campo) e o valor engrossou:
/// num campo o texto grande é o que a PESSOA escreveu; aqui é o que o app
/// respondeu.
/// Placeholder do card do Pix no computador: a moldura do card real com o
/// quadrado do QR à esquerda, as linhas da chave à direita e o botão de
/// copiar embaixo. Um retângulo cinza do tamanho certo reservava o espaço,
/// mas não parecia o card que chega.
/// Linha fina que separa os três blocos da tela de aposta no celular
/// (situação do sorteio, formulário e Pix).
///
/// Fica no MEIO do vão, entre as duas folgas elásticas que repartem a sobra
/// da tela: encostada num dos blocos, ela leria como parte dele, e não como
/// a fronteira entre os dois. O mesmo widget entra no placeholder, senão a
/// tela ganharia duas linhas do nada ao terminar de carregar.
class SeparadorBlocosAposta extends StatelessWidget {
  const SeparadorBlocosAposta({super.key});

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, thickness: 1, color: AppCores.de(context).borda);
  }
}

class _SkeletonPix extends StatelessWidget {
  /// No celular o card do Pix é outro (Copia e Cola): logo, título e um
  /// botão largo de copiar, sem o QR — que ali não serve para nada, já que
  /// o aparelho que mostra o código é o mesmo que teria de lê-lo.
  final bool mobile;

  const _SkeletonPix({this.mobile = false});

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    if (mobile) {
      return Container(
        height: _alturaPixDesktop,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cores.campo,
          borderRadius: AppRadii.circularMd,
          border: Border.all(color: cores.bordaCampo),
        ),
        child: Shimmer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Row(
                children: [
                  SkeletonBox(width: 30, height: 30, radius: 9),
                  SizedBox(width: 10),
                  SkeletonBox(width: 168, height: 17),
                ],
              ),
              SizedBox(height: 12),
              SkeletonBox(width: double.infinity, height: 52, radius: 12),
            ],
          ),
        ),
      );
    }
    return Container(
      height: _alturaPixDesktop,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cores.campo,
        borderRadius: AppRadii.circularMd,
        border: Border.all(color: cores.bordaCampo, width: 1.5),
      ),
      child: Shimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Row(
                children: [
                  const SkeletonBox(width: 66, height: 66, radius: 8),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        SkeletonBox(width: 54, height: 14),
                        SizedBox(height: 8),
                        SkeletonBox(width: double.infinity, height: 12),
                        SizedBox(height: 6),
                        SkeletonBox(width: 96, height: 11),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const SkeletonBox(width: double.infinity, height: 30, radius: 10),
          ],
        ),
      ),
    );
  }
}

class _DisplayInfo extends StatelessWidget {
  final String titulo;
  final String valor;

  /// Valor em dinheiro: ganha a cor do dinheiro do tema, a mesma da coluna de
  /// prêmio na tabela de participantes.
  final bool dinheiro;

  const _DisplayInfo({
    required this.titulo,
    required this.valor,
    this.dinheiro = false,
  });

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cores.campo,
        borderRadius: BorderRadius.circular(CustomFieldDecoration.radius),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            titulo,
            softWrap: true,
            style: TextStyle(fontSize: 13.5, color: cores.textoSuave),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              valor,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: dinheiro ? cores.verde : cores.texto,
                // Números que mudam a cada tecla no campo de valor: sem
                // dígitos tabulares, o valor "dança" de largura enquanto se
                // digita.
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Resultado do valor digitado, no celular: prêmio estimado e quantas cotas
/// isso compra.
///
/// Tem a MESMA anatomia dos campos em volta (Nome, Valor, Meus jogos): rótulo
/// sobre a borda, ícone na coluna dos ícones e o conteúdo na linha. Já foi uma
/// caixa com desenho próprio — rótulo e valor disputando a mesma linha, um
/// bloco com o troféu fora da coluna dos ícones, um canhoto de bilhete colado
/// no Valor — e nenhuma dessas versões agradou.
class _ResumoAposta extends StatelessWidget {
  final double premio;
  final int cotas;

  const _ResumoAposta({required this.premio, required this.cotas});

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    // Números que mudam a cada tecla no campo de valor: sem dígitos
    // tabulares, o valor "dança" de largura enquanto se digita.
    const tabular = [FontFeature.tabularFigures()];

    return InputDecorator(
      // Rótulo sempre no alto: o campo sempre mostra um valor.
      isEmpty: false,
      // "Seu": o card do topo também mostra um prêmio (o do sorteio inteiro),
      // e sem o possessivo os dois valores se confundiam.
      decoration: CustomFieldDecoration.build(
        context,
        hint: 'Seu prêmio estimado',
        icon: Icons.emoji_events_outlined,
      ),
      child: Row(
        children: [
          // O prêmio leva a linha: é o número que precisa de largura (13
          // dígitos na Mega acumulada), e encolhe a fonte se não couber.
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              // Os dígitos que mudam giram até o valor novo a cada toque no
              // + e − do Valor (ver NumeroRolante).
              child: NumeroRolante(
                texto: Formatters.moeda.format(premio),
                valor: premio,
                estilo: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: cores.verde,
                  fontFeatures: tabular,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$cotas ${cotas == 1 ? 'Cota' : 'Cotas'}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cores.textoSuave,
              fontFeatures: tabular,
            ),
          ),
        ],
      ),
    );
  }
}

// Espaço entre os blocos do formulário no celular: mais que os 10 do
// desktop, para os alvos de toque não ficarem colados.
const double _espacoMobile = 14;

// Alturas dos blocos do formulário, usadas pelo skeleton para reservar
// exatamente o espaço que o conteúdo real vai ocupar.
//
// _DisplayInfo: padding vertical 8 + a linha do valor (corpo 16).
// PrimaryButton não-compacto tem 54 (ver buttons.dart) — o skeleton usava
// 48 e o botão saltava ao aparecer.
// _SituacaoAposta: a folhinha de 96 mais o padding de 14 do bloco.
const double _alturaDisplayInfo = 38;
const double _alturaBotao = 54;
const double _alturaSituacao = 124;

/// Card do Pix no computador (QR + chave + botão de copiar). Medido do
/// PixInfo real: ele não muda de altura com a largura do card.
const double _alturaPixDesktop = 120;

// Folga mínima entre os três blocos da aposta no celular (sorteio,
// formulário, Pix) — e abaixo do Pix. Quase o dobro do espaço entre os
// campos ([_espacoMobile]) de propósito: com 16, praticamente igual aos 14 de
// dentro do formulário, o olho não via onde um bloco acabava e o outro
// começava, e a tela lia como uma pilha só, "cheia demais".
const double _folgaPix = 26;

/// Situação da aposta do usuário, na ordem em que ela acontece.
enum _Situacao {
  semAposta,
  aguardando,
  alterada,
  confirmada;

  /// A partir da linha do usuário em `streamBets()` (null = ainda não
  /// apostou). Editar depois de verificada volta a precisar do admin, então
  /// `editadoAposVerificacao` vence `verificado`.
  static _Situacao de(Map<String, Object?>? aposta) {
    if (aposta == null) return semAposta;
    if (aposta['editadoAposVerificacao'] == true) return alterada;
    if (aposta['verificado'] == true) return confirmada;
    return aguardando;
  }
}

/// Bloco do topo da aposta no celular: qual sorteio, quando, quanto falta e
/// em que pé está a aposta. A confirmação do admin é o que decide quem entra
/// no rateio, e até aqui a pessoa só descobria isso procurando o próprio nome
/// na lista de participantes.
///
/// A data vem numa "folhinha" de calendário à esquerda: faixa do dia da
/// semana na cor de ação do tema (a do botão Confirmar, com o texto do par
/// [AppCores.textoSobreAcao]) e corpo tingido dela a 22%. A mesma cor entra
/// bem de leve no degradê do fundo, do lado da folhinha, e um bilhete grande
/// e quase transparente no canto dá o clima de loteria sem disputar atenção
/// com o texto. A situação vai num selo com o par fundo/borda/texto da
/// paleta: verde confirmada, amarelo aguardando o admin.
class _SituacaoAposta extends StatelessWidget {
  final String? sorteio;
  final DateTime? dataSorteio;
  final _Situacao situacao;
  // Prêmio do sorteio (da sala), na última linha. 0 = a sala ainda não tem
  // prêmio cadastrado, e a linha não aparece.
  final double premio;

  const _SituacaoAposta({
    required this.sorteio,
    required this.dataSorteio,
    required this.situacao,
    required this.premio,
  });

  // O intl devolve "qui." e "dez."; na folhinha o ponto sobra.
  static String _abreviado(String padrao, DateTime data) => DateFormat(
    padrao,
    'pt_BR',
  ).format(data).replaceAll('.', '').toUpperCase();

  // Contagem em dias de CALENDÁRIO (meia-noite a meia-noite), não em blocos
  // de 24h: sorteio amanhã às 20h, visto hoje às 23h, é "amanhã" e não "hoje".
  // Devolve (prefixo, destaque): o destaque sai em negrito na linha.
  static (String, String) _quantoFalta(DateTime data) {
    final agora = DateTime.now();
    if (data.isBefore(agora)) return ('Sorteio já realizado', '');
    final dias = DateUtils.dateOnly(
      data,
    ).difference(DateUtils.dateOnly(agora)).inDays;
    return switch (dias) {
      0 => ('', 'É hoje!'),
      1 => ('', 'É amanhã'),
      _ => ('Faltam ', '$dias dias'),
    };
  }

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    final nomeSorteio = isLotofacil(sorteio) ? 'Lotofácil' : 'Mega-Sena';
    final data = dataSorteio;
    final estiloFolhinha = TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.8,
      color: cores.texto,
    );

    final folhinha = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 60,
        height: 96,
        child: data == null
            ? ColoredBox(
                color: Color.alphaBlend(
                  cores.acaoPrimaria.withValues(alpha: 0.22),
                  cores.campo,
                ),
                child: Icon(Icons.event_outlined, color: cores.texto),
              )
            : Column(
                // stretch: sem isto o corpo tingido encolhe para a largura do
                // "31"/"DEZ" e vira uma faixa estreita sob a tarja do dia.
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 20,
                    color: cores.acaoPrimaria,
                    alignment: Alignment.center,
                    child: Text(
                      _abreviado('EEE', data),
                      style: estiloFolhinha.copyWith(
                        color: cores.textoSobreAcao,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ColoredBox(
                      color: Color.alphaBlend(
                        cores.acaoPrimaria.withValues(alpha: 0.22),
                        cores.campo,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${data.day}',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              height: 1.05,
                              color: cores.texto,
                            ),
                          ),
                          Text(_abreviado('MMM', data), style: estiloFolhinha),
                        ],
                      ),
                    ),
                  ),
                  // Horário no rodapé da própria folhinha, como a hora
                  // impressa num ingresso: data e hora formam uma peça só.
                  // Tom um pouco mais forte que o corpo, para separar as duas
                  // partes sem outra linha.
                  Container(
                    height: 20,
                    color: Color.alphaBlend(
                      cores.acaoPrimaria.withValues(alpha: 0.38),
                      cores.campo,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      Formatters.horaCurta.format(data),
                      style: estiloFolhinha.copyWith(letterSpacing: 0.4),
                    ),
                  ),
                ],
              ),
      ),
    );

    final (prefixo, destaque) = data == null ? ('', '') : _quantoFalta(data);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(CustomFieldDecoration.radius),
        border: Border.all(color: cores.bordaCampo),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color.alphaBlend(
              cores.acaoPrimaria.withValues(alpha: 0.10),
              cores.campo,
            ),
            cores.campo,
          ],
        ),
      ),
      child: Stack(
        children: [
          // Bilhete de fundo: decoração pura, fora da leitura de tela.
          Positioned(
            right: -18,
            bottom: -30,
            child: ExcludeSemantics(
              child: Transform.rotate(
                angle: -0.3,
                child: Icon(
                  Icons.confirmation_number_outlined,
                  size: 96,
                  color: cores.texto.withValues(alpha: 0.05),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            // IntrinsicHeight + stretch: a coluna do texto ocupa a altura toda
            // da coluna da folhinha, para o título alinhar com o topo do
            // calendário e o prêmio com o horário embaixo dele.
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  folhinha,
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nomeSorteio,
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: cores.texto,
                                    ),
                                  ),
                                  // Dentro da coluna do título, e não abaixo da
                                  // linha inteira: lá ela ficava presa à altura
                                  // do bloco do prêmio, mais alto que o título,
                                  // e descolava do "Mega-Sena".
                                  if (data != null)
                                    Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(text: prefixo),
                                          TextSpan(
                                            text: destaque,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: cores.texto,
                                            ),
                                          ),
                                        ],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: cores.textoSuave,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            // Situação no canto: é status, e status mora no
                            // topo. Por isso o selo tem rótulos curtos — aqui
                            // ele divide a linha com o nome do sorteio.
                            const SizedBox(width: 8),
                            _SeloSituacao(situacao: situacao),
                          ],
                        ),
                        if (premio > 0) ...[
                          // Rótulo em cima e valor embaixo, alinhado à
                          // esquerda com o título: na mesma linha, o rótulo
                          // empurrava o valor para o meio do card. Valor na
                          // cor do título — o verde fica para o dinheiro da
                          // pessoa (prêmio estimado), não o do sorteio.
                          // Agrupados numa coluna só: soltos na coluna de fora
                          // (spaceBetween), o espaço sobrando se dividia entre
                          // o rótulo e o valor e separava os dois.
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PRÊMIO',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: cores.textoSuave,
                                ),
                              ),
                              // Valor por extenso; FittedBox encolhe a fonte se
                              // não couber.
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  Formatters.moeda.format(premio),
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    height: 1.15,
                                    color: cores.texto,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeloSituacao extends StatelessWidget {
  final _Situacao situacao;

  const _SeloSituacao({required this.situacao});

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    final (fundo, borda, texto, icone, rotulo) = switch (situacao) {
      _Situacao.semAposta => (
        cores.superficieAlta,
        cores.borda,
        cores.textoSuave,
        Icons.info_outline,
        'Sem aposta',
      ),
      _Situacao.aguardando => (
        cores.fundoAmarelo,
        cores.bordaAmarelo,
        cores.textoAmarelo,
        Icons.hourglass_empty,
        'Aguardando',
      ),
      _Situacao.alterada => (
        cores.fundoAmarelo,
        cores.bordaAmarelo,
        cores.textoAmarelo,
        Icons.edit_outlined,
        'Alterada',
      ),
      _Situacao.confirmada => (
        cores.fundoVerde,
        cores.bordaVerde,
        cores.textoVerde,
        Icons.check_circle_outline,
        'Confirmada',
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borda),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 14, color: texto),
          const SizedBox(width: 5),
          // Sem Flexible: o selo fica no canto de uma Row, onde recebe largura
          // livre, e um filho flexível ali quebra o layout. Os rótulos são
          // curtos justamente para caberem sempre.
          Text(
            rotulo,
            maxLines: 1,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: texto,
            ),
          ),
        ],
      ),
    );
  }
}
