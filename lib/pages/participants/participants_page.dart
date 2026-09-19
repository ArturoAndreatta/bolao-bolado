import 'dart:async';
import 'package:bolao_bolado/components/shared/header_card.dart';
import 'package:bolao_bolado/components/shell/default_layout.dart';
import 'package:bolao_bolado/components/shell/drawer.dart';
import 'package:bolao_bolado/components/shell/secoes_mobile.dart';
import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/core/responsive.dart';
import 'package:bolao_bolado/dev/simulador_apostas.dart';
import 'package:bolao_bolado/pages/participants/participants_painel.dart';
import 'package:bolao_bolado/pages/participants/participants_simulacao_dialog.dart';
import 'package:bolao_bolado/pages/participants/participants_skeletons.dart';
import 'package:bolao_bolado/router/app_router.dart';
import 'package:bolao_bolado/services/authentication/auth_service.dart';
import 'package:bolao_bolado/services/bet/bet_service.dart';
import 'package:bolao_bolado/services/bet/preco_cota.dart';
import 'package:bolao_bolado/widgets/chat_sala.dart';
import 'package:bolao_bolado/widgets/minha_aposta_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class Participants extends StatefulWidget {
  // Seção a abrir no layout mobile, vinda da query string (?aba=aposta|chat).
  // Usada pelo Drawer para navegar direto pra seção certa.
  final String? abaInicial;

  const Participants({super.key, this.abaInicial});

  @override
  State<Participants> createState() => _ParticipantsState();
}

class _ParticipantsState extends State<Participants> {
  // Apostas reais, já com cotas/prêmio calculados por streamBets().
  List<Map<String, Object?>> _apostasReais = [];
  bool _loading = true;
  String? _salaId;
  bool _isAdmin = false;
  String? _sorteio;
  DateTime? _dataSorteio;
  double _premioSala = 0;

  StreamSubscription<List<Map<String, Object?>>>? _betsSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _salaSubscription;
  final SimuladorApostas _simulador = SimuladorApostas();

  // Seção ativa no mobile, pelo `indice` de [_SecaoMobile].
  static int _secaoDe(String? aba) => switch (aba) {
    'aposta' => _SecaoMobile.aposta.indice,
    'chat' => _SecaoMobile.chat.indice,
    _ => _SecaoMobile.participantes.indice,
  };

  // ValueNotifier e não campo com setState — ver _layoutMobile.
  late final ValueNotifier<int> _secaoMobile = ValueNotifier(
    _secaoDe(widget.abaInicial),
  );

  // Controla se o chat está sobreposto ao grid no desktop (dispara a
  // animação de abrir/fechar).
  //
  // Nasce aberto quando a navegação pediu o chat. No desktop não existe aba
  // de Chat — o painel é sobreposto —, então o MESMO `?aba=chat` que escolhe
  // a seção no mobile precisa abrir o painel aqui; sem isto, clicar em Chat no
  // Drawer levava para Participantes e parava por aí.
  late bool _chatAbertoDesktop = widget.abaInicial == 'chat';

  // Mantém o ChatSala montado durante a animação de fechamento; some da
  // árvore só quando a animação termina (evita "sumir" abrupto).
  late bool _chatVisivelDesktop = _chatAbertoDesktop;

  @override
  void initState() {
    super.initState();
    _load();
    // Reflete apostas fake do simulador em modo "não gravar" (ver
    // gravarSimulacaoFirestoreGlobal em debug_flags.dart): elas vivem só em
    // memória, dentro do próprio _simulador, então esta tela precisa
    // reconstruir sempre que a lista local mudar — sem isso a rajada local
    // nunca apareceria na tabela.
    _simulador.apostasLocais.addListener(_onApostasLocaisMudaram);
  }

  void _onApostasLocaisMudaram() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant Participants oldWidget) {
    super.didUpdateWidget(oldWidget);
    // GoRouter reusa este State ao navegar de /participantes?aba=X pra
    // /participantes?aba=Y (mesma rota, query diferente): sem isso, clicar
    // em outro item do Drawer estando já na tela não troca de seção.
    if (widget.abaInicial != oldWidget.abaInicial) {
      _secaoMobile.value = _secaoDe(widget.abaInicial);
      setState(() {
        // No desktop o mesmo parâmetro decide o painel sobreposto. Ir para
        // "Participantes" ou "Minha Aposta" fecha o chat de propósito: o
        // painel cobre parte do grid, e quem pediu a tabela quer ver a tabela.
        _chatAbertoDesktop = widget.abaInicial == 'chat';
        if (_chatAbertoDesktop) _chatVisivelDesktop = true;
      });
    }
  }

  @override
  void dispose() {
    _betsSubscription?.cancel();
    _salaSubscription?.cancel();
    _simulador.apostasLocais.removeListener(_onApostasLocaisMudaram);
    _simulador.parar();
    _secaoMobile.dispose();
    super.dispose();
  }

  /// Apostas reais + apostas fake locais do simulador (quando houver),
  /// recalculando cotas/prêmio do conjunto junto — as fake locais entram no
  /// mesmo rateio que apostas de verdade, para a tela ficar idêntica ao modo
  /// "grava no Firestore". Sem apostas locais, é simplesmente `_apostasReais`
  /// (o caminho comum, sem custo extra de recálculo).
  // Resultado do último merge reais+fake e as entradas que o produziram. Sem
  // isto o getter devolvia uma lista NOVA a cada build, e o painel logo abaixo
  // (que memoiza filtro/ordenação por identidade da lista) errava o cache
  // sempre — justamente durante a simulação, que é quando mais reconstrói.
  List<Map<String, Object?>>? _rowsDataCache;
  List<Map<String, Object?>>? _reaisDoCache;
  List<Map<String, Object?>>? _locaisDoCache;
  double? _premioDoCache;
  String? _sorteioDoCache;

  List<Map<String, Object?>> get _rowsData {
    final locais = _simulador.apostasLocais.value;
    if (locais.isEmpty) return _apostasReais;

    final cache = _rowsDataCache;
    if (cache != null &&
        identical(_reaisDoCache, _apostasReais) &&
        identical(_locaisDoCache, locais) &&
        _premioDoCache == _premioSala &&
        _sorteioDoCache == _sorteio) {
      return cache;
    }

    // As reais já vieram de streamBets() com `cotas`/`premio` calculados só
    // entre elas; juntar direto com as fake (que não têm esses campos)
    // deixaria os dois conjuntos com números que não somam entre si. Tira
    // esses campos das reais e recalcula tudo junto, com o mesmo prêmio e
    // preço de cota da sala.
    final semCotasPremio = _apostasReais.map((item) {
      final copia = Map<String, Object?>.from(item)
        ..remove('cotas')
        ..remove('premio');
      return copia;
    });
    final precoCota = precoCotaPara(_sorteio);
    final resultado = calcularCotasEPremios(
      [...semCotasPremio, ...locais],
      _premioSala,
      precoCota,
    );

    _rowsDataCache = resultado;
    _reaisDoCache = _apostasReais;
    _locaisDoCache = locais;
    _premioDoCache = _premioSala;
    _sorteioDoCache = _sorteio;
    return resultado;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      // Usuário anônimo nunca é admin: evita checagem desnecessária no Firestore
      final isAdminFuture = user != null && !user.isAnonymous
          ? AuthService().isAdmin(user.uid)
          : Future.value(false);

      // As duas leituras são independentes uma da outra, então saem juntas.
      // Encadeadas (`await` uma, depois a outra) eram dois round-trips
      // seriais antes de qualquer pixel de conteúdo aparecer — em rede
      // lenta, os primeiros segundos de skeleton eram só isso.
      final (isAdmin, salaId) = await (
        isAdminFuture,
        buscarSalaPrincipalId(),
      ).wait;

      if (!mounted) return;
      setState(() {
        _salaId = salaId;
        _isAdmin = isAdmin;
      });

      // Dados do sorteio (prêmio, data) vêm da stream da sala em vez de uma
      // leitura pontual: tira mais um round-trip do caminho crítico e, de
      // quebra, o painel de estatísticas passa a acompanhar edições do admin
      // sem depender de um novo _load().
      unawaited(_salaSubscription?.cancel());
      _salaSubscription = streamSalaPrincipal().listen((doc) {
        if (!mounted) return;
        final dados = doc.data();
        setState(() {
          _sorteio = dados?['sorteio']?.toString();
          _dataSorteio = (dados?['dataHora'] as Timestamp?)?.toDate();
          _premioSala = (dados?['premio'] as num?)?.toDouble() ?? 0;
        });
      });

      // Cancela stream anterior antes de reabrir (ex: troca de sala via _load())
      unawaited(_betsSubscription?.cancel());
      _betsSubscription = streamBets().listen(
        (dataBets) {
          if (!mounted) return;
          setState(() {
            _apostasReais = dataBets;
            _loading = false;
          });
        },
        onError: (_) {
          // Erro no stream de apostas apenas encerra o loading; mantém a
          // última lista carregada em vez de quebrar a tela.
          if (!mounted) return;
          setState(() => _loading = false);
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Compact cobre mobile E tablet/janela estreita: abaixo da largura
    // mínima em que os dois cards cabem lado a lado sem estourar
    // horizontalmente, mostra uma seção por vez (mesmo layout do mobile).
    final isCompact = Responsive.isCompact(context);
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isLoggedIn = AuthService().isLoggedIn;

    return DefaultLayout(
      drawer: AppDrawer(onAvatarChanged: (_) => _load()),
      esticarLarguraCompact: true,
      bottomNavigationBar: isCompact ? _barraSecoesMobile() : null,
      // A barra flutua sobre o conteúdo (ver BarraSecoesMobile); cada seção
      // desconta a altura dela em [_secao].
      extendBody: isCompact,
      child: isCompact
          ? _layoutMobile(currentUid)
          : _layoutDesktop(currentUid, isLoggedIn),
    );
  }

  // ── Layout Desktop: minha aposta + participantes + chat lateral ─────────
  Widget _layoutDesktop(String? currentUid, bool isLoggedIn) {
    final isLoggedInDeVerdade =
        FirebaseAuth.instance.currentUser?.isAnonymous == false && isLoggedIn;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLoggedInDeVerdade) ...[
          MinhaApostaCard(onApostaConfirmada: () => setState(() {})),
          const SizedBox(width: 16),
        ],
        _painelParticipantesDesktop(currentUid, isLoggedIn),
      ],
    );
  }

  Widget _painelParticipantesDesktop(String? currentUid, bool isLoggedIn) {
    // Altura igual à do card interno de MinhaApostaCard (height: 538), para
    // os dois cards ficarem com a mesma altura total lado a lado no
    // desktop — a altura vai direto pro CustomCard(isChild:true) do
    // HeaderCard, no mesmo ponto da árvore que MinhaApostaCard usa.
    const double chatHeight = 538;

    return GestureDetector(
      // Fecha o chat clicando em qualquer lugar do card pai (cabeçalho,
      // estatísticas, tabela) fora do próprio painel do chat — que tem seu
      // próprio GestureDetector opaco para não propagar o clique até aqui.
      behavior: HitTestBehavior.translucent,
      onTap: _chatAbertoDesktop ? _fecharChatDesktop : null,
      child: HeaderCard(
        text: 'Participantes',
        subtitle: 'Visualize quem está participando',
        maxWidth: 937,
        height: chatHeight,
        trailing: _botoesTrailingDesktop(),
        // Participants é sempre acessada via context.go (login ou
        // "Visualizar" na Home), nunca empilhada. Usuário logado não tem
        // para onde voltar; visitante (deslogado ou sessão anônima) veio da Home.
        showBackButton: !isLoggedIn,
        onBack: () => context.go(AppRoutes.home),
        children: [
          Expanded(
            child: Stack(
              children: [
                PainelParticipantes(
                  currentUid: currentUid,
                  loading: _loading,
                  rowsData: _rowsData,
                  isAdmin: _isAdmin,
                  sorteio: _sorteio,
                  dataSorteio: _dataSorteio,
                  premioSala: _premioSala,
                  onEditarSala: _botaoEditarSala,
                  mobile: false,
                  expandirConteudo: true,
                  mostrarCabecalho: false,
                ),
                if (_chatVisivelDesktop)
                  Positioned(
                    top: 0,
                    right: 0,
                    bottom: 0,
                    width: 360,
                    child: _PainelChatAnimado(
                      aberto: _chatAbertoDesktop,
                      onFechado: () {
                        if (mounted) {
                          setState(() => _chatVisivelDesktop = false);
                        }
                      },
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {},
                        child: _loading
                            ? const SkeletonChatSala()
                            : ChatSala(
                                salaId: _salaId!,
                                mostrarCabecalho: false,
                                flutuante: true,
                              ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _botoesTrailingDesktop() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isAdmin) ...[_botaoSimularApostas(), _botaoEditarSala()],
        const SizedBox(width: 4),
        _botaoChatDesktop(),
      ],
    );
  }

  void _alternarChatDesktop() {
    if (_chatAbertoDesktop) {
      _fecharChatDesktop();
      return;
    }
    setState(() {
      _chatAbertoDesktop = true;
      _chatVisivelDesktop = true;
    });
  }

  /// Fecha o painel e apaga o `?aba=chat` da URL.
  ///
  /// Limpar a query é o que faz o item Chat do Drawer voltar a funcionar: sem
  /// isso a URL continuaria dizendo "chat" depois de o usuário fechar o
  /// painel, e clicar em Chat de novo não mudaria parâmetro nenhum — o
  /// [didUpdateWidget] não veria diferença e o painel não reabriria.
  ///
  /// `replace` e não `go` porque isto não é navegação: fechar o painel não
  /// pode empilhar uma entrada no histórico do navegador, senão o Voltar
  /// passaria a desfazer cliques de chat em vez de sair da tela.
  ///
  /// O State sobrevive à troca de query nos dois casos — `state.pageKey` sai
  /// do caminho da rota, não da query, e é o mesmo motivo pelo qual
  /// [didUpdateWidget] existe aqui em vez de um State novo a cada `?aba=`.
  void _fecharChatDesktop() {
    setState(() => _chatAbertoDesktop = false);
    // Só o `aba=chat` é assunto deste botão: fechar o chat não pode apagar um
    // `aba=aposta` que veio de outro item do Drawer.
    if (widget.abaInicial == 'chat') context.replace(AppRoutes.participants);
  }

  Widget _botaoChatDesktop() {
    final cores = AppCores.de(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: OutlinedButton.icon(
        onPressed: _alternarChatDesktop,
        icon: Icon(
          _chatAbertoDesktop ? Icons.close : Icons.chat_bubble_outline,
          size: 16,
        ),
        label: const Text('Chat'),
        style: OutlinedButton.styleFrom(
          foregroundColor: cores.azul,
          side: BorderSide(color: cores.azul),
        ),
      ),
    );
  }

  // ── Layout Mobile: uma seção por vez + barra inferior ──────────────────
  //
  // Folha de seções + barra flutuante, o layout compartilhado com o Painel
  // ADM (ver secoes_mobile.dart). Já foi um fichário de abas coloridas colado
  // nas bordas da tela, com uma cor por seção: nada disso existia no
  // desktop, e as duas versões pareciam apps diferentes.
  //
  // Vale também para tablet e janela estreita (tudo abaixo de
  // kLarguraMinimaLadoALado).

  List<_SecaoMobile> _secoesMobile() => [
    // Visitante não tem aposta: a seção nem aparece na barra.
    if (FirebaseAuth.instance.currentUser?.isAnonymous == false)
      _SecaoMobile.aposta,
    _SecaoMobile.participantes,
    _SecaoMobile.chat,
  ];

  // Deep link para uma seção que o usuário não tem (visitante abrindo
  // `?aba=aposta`) cai em Participantes em vez de mostrar a tela vazia.
  static int _indiceVisivel(int pedido, List<_SecaoMobile> secoes) =>
      secoes.any((s) => s.indice == pedido)
      ? pedido
      : _SecaoMobile.participantes.indice;

  Widget _layoutMobile(String? currentUid) {
    final secoes = _secoesMobile();
    return FolhaSecoesMobile(
      itens: [for (final secao in secoes) secao.item],
      ativa: _secaoMobile,
      resolverAtiva: (pedido) => _indiceVisivel(pedido, secoes),
      construir: (context, item, altura) => _conteudoSecao(
        secao: _SecaoMobile.values.firstWhere((s) => s.indice == item.indice),
        currentUid: currentUid,
        altura: altura,
      ),
    );
  }

  Widget _barraSecoesMobile() {
    final secoes = _secoesMobile();
    return ValueListenableBuilder<int>(
      valueListenable: _secaoMobile,
      builder: (context, ativa, _) => BarraSecoesMobile(
        itens: [for (final secao in secoes) secao.item],
        ativa: _indiceVisivel(ativa, secoes),
        onSelecionar: (indice) => _secaoMobile.value = indice,
      ),
    );
  }

  Widget _conteudoSecao({
    required _SecaoMobile secao,
    required String? currentUid,
    required double altura,
  }) {
    switch (secao) {
      case _SecaoMobile.aposta:
        return MinhaApostaCard(
          // Aposta confirmada leva para a lista, onde ela acabou de entrar.
          onApostaConfirmada: () =>
              _secaoMobile.value = _SecaoMobile.participantes.indice,
          mobile: true,
          alturaMobile: altura,
          mostrarCabecalho: false,
          apenasConteudo: true,
        );
      case _SecaoMobile.participantes:
        return PainelParticipantes(
          currentUid: currentUid,
          loading: _loading,
          rowsData: _rowsData,
          isAdmin: _isAdmin,
          sorteio: _sorteio,
          dataSorteio: _dataSorteio,
          premioSala: _premioSala,
          onEditarSala: _botaoEditarSala,
          mobile: true,
          alturaMobile: altura,
          mostrarCabecalho: false,
        );
      case _SecaoMobile.chat:
        return SizedBox(
          height: altura,
          child: _salaId == null
              ? const SkeletonChatSala()
              : ChatSala(salaId: _salaId!, mostrarCabecalho: false),
        );
    }
  }

  Widget _botaoEditarSala() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: IconButton(
        tooltip: 'Editar sala',
        icon: Icon(Icons.edit_outlined, color: AppCores.de(context).azul),
        onPressed: _salaId == null
            ? null
            : () async {
                await context.push(
                  Uri(
                    path: AppRoutes.cadastrarSala,
                    queryParameters: {'salaId': _salaId},
                  ).toString(),
                );
                if (mounted) unawaited(_load());
              },
      ),
    );
  }

  Widget _botaoSimularApostas() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: IconButton(
        tooltip: 'Simular apostas',
        icon: Icon(Icons.groups_2_outlined, color: AppCores.de(context).roxo),
        onPressed: _salaId == null ? null : _abrirDialogoSimulacao,
      ),
    );
  }

  void _abrirDialogoSimulacao() {
    if (_salaId == null) return;
    showDialog(
      context: context,
      builder: (_) =>
          DialogoSimulacaoApostas(simulador: _simulador, salaId: _salaId!),
    );
  }
}

// Anima o painel do chat entre a posição escondida (fora da tela, à
// direita) e visível. Monta sempre fechado e agenda a abertura no frame
// seguinte, garantindo que o AnimatedSlide tenha um estado de origem
// diferente do destino (senão a 1ª abertura não anima).
class _PainelChatAnimado extends StatefulWidget {
  final bool aberto;
  final VoidCallback onFechado;
  final Widget child;

  const _PainelChatAnimado({
    required this.aberto,
    required this.onFechado,
    required this.child,
  });

  @override
  State<_PainelChatAnimado> createState() => _PainelChatAnimadoState();
}

class _PainelChatAnimadoState extends State<_PainelChatAnimado> {
  static const _duracaoAbrir = Duration(milliseconds: 220);
  static const _duracaoFechar = Duration(milliseconds: 420);

  bool _mostrar = false;

  @override
  void initState() {
    super.initState();
    if (widget.aberto) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _mostrar = true);
      });
    }
  }

  @override
  void didUpdateWidget(covariant _PainelChatAnimado oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.aberto != oldWidget.aberto) {
      setState(() => _mostrar = widget.aberto);
    }
  }

  @override
  Widget build(BuildContext context) {
    final duracao = _mostrar ? _duracaoAbrir : _duracaoFechar;
    return AnimatedSlide(
      offset: _mostrar ? Offset.zero : const Offset(1, 0),
      duration: duracao,
      curve: Curves.easeOutCubic,
      onEnd: () {
        if (!widget.aberto) widget.onFechado();
      },
      child: AnimatedOpacity(
        opacity: _mostrar ? 1 : 0,
        duration: duracao,
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// Seções do layout mobile. [indice] é o valor guardado no estado da página
/// (e o que o `?aba=` escolhe); a ORDEM desta enum é a ordem na barra.
enum _SecaoMobile {
  aposta(2, 'Aposta', Icons.attach_money),
  participantes(0, 'Participantes', Icons.people_outline),
  chat(1, 'Chat', Icons.chat_bubble_outline);

  final int indice;
  final String rotulo;
  final IconData icone;

  const _SecaoMobile(this.indice, this.rotulo, this.icone);

  ItemSecaoMobile get item =>
      ItemSecaoMobile(indice: indice, rotulo: rotulo, icone: icone);
}
