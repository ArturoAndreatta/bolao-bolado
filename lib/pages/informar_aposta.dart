import 'package:bolao_bolado/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// "Minha Aposta" foi unificada à tela de Participantes (AppRoutes.participants).
// Esta rota é mantida apenas para não quebrar links/drawer existentes.
class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go(AppRoutes.participants);
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
