import 'dart:async';

import 'package:bolao_bolado/router/app_router.dart';
import 'package:bolao_bolado/services/authentication/auth_service.dart';
import 'package:bolao_bolado/services/avatar/avatar_service.dart';
import 'package:bolao_bolado/services/bet/bet_service.dart';
import 'package:bolao_bolado/components/shared/avatar_emoji.dart';
import 'package:bolao_bolado/components/shell/avatar_picker_dialog.dart';
import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/core/app_radii.dart';
import 'package:bolao_bolado/core/tema_controller.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppDrawer extends StatefulWidget {
  final void Function(Color novaCor)? onAvatarChanged;

  const AppDrawer({super.key, this.onAvatarChanged});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  Color? _corAvatarAtual;
  String? _emojiAvatarAtual;
  bool _isAdmin = false;

  // Instanciada uma única vez: se streamApostasPendentes() fosse chamada
  // direto no build(), cada setState() (ex: ao carregar avatar/isAdmin)
  // recriaria a Query e o badge piscaria durante a sincronização.
  //
  // Só é aberta depois de confirmar que o usuário é admin. Como campo
  // inicializado direto, ela abria um listener collectionGroup sobre as
  // apostas de TODAS as salas para qualquer pessoa que tocasse no menu uma
  // vez — inclusive visitante anônimo, que nem vê o badge.
  Stream<QuerySnapshot<Map<String, dynamic>>>? _apostasPendentesStream;

  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return;

    // O menu é DESMONTADO ao fechar, então este initState roda a cada
    // abertura. Enquanto ele dependia de um `await` para saber o `isAdmin`, o
    // drawer abria com os itens de participante e completava com Cadastrar
    // Sala / Consultar Salas / Painel ADM um instante depois — o pisca que
    // parecia recarregamento (e era: uma leitura cobrada por toque no menu).
    //
    // Com o perfil memoizado por sessão, da segunda abertura em diante o valor
    // já está aqui e é aplicado ANTES do primeiro frame. Na primeira ele
    // costuma vir pronto também, porque o main.dart adianta essa leitura logo
    // depois do login.
    final conhecido = AuthService.perfilConhecido(user.uid);
    if (conhecido != null) {
      _aplicarPerfil(user.uid, conhecido, primeiroFrame: true);
      return;
    }
    _carregarPerfil(user.uid);
  }

  /// Cor do avatar, emoji e `isAdmin` numa LEITURA só.
  ///
  /// Eram três chamadas separadas (`buscarCor`, `buscarEmoji`, `isAdmin`) e as
  /// três liam o mesmo documento `usuarios/{uid}` — três leituras cobradas
  /// para abrir o menu. Estavam em paralelo, o que resolvia a latência mas não
  /// o custo. Agora o documento é lido uma vez, por sessão, e os três valores
  /// saem dele (ver [AuthService.perfil]).
  Future<void> _carregarPerfil(String uid) async {
    final dados = await AuthService().perfil(uid);
    if (!mounted) return;
    _aplicarPerfil(uid, dados, primeiroFrame: false);
  }

  /// [primeiroFrame] distingue o caminho síncrono (initState, antes de existir
  /// árvore para reconstruir) do assíncrono, que precisa de `setState`.
  void _aplicarPerfil(
    String uid,
    Map<String, dynamic>? dados, {
    required bool primeiroFrame,
  }) {
    final avatar = AvatarService.avatarDeDados(dados);
    final isAdmin = dados?['isAdmin'] == true;

    void aplicar() {
      _corAvatarAtual = avatar.cor;
      _emojiAvatarAtual = avatar.emoji;
      _isAdmin = isAdmin;
      if (isAdmin) _apostasPendentesStream ??= streamApostasPendentes();
    }

    if (primeiroFrame) {
      aplicar();
    } else {
      setState(aplicar);
    }

    // Conta antiga, sem cor/emoji gravados: persiste o que foi sorteado agora,
    // fora do caminho da abertura do menu (a UI já está pintada com o valor).
    // Só faz sentido com documento existente — anônimo nem chega aqui.
    if (avatar.faltava && dados != null) {
      // Guarda no cache o que acabou de ser sorteado: sem isto, a próxima
      // abertura do menu chamaria `avatarDeDados` de novo sobre o mesmo
      // documento sem cor e sortearia OUTRA — o avatar mudaria sozinho a cada
      // toque no hambúrguer até a escrita chegar de volta.
      AuthService.mesclarNoCache(uid, {
        // As mesmas condições de persistirAvatar: só entra no cache o que de
        // fato vai para o documento.
        if (dados['avatarColor'] == null && dados['isAdmin'] != true)
          'avatarColor': avatar.cor.toARGB32(),
        if ((dados['avatarEmoji'] as String?)?.isNotEmpty != true)
          'avatarEmoji': avatar.emoji,
      });
      unawaited(
        AvatarService.persistirAvatar(
          uid,
          dados: dados,
          cor: avatar.cor,
          emoji: avatar.emoji,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    final user = FirebaseAuth.instance.currentUser;
    final isLoggedIn = user != null && !user.isAnonymous;
    final nome = user?.displayName ?? 'Visitante';
    final email = user?.email ?? 'Acesse sua conta';
    final inicial = nome.isNotEmpty ? nome[0].toUpperCase() : '?';

    return Drawer(
      width: 280,
      backgroundColor: cores.drawerFundo,
      child: SafeArea(
        child: Column(
          children: [
            // Header do usuário
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: cores.drawerBorda, width: 1),
                ),
              ),
              child: Row(
                children: [
                  // Avatar clicável
                  MouseRegion(
                    cursor: isLoggedIn
                        ? SystemMouseCursors.click
                        : SystemMouseCursors.basic,
                    child: GestureDetector(
                      onTap: isLoggedIn
                          ? () async {
                              if (_corAvatarAtual == null) return;
                              await mostrarEscolhaAvatar(
                                context,
                                corAtual: _corAvatarAtual!,
                                emojiAtual:
                                    _emojiAvatarAtual ?? kEmojiAvatarPadrao,
                                isAdmin: _isAdmin,
                                onSelecionado: (novoEmoji, novaCor) {
                                  setState(() {
                                    _emojiAvatarAtual = novoEmoji;
                                    _corAvatarAtual = novaCor;
                                  });
                                  // O perfil fica em cache pela sessão: sem
                                  // atualizá-lo aqui, a próxima abertura do
                                  // menu voltaria a mostrar o avatar antigo.
                                  AuthService.mesclarNoCache(user.uid, {
                                    'avatarColor': novaCor.toARGB32(),
                                    'avatarEmoji': novoEmoji,
                                  });
                                  widget.onAvatarChanged?.call(novaCor);
                                },
                              );
                            }
                          : null,
                      child: Stack(
                        children: [
                          AvatarEmoji(
                            tamanho: 52,
                            cor: _corAvatarAtual ?? cores.azul,
                            emoji: _emojiAvatarAtual ?? inicial,
                            corBorda: cores.azul,
                          ),
                          if (isLoggedIn)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: cores.azul,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: cores.drawerFundo,
                                    width: 1.5,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  size: 10,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nome,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email,
                          style: TextStyle(
                            color: cores.textoFraco,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  if (isLoggedIn) ...[
                    _DrawerItem(
                      icon: Icons.how_to_vote_outlined,
                      label: 'Minha Aposta',
                      onTap: () {
                        final router = GoRouter.of(context);
                        Navigator.of(context).pop();
                        router.go(
                          Uri(
                            path: AppRoutes.participants,
                            queryParameters: {'aba': 'aposta'},
                          ).toString(),
                        );
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.people_outline,
                      label: 'Participantes',
                      onTap: () {
                        final router = GoRouter.of(context);
                        Navigator.of(context).pop();
                        router.go(AppRoutes.participants);
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.chat_bubble_outline,
                      label: 'Chat',
                      onTap: () {
                        final router = GoRouter.of(context);
                        Navigator.of(context).pop();
                        router.go(
                          Uri(
                            path: AppRoutes.participants,
                            queryParameters: {'aba': 'chat'},
                          ).toString(),
                        );
                      },
                    ),
                    if (_isAdmin) ...[
                      _DrawerItem(
                        icon: Icons.add_business_outlined,
                        label: 'Cadastrar Sala',
                        onTap: () {
                          final router = GoRouter.of(context);
                          Navigator.of(context).pop();
                          router.go(AppRoutes.cadastrarSala);
                        },
                      ),
                      _DrawerItem(
                        icon: Icons.search,
                        label: 'Consultar Salas',
                        onTap: () {
                          final router = GoRouter.of(context);
                          Navigator.of(context).pop();
                          router.go(AppRoutes.consultarSalas);
                        },
                      ),
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        // Null enquanto o isAdmin ainda não voltou: o
                        // StreamBuilder aceita stream nula e só mostra o
                        // item sem badge até a stream existir.
                        stream: _apostasPendentesStream,
                        builder: (context, snapshot) {
                          final pendentes = snapshot.data?.docs.length ?? 0;
                          return _DrawerItem(
                            icon: Icons.admin_panel_settings_outlined,
                            label: 'Painel ADM',
                            badgeCount: pendentes,
                            onTap: () {
                              final router = GoRouter.of(context);
                              Navigator.of(context).pop();
                              router.go(AppRoutes.painelAdmin);
                            },
                          );
                        },
                      ),
                    ],
                    const _DrawerDivider(),
                  ],
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: Column(
                children: [
                  // Fica no rodapé do menu (e não numa tela de ajustes): o
                  // drawer é o único lugar alcançável de qualquer tela do app,
                  // e trocar de tema é algo que se faz pelo ambiente do
                  // momento — não vale esconder atrás de mais navegação.
                  const _AlternadorTema(),
                  const _DrawerDivider(),
                  const SizedBox(height: 4),
                  if (isLoggedIn)
                    _DrawerItem(
                      icon: Icons.logout,
                      label: 'Sair',
                      isDestructive: true,
                      onTap: () async {
                        // Captura o GoRouter antes de fechar o drawer: o
                        // context do item do drawer é desmontado junto com
                        // o Drawer, então usá-lo depois do pop (mesmo que
                        // "mounted") pode não navegar mais.
                        final router = GoRouter.of(context);
                        Navigator.of(context).pop();
                        // Navegar SÓ depois do logout: o redirect do router lê
                        // o usuário atual, e enquanto ele ainda estiver logado
                        // `/home` é rota guest-only — ir pra lá antes rebatia
                        // de volta pra Participantes/Painel ADM, e o
                        // GoRouter não reavalia o redirect quando o Auth muda.
                        await AuthService().logout();
                        router.go(AppRoutes.home);
                      },
                    )
                  else
                    _DrawerItem(
                      icon: Icons.login,
                      label: 'Entrar',
                      onTap: () {
                        final router = GoRouter.of(context);
                        Navigator.of(context).pop();
                        router.go(AppRoutes.signup);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Seletor de tema no rodapé do drawer: Claro / Escuro / Mais.
///
/// As duas primeiras respondem "quão claro"; "Mais" abre, ali mesmo no
/// drawer, a lista de temas únicos (Cassino, Meia-noite, Cyber, Papel,
/// Bilhete) e o "Auto".
///
/// "Auto" saiu do pill e foi para dentro da lista — e não por ser menos
/// importante (continua sendo o padrão de fábrica), mas porque com oito temas
/// no total o pill precisa carregar só a decisão do dia a dia. Quem configura
/// "seguir o sistema" faz isso uma vez; quem escurece a tela faz toda noite.
///
/// A lista abre embaixo do pill e não num diálogo: o rodapé cresce e empurra
/// o pill para cima, encolhendo a lista de navegação acima dele (que rola).
/// Assim a pessoa vê a prévia de cada tema sem perder o drawer de vista, e
/// cada toque aplica o tema no app inteiro, por trás.
///
/// O botão "Mais" fica ACESO quando o tema atual é um dos de dentro: sem
/// isso, quem estivesse no Cassino veria os três botões apagados e o pill
/// pareceria quebrado.
class _AlternadorTema extends StatefulWidget {
  const _AlternadorTema();

  @override
  State<_AlternadorTema> createState() => _AlternadorTemaState();
}

class _AlternadorTemaState extends State<_AlternadorTema>
    with SingleTickerProviderStateMixin {
  // Controller explícito em vez de AnimatedSize: abrir e fechar têm curvas
  // diferentes (desacelera chegando, acelera saindo), e com o valor em mãos
  // dá para nem montar a lista enquanto ela está fechada.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
    reverseDuration: const Duration(milliseconds: 220),
  );
  late final Animation<double> _abertura = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  bool get _aberto =>
      _controller.status == AnimationStatus.forward ||
      _controller.status == AnimationStatus.completed;

  void _alternar() {
    setState(() {
      if (_aberto) {
        _controller.reverse();
      } else {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);

    return ValueListenableBuilder<TemaApp>(
      valueListenable: temaGlobal,
      builder: (context, tema, _) {
        final noMais = tema != TemaApp.claro && tema != TemaApp.escuro;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.palette_outlined,
                    size: 18,
                    color: cores.drawerTexto,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Tema',
                    style: TextStyle(
                      color: cores.drawerTexto,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Pill com as três opções lado a lado. As cores aqui saem do
              // drawer (que é escuro em todos os temas), não da paleta de
              // superfícies — por isso o branco/alpha em vez de cores.card.
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: AppRadii.circularSmd,
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: [
                    _OpcaoTema(
                      icone: TemaApp.claro.icone,
                      rotulo: TemaApp.claro.rotulo,
                      ativo: tema == TemaApp.claro,
                      onTap: () => salvarTema(TemaApp.claro),
                    ),
                    _OpcaoTema(
                      icone: TemaApp.escuro.icone,
                      rotulo: TemaApp.escuro.rotulo,
                      ativo: tema == TemaApp.escuro,
                      onTap: () => salvarTema(TemaApp.escuro),
                    ),
                    _OpcaoTema(
                      // Aberta, a lista já mostra qual tema vale, e o botão
                      // passa a dizer como fechá-la. Fechada, quando um tema
                      // de dentro está ativo, o botão mostra o ícone DELE em
                      // vez do genérico: o pill vira o indicador do que está
                      // valendo.
                      icone: _aberto
                          ? Icons.expand_more
                          : noMais
                          ? tema.icone
                          : Icons.more_horiz,
                      rotulo: _aberto ? 'Fechar' : 'Mais',
                      ativo: noMais,
                      onTap: _alternar,
                    ),
                  ],
                ),
              ),
              AnimatedBuilder(
                animation: _abertura,
                // A lista é montada uma vez por abertura e só a altura e a
                // opacidade mudam a cada quadro. Fechada, ela nem existe:
                // nada a mais para medir no layout do drawer.
                child: _ListaTemas(atual: tema),
                builder: (context, lista) {
                  if (_controller.isDismissed) return const SizedBox.shrink();
                  return ClipRect(
                    child: Align(
                      alignment: Alignment.topCenter,
                      heightFactor: _abertura.value,
                      child: Opacity(
                        // A opacidade corre na frente da altura: os itens
                        // já estão legíveis quando terminam de aparecer, e
                        // somem antes de a moldura acabar de fechar.
                        opacity: (_abertura.value * 1.5).clamp(0.0, 1.0),
                        child: lista,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OpcaoTema extends StatelessWidget {
  final IconData icone;
  final String rotulo;
  final bool ativo;
  final VoidCallback onTap;

  const _OpcaoTema({
    required this.icone,
    required this.rotulo,
    required this.ativo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    // O bloco ativo é pintado com a cor de ação do tema, e o rótulo por cima
    // usa o par de contraste que essa cor já carrega — o mesmo do CTA
    // principal do app. Resolver por `escuro ? a : b` aqui daria errado nos
    // temas únicos, cujas ações primárias vão de ouro a magenta.
    final cor = ativo ? cores.textoSobreAcao : cores.textoFraco;

    return Expanded(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: ativo ? cores.acaoPrimaria : Colors.transparent,
              borderRadius: AppRadii.circularSm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icone, size: 17, color: cor),
                const SizedBox(height: 3),
                Text(
                  rotulo,
                  style: TextStyle(
                    color: cor,
                    fontSize: 10.5,
                    fontWeight: ativo ? FontWeight.w700 : FontWeight.w500,
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

/// Lista de "Auto" + temas únicos, embaixo do pill.
///
/// A prévia não é enfeite: "Cassino" e "Meia-noite" não dizem nada sobre a
/// cor da tela, e trocar o tema inteiro só para descobrir como ele é seria um
/// vaivém. As três bolinhas mostram fundo, superfície e cor de ação — que é o
/// que muda de verdade entre eles.
class _ListaTemas extends StatelessWidget {
  final TemaApp atual;

  const _ListaTemas({required this.atual});

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);

    // RepaintBoundary: enquanto a altura anima, só o recorte muda; o
    // conteúdo vira uma camada pronta em vez de ser repintado por quadro.
    return RepaintBoundary(
      child: ConstrainedBox(
        // Em tela baixa a lista inteira não cabe junto do resto do drawer;
        // passado o teto ela rola por dentro em vez de estourar o rodapé.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.45,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ItemTema(tema: TemaApp.seguirSistema, atual: atual),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
                child: Text(
                  'TEMAS ÚNICOS',
                  style: TextStyle(
                    color: cores.textoFraco,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              for (final tema in TemaApp.unicos)
                _ItemTema(tema: tema, atual: atual),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemTema extends StatelessWidget {
  final TemaApp tema;
  final TemaApp atual;

  const _ItemTema({required this.tema, required this.atual});

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    final ativo = tema == atual;
    // A prévia de "Auto" mostra a paleta que ele resolveria AGORA — é a
    // informação útil ali, já que o item não tem cor própria.
    final previa = paletaDe(tema, MediaQuery.platformBrightnessOf(context));

    // Mesma linguagem do pill logo acima: o drawer é escuro em todos os
    // temas, então o destaque é branco translúcido com borda na cor de ação,
    // e não os fundo*/borda* calibrados para cima do card.
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadii.circularSm,
          onTap: () => salvarTema(tema),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: ativo
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: AppRadii.circularSm,
              border: Border.all(
                color: ativo ? cores.acaoPrimaria : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                _PreviaPaleta(cores: previa, borda: cores.drawerBorda),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tema.rotulo,
                    style: TextStyle(
                      color: ativo ? Colors.white : cores.drawerTexto,
                      fontSize: 13,
                      fontWeight: ativo ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                // O ícone do tema fica SEMPRE visível — ele é parte da
                // identidade do item, e trocá-lo por um check no selecionado
                // apagava justamente a linha que o usuário acabou de escolher.
                Icon(
                  tema.icone,
                  size: 17,
                  color: ativo ? cores.acaoPrimaria : cores.textoFraco,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Três discos sobrepostos com o fundo, a superfície e a ação do tema.
class _PreviaPaleta extends StatelessWidget {
  final AppCores cores;
  final Color borda;

  const _PreviaPaleta({required this.cores, required this.borda});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 22,
      child: Stack(
        children: [
          _disco(cores.gradienteFundo.last, 0),
          _disco(cores.card, 8),
          _disco(cores.acaoPrimaria, 16),
        ],
      ),
    );
  }

  Widget _disco(Color cor, double esquerda) => Positioned(
    left: esquerda,
    top: 0,
    child: Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: cor,
        shape: BoxShape.circle,
        // Borda na cor do drawer (não do tema previsto): é o que separa os
        // discos entre si e do fundo quando as cores são próximas.
        border: Border.all(color: borda, width: 1.5),
      ),
    ),
  );
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;
  final int badgeCount;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    final color = isDestructive ? cores.vermelho : cores.drawerTexto;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.circularSmd,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (badgeCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: cores.vermelho,
                    borderRadius: AppRadii.circularPill,
                  ),
                  child: Text(
                    badgeCount > 99 ? '99+' : '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerDivider extends StatelessWidget {
  const _DrawerDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      color: AppCores.de(context).drawerBorda,
      height: 16,
      thickness: 1,
    );
  }
}
