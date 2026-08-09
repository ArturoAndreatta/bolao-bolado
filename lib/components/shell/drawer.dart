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
    _carregarAvatar();
    _carregarIsAdmin();
  }

  Future<void> _carregarAvatar() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return;
    // Cor e emoji leem o mesmo doc `usuarios/{uid}` e não dependem um do
    // outro: em série eram dois round-trips para abrir o menu.
    final (cor, emoji) = await (
      AvatarService.buscarCor(user.uid),
      AvatarService.buscarEmoji(user.uid),
    ).wait;
    if (mounted) {
      setState(() {
        _corAvatarAtual = cor;
        _emojiAvatarAtual = emoji;
      });
    }
  }

  Future<void> _carregarIsAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return;
    final isAdmin = await AuthService().isAdmin(user.uid);
    if (!mounted) return;
    setState(() {
      _isAdmin = isAdmin;
      if (isAdmin) _apostasPendentesStream ??= streamApostasPendentes();
    });
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
                        router.go(AppRoutes.home);
                        await AuthService().logout();
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

/// Seletor de tema no rodapé do drawer: Claro / Escuro / Sistema.
///
/// Três opções, e não um interruptor de dois estados, porque "seguir o
/// sistema" é um estado próprio — quem tem o celular agendado para escurecer
/// à noite quer que o app acompanhe, e um toggle simples obrigaria a escolher
/// manualmente duas vezes por dia. É também o padrão de fábrica do app.
class _AlternadorTema extends StatelessWidget {
  const _AlternadorTema();

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: temaModoGlobal,
      builder: (context, modo, _) {
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
              // drawer (que é escuro nos DOIS temas), não da paleta de
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
                      icone: Icons.light_mode_outlined,
                      rotulo: 'Claro',
                      ativo: modo == ThemeMode.light,
                      onTap: () => salvarTema(ThemeMode.light),
                    ),
                    _OpcaoTema(
                      icone: Icons.dark_mode_outlined,
                      rotulo: 'Escuro',
                      ativo: modo == ThemeMode.dark,
                      onTap: () => salvarTema(ThemeMode.dark),
                    ),
                    _OpcaoTema(
                      icone: Icons.brightness_auto_outlined,
                      rotulo: 'Auto',
                      ativo: modo == ThemeMode.system,
                      onTap: () => salvarTema(ThemeMode.system),
                    ),
                  ],
                ),
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
    // Sobre o verde-água claro do escuro, branco dá só 2.18:1 — o rótulo
    // ativo lá é escuro (8.6:1 contra o mesmo fundo). No claro o bloco ativo
    // é o azul, sobre o qual branco continua sendo o certo.
    final cor = ativo
        ? (cores.escuro ? cores.drawerFundo : Colors.white)
        : cores.textoFraco;

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
              // Verde-água no escuro em vez do azul de ação: dentro do drawer
              // de feltro, um bloco azul era a única coisa fria da tela. No
              // claro o azul continua, que é a cor de seleção do app lá.
              color: ativo
                  ? (cores.escuro ? cores.verdeAgua : cores.azul)
                  : Colors.transparent,
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
