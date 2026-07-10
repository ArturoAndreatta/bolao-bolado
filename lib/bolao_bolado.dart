import 'package:bolao_bolado/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class BolaoBolado extends StatelessWidget {
  const BolaoBolado({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Bolão Bolado',
      theme: ThemeData(
        useMaterial3: true,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
            TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          },
        ),
      ),
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
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
