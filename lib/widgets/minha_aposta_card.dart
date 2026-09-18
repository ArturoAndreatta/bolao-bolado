import 'dart:async';

import 'package:bolao_bolado/components/formatters/formatters.dart';
import 'package:bolao_bolado/components/shared/custom_field_decoration.dart';
import 'package:bolao_bolado/components/shared/custom_show_dialog.dart';
import 'package:bolao_bolado/components/shared/buttons.dart';
import 'package:bolao_bolado/components/shared/custom_card.dart';
import 'package:bolao_bolado/components/shared/custom_fields.dart';
import 'package:bolao_bolado/components/shared/header_paginas.dart';
import 'package:bolao_bolado/components/shared/skeletons.dart';
import 'package:bolao_bolado/components/shared/snackbar_deslizante.dart';
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
import 'package:flutter/rendering.dart';

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
  // Quando true (mobile), renderiza só o conteúdo, sem nenhum CustomCard: a
  // página monta o card da seção em volta, com o mesmo título e subtítulo
  // do desktop, e um CustomCard aqui dentro duplicaria a moldura.
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
  // Altura real do bloco de campos (até o botão Confirmar), informada pelo
  // próprio layout — ver _MedidorDeAltura e o cálculo de escalaPix.
  double? _alturaTopoMedida;

  // Última escala do Pix calculada, e a chave das condições que a produziram
  // (ver _escalaPix). Memoizar é o que tira a medição do caminho do teclado.
  String? _chaveEscalaPix;
  double _escalaPixMemo = 1;

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
        setState(() {
          _totalCotasOutros = bets
              .where((item) => item['uid'] != uid)
              .fold<int>(0, (soma, item) => soma + (item['cotas'] as int));
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

  void _onValorAlterado() => setState(() {});

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

  // Recebe do layout a altura real do bloco de campos. Roda DURANTE o
  // layout, então o setState é adiado para depois do frame; o limiar de 1px
  // evita rebuild infinito por variação de arredondamento.
  void _registrarAlturaTopo(double altura) {
    if (_alturaTopoMedida != null &&
        (_alturaTopoMedida! - altura).abs() < 1.0) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _alturaTopoMedida = altura);
    });
  }

  // Mede a altura que `widget` teria com a largura dada, sem exibi-lo: monta
  // uma árvore de layout descartável (fora da árvore visível) só para ler o
  // tamanho. É o que permite descobrir a folga vertical sobrando no card
  // antes de decidir o quanto esticar o Pix — a alternativa seria pintar uma
  // vez errado e corrigir no frame seguinte, o que piscaria na tela.
  double _alturaDe(BuildContext context, Widget widget, double largura) {
    if (largura <= 0 || !largura.isFinite) return 0;
    final pipelineOwner = PipelineOwner();
    final buildOwner = BuildOwner(focusManager: FocusManager());
    // RenderView dá o passe de layout completo (com constraints de raiz) que
    // o LayoutBuilder dentro do PixInfo exige.
    final raiz = _RaizDeMedicao(largura: largura);
    try {
      final elemento = RenderObjectToWidgetAdapter<RenderBox>(
        container: raiz,
        debugShortDescription: '[medição de altura]',
        child: Directionality(
          textDirection: Directionality.of(context),
          child: MediaQuery(
            data: MediaQuery.of(context),
            child: DefaultTextStyle(
              style: DefaultTextStyle.of(context).style,
              child: Theme(data: Theme.of(context), child: widget),
            ),
          ),
        ),
      ).attachToRenderTree(buildOwner);
      buildOwner
        ..buildScope(elemento)
        ..finalizeTree();
      // flushLayout (e não raiz.layout direto): PixInfo usa LayoutBuilder
      // internamente, e o callback dele só pode rodar dentro de um passe de
      // layout de verdade do PipelineOwner.
      pipelineOwner.rootNode = raiz;
      raiz.scheduleInitialLayout();
      pipelineOwner.flushLayout();
      final medido = raiz.child;
      return medido == null || !medido.hasSize ? 0 : medido.size.height;
    } catch (_) {
      // Medição é otimização visual: se algo no subwidget não tolerar o
      // layout fora da árvore, cai no comportamento antigo (escala 1).
      return 0;
    }
  }

  /// Quanto esticar o bloco Pix para ele absorver a folga vertical do card —
  /// **memoizado pelas condições que realmente mudam essa conta**.
  ///
  /// A memoização não é micro-otimização. Descobrir a escala custa SETE
  /// chamadas de [_alturaDe] (uma para a altura natural + seis passos da busca
  /// binária), e cada uma monta o `PixInfo` inteiro numa árvore descartável —
  /// incluindo o `QrImageView`, que codifica o QR code no próprio build. Sem
  /// cache isso rodava a cada rebuild do card: **toda tecla digitada no campo
  /// Valor** (o listener do controller chama setState), toda emissão de
  /// `streamBets()` e toda mudança na sala. Digitar um valor de dois dígitos
  /// gerava e jogava no lixo 14 QR codes.
  ///
  /// Nada disso depende do valor apostado: ele entra só no payload do QR, que
  /// ocupa o mesmo espaço em pixels qualquer que seja o conteúdo. O que mexe
  /// na altura é a CHAVE Pix (o texto ao lado do QR), o espaço disponível, a
  /// altura já ocupada pelos campos e a escala de fonte do sistema — e é por
  /// esses quatro que a conta é chaveada.
  double _escalaPix({
    required BuildContext context,
    required Widget Function({double escalaPix}) blocoPix,
    required double largura,
    required double alturaDisponivel,
    required double alturaTopo,
  }) {
    if (_chavePix.isEmpty || !alturaDisponivel.isFinite) return 1;

    // Arredondado para pixel inteiro: variação sub-pixel de constraint não
    // muda a escala de forma perceptível, e sem isso o cache erraria sempre.
    final chave =
        '$_chavePix|${largura.round()}|${alturaDisponivel.round()}'
        '|${alturaTopo.round()}|${MediaQuery.textScalerOf(context).scale(14)}';
    if (chave == _chaveEscalaPix) return _escalaPixMemo;

    var escala = 1.0;
    final alturaBloco = _alturaDe(context, blocoPix(), largura);
    // Reserva 12px para o Pix não colar no botão Confirmar.
    final folga = alturaDisponivel - alturaTopo - alturaBloco - 12;
    if (alturaBloco > 0 && folga > 0) {
      // A altura do card NÃO é linear na escala (o QR tem teto de largura,
      // textos quebram em linhas), então em vez de calcular a escala por regra
      // de três faz-se uma busca binária medindo o bloco realmente escalado. 6
      // passos já chegam a ~1% do alvo.
      final alvo = alturaBloco + folga;
      var min = 1.0;
      var max = 1.6;
      for (var i = 0; i < 6; i++) {
        final meio = (min + max) / 2;
        final altura = _alturaDe(context, blocoPix(escalaPix: meio), largura);
        if (altura <= alvo) {
          min = meio;
        } else {
          max = meio;
        }
      }
      escala = min;
    }

    _chaveEscalaPix = chave;
    _escalaPixMemo = escala;
    return escala;
  }

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
    // tanto soltos (apenasConteudo, no card de seção do mobile) quanto
    // envoltos num CustomCard(isChild:true) (desktop).
    // camposTopo fica com o formulário (nome/valor/prêmio/botão); o bloco
    // Pix é montado à parte para poder ser empurrado até o fim do card
    // (ver `blocoPix` mais abaixo).
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
            // Uma cota por toque, seja ela R$6 ou R$3,50.
            onIncrementar: () => _ajustarValor(1),
            onDecrementar: () => _ajustarValor(-1),
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
              dinheiro: true,
            ),
            const SizedBox(height: 8),
            _DisplayInfo(titulo: 'Cotas', valor: _minhasCotas.toString()),
          ],
        ),
      ),
      const SizedBox(height: 10),
      ConstrainedBox(
        constraints: BoxConstraints(maxWidth: larguraConteudo),
        child: _BotaoEscolherJogos(
          jogos: _jogos,
          cotasUsadas: _cotasDosJogos,
          cotasDisponiveis: _minhasCotas,
          onTap: _abrirSelecaoJogos,
        ),
      ),
      const SizedBox(height: 12),
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

    // Bloco Pix (altura natural): usado no mobile (apenasConteudo), logo
    // abaixo do botão Confirmar. `escalaPix` estica proporcionalmente o
    // card do Pix para ele absorver a folga vertical que sobraria acima
    // dele — sem o ComoFunciona ao lado, o Pix é livre para ocupar a
    // largura toda do card e crescer mais antes de precisar da escala.
    Widget blocoPix({double escalaPix = 1}) => ConstrainedBox(
      constraints: BoxConstraints(maxWidth: larguraConteudo),
      child: PixInfo(
        chavePix: _chavePix,
        valor: _valorApostado,
        escala: escalaPix,
      ),
    );

    // Card do Pix isolado, altura natural: usado no desktop, onde só o QR
    // code/chave aparece.
    final blocoApenasPix = _chavePix.isEmpty
        ? null
        : ConstrainedBox(
            constraints: BoxConstraints(maxWidth: larguraConteudo),
            child: PixInfo(chavePix: _chavePix, valor: _valorApostado),
          );

    final form = Form(
      key: _formKey,
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: widget.apenasConteudo
            // Ocupa a altura cedida pelo card de seção (alturaCard): quando o
            // conteúdo é mais curto que isso, MainAxisAlignment.spaceBetween
            // empurra o bloco Pix/Como Funciona para o fim do card — usa
            // minHeight (não uma altura fixa) para não quebrar quando o
            // conteúdo é mais alto (nomes longos etc.), caso em que apenas
            // rola dentro do card em vez de estourar por baixo dele.
            ? LayoutBuilder(
                builder: (context, constraints) {
                  // O card do Pix fica ancorado embaixo (spaceBetween), mas
                  // cresce para cima até quase encostar no botão Confirmar:
                  // mede-se a folga que sobraria e converte-se em escala. A
                  // medição é feita com um layout "seco" (_alturaDe) no mesmo
                  // BoxConstraints do card, então o valor já considera o
                  // tamanho real dos textos/campos nesta tela.
                  final larguraDisponivel = constraints.maxWidth;
                  final conteudo = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [...camposTopo, const SizedBox(height: 12)],
                  );

                  // Escala do Pix: parte da altura sobrando entre o topo (que
                  // termina no botão Confirmar) e o bloco ancorado embaixo.
                  //
                  // A altura do topo NÃO pode ser medida com _alturaDe: os
                  // campos carregam GlobalKey/FocusNode já montados na árvore
                  // visível, e reconstruí-los numa árvore paralela devolve um
                  // tamanho inválido (não lança — só mente). Por isso quem
                  // informa a altura real do topo é o próprio layout, via
                  // _MedidorDeAltura; só o bloco de baixo (widgets sem estado
                  // compartilhado) passa por _alturaDe.
                  final alturaTopo =
                      _alturaTopoMedida ?? constraints.maxHeight * 0.55;
                  // Medir custa 7 layouts fora da árvore (com 7 QR codes),
                  // então o resultado é memoizado pelas condições que o
                  // determinam — ver [_escalaPix].
                  final escalaPix = _escalaPix(
                    context: context,
                    blocoPix: blocoPix,
                    largura: larguraDisponivel,
                    alturaDisponivel: constraints.maxHeight,
                    alturaTopo: alturaTopo,
                  );

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
                          _MedidorDeAltura(
                            onMedida: _registrarAlturaTopo,
                            child: conteudo,
                          ),
                          blocoPix(escalaPix: escalaPix),
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
      // Sem padding próprio: o card de seção da página já tem o mesmo
      // respiro interno do desktop, e somar outro aqui deixava os campos
      // mais estreitos que a lista da seção Participantes.
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
      final isAdmin = await _authService.isAdmin(user.uid);

      await apostaRef.set({
        'nome': nome,
        'valor': valorEditado,
        'uid': user.uid,
        'data-hora': FieldValue.serverTimestamp(),
        'verificado': isAdmin ? true : false,
        'editadoAposVerificacao': isAdmin ? false : jaEstavaVerificada,
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
      0 => 'Escolher meus jogos (opcional)',
      1 => jogos.first.map((n) => n.toString().padLeft(2, '0')).join(' · '),
      final total => '$total jogos',
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(CustomFieldDecoration.radius),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: cores.campo,
          borderRadius: BorderRadius.circular(CustomFieldDecoration.radius),
          border: Border.fromBorderSide(
            BorderSide(
              color: excedeu ? cores.vermelho : cores.bordaCampo,
              width: 1.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              excedeu ? Icons.error_outline : Icons.casino_outlined,
              size: 18,
              color: excedeu ? cores.vermelho : cores.textoSuave,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                excedeu
                    ? 'Jogos passam do valor apostado ($cotasUsadas de '
                          '$cotasDisponiveis cotas)'
                    : resumo,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: jogos.isEmpty ? FontWeight.w500 : FontWeight.w600,
                  color: excedeu
                      ? cores.vermelho
                      : (jogos.isEmpty ? cores.textoSuave : cores.texto),
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: cores.textoFraco),
          ],
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

// Raiz da árvore descartável usada por _alturaDe: é seu próprio relayout
// boundary (sizedByParent com constraints fixas), o que permite chamar
// scheduleInitialLayout + flushLayout — o passe completo do PipelineOwner de
// que o LayoutBuilder dentro do PixInfo precisa para rodar seu callback.
class _RaizDeMedicao extends RenderBox
    with RenderObjectWithChildMixin<RenderBox> {
  _RaizDeMedicao({required this.largura});

  final double largura;

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => Size(largura, 0);

  @override
  void performLayout() {
    child?.layout(BoxConstraints(maxWidth: largura), parentUsesSize: true);
  }

  // Nunca é pintada nem testada por toque: existe só para medir.
  @override
  void paint(PaintingContext context, Offset offset) {}
}

// Reporta ao pai a altura que seu filho ocupou de fato, sem alterar o
// layout (repassa constraints e tamanho inalterados).
//
// Existe porque o bloco de campos NÃO pode ser medido fora da árvore: ele
// carrega GlobalKey (_formKey) e FocusNodes já montados, e reconstruí-lo
// numa árvore paralela devolve altura inválida silenciosamente, sem lançar
// exceção. Aqui a altura vem do único lugar onde ela é confiável — o layout
// real do widget que está na tela.
class _MedidorDeAltura extends SingleChildRenderObjectWidget {
  const _MedidorDeAltura({required this.onMedida, required super.child});

  final ValueChanged<double> onMedida;

  @override
  _RenderMedidorDeAltura createRenderObject(BuildContext context) =>
      _RenderMedidorDeAltura(onMedida: onMedida);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMedidorDeAltura renderObject,
  ) {
    renderObject.onMedida = onMedida;
  }
}

class _RenderMedidorDeAltura extends RenderProxyBox {
  _RenderMedidorDeAltura({required this.onMedida});

  ValueChanged<double> onMedida;

  @override
  void performLayout() {
    super.performLayout();
    onMedida(size.height);
  }
}
