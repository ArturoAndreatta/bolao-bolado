import 'package:bolao_bolado/pages/auth/signup.dart';
import 'package:bolao_bolado/pages/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class BolaoBolado extends StatefulWidget {
  const BolaoBolado({super.key});

  @override
  State<BolaoBolado> createState() => _BolaoBoladoState();
}

class _BolaoBoladoState extends State<BolaoBolado> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bolão Bolado',
      home: HomePage(), //Signup(),
      theme: ThemeData(useMaterial3: true),
      debugShowCheckedModeBanner: false,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
