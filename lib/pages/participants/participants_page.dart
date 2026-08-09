import 'dart:async';
import 'package:bolao_bolado/components/shared/ficharios.dart';
import 'package:bolao_bolado/components/shared/header_card.dart';
import 'package:bolao_bolado/components/shell/default_layout.dart';
import 'package:bolao_bolado/components/shell/drawer.dart';
import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/core/responsive.dart';
import 'package:bolao_bolado/dev/simulador_apostas.dart';
import 'package:bolao_bolado/pages/participants/participants_painel.dart';
import 'package:bolao_bolado/pages/participants/participants_simulacao_dialog.dart';
import 'package:bolao_bolado/pages/participants/participants_skeletons.dart';
import 'package:bolao_bolado/router/app_router.dart';
import 'package:bolao_bolado/services/authentication/auth_service.dart';
import 'package:bolao_bolado/services/bet/bet_service.dart';
import 'package:bolao_bolado/widgets/chat_sala.dart';
import 'package:bolao_bolado/widgets/minha_aposta_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class Participants extends StatefulWidget {
  // Aba a abrir no layout mobile, vinda da query string (?aba=aposta|chat).
  // Usada pelo Drawer para navegar direto pra seção certa.
  final String? abaInicial;

  const Participants({super.key, this.abaInicial});

  @override
  State<Participants> createState() => _ParticipantsState();
}

class _ParticipantsState extends State<Participants> {
  List<Map<String, dynamic>> _rowsData = [];
  bool _loading = true;
  String? _salaId;
  bool _isAdmin = false;
  String? _sorteio;
  DateTime? _dataSorteio;
  double _premioSala = 0;

  StreamSubscription<List<Map<String, Object?>>>? _betsSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _salaSubscription;
  final SimuladorApostas _simulador = SimuladorApostas();

  // Aba ativa no mobile: 0 = Participantes, 1 = Chat, 2 = Minha Aposta
  late int _abaAtiva = switch (widget.abaInicial) {
    'aposta' => 2,
    'chat' => 1,
    _ => 0,
  };

  // Controla se o chat está sobreposto ao grid no desktop (dispara a
  // animação de abrir/fechar).
  bool _chatAbertoDesktop = false;

  // Mantém o ChatSala montado durante a animação de fechamento; some da
  // árvore só quando a animação termina (evita "sumir" abrupto).
  bool _chatVisivelDesktop = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant Participants oldWidget) {
    super.didUpdateWidget(oldWidget);
    // GoRouter reusa este State ao navegar de /participantes?aba=X pra
    // /participantes?aba=Y (mesma rota, query diferente): sem isso, clicar
    // em outro item do Drawer estando já na tela não troca de aba.
    if (widget.abaInicial != oldWidget.abaInicial) {
      setState(() {
        _abaAtiva = switch (widget.abaInicial) {
          'aposta' => 2,
          'chat' => 1,
          _ => 0,
        };
      });
    }
  }

  @override
  void dispose() {
    _betsSubscription?.cancel();
    _salaSubscription?.cancel();
    _simulador.parar();
    super.dispose();
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
            _rowsData = dataBets;
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
    // horizontalmente, usa o layout empilhado em abas (mesmo do mobile).
    final isCompact = Responsive.isCompact(context);
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isLoggedIn = AuthService().isLoggedIn;

    return DefaultLayout(
      drawer: AppDrawer(onAvatarChanged: (_) => _load()),
      esticarLarguraCompact: true,
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
    // Altura igual à do card interno de MinhaApostaCard (height: 486), para
    // os dois cards ficarem com a mesma altura total lado a lado no
    // desktop — a altura vai direto pro CustomCard(isChild:true) do
    // HeaderCard, no mesmo ponto da árvore que MinhaApostaCard usa.
    const double chatHeight = 486;

    return GestureDetector(
      // Fecha o chat clicando em qualquer lugar do card pai (cabeçalho,
      // estatísticas, tabela) fora do próprio painel do chat — que tem seu
      // próprio GestureDetector opaco para não propagar o clique até aqui.
      behavior: HitTestBehavior.translucent,
      onTap: _chatAbertoDesktop
          ? () => setState(() => _chatAbertoDesktop = false)
          : null,
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
    setState(() {
      _chatAbertoDesktop = !_chatAbertoDesktop;
      if (_chatAbertoDesktop) _chatVisivelDesktop = true;
    });
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

  Widget _layoutMobile(String? currentUid) {
    final isLoggedInDeVerdade =
        FirebaseAuth.instance.currentUser?.isAnonymous == false;

    // Índices fixos (0=Participantes, 1=Chat, 2=Aposta) por compatibilidade
    // com o resto do estado _abaAtiva da página; a ORDEM visual na fileira
    // é dada pela ordem desta lista. Também decide quais cantos da folha
    // ativa ficam retos (primeira aba da fileira → canto esquerdo reto;
    // última → canto direito reto).
    // Sem corAtiva explícita: o Fichario atribui a cor automaticamente pela
    // posição na fileira (1ª aba verde, 2ª azul, 3ª dourado, ciclando),
    // então a sequência de cores fica consistente mesmo se abas forem
    // adicionadas/removidas depois.
    final abas = [
      if (isLoggedInDeVerdade)
        const AbaFichario(
          texto: 'Minha Aposta',
          icone: Icons.attach_money,
          indice: 2,
        ),
      const AbaFichario(
        texto: 'Participantes',
        icone: Icons.people_outline,
        indice: 0,
      ),
      const AbaFichario(
        texto: 'Chat',
        icone: Icons.chat_bubble_outline,
        indice: 1,
      ),
    ];

    return Fichario(
      abaAtiva: _abaAtiva,
      onSelecionar: (i) => setState(() => _abaAtiva = i),
      abas: abas,
      semMargem: true,
      esticarAltura: true,
      // LayoutBuilder mede a altura real que o Expanded do Fichario cedeu
      // pra folha ativa — evita recalcular manualmente o chrome (pill,
      // paddings dos cards etc) e garante que os widgets internos (que
      // esperam uma altura fixa em pixels) preencham exatamente o espaço
      // certo, sem overflow nem sobra.
      builder: (context, aba) => LayoutBuilder(
        builder: (context, constraints) => _conteudoAba(
          aba: aba,
          currentUid: currentUid,
          isLoggedInDeVerdade: isLoggedInDeVerdade,
          alturaDisponivel: constraints.maxHeight,
        ),
      ),
    );
  }

  // Conteúdo de UMA aba do fichário (Minha Aposta, Participantes ou Chat).
  // O Fichario agora constrói as três de uma vez e mantém as inativas
  // "vivas" atrás de um Offstage (ver ficharios.dart) — por isso este método
  // recebe [aba] em vez de olhar só pra _abaAtiva: precisa devolver o
  // widget de qualquer uma das três, não só da selecionada no momento.
  Widget _conteudoAba({
    required AbaFichario aba,
    required String? currentUid,
    required bool isLoggedInDeVerdade,
    required double alturaDisponivel,
  }) {
    final alturaConteudo = alturaDisponivel;
    if (aba.indice == 2 && isLoggedInDeVerdade) {
      return MinhaApostaCard(
        onApostaConfirmada: () => setState(() => _abaAtiva = 0),
        mobile: true,
        alturaMobile: alturaConteudo,
        mostrarCabecalho: false,
        apenasConteudo: true,
      );
    }
    if (aba.indice == 0) {
      return PainelParticipantes(
        currentUid: currentUid,
        loading: _loading,
        rowsData: _rowsData,
        isAdmin: _isAdmin,
        sorteio: _sorteio,
        dataSorteio: _dataSorteio,
        premioSala: _premioSala,
        onEditarSala: _botaoEditarSala,
        onSimularApostas: _isAdmin ? _abrirDialogoSimulacao : null,
        mobile: true,
        alturaMobile: alturaConteudo,
        mostrarCabecalho: false,
        apenasConteudo: true,
      );
    }
    if (_salaId != null) {
      // Sem nenhum CustomCard envolvendo o chat: o Fichario já monta o
      // cartão branco ao redor, e o ChatSala desenha sua própria borda/
      // fundo, preenchendo todo o espaço disponível da folha ativa.
      return SizedBox(
        // Ocupa o restante da altura visível, medida a partir do
        // LayoutBuilder em _layoutMobile.
        height: alturaConteudo,
        child: ChatSala(
          salaId: _salaId!,
          mostrarCabecalho: false,
          // A folha do Fichario já é o cartão: sem isso o chat desenharia uma
          // segunda borda por dentro dela.
          compacto: true,
        ),
      );
    }
    return const SizedBox.shrink();
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
