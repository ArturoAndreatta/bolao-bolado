import 'package:bolao_bolado/pages/home_page.dart';
import 'package:bolao_bolado/pages/informar_aposta.dart';
import 'package:bolao_bolado/pages/participants.dart';
import 'package:bolao_bolado/pages/consultar_salas.dart';
import 'package:bolao_bolado/services/authentication/auth_service.dart';
import 'package:bolao_bolado/services/avatar/avatar_service.dart';
import 'package:bolao_bolado/components/shell/avatar_picker_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  String? _avatarAtual;

  @override
  void initState() {
    super.initState();
    _carregarAvatar();
  }

  Future<void> _carregarAvatar() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final avatar = await AvatarService.buscarAvatar(uid);
    if (mounted) setState(() => _avatarAtual = avatar);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isLoggedIn = user != null && !user.isAnonymous;
    final nome = user?.displayName ?? 'Visitante';
    final email = user?.email ?? 'Acesse sua conta';
    final inicial = nome.isNotEmpty ? nome[0].toUpperCase() : '?';

    return Drawer(
      width: 280,
      backgroundColor: const Color(0xFF1F2937),
      child: SafeArea(
        child: Column(
          children: [
            // Header do usuário
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFF374151), width: 1),
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
                              if (_avatarAtual == null) return;
                              await mostrarEscolhaAvatar(
                                context,
                                avatarAtual: _avatarAtual!,
                                onSelecionado: (novoAvatar) {
                                  setState(() => _avatarAtual = novoAvatar);
                                },
                              );
                            }
                          : null,
                      child: Stack(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF487DE5),
                                width: 2,
                              ),
                            ),
                            child: ClipOval(
                              child: _avatarAtual != null
                                  ? Image.asset(
                                      _avatarAtual!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _avatarFallback(inicial),
                                    )
                                  : _avatarFallback(inicial),
                            ),
                          ),
                          if (isLoggedIn)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF487DE5),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF1F2937),
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
                          style: const TextStyle(
                            color: Color(0xFF9CA3AF),
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
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          PageRouteBuilder(
                            transitionDuration: Duration.zero,
                            reverseTransitionDuration: Duration.zero,
                            pageBuilder: (_, _, _) => const Login(),
                          ),
                        );
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.people_outline,
                      label: 'Participantes',
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          PageRouteBuilder(
                            transitionDuration: Duration.zero,
                            reverseTransitionDuration: Duration.zero,
                            pageBuilder: (_, _, _) => const Participants(),
                          ),
                        );
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.search,
                      label: 'Consultar Salas',
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          PageRouteBuilder(
                            transitionDuration: Duration.zero,
                            reverseTransitionDuration: Duration.zero,
                            pageBuilder: (_, _, _) => const ConsultarSalas(),
                          ),
                        );
                      },
                    ),
                    const _DrawerDivider(),
                  ],
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: Column(
                children: [
                  const _DrawerDivider(),
                  const SizedBox(height: 4),
                  if (isLoggedIn)
                    _DrawerItem(
                      icon: Icons.logout,
                      label: 'Sair',
                      isDestructive: true,
                      onTap: () async {
                        Navigator.of(context).pop();
                        await AuthService().logout();
                        if (context.mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            PageRouteBuilder(
                              transitionDuration: Duration.zero,
                              reverseTransitionDuration: Duration.zero,
                              pageBuilder: (_, _, _) => const HomePage(),
                            ),
                            (route) => false,
                          );
                        }
                      },
                    )
                  else
                    _DrawerItem(
                      icon: Icons.login,
                      label: 'Entrar',
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          PageRouteBuilder(
                            transitionDuration: Duration.zero,
                            reverseTransitionDuration: Duration.zero,
                            pageBuilder: (_, _, _) => const HomePage(),
                          ),
                        );
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

  Widget _avatarFallback(String inicial) {
    return Container(
      color: const Color(0xFF487DE5),
      child: Center(
        child: Text(
          inicial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
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

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? const Color(0xFFEF4444)
        : const Color(0xFFD1D5DB);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
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
    return const Divider(color: Color(0xFF374151), height: 16, thickness: 1);
  }
}
