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
    _carregarPerfil();
  }

  /// Cor do avatar, emoji e `isAdmin` numa LEITURA só.
  ///
  /// Eram três chamadas separadas (`buscarCor`, `buscarEmoji`, `isAdmin`) e as
  /// três liam o mesmo documento `usuarios/{uid}` — três leituras cobradas
  /// para abrir o menu. Estavam em paralelo, o que resolvia a latência mas não
  /// o custo. Agora o documento é lido uma vez e os três valores saem dele.
  Future<void> _carregarPerfil() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return;

    final dados = await AuthService().getDadosUsuario(user.uid);
    if (!mounted) return;

    final avatar = AvatarService.avatarDeDados(dados);
    final isAdmin = dados?['isAdmin'] == true;

    setState(() {
      _corAvatarAtual = avatar.cor;
      _emojiAvatarAtual = avatar.emoji;
      _isAdmin = isAdmin;
      if (isAdmin) _apostasPendentesStream ??= streamApostasPendentes();
    });

    // Conta antiga, sem cor/emoji gravados: persiste o que foi sorteado agora,
    // fora do caminho da abertura do menu (a UI já está pintada com o valor).
    // Só faz sentido com documento existente — anônimo nem chega aqui.
    if (avatar.faltava && dados != null) {
      unawaited(
        AvatarService.persistirAvatar(
          user.uid,
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

/// Seletor de tema no rodapé do drawer: Claro / Escuro / Mais.
///
/// As duas primeiras respondem "quão claro"; "Mais" abre a lista de temas
/// únicos (Cassino, Meia-noite, Cyber, Papel, Bilhete) e o "Auto".
///
/// "Auto" saiu do pill e foi para dentro do diálogo — e não por ser menos
/// importante (continua sendo o padrão de fábrica), mas porque com oito temas
/// no total o pill precisa carregar só a decisão do dia a dia. Quem configura
/// "seguir o sistema" faz isso uma vez; quem escurece a tela faz toda noite.
///
/// O botão "Mais" fica ACESO quando o tema atual é um dos de dentro: sem
/// isso, quem estivesse no Cassino veria os três botões apagados e o pill
/// pareceria quebrado.
class _AlternadorTema extends StatelessWidget {
  const _AlternadorTema();

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
                      // Quando um tema de dentro está ativo, o botão mostra o
                      // ícone DELE em vez do genérico: o pill vira o indicador
                      // do que está valendo, sem precisar abrir o diálogo.
                      icone: noMais ? tema.icone : Icons.more_horiz,
                      rotulo: 'Mais',
                      ativo: noMais,
                      onTap: () => _abrirSeletorDeTemas(context),
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

/// Abre a lista de temas únicos + "Auto".
Future<void> _abrirSeletorDeTemas(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _DialogoTemas(),
  );
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

/// Lista dos temas únicos, com prévia da paleta de cada um.
///
/// A prévia não é enfeite: "Cassino" e "Meia-noite" não dizem nada sobre a
/// cor da tela, e trocar o tema inteiro só para descobrir como ele é seria um
/// vaivém. As três bolinhas mostram fundo, superfície e cor de ação — que é o
/// que muda de verdade entre eles.
class _DialogoTemas extends StatelessWidget {
  const _DialogoTemas();

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);

    return ValueListenableBuilder<TemaApp>(
      valueListenable: temaGlobal,
      builder: (context, atual, _) {
        return AlertDialog(
          backgroundColor: cores.card,
          shape: RoundedRectangleBorder(borderRadius: AppRadii.circularMd),
          title: const Text('Escolha um tema'),
          contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          content: SizedBox(
            width: 380,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ItemTema(tema: TemaApp.seguirSistema, atual: atual),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                    child: Row(
                      children: [
                        Text(
                          'TEMAS ÚNICOS',
                          style: TextStyle(
                            color: cores.textoFraco,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  for (final tema in TemaApp.unicos)
                    _ItemTema(tema: tema, atual: atual),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Fechar', style: TextStyle(color: cores.textoSuave)),
            ),
          ],
        );
      },
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadii.circularSmd,
        onTap: () => salvarTema(tema),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: ativo ? cores.fundoAzul : Colors.transparent,
            borderRadius: AppRadii.circularSmd,
            border: Border.all(
              color: ativo ? cores.bordaAzul : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              _PreviaPaleta(cores: previa),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tema.rotulo,
                      style: TextStyle(
                        color: cores.texto,
                        fontSize: 14,
                        fontWeight: ativo ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    if (tema.descricao != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          tema.descricao!,
                          style: TextStyle(
                            color: cores.textoSuave,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // O ícone do tema fica SEMPRE visível — ele é parte da
              // identidade do item, e trocá-lo por um check no selecionado
              // apagava justamente a linha que o usuário acabou de escolher.
              // A seleção já se lê no fundo tingido, na borda e no negrito do
              // rótulo; aqui basta a cor de destaque.
              Icon(
                tema.icone,
                size: 20,
                color: ativo ? cores.azul : cores.textoFraco,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Três discos sobrepostos com o fundo, a superfície e a ação do tema.
class _PreviaPaleta extends StatelessWidget {
  final AppCores cores;

  const _PreviaPaleta({required this.cores});

  @override
  Widget build(BuildContext context) {
    final bordaPrevia = AppCores.de(context).borda;

    return SizedBox(
      width: 46,
      height: 26,
      child: Stack(
        children: [
          _disco(cores.gradienteFundo.last, 0, bordaPrevia),
          _disco(cores.card, 10, bordaPrevia),
          _disco(cores.acaoPrimaria, 20, bordaPrevia),
        ],
      ),
    );
  }

  Widget _disco(Color cor, double esquerda, Color borda) => Positioned(
    left: esquerda,
    top: 0,
    child: Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: cor,
        shape: BoxShape.circle,
        // Borda na cor do tema ATIVO (não do previsto): é o que separa os
        // discos entre si e do fundo do diálogo quando as cores são próximas.
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
