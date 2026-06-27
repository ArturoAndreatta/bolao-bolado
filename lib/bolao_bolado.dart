import 'package:bolao_bolado/pages/auth/signup.dart';
import 'package:bolao_bolado/pages/home_page.dart';
import 'package:bolao_bolado/pages/participants.dart';
import 'package:bolao_bolado/services/authentication/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class BolaoBolado extends StatefulWidget {
  const BolaoBolado({super.key});

  @override
  State<BolaoBolado> createState() => _BolaoBoladoState();
}

class _BolaoBoladoState extends State<BolaoBolado> {
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bolão Bolado',
      theme: ThemeData(useMaterial3: true),
      debugShowCheckedModeBanner: false,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: StreamBuilder<User?>(
        stream: _authService.authStateChanges,
        builder: (context, snapshot) {
          // Ainda carregando
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final user = snapshot.data;

          // Usuário logado de verdade (não anônimo) → Visualizar
          if (user != null && !user.isAnonymous) {
            return const Participants();
          }

          // Não logado ou anônimo → Home
          return const HomePage();
        },
      ),
    );
  }
}
