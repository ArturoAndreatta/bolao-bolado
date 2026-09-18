import 'dart:async';

import 'package:bolao_bolado/components/formatters/formatters.dart';
import 'package:bolao_bolado/components/shared/avatar_emoji.dart';
import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/core/app_radii.dart';
import 'package:bolao_bolado/models/mensagem.dart';
import 'package:bolao_bolado/widgets/chat/barra_reacoes.dart';
import 'package:bolao_bolado/widgets/chat/quem_reagiu.dart';
import 'package:bolao_bolado/widgets/chat/seletor_emoji.dart';
import 'package:bolao_bolado/widgets/chat/texto_mensagem.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Ações que o menu de contexto da bolha pode devolver.
enum _AcaoMensagem { copiar, quemReagiu, fixar, desafixar, apagar }

/// Quem está com a barra de reações aberta agora — no app inteiro.
///
/// Cada bolha tem o seu próprio [OverlayPortal], e o fechamento por hover é
/// adiado (ver `_agendarFechamento`) para o ponteiro conseguir atravessar até
/// a pílula. Sem um dono único, passar o mouse rápido por várias mensagens
/// deixava a barra da anterior ainda na tela enquanto a próxima já entrava —
/// duas, às vezes três pílulas empilhadas ao mesmo tempo.
_BolhaMensagemState? _barraAberta;

/// Uma mensagem no chat: avatar, nome, bolha com o texto formatado e as
/// reações.
class BolhaMensagem extends StatefulWidget {
  final Mensagem mensagem;
  final bool isMinha;

  /// Primeira/última mensagem de um bloco de mensagens seguidas do mesmo autor
  /// no mesmo dia. Controlam quem mostra avatar e nome (só a primeira) e o
  /// arredondamento do "rabinho" da bolha (só a última).
  final bool iniciaBloco;
  final bool encerraBloco;

  final bool compacto;

  /// UID de quem está olhando: decide qual reação aparece marcada e se esta
  /// mensagem cita você.
  final String? uidAtual;

  final bool isAdmin;

  /// Quem está olhando pode reagir e abrir o menu da mensagem. Falso para
  /// visitante (anônimo) e para quem não apostou: a regra do Firestore já
  /// recusa a reação deles, e mostrar a barra só fazia o toque sumir calado.
  final bool podeInteragir;

  /// Esta é a mensagem que está fixada no topo agora.
  final bool fixada;

  /// Nome de cada participante, para a lista de quem reagiu.
  ///
  /// Vem pronto do chat, que já tem a lista da stream COMPARTILHADA de
  /// apostas. Sem isso, mostrar quem reagiu custaria uma leitura de
  /// `usuarios/{uid}` por pessoa — e é justamente quem apostou que pode
  /// reagir, então a lista que o chat já tem cobre todo mundo.
  final Map<String, String> nomesPorUid;

  final void Function(String emoji) onReagir;
  final VoidCallback onFixar;
  final VoidCallback onDesafixar;
  final VoidCallback onApagar;

  const BolhaMensagem({
    super.key,
    required this.mensagem,
    required this.isMinha,
    required this.iniciaBloco,
    required this.encerraBloco,
    required this.compacto,
    required this.uidAtual,
    required this.isAdmin,
    required this.podeInteragir,
    required this.fixada,
    this.nomesPorUid = const {},
    required this.onReagir,
    required this.onFixar,
    required this.onDesafixar,
    required this.onApagar,
  });

  @override
  State<BolhaMensagem> createState() => _BolhaMensagemState();
}

class _BolhaMensagemState extends State<BolhaMensagem>
    with SingleTickerProviderStateMixin {
  /// A barra de reações vive num [OverlayPortal] e não no Column da bolha:
  /// dentro do layout ela empurraria a mensagem para baixo toda vez que o
  /// mouse passasse, e a lista inteira tremeria conforme o cursor a
  /// atravessa.
  final OverlayPortalController _barra = OverlayPortalController();

  /// Prende a barra à bolha enquanto a lista rola.
  final LayerLink _ancora = LayerLink();

  /// A BOLHA em si, para medir onde ela está na tela.
  ///
  /// O `context` deste State cobre a linha inteira (avatar, respiro até a
  /// margem oposta), então medir por ele devolve a largura toda da lista —
  /// e era isso que jogava o menu de ações longe da mensagem.
  final GlobalKey _chaveBolha = GlobalKey();

  /// Fechar no `onExit` do mouse direto fazia a barra sumir no meio do
  /// caminho entre a bolha e ela própria (há um vão de poucos pixels que
  /// nenhuma das duas regiões cobre). O timer dá tempo de o ponteiro chegar,
  /// e o `onEnter` da barra o cancela.
  Timer? _fechamento;

  /// Aberta por toque longo: fica até escolherem algo ou tocarem fora, e
  /// nesse modo o overlay ganha uma barreira de tela cheia. Hover não pode
  /// ter barreira — ela engoliria o clique em qualquer outra coisa da tela.
  bool _presaPorToque = false;

  /// Barra desenhada ABAIXO da bolha, para mensagem colada no topo da tela
  /// (onde não sobra altura acima dela).
  bool _abaixo = false;

  /// Entrada e saída da pílula. Aparecer seco fazia a barra "piscar" na tela
  /// a cada mensagem que o ponteiro cruzava; o recuo é mais curto que a
  /// entrada porque sair já é a decisão tomada — arrastar a saída dá a
  /// impressão de que a barra gruda no cursor.
  late final AnimationController _animacao;
  late final CurvedAnimation _curva;

  /// Criada uma vez, e não a cada montagem do overlay: `Tween.animate` produz
  /// um objeto novo com listener próprio toda vez que é chamado.
  late final Animation<double> _escala;

  @override
  void initState() {
    super.initState();
    _animacao = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
      reverseDuration: const Duration(milliseconds: 90),
    );
    _curva = CurvedAnimation(
      parent: _animacao,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _escala = Tween<double>(begin: 0.90, end: 1).animate(_curva);
  }

  @override
  void dispose() {
    _fechamento?.cancel();
    if (_barraAberta == this) _barraAberta = null;
    // A CurvedAnimation assina o controller: sem descartar, cada bolha que
    // sai da lista deixa o listener dela para trás.
    _curva.dispose();
    _animacao.dispose();
    super.dispose();
  }

  void _abrirBarra({bool presa = false}) {
    _fechamento?.cancel();

    // Fecha na hora a barra de outra mensagem — sem esperar o timer dela.
    if (_barraAberta != null && _barraAberta != this) {
      _barraAberta!._fecharBarra(imediato: true);
    }
    _barraAberta = this;

    // Mede na hora de abrir, não no build: a bolha muda de posição a cada
    // rolagem, e o que interessa é onde ela está agora.
    final caixa = _caixaDaBolha();
    if (caixa != null) {
      _abaixo = caixa.top < _alturaBarra + 8;
    }

    if (presa) {
      HapticFeedback.selectionClick();
      setState(() => _presaPorToque = true);
    }
    if (!_barra.isShowing) _barra.show();
    _animacao.forward();
  }

  void _agendarFechamento() {
    if (_presaPorToque) return;
    _fechamento?.cancel();
    _fechamento = Timer(const Duration(milliseconds: 140), _fecharBarra);
  }

  /// Fecha a barra. [imediato] pula a animação de saída.
  void _fecharBarra({bool imediato = false}) {
    _fechamento?.cancel();
    if (_barraAberta == this) _barraAberta = null;
    if (_presaPorToque && mounted) setState(() => _presaPorToque = false);
    if (!_barra.isShowing) return;

    if (imediato) {
      // Outra mensagem assumiu a barra. Sair desenhando deixaria a pílula
      // antiga sumindo enquanto a nova entra — duas na tela, que é justo o
      // que o dono único existe para impedir.
      _animacao.reset();
      _barra.hide();
      return;
    }

    // Tira do overlay só quando o recuo termina. `whenComplete` também dispara
    // quando a animação é INTERROMPIDA (o ponteiro voltou), então o estado
    // final é o que decide — sem essa checagem, voltar para a mensagem no meio
    // da saída fazia a barra sumir logo depois de reaparecer.
    _animacao.reverse().whenComplete(() {
      if (!mounted) return;
      if (_animacao.status == AnimationStatus.dismissed && _barra.isShowing) {
        _barra.hide();
      }
    });
  }

  /// Altura aproximada da pílula, usada só para decidir se ela cabe acima da
  /// bolha. Não precisa ser exata — erra para o lado de virar a barra para
  /// baixo, que é o resultado seguro.
  static const double _alturaBarra = 44;

  /// Retângulo da bolha em coordenadas de tela, ou null antes do layout.
  Rect? _caixaDaBolha() {
    final render = _chaveBolha.currentContext?.findRenderObject() as RenderBox?;
    if (render == null || !render.hasSize) return null;
    return render.localToGlobal(Offset.zero) & render.size;
  }

  /// Alguém escreveu `@você` nesta mensagem.
  bool get _citaVoce =>
      widget.uidAtual != null &&
      widget.mensagem.mencoes.any((m) => m.uid == widget.uidAtual);

  String? get _minhaReacao =>
      widget.uidAtual == null ? null : widget.mensagem.reacoes[widget.uidAtual];

  /// Nome de quem reagiu, na ordem de quem sabe mais sobre ele.
  ///
  /// O autor da mensagem é o único cujo nome o próprio documento carrega, e
  /// ele vale como último recurso: participante que já saiu da sala some da
  /// lista de apostas, mas a reação dele continua no doc.
  String _nomeDe(String uid) {
    if (uid == widget.uidAtual) return 'Você';
    final nome = widget.nomesPorUid[uid];
    if (nome != null && nome.isNotEmpty) return nome;
    if (uid == widget.mensagem.autorUid) return widget.mensagem.autorNome;
    return 'Alguém';
  }

  Future<void> _abrirQuemReagiu() {
    return mostrarQuemReagiu(
      context,
      reacoes: widget.mensagem.reacoes,
      uidAtual: widget.uidAtual,
      nomeDe: _nomeDe,
      // Reagir com o emoji que já é o seu é o que o serviço traduz em
      // remover — não existe uma chamada separada para isso.
      onRemoverMinha: () {
        final minha = _minhaReacao;
        if (minha != null) widget.onReagir(minha);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Mensagem recém-enviada aparece na tela ANTES de o servidor responder
    // (escrita otimista do cache local), e nesse intervalo `criadoEm` é nulo.
    // Deixar o carimbo vazio até a resposta chegar fazia a bolha nascer curta
    // e "pular" de largura quando a hora entrava — o Wrap dividia a linha com
    // um filho a menos.
    //
    // Enquanto pende, usa o relógio do APARELHO, com exatamente o mesmo
    // formato e estilo do carimbo definitivo. A diferença entre ele e o
    // serverTimestamp é de milissegundos, então o texto que entra depois é o
    // mesmo que já estava lá: a troca não aparece. Nada de estado visual de
    // "enviando" (carimbo apagado, ícone de relógio) — qualquer marca que
    // depois some é justamente a impressão de que algo mudou.
    final horario = Formatters.horaCurta.format(
      widget.mensagem.criadoEm ?? DateTime.now(),
    );

    const larguraAvatar = 28.0;
    const espacoAvatar = 8.0;

    return Padding(
      // Dentro de um bloco as mensagens ficam bem mais próximas do que entre
      // blocos: é o espaçamento que faz a sequência ser lida como uma fala só.
      padding: EdgeInsets.only(top: widget.iniciaBloco ? 8 : 2, bottom: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: widget.isMinha
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!widget.isMinha) ...[
            // Continuações do bloco reservam o mesmo espaço do avatar para
            // as bolhas ficarem alinhadas na vertical.
            widget.iniciaBloco
                ? AvatarDoParticipante(
                    uid: widget.mensagem.autorUid,
                    tamanho: 28,
                  )
                : const SizedBox(width: larguraAvatar, height: 0),
            const SizedBox(width: espacoAvatar),
          ],
          Flexible(
            child: ConstrainedBox(
              // Bolha nunca encosta na margem oposta: mesmo no mobile sobra
              // um respiro que deixa claro de que lado a mensagem está.
              //
              // `sizeOf` e não `of`: com `of`, cada bolha passava a depender do
              // MediaQueryData inteiro — inclusive de `viewInsets` —, então
              // abrir o teclado para responder reconstruía todas as bolhas
              // visíveis de uma vez, justamente no momento em que o chat
              // precisa estar leve.
              constraints: BoxConstraints(
                maxWidth:
                    MediaQuery.sizeOf(context).width *
                    (widget.compacto ? 0.78 : 0.85),
              ),
              child: Column(
                crossAxisAlignment: widget.isMinha
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (!widget.isMinha && widget.iniciaBloco)
                    Padding(
                      padding: const EdgeInsets.only(left: 10, bottom: 3),
                      child: Text(
                        widget.mensagem.autorNome,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppCores.de(context).textoSuave,
                        ),
                      ),
                    ),
                  _comGestos(_corpoBolha(context, horario)),
                  // Sempre montado, mesmo sem reação nenhuma: é o PRÓPRIO
                  // widget quem precisa saber quando a última reação sai,
                  // para poder animar a saída antes de encolher a zero — um
                  // `if` aqui o derrubaria da árvore no mesmo frame em que a
                  // reação some do doc, sem tempo de animar nada.
                  _ChipsReacoes(
                    reacoes: widget.mensagem.reacoes,
                    uidAtual: widget.uidAtual,
                    alinharADireita: widget.isMinha,
                    nomeDe: _nomeDe,
                    onReagir: widget.podeInteragir ? widget.onReagir : null,
                    onAbrirDetalhes: _abrirQuemReagiu,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Mouse por cima (desktop) e toque longo (mobile) abrem a mesma barra —
  /// são os gestos que cada plataforma já ensinou. Botão direito continua
  /// indo direto ao menu de ações, que é o que ele significa no desktop.
  /// Clique/toque simples segue livre para a seleção de texto do SelectionArea.
  Widget _comGestos(Widget bolha) {
    // Sem permissão, a bolha fica só leitura: nem barra nem menu. O clique
    // simples continua livre para a seleção de texto.
    if (!widget.podeInteragir) return bolha;
    return OverlayPortal(
      controller: _barra,
      overlayChildBuilder: _construirBarra,
      child: CompositedTransformTarget(
        key: _chaveBolha,
        link: _ancora,
        child: MouseRegion(
          onEnter: (_) => _abrirBarra(),
          onExit: (_) => _agendarFechamento(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPress: () => _abrirBarra(presa: true),
            onSecondaryTapDown: (detalhe) =>
                _abrirMenuAcoes(detalhe.globalPosition),
            child: bolha,
          ),
        ),
      ),
    );
  }

  Widget _construirBarra(BuildContext context) {
    // A barra encosta na borda EXTERNA da bolha (direita na própria, esquerda
    // na dos outros), de onde ela não cobre o começo do texto.
    final ancoraBolha = widget.isMinha
        ? (_abaixo ? Alignment.bottomRight : Alignment.topRight)
        : (_abaixo ? Alignment.bottomLeft : Alignment.topLeft);
    final ancoraBarra = widget.isMinha
        ? (_abaixo ? Alignment.topRight : Alignment.bottomRight)
        : (_abaixo ? Alignment.topLeft : Alignment.bottomLeft);

    return Stack(
      children: [
        // Só no toque: fechar ao tocar fora. No hover a barra se fecha
        // sozinha quando o ponteiro sai, e uma barreira invisível de tela
        // cheia roubaria o clique de todo o resto do app.
        if (_presaPorToque)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _fecharBarra,
            ),
          ),
        CompositedTransformFollower(
          link: _ancora,
          showWhenUnlinked: false,
          targetAnchor: ancoraBolha,
          followerAnchor: ancoraBarra,
          // Encostada na bolha, sem vão e sem sobrepor. O vão faria o ponteiro
          // "sair" da bolha antes de chegar na barra; sobrepor escondia o topo
          // da mensagem que se está lendo, que é justamente a que interessa.
          // A costura de 1px que sobra é coberta pelo timer de fechamento.
          offset: Offset.zero,
          child: MouseRegion(
            onEnter: (_) => _fechamento?.cancel(),
            onExit: (_) => _agendarFechamento(),
            // FadeTransition/ScaleTransition e não AnimatedBuilder: eles
            // recebem o `child` já montado e só mexem no opacity/transform a
            // cada quadro. Com AnimatedBuilder, a pílula inteira — oito
            // botões, borda, sombra — seria reconstruída 60 vezes por segundo
            // para animar dois números.
            child: FadeTransition(
              opacity: _curva,
              child: ScaleTransition(
                scale: _escala,
                // Cresce a partir do canto colado na bolha, e não do centro:
                // é de lá que ela "sai" da mensagem.
                alignment: ancoraBarra,
                // A pílula anima sobre a lista de mensagens. Sem isolar, cada
                // quadro do fade sujaria a camada inteira do overlay.
                child: RepaintBoundary(
                  child: BarraReacoes(
                    reacaoAtual: _minhaReacao,
                    onEscolher: (emoji) {
                      _fecharBarra();
                      widget.onReagir(emoji);
                    },
                    onMais: _escolherDoCatalogo,
                    onAcoes: () => _abrirMenuAcoes(null),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _escolherDoCatalogo() async {
    _fecharBarra();
    final emoji = await escolherEmoji(context);
    if (emoji == null || !mounted) return;
    widget.onReagir(emoji);
  }

  /// Menu de ações da mensagem. [posicao] vem do clique com o botão direito;
  /// quando é null (veio do "⋯" da barra), ancora no canto superior da bolha.
  Future<void> _abrirMenuAcoes(Offset? posicao) async {
    _fecharBarra();

    final cores = AppCores.de(context);
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;

    // De onde o menu cresce. Botão direito ancora no cursor, que é o que se
    // espera de um menu de contexto no desktop. O "⋯" da barra ancora na
    // BOLHA: logo abaixo dela e alinhado à borda externa (direita na sua
    // mensagem, esquerda na dos outros).
    //
    // O alvo precisa ser o retângulo da bolha, não um ponto: o
    // `_PopupMenuRouteLayout` do Material cresce para o lado com mais espaço,
    // e com um alvo de tamanho zero na borda ESQUERDA da bolha ele encostava
    // a direita do menu ali e jogava o resto para fora do painel do chat —
    // o menu aparecia lá na tabela de participantes.
    final caixa = _caixaDaBolha();
    final Rect alvo;
    if (posicao != null) {
      alvo = posicao & Size.zero;
    } else if (caixa != null) {
      alvo = Rect.fromLTRB(caixa.left, caixa.bottom, caixa.right, caixa.bottom);
    } else {
      alvo = Offset.zero & Size.zero;
    }

    final escolha = await showMenu<_AcaoMensagem>(
      context: context,
      color: cores.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.circularSmd),
      position: RelativeRect.fromRect(alvo, Offset.zero & overlay.size),
      items: [
        const PopupMenuItem<_AcaoMensagem>(
          value: _AcaoMensagem.copiar,
          child: _ItemMenu(icone: Icons.copy_rounded, rotulo: 'Copiar texto'),
        ),
        // Segundo caminho até a lista de quem reagiu. O primeiro é o toque
        // longo no chip, que ninguém descobre sozinho — este item existe para
        // a lista não depender de um gesto escondido.
        if (widget.mensagem.reacoes.isNotEmpty)
          const PopupMenuItem<_AcaoMensagem>(
            value: _AcaoMensagem.quemReagiu,
            // Já foi `emoji_emotions_outlined` (0xf019), que sai VAZIO na
            // web: o codepoint está no manifesto da fonte, mas o glifo não
            // aparece. Não é "ícone novo no bundle" — `more_horiz_rounded`
            // e `add_reaction_outlined` estrearam junto e desenham normal.
            // A causa não foi apurada; `groups_outlined` já roda no Painel
            // ADM, então é terreno conhecido, e cabe no sentido do item.
            child: _ItemMenu(
              icone: Icons.groups_outlined,
              rotulo: 'Quem reagiu',
            ),
          ),
        if (widget.isAdmin)
          PopupMenuItem<_AcaoMensagem>(
            value: widget.fixada
                ? _AcaoMensagem.desafixar
                : _AcaoMensagem.fixar,
            child: _ItemMenu(
              icone: widget.fixada
                  ? Icons.push_pin_outlined
                  : Icons.push_pin_rounded,
              rotulo: widget.fixada ? 'Desafixar' : 'Fixar no topo',
            ),
          ),
        if (widget.isAdmin)
          PopupMenuItem<_AcaoMensagem>(
            value: _AcaoMensagem.apagar,
            child: _ItemMenu(
              icone: Icons.delete_outline,
              rotulo: 'Apagar',
              cor: cores.vermelho,
            ),
          ),
      ],
    );

    if (escolha == null) return;
    switch (escolha) {
      case _AcaoMensagem.copiar:
        await Clipboard.setData(ClipboardData(text: widget.mensagem.texto));
      case _AcaoMensagem.quemReagiu:
        if (mounted) await _abrirQuemReagiu();
      case _AcaoMensagem.fixar:
        widget.onFixar();
      case _AcaoMensagem.desafixar:
        widget.onDesafixar();
      case _AcaoMensagem.apagar:
        widget.onApagar();
    }
  }

  // Texto e horário dividem a mesma bolha: o carimbo flutua no canto inferior
  // junto à última linha em vez de ocupar uma linha inteira abaixo — era isso
  // que fazia cada mensagem custar três alturas de texto no mobile.
  Widget _corpoBolha(BuildContext context, String horario) {
    final cores = AppCores.de(context);
    final corTexto = widget.isMinha
        ? cores.textoSobreCor
        : cores.bolhaOutroTexto;
    final corHorario = widget.isMinha
        ? cores.textoSobreCor.withValues(alpha: 0.75)
        : cores.textoFraco;

    const raio = Radius.circular(16);
    const raioRabo = Radius.circular(5);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 7, 10, 7),
      decoration: BoxDecoration(
        color: widget.isMinha ? cores.azul : cores.bolhaOutro,
        borderRadius: BorderRadius.only(
          topLeft: raio,
          topRight: raio,
          // Só a última bolha do bloco ganha o canto "rabinho" apontando para
          // o avatar; as do meio ficam com os quatro cantos redondos.
          bottomLeft: !widget.isMinha && widget.encerraBloco ? raioRabo : raio,
          bottomRight: widget.isMinha && widget.encerraBloco ? raioRabo : raio,
        ),
        // Mensagem que cita VOCÊ ganha um aro na cor de acento. É o realce
        // mais barato que funciona nos dois lados da conversa: mudar o fundo
        // da bolha exigiria um par de cores novo para cada tema e brigaria
        // com o azul da bolha própria.
        border: _citaVoce ? Border.all(color: cores.azul, width: 1.5) : null,
      ),
      child: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: 8,
        children: [
          TextoMensagem(
            texto: widget.mensagem.texto,
            mencoes: widget.mensagem.mencoes,
            corTexto: corTexto,
            isMinha: widget.isMinha,
          ),
          Text(
            horario,
            style: TextStyle(
              fontSize: 10,
              height: 1.3,
              color: corHorario,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemMenu extends StatelessWidget {
  final IconData icone;
  final String rotulo;
  final Color? cor;

  const _ItemMenu({required this.icone, required this.rotulo, this.cor});

  @override
  Widget build(BuildContext context) {
    final corFinal = cor ?? AppCores.de(context).texto;
    return Row(
      children: [
        Icon(icone, size: 18, color: corFinal),
        const SizedBox(width: 10),
        Text(rotulo, style: TextStyle(fontSize: 13.5, color: corFinal)),
      ],
    );
  }
}

/// Fileira de "👍 3" abaixo da bolha.
///
/// Agrupa o mapa `{uid: emoji}` por emoji na hora de desenhar: contar aqui é
/// mais barato do que manter um contador no documento, que precisaria de
/// transação a cada toque para não dessincronizar do mapa.
///
/// Tocar num chip dá aquela reação, ou tira a sua se ela já for essa — é o
/// atalho para o que a barra flutuante faria em dois passos. Quem reagiu sai
/// no tooltip do mouse, no toque longo e no menu de ações.
/// O que um chip mostra, sem a parte de identidade (o emoji, que é a chave).
class _DadosChip {
  final int quantidade;
  final String quem;
  final bool minha;

  const _DadosChip({
    required this.quantidade,
    required this.quem,
    required this.minha,
  });
}

class _ChipsReacoes extends StatefulWidget {
  final Map<String, String> reacoes;
  final String? uidAtual;
  final bool alinharADireita;
  final String Function(String uid) nomeDe;

  /// Null para quem não pode reagir: o chip continua mostrando a contagem e
  /// quem reagiu, só não responde ao toque.
  final void Function(String emoji)? onReagir;
  final VoidCallback onAbrirDetalhes;

  const _ChipsReacoes({
    required this.reacoes,
    required this.uidAtual,
    required this.alinharADireita,
    required this.nomeDe,
    required this.onReagir,
    required this.onAbrirDetalhes,
  });

  @override
  State<_ChipsReacoes> createState() => _ChipsReacoesState();
}

/// Cada emoji tem seu próprio controller de entrada/saída, e ele SOBREVIVE à
/// reação sumir do doc: enquanto a saída anima, o chip ainda está na árvore
/// desenhando o último dado conhecido (`_dados`), só sem contar mais para
/// `widget.reacoes`. `_ordem` é a lista de quem está visível AGORA (recém
/// chegado ou ainda saindo) — sem ela, remover do mapa `reacoes` já
/// derrubaria o widget do Wrap antes da animação rodar.
class _ChipsReacoesState extends State<_ChipsReacoes>
    with TickerProviderStateMixin {
  final Map<String, AnimationController> _controladores = {};
  final Map<String, _DadosChip> _dados = {};
  final List<String> _ordem = [];

  @override
  void initState() {
    super.initState();
    // Sem "pop" de entrada aqui: isto roda toda vez que a bolha aparece pela
    // primeira vez, inclusive ao rolar o histórico para cima. Uma reação de
    // três dias atrás animando "de novo" a cada vez que passa pela tela
    // pareceria fogo de artifício em vez de novidade.
    _sincronizar(animarEntrada: false);
  }

  @override
  void didUpdateWidget(covariant _ChipsReacoes oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sincronizar();
  }

  @override
  void dispose() {
    for (final controlador in _controladores.values) {
      controlador.dispose();
    }
    super.dispose();
  }

  ({List<String> ordenados, Map<String, _DadosChip> dados}) _agrupar() {
    final minhaReacao = widget.uidAtual == null
        ? null
        : widget.reacoes[widget.uidAtual];

    // Mesma função que monta a folha de quem reagiu: o tooltip do chip e a
    // lista da folha precisam nomear as pessoas na MESMA ordem, senão os dois
    // caminhos para a mesma pergunta respondem diferente.
    final nomesPorEmoji = <String, List<String>>{};
    final ordenados = <String>[];
    for (final linha in ordenarReacoes(
      reacoes: widget.reacoes,
      uidAtual: widget.uidAtual,
      nomeDe: widget.nomeDe,
    )) {
      if (!nomesPorEmoji.containsKey(linha.emoji)) ordenados.add(linha.emoji);
      (nomesPorEmoji[linha.emoji] ??= []).add(linha.nome);
    }

    return (
      ordenados: ordenados,
      dados: {
        for (final emoji in ordenados)
          emoji: _DadosChip(
            quantidade: nomesPorEmoji[emoji]!.length,
            quem: resumoQuemReagiu(nomesPorEmoji[emoji]!),
            minha: minhaReacao == emoji,
          ),
      },
    );
  }

  void _sincronizar({bool animarEntrada = true}) {
    final agrupado = _agrupar();
    final atuais = agrupado.ordenados.toSet();

    for (final emoji in agrupado.ordenados) {
      _dados[emoji] = agrupado.dados[emoji]!;
      final existente = _controladores[emoji];
      if (existente == null) {
        final controlador = AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 220),
          reverseDuration: const Duration(milliseconds: 140),
        );
        _controladores[emoji] = controlador;
        _ordem.add(emoji);
        if (animarEntrada) {
          controlador.forward();
        } else {
          controlador.value = 1;
        }
      } else if (existente.status == AnimationStatus.reverse ||
          existente.status == AnimationStatus.dismissed) {
        // A mesma reação saiu e voltou rápido (removeu, reagiu nela de novo
        // antes da saída terminar): retoma a entrada de onde a saída parou,
        // em vez de reiniciar do zero — o chip não "pisca".
        existente.forward();
      }
    }

    // O que sumiu de `widget.reacoes` toca a saída e só deixa `_ordem`
    // quando ela termina — é isto que dá tempo do fade/encolhimento rodar
    // antes do chip sumir de vez.
    for (final emoji in List<String>.from(_ordem)) {
      if (atuais.contains(emoji)) continue;
      final controlador = _controladores[emoji]!;
      controlador.reverse().whenCompleteOrCancel(() {
        if (!mounted || controlador.status != AnimationStatus.dismissed) {
          return;
        }
        setState(() {
          _ordem.remove(emoji);
          _dados.remove(emoji);
          _controladores.remove(emoji)?.dispose();
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Encolhe pra zero quando a última reação sai (e cresce quando a
    // primeira chega): sem isto, o espaço reservado para o chip sumia de
    // um frame pro outro assim que a saída terminava, e a bolha "pulava".
    return AnimatedSize(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      alignment: widget.alinharADireita
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: _ordem.isEmpty
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                alignment: widget.alinharADireita
                    ? WrapAlignment.end
                    : WrapAlignment.start,
                children: [
                  for (final emoji in _ordem)
                    _ChipAnimado(
                      key: ValueKey(emoji),
                      animacao: _controladores[emoji]!,
                      child: _ChipReacao(
                        emoji: emoji,
                        quantidade: _dados[emoji]!.quantidade,
                        minha: _dados[emoji]!.minha,
                        quem: _dados[emoji]!.quem,
                        onTap: widget.onReagir == null
                            ? null
                            : () => widget.onReagir!(emoji),
                        onLongPress: widget.onAbrirDetalhes,
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

/// Entrada/saída de UM chip: nasce pequeno e transparente, cresce com uma
/// leve "batida" (`easeOutBack`, que passa de 1 e volta) e sai reto.
/// A batida só faz sentido chegando — é isso que faz a reação "pipocar" —,
/// então a curva de saída é linear via `reverseCurve`.
class _ChipAnimado extends StatefulWidget {
  final AnimationController animacao;
  final Widget child;

  const _ChipAnimado({
    required super.key,
    required this.animacao,
    required this.child,
  });

  @override
  State<_ChipAnimado> createState() => _ChipAnimadoState();
}

class _ChipAnimadoState extends State<_ChipAnimado> {
  late CurvedAnimation _curva;

  @override
  void initState() {
    super.initState();
    _curva = _construirCurva();
  }

  @override
  void didUpdateWidget(covariant _ChipAnimado oldWidget) {
    super.didUpdateWidget(oldWidget);
    // O controller é sempre o MESMO enquanto o emoji existe (a key trata
    // disso), mas se algum dia vier outro, a curva velha ficaria presa a um
    // controller descartado.
    if (oldWidget.animacao != widget.animacao) {
      _curva.dispose();
      _curva = _construirCurva();
    }
  }

  CurvedAnimation _construirCurva() => CurvedAnimation(
    parent: widget.animacao,
    curve: Curves.easeOutBack,
    reverseCurve: Curves.easeIn,
  );

  @override
  void dispose() {
    _curva.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      // A "batida" do easeOutBack passa de 1.0 e um alpha > 1 quebraria o
      // FadeTransition — por isso a opacidade usa o controller CRU (sempre
      // 0..1) e só a escala usa a curva com batida.
      opacity: widget.animacao,
      child: ScaleTransition(scale: _curva, child: widget.child),
    );
  }
}

class _ChipReacao extends StatelessWidget {
  final String emoji;
  final int quantidade;
  final bool minha;

  /// Resumo dos nomes, para o tooltip do mouse.
  final String quem;

  /// Dá esta reação, ou tira a sua quando ela já é esta.
  final VoidCallback? onTap;

  /// Abre a lista de quem reagiu.
  final VoidCallback onLongPress;

  const _ChipReacao({
    required this.emoji,
    required this.quantidade,
    required this.minha,
    required this.quem,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    // No desktop o nome sai sem custar um toque; no mobile, onde tooltip só
    // aparece em toque longo, quem responde a pergunta é a folha.
    return Tooltip(message: quem, child: _chip(cores));
  }

  Widget _chip(AppCores cores) {
    // AnimatedContainer pela cor/borda, e não Material.color: o toggle da
    // SUA reação (a barra de estado "minha") acontece num chip que já existe
    // — sem isto a cor trocava de vermelho pra azul num corte seco.
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: minha ? cores.fundoAzul : cores.campo,
        borderRadius: AppRadii.circularPill,
        border: Border.all(color: minha ? cores.bordaAzul : cores.borda),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: AppRadii.circularPill,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 3),
                Text(
                  '$quantidade',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: minha ? cores.textoAzul : cores.textoSuave,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
