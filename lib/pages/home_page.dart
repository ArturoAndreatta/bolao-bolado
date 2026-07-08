import 'dart:async';
import 'dart:math';
import 'package:bolao_bolado/bolao_bolado.dart';
import 'package:bolao_bolado/components/shell/default_layout.dart';
import 'package:bolao_bolado/components/shared/buttons.dart';
import 'package:bolao_bolado/components/shared/custom_card.dart';
import 'package:bolao_bolado/components/shell/drawer.dart';
import 'package:bolao_bolado/components/shared/branding/logo.dart';
import 'package:bolao_bolado/pages/auth/signup.dart';
import 'package:bolao_bolado/pages/informar_aposta.dart';
import 'package:bolao_bolado/pages/pages.dart';
import 'package:bolao_bolado/pages/participants.dart';
import 'package:bolao_bolado/components/shared/constants/phrases.dart';
import 'package:bolao_bolado/services/authentication/auth_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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
    final width = MediaQuery.of(context).size.width;
    final isDesktopWeb = kIsWeb && width >= 900;
    return DefaultLayout(
      drawer: AppDrawer(),
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
                  Navigator.of(context).push(
                    PageRouteBuilder(
                      transitionDuration: Duration.zero,
                      reverseTransitionDuration: Duration.zero,
                      pageBuilder: (_, _, _) =>
                          _authService.isLoggedIn ? Login() : Signup(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              SecondaryButton(
                text: 'Visualizar',
                onTap: () {
                  final navigator = Navigator.of(context);
                  navigator.push(
                    PageRouteBuilder(
                      transitionDuration: Duration.zero,
                      reverseTransitionDuration: Duration.zero,
                      pageBuilder: (_, _, _) => const Participants(),
                    ),
                  );
                },
              ),
              SizedBox(height: 30),
            ],
          ),
          Positioned(
            top: 10,
            left: isDesktopWeb ? 500 : 250,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () {
                  Navigator.of(context).push(
                    PageRouteBuilder(
                      transitionDuration: Duration.zero,
                      reverseTransitionDuration: Duration.zero,
                      pageBuilder: (_, _, _) => Pages(),
                    ),
                  );
                },
                child: Container(padding: EdgeInsets.all(20)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
