import 'dart:async';
import 'dart:math';
import 'package:bolao_bolado/components/shell/default_layout.dart';
import 'package:bolao_bolado/components/shared/buttons.dart';
import 'package:bolao_bolado/components/shared/custom_card.dart';
import 'package:bolao_bolado/components/shell/drawer.dart';
import 'package:bolao_bolado/components/shared/branding/logo.dart';
import 'package:bolao_bolado/components/shared/constants/phrases.dart';
import 'package:bolao_bolado/router/app_router.dart';
import 'package:bolao_bolado/services/authentication/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with RouteAware {
  static const _fraseInterval = Duration(seconds: 5);

  late String frase;
  Timer? _fraseTimer;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _sortearFrase();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _stopTimer();
    super.dispose();
  }

  @override
  void didPush() => _startTimer();

  @override
  void didPopNext() => _startTimer();

  @override
  void didPushNext() => _stopTimer();

  @override
  void didPop() => _stopTimer();

  // Timer só roda enquanto a HomePage está visível (ver RouteAware abaixo),
  // evitando setState em segundo plano quando outra tela está no topo da pilha.
  void _startTimer() {
    _stopTimer();
    _fraseTimer = Timer.periodic(_fraseInterval, (_) => _sortearFrase());
  }

  void _stopTimer() {
    _fraseTimer?.cancel();
    _fraseTimer = null;
  }

  void _sortearFrase() {
    final random = Random();
    final novaFrase = phrases[random.nextInt(phrases.length)];
    if (!mounted) return;
    setState(() => frase = novaFrase);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultLayout(
      drawer: AppDrawer(),
      showLogo: false,
      child: Stack(
        children: [
          CustomCard(
            children: [
              Logo(),
              SizedBox(height: 20),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Bem-vindo',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: ' ao Bolão Bolado!',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 25),
                softWrap: true,
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: Text(
                  frase,
                  key: ValueKey(frase),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w500,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
              SizedBox(height: 20),
              PrimaryButton(
                text: _authService.isLoggedIn ? 'Minha Aposta' : 'Acessar',
                onTap: () {
                  context.go(
                    _authService.isLoggedIn
                        ? AppRoutes.informarAposta
                        : AppRoutes.signup,
                  );
                },
              ),
              const SizedBox(height: 20),
              SecondaryButton(
                text: 'Visualizar',
                onTap: () => context.go(AppRoutes.participants),
              ),
              SizedBox(height: 30),
            ],
          ),
        ],
      ),
    );
  }
}
