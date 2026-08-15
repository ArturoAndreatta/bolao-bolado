import 'dart:async';

import 'package:bolao_bolado/components/formatters/formatters.dart';
import 'package:bolao_bolado/components/shared/avatar_emoji.dart';
import 'package:bolao_bolado/components/shared/custom_confirm_dialog.dart';
import 'package:bolao_bolado/components/shared/skeletons.dart';
import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/core/app_radii.dart';
import 'package:bolao_bolado/core/debug_flags.dart';
import 'package:bolao_bolado/models/mensagem.dart';
import 'package:bolao_bolado/pages/participants/participants_skeletons.dart';
import 'package:bolao_bolado/services/authentication/auth_service.dart';
import 'package:bolao_bolado/services/bet/bet_service.dart';
import 'package:bolao_bolado/services/chat/chat_service.dart';
import 'package:bolao_bolado/services/chat/formatacao_mensagem.dart';
import 'package:bolao_bolado/widgets/chat/bolha_mensagem.dart';
import 'package:bolao_bolado/widgets/chat/campo_envio_chat.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChatSala extends StatefulWidget {
  final String salaId;
  // No mobile o chat já está dentro da aba "Chat", então o cabeçalho
  // repetindo "Chat da Sala" é redundante.
  final bool mostrarCabecalho;

  // Quando definido, exibe um botão de fechar (no cabeçalho, ou flutuando
  // sobre o card quando mostrarCabecalho é false).
  final VoidCallback? onFechar;

  // Sobreposto à tabela de participantes no desktop: aumenta a elevação
  // para reforçar a hierarquia visual de "por cima" da tabela.
  final bool flutuante;

  // No mobile o chat vive dentro da folha do Fichario, que já desenha o
  // cartão branco com borda e sombra. Sem isto o usuário vê dois retângulos
  // encaixados (o da folha e o do próprio chat) e perde ~16px de largura útil
  // de cada lado — que na tela estreita é justamente o que falta às bolhas.
  final bool compacto;

  const ChatSala({
    super.key,
    required this.salaId,
    this.mostrarCabecalho = true,
    this.onFechar,
    this.flutuante = false,
    this.compacto = false,
  });

  @override
  State<ChatSala> createState() => _ChatSalaState();
}

class _ChatSalaState extends State<ChatSala> {
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  final TextEditingController _textoController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _campoFocusNode = FocusNode();

  bool _podeEnviar = false;
  bool _verificandoPermissao = true;
  bool _isAdmin = false;

  // Participantes da sala, fonte do autocomplete de menção. Vem da stream
  // COMPARTILHADA de apostas (a mesma que a tela de Participantes e o card
  // Minha Aposta já escutam), então saber quem pode ser mencionado não custa
  // nenhuma leitura a mais.
  //
  // ATENÇÃO: `streamBets()` é sempre a da sala PRINCIPAL, e este widget
  // recebe um salaId qualquer. Hoje as duas coisas coincidem (só existe a
  // principal). Quando houver mais de uma sala, isto precisa virar uma query
  // por `widget.salaId` — ao custo de um listener a mais, já que a ordenação
  // de `streamBets()` faz dela um alvo diferente no Firestore.
  List<({String uid, String nome})> _participantes = const [];

  /// Os mesmos participantes indexados por uid, para a lista de quem reagiu.
  /// Montado uma vez por atualização da stream, e não por bolha: a lista de
  /// mensagens reconstrói muito mais vezes do que a de apostas muda.
  Map<String, String> _nomesPorUid = const {};
  StreamSubscription<List<Map<String, Object?>>>? _apostasSub;

  // Estado do autocomplete de menção.
  List<({String uid, String nome})> _sugestoes = const [];
  int _indiceSugestao = 0;
  int _inicioTokenMencao = -1;

  // Quem o usuário escolheu no autocomplete nesta mensagem. As POSIÇÕES não
  // são guardadas aqui: elas são descobertas no envio, contra o texto final
  // (ver resolverMencoes em formatacao_mensagem.dart).
  final List<({String uid, String nome})> _mencoesEscolhidas = [];

  // Criada uma única vez em initState: se fosse aberta direto no build(),
  // cada rebuild do widget pai (ex: nova aposta atualizando a tela de
  // participantes) geraria uma nova instância de Stream, forçando o
  // StreamBuilder a descartar a subscription antiga e reiniciar o chat
  // (efeito de "recarregar" mesmo sem nenhuma mensagem nova).
  late final Stream<List<Mensagem>> _mensagensStream = _chatService
      .mensagensStream(widget.salaId);
  late final Stream<MensagemFixada?> _fixadaStream = _chatService
      .mensagemFixadaStream(widget.salaId);

  @override
  void initState() {
    super.initState();
    _verificarPermissao();
    _textoController.addListener(_avaliarMencao);
    _apostasSub = streamBets().listen(
      (apostas) {
        if (!mounted) return;
        setState(() {
          _participantes = [
            for (final aposta in apostas)
              if (aposta['uid'] case final String uid)
                if (aposta['nome'] case final String nome)
                  if (nome.trim().isNotEmpty) (uid: uid, nome: nome.trim()),
          ];
          _nomesPorUid = {
            for (final participante in _participantes)
              participante.uid: participante.nome,
          };
        });
      },
      // Sem apostas carregadas o chat continua funcionando: só o autocomplete
      // de menção fica vazio.
      onError: (Object _) {},
    );
  }

  @override
  void dispose() {
    _apostasSub?.cancel();
    _textoController.dispose();
    _scrollController.dispose();
    _campoFocusNode.dispose();
    super.dispose();
  }

  Future<void> _verificarPermissao() async {
    final user = FirebaseAuth.instance.currentUser;
    // As duas perguntas são independentes — encadeá-las custaria dois
    // round-trips em fila antes de o rodapé do chat sair do skeleton.
    final (pode, admin) = await (
      _chatService.usuarioPodeParticipar(widget.salaId),
      user == null || user.isAnonymous
          ? Future.value(false)
          : _authService.isAdmin(user.uid),
    ).wait;

    if (mounted) {
      setState(() {
        _podeEnviar = pode;
        _isAdmin = admin;
        _verificandoPermissao = false;
      });
      // O campo de texto só é montado depois que a permissão é conhecida;
      // o foco automático fica restrito ao chat sobreposto no desktop
      // (mobile abre via aba, sem necessidade de puxar o teclado sozinho).
      if (widget.flutuante && pode) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _campoFocusNode.requestFocus();
        });
      }
    }
  }

  // Duas mensagens caem no mesmo dia? Usado tanto para agrupar mensagens
  // seguidas do mesmo autor quanto para decidir onde entra o separador de
  // data. Mensagem ainda sem `criadoEm` (escrita otimista local, antes do
  // serverTimestamp voltar) conta como "mesmo dia" da vizinha para não piscar
  // um separador que some no frame seguinte.
  static bool _mesmoDia(DateTime? a, DateTime? b) {
    if (a == null || b == null) return true;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // A lista usa reverse:true (mensagem mais recente no topo visual), então
  // "rolar para o final" na prática é rolar até o offset 0.
  void _scrollParaFinal() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Menção ──────────────────────────────────────────────────────────────

  void _avaliarMencao() {
    final selecao = _textoController.selection;
    final texto = _textoController.text;
    if (!selecao.isCollapsed || selecao.baseOffset < 0) {
      _fecharSugestoes();
      return;
    }

    final emDigitacao = detectarMencao(
      texto,
      selecao.baseOffset.clamp(0, texto.length),
    );
    if (emDigitacao == null) {
      _fecharSugestoes();
      return;
    }

    final uidAtual = FirebaseAuth.instance.currentUser?.uid;
    final encontrados = [
      for (final participante in _participantes)
        // Você não se menciona: a linha só ocuparia espaço na lista.
        if (participante.uid != uidAtual)
          if (nomeCasaConsulta(participante.nome, emDigitacao.consulta))
            participante,
    ];

    if (encontrados.isEmpty) {
      _fecharSugestoes();
      return;
    }

    setState(() {
      _inicioTokenMencao = emDigitacao.inicio;
      _sugestoes = encontrados.take(6).toList();
      _indiceSugestao = 0;
    });
  }

  void _fecharSugestoes() {
    if (_sugestoes.isEmpty && _inicioTokenMencao == -1) return;
    setState(() {
      _sugestoes = const [];
      _inicioTokenMencao = -1;
      _indiceSugestao = 0;
    });
  }

  void _escolherMencao(({String uid, String nome}) participante) {
    final texto = _textoController.text;
    final cursor = _textoController.selection.baseOffset.clamp(0, texto.length);
    if (_inicioTokenMencao < 0 || _inicioTokenMencao > cursor) return;

    final resultado = aplicarMencao(
      texto: texto,
      cursor: cursor,
      inicio: _inicioTokenMencao,
      nome: participante.nome,
    );

    _mencoesEscolhidas.add(participante);
    // O listener do controller roda com o texto novo e fecharia/reabriria a
    // lista sozinho; fechar aqui evita o piscar de um frame.
    _textoController.value = TextEditingValue(
      text: resultado.texto,
      selection: TextSelection.collapsed(offset: resultado.cursor),
    );
    _fecharSugestoes();
    _campoFocusNode.requestFocus();
  }

  // ── Ações da mensagem ───────────────────────────────────────────────────

  Future<void> _reagir(Mensagem mensagem, String emoji) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    try {
      await _chatService.alternarReacao(
        salaId: widget.salaId,
        mensagemId: mensagem.id,
        emoji: emoji,
        reacaoAtual: uid == null ? null : mensagem.reacoes[uid],
      );
    } catch (_) {
      // Mesma escolha do envio: falhar em silêncio é melhor do que abrir
      // diálogo num componente lateral pequeno. A reação simplesmente não
      // aparece.
    }
  }

  Future<void> _fixar(Mensagem mensagem) async {
    try {
      await _chatService.fixarMensagem(
        salaId: widget.salaId,
        mensagem: mensagem,
      );
    } catch (_) {}
  }

  Future<void> _desafixar() async {
    try {
      await _chatService.desafixarMensagem(widget.salaId);
    } catch (_) {}
  }

  Future<void> _apagar(Mensagem mensagem) async {
    // Apagar some da tela de todo mundo e não tem desfazer — mesma proteção
    // do diálogo de moderação do painel admin.
    final confirmar = await CustomConfirmDialog.show(
      context,
      titulo: 'Apagar mensagem?',
      mensagem:
          'A mensagem de ${mensagem.autorNome} será apagada permanentemente '
          'para todos os participantes.',
      textoConfirmar: 'Apagar',
      destrutivo: true,
    );
    if (!confirmar) return;

    try {
      await _chatService.apagarMensagem(
        salaId: widget.salaId,
        mensagemId: mensagem.id,
      );
    } catch (_) {}
  }

  /// Envia o que está no campo, ESVAZIANDO-O na hora.
  ///
  /// O campo é limpo antes de esperar o servidor porque a mensagem já entra na
  /// conversa no mesmo frame: a escrita do Firestore passa pelo cache local e
  /// a stream do chat a devolve imediatamente. Esperar a confirmação para
  /// então limpar deixava o texto parado no campo enquanto a bolha dele já
  /// estava na lista — e era isso que pedia um spinner no botão para explicar
  /// a espera.
  ///
  /// Limpar antes também é o que dispensa o antigo trinco de "enviando": a
  /// segunda tecla Enter encontra o campo vazio e volta sozinha.
  Future<void> _enviar() async {
    final texto = _textoController.text.trim();
    if (texto.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final mencoes = List.of(_mencoesEscolhidas);
    _textoController.clear();
    _mencoesEscolhidas.clear();
    _fecharSugestoes();
    _scrollParaFinal();
    // onSubmitted do TextField tira o foco por padrão; sem isso o usuário
    // precisa clicar de novo no campo pra mandar a próxima mensagem.
    _campoFocusNode.requestFocus();

    try {
      await _chatService.enviarMensagem(
        salaId: widget.salaId,
        texto: texto,
        autorNome: user.displayName ?? 'Participante',
        mencoesEscolhidas: mencoes,
      );
    } catch (_) {
      // Devolve o texto ao campo em vez de perdê-lo em silêncio: agora que a
      // limpeza é otimista, uma falha (regra recusando a escrita, por ex.)
      // apagaria o que a pessoa escreveu sem deixar rastro. Só repõe se ela
      // ainda não começou a digitar outra coisa.
      if (!mounted || _textoController.text.isNotEmpty) return;
      _textoController.value = TextEditingValue(
        text: texto,
        selection: TextSelection.collapsed(offset: texto.length),
      );
      _mencoesEscolhidas
        ..clear()
        ..addAll(mencoes);
    }
  }

  // Enter escolhe a sugestão quando a lista está aberta, e só envia quando
  // não está: é o comportamento que todo chat com menção tem, e sem isso a
  // primeira tecla depois de digitar `@ana` mandaria a mensagem pela metade.
  void _submeterCampo() {
    if (_sugestoes.isNotEmpty) {
      _escolherMencao(_sugestoes[_indiceSugestao]);
      return;
    }
    _enviar();
  }

  void _moverSelecao(int passo) {
    if (_sugestoes.isEmpty) return;
    setState(() {
      _indiceSugestao =
          (_indiceSugestao + passo + _sugestoes.length) % _sugestoes.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    return SizedBox.expand(
      child: Material(
        color: cores.card,
        // No modo compacto o cartão ao redor é do Fichario: aqui só o fundo,
        // sem elevação nem borda própria (ver [ChatSala.compacto]).
        elevation: widget.compacto ? 0 : (widget.flutuante ? 10 : 3),
        shadowColor: cores.sombra,
        surfaceTintColor: Colors.transparent,
        shape: widget.compacto
            ? const RoundedRectangleBorder()
            : RoundedRectangleBorder(
                borderRadius: AppRadii.circularSmd,
                side: BorderSide(color: cores.borda, width: 1.5),
              ),
        clipBehavior: Clip.antiAlias,
        child: StreamBuilder<MensagemFixada?>(
          stream: _fixadaStream,
          builder: (context, snapshotFixada) {
            final fixada = snapshotFixada.data;
            return Column(
              children: [
                if (widget.mostrarCabecalho)
                  _CabecalhoChat(onFechar: widget.onFechar),
                if (fixada != null)
                  _BannerFixado(
                    fixada: fixada,
                    podeDesafixar: _isAdmin,
                    onDesafixar: _desafixar,
                  ),
                Expanded(child: _lista(fixada)),
                if (_sugestoes.isNotEmpty)
                  _ListaSugestoes(
                    key: const ValueKey('sugestoes-mencao'),
                    sugestoes: _sugestoes,
                    selecionado: _indiceSugestao,
                    onEscolher: _escolherMencao,
                  ),
                // Chave fixa: a lista de sugestões entra e sai da coluna acima
                // dele, e sem chave o casamento de filhos passa a depender da
                // posição — o rodapé seria remontado a cada abrir/fechar, com
                // o mesmo efeito de campo morto descrito em [_CampoEnvioChat].
                CampoEnvioChat(
                  key: const ValueKey('campo-envio'),
                  verificandoPermissao: _verificandoPermissao,
                  podeEnviar: _podeEnviar,
                  controller: _textoController,
                  focusNode: _campoFocusNode,
                  onEnviar: _submeterCampo,
                  compacto: widget.compacto,
                  sugestoesAbertas: _sugestoes.isNotEmpty,
                  onSubir: () => _moverSelecao(-1),
                  onDescer: () => _moverSelecao(1),
                  onFechar: _fecharSugestoes,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _lista(MensagemFixada? fixada) {
    final cores = AppCores.de(context);
    return ValueListenableBuilder<bool>(
      valueListenable: forcarSkeletonGlobal,
      builder: (context, forcarSkeleton, _) {
        return StreamBuilder<List<Mensagem>>(
          stream: _mensagensStream,
          builder: (context, snapshot) {
            if (forcarSkeleton ||
                snapshot.connectionState == ConnectionState.waiting) {
              return const _SkeletonMensagens();
            }

            final mensagens = snapshot.data ?? [];

            if (mensagens.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: SelectionArea(
                    child: Text(
                      'Nenhuma mensagem ainda.\nSeja o primeiro a falar! 💬',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cores.textoFraco, fontSize: 13),
                    ),
                  ),
                ),
              );
            }

            final uidAtual = FirebaseAuth.instance.currentUser?.uid;

            final lista = ListView.builder(
              controller: _scrollController,
              reverse: true,
              padding: EdgeInsets.symmetric(
                horizontal: widget.compacto ? 10 : 12,
                vertical: 10,
              ),
              itemCount: mensagens.length,
              itemBuilder: (context, index) {
                final msg = mensagens[index];
                // A lista é reverse:true e vem do mais recente para
                // o mais antigo, então o vizinho ANTERIOR na tela é
                // index+1 e o POSTERIOR é index-1.
                final anterior = index + 1 < mensagens.length
                    ? mensagens[index + 1]
                    : null;
                final posterior = index > 0 ? mensagens[index - 1] : null;

                // Agrupa mensagens seguidas do mesmo autor: só a
                // primeira do bloco mostra nome e avatar, as demais
                // ganham um recuo equivalente. Evita repetir
                // "Orlindo Cruz" + avatar quatro vezes em sequência.
                final iniciaBloco =
                    anterior == null ||
                    anterior.autorUid != msg.autorUid ||
                    !_mesmoDia(anterior.criadoEm, msg.criadoEm);
                final encerraBloco =
                    posterior == null ||
                    posterior.autorUid != msg.autorUid ||
                    !_mesmoDia(posterior.criadoEm, msg.criadoEm);

                final bolha = BolhaMensagem(
                  // A lista é reverse:true: toda mensagem nova entra no
                  // ÍNDICE 0 e empurra as demais uma posição adiante. Sem
                  // key por id, o ListView reaproveitaria o State de cada
                  // índice para a mensagem ERRADA — e é exatamente o que
                  // faz a animação de reação de uma bolha vazar pra outra.
                  key: ValueKey(msg.id),
                  mensagem: msg,
                  isMinha: msg.autorUid == uidAtual,
                  iniciaBloco: iniciaBloco,
                  encerraBloco: encerraBloco,
                  compacto: widget.compacto,
                  uidAtual: uidAtual,
                  isAdmin: _isAdmin,
                  fixada: fixada?.id == msg.id,
                  nomesPorUid: _nomesPorUid,
                  onReagir: (emoji) => _reagir(msg, emoji),
                  onFixar: () => _fixar(msg),
                  onDesafixar: _desafixar,
                  onApagar: () => _apagar(msg),
                );

                // Separador de data acima da primeira mensagem de
                // cada dia. Como a lista é invertida, "primeira do
                // dia" é aquela cujo vizinho mais antigo (index+1)
                // caiu em outro dia.
                if (!_mesmoDia(anterior?.criadoEm, msg.criadoEm)) {
                  return Column(
                    children: [
                      _SeparadorData(dataHora: msg.criadoEm),
                      bolha,
                    ],
                  );
                }
                return bolha;
              },
            );

            return SelectionArea(child: lista);
          },
        );
      },
    );
  }
}

/// Lista de participantes que casam com o `@` sendo digitado.
///
/// Fica ANCORADA acima do campo, dentro da própria coluna do chat, em vez de
/// flutuar num `Overlay`: no mobile o teclado sobe junto e um overlay
/// posicionado por coordenada acaba embaixo dele ou fora da tela.
class _ListaSugestoes extends StatelessWidget {
  final List<({String uid, String nome})> sugestoes;
  final int selecionado;
  final void Function(({String uid, String nome}) participante) onEscolher;

  const _ListaSugestoes({
    super.key,
    required this.sugestoes,
    required this.selecionado,
    required this.onEscolher,
  });

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    return Container(
      constraints: const BoxConstraints(maxHeight: 188),
      decoration: BoxDecoration(
        color: cores.card,
        border: Border(top: BorderSide(color: cores.borda, width: 1)),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: sugestoes.length,
        itemBuilder: (context, index) {
          final participante = sugestoes[index];
          final ativo = index == selecionado;
          return InkWell(
            onTap: () => onEscolher(participante),
            child: Container(
              color: ativo ? cores.campo : Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Row(
                children: [
                  AvatarDoParticipante(uid: participante.uid, tamanho: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      participante.nome,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: ativo ? FontWeight.w700 : FontWeight.w500,
                        color: cores.texto,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Faixa com o recado que o admin prendeu no topo do chat.
class _BannerFixado extends StatelessWidget {
  final MensagemFixada fixada;
  final bool podeDesafixar;
  final VoidCallback onDesafixar;

  const _BannerFixado({
    required this.fixada,
    required this.podeDesafixar,
    required this.onDesafixar,
  });

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
        color: cores.fundoAmarelo,
        border: Border(bottom: BorderSide(color: cores.bordaAmarelo)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.push_pin_rounded, size: 15, color: cores.textoAmarelo),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fixada.autorNome,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: cores.textoAmarelo,
                  ),
                ),
                Text(
                  fixada.texto,
                  // Duas linhas: um recado de sala cabe nisso, e mais que
                  // isso o banner passa a comer a conversa que ele anuncia.
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.25,
                    color: cores.texto,
                  ),
                ),
              ],
            ),
          ),
          if (podeDesafixar)
            IconButton(
              tooltip: 'Desafixar',
              icon: const Icon(Icons.close, size: 16),
              color: cores.textoAmarelo,
              onPressed: onDesafixar,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
        ],
      ),
    );
  }
}

class _SkeletonMensagens extends StatelessWidget {
  const _SkeletonMensagens();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            SkeletonBolhaMensagem(isMinha: false, largura: 140),
            SkeletonBolhaMensagem(isMinha: false, largura: 100),
            SkeletonBolhaMensagem(isMinha: true, largura: 120),
            SkeletonBolhaMensagem(isMinha: false, largura: 160),
            SkeletonBolhaMensagem(isMinha: true, largura: 90),
          ],
        ),
      ),
    );
  }
}

class _CabecalhoChat extends StatelessWidget {
  final VoidCallback? onFechar;

  const _CabecalhoChat({this.onFechar});

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cores.campo,
        border: Border(bottom: BorderSide(color: cores.borda, width: 1)),
      ),
      child: Row(
        children: [
          Icon(Icons.chat_bubble_outline, size: 16, color: cores.azul),
          const SizedBox(width: 8),
          Text(
            'Chat da Sala',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: cores.texto,
            ),
          ),
          if (onFechar != null) ...[
            const Spacer(),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: IconButton(
                tooltip: 'Fechar chat',
                icon: const Icon(Icons.close, size: 18),
                color: cores.textoSuave,
                onPressed: onFechar,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Faixa "Hoje" / "Ontem" / "12/07/2026" entre blocos de dias diferentes.
// Sem ela o chat vira um rolo contínuo em que só dá pra saber a data lendo o
// carimbo de cada mensagem — que agora é só a hora.
class _SeparadorData extends StatelessWidget {
  final DateTime? dataHora;

  const _SeparadorData({required this.dataHora});

  String _rotulo(DateTime data) {
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final dia = DateTime(data.year, data.month, data.day);
    final diferenca = hoje.difference(dia).inDays;

    if (diferenca == 0) return 'Hoje';
    if (diferenca == 1) return 'Ontem';
    return Formatters.data.format(data);
  }

  @override
  Widget build(BuildContext context) {
    if (dataHora == null) return const SizedBox.shrink();

    final cores = AppCores.de(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(child: Divider(color: cores.borda, height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              _rotulo(dataHora!),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: cores.textoFraco,
              ),
            ),
          ),
          Expanded(child: Divider(color: cores.borda, height: 1)),
        ],
      ),
    );
  }
}
