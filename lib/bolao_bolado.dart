import 'package:bolao_bolado/core/app_tema.dart';
import 'package:bolao_bolado/core/tema_controller.dart';
import 'package:bolao_bolado/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class BolaoBolado extends StatelessWidget {
  const BolaoBolado({super.key});

  /// Duração da transição claro↔escuro.
  ///
  /// O padrão do Flutter (200ms) é curto para uma virada de tela INTEIRA — lê
  /// como um piscar. 450ms deixa o olho acompanhar a mudança sem que ela vire
  /// espera: acima de ~600ms a troca começa a parecer travamento.
  static const _duracaoTransicaoTema = Duration(milliseconds: 450);

  @override
  Widget build(BuildContext context) {
    // O MaterialApp fica FORA do ValueListenableBuilder, e quem escuta o modo
    // é o builder abaixo. A ordem importa e não é estética:
    //
    // Com o notifier envolvendo o MaterialApp (como era antes), trocar de tema
    // reconstruía o próprio MaterialApp — e o AnimatedTheme que ele monta
    // internamente perdia o estado junto, ficando sem "tema anterior" de onde
    // partir. O resultado é que `themeAnimationDuration` não produzia
    // animação nenhuma: as cores saltavam no primeiro frame (verificado
    // medindo pixels durante a troca).
    //
    // Aqui o MaterialApp é estável e a animação acontece num AnimatedTheme
    // logo abaixo dele, que sobrevive à mudança de modo e portanto consegue
    // interpolar do ThemeData antigo para o novo — incluindo a extension
    // AppCores, o que faz os ~95 pontos que leem a paleta atravessarem juntos.
    return MaterialApp.router(
      title: 'Bolão Bolado',
      theme: AppTema.claro(),
      darkTheme: AppTema.escuro(),
      // themeMode fixo: quem decide o tema exibido é o AnimatedTheme do
      // builder. Deixar o MaterialApp também reagir ao modo faria os dois
      // competirem, e a troca dele (não animada) venceria a do builder.
      themeMode: ThemeMode.light,
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: temaModoGlobal,
          child: child,
          builder: (context, modo, child) {
            final escuro = switch (modo) {
              ThemeMode.dark => true,
              ThemeMode.light => false,
              // ThemeMode.system: acompanha o brilho do SO ao vivo — o
              // MediaQuery aqui já reconstrói sozinho quando ele muda.
              ThemeMode.system =>
                MediaQuery.platformBrightnessOf(context) == Brightness.dark,
            };
            return AnimatedTheme(
              data: escuro ? AppTema.escuro() : AppTema.claro(),
              duration: _duracaoTransicaoTema,
              // easeInOutCubic (em vez do linear padrão): a transição arranca
              // e termina devagar, sem salto no primeiro frame nem parada
              // seca no último.
              curve: Curves.easeInOutCubic,
              child: child!,
            );
          },
        );
      },
    );
  }
}
