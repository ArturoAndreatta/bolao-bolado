import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/core/app_radii.dart';
import 'package:flutter/material.dart';

/// Monta o [ThemeData] de cada modo a partir da paleta semântica em
/// [AppCores].
///
/// O app pinta a maior parte das cores explicitamente nos widgets (via
/// `AppCores.de(context)`), mas há um conjunto de superfícies que o Material
/// desenha sozinho e que nenhum widget do projeto toca: menus de
/// `PopupMenuButton`, `showDatePicker`/`showTimePicker`, `SnackBar`,
/// `Tooltip`, o cursor e a alça de seleção de texto. Sem configurá-las aqui,
/// esses elementos continuariam claros no tema escuro — é o tipo de detalhe
/// que denuncia um dark mode "pela metade".
class AppTema {
  // Construídos uma vez e reusados: `_construir` devolvia uma instância nova
  // a cada chamada, e o AnimatedTheme de [BolaoBolado] compara `data` por
  // `!=` — ThemeData novo nunca é igual ao anterior, então ele reiniciava a
  // animação de 450ms a cada rebuild da árvore.
  static final ThemeData _claro = _construir(AppCores.claro, Brightness.light);
  static final ThemeData _escuro = _construir(
    AppCores.escuroTema,
    Brightness.dark,
  );

  static ThemeData claro() => _claro;

  static ThemeData escuro() => _escuro;

  static ThemeData _construir(AppCores cores, Brightness brilho) {
    final base = ColorScheme.fromSeed(seedColor: cores.azul, brightness: brilho)
        .copyWith(
          // Sobrescreve o que o fromSeed deriva sozinho: o algoritmo do Material
          // gera tons harmônicos, mas não os TONS DESTE app — deixar por conta
          // dele faria diálogos e menus divergirem dos cards pintados à mão.
          surface: cores.card,
          onSurface: cores.texto,
          primary: cores.azul,
          onPrimary: cores.textoSobreCor,
          error: cores.vermelho,
          outline: cores.borda,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brilho,
      colorScheme: base,
      // Registra a paleta como extension: é daqui que `AppCores.de(context)`
      // lê, e é o que permite ao MaterialApp INTERPOLAR os ~50 campos durante
      // a troca de tema (ver [AppCores.lerp]).
      extensions: [cores],
      scaffoldBackgroundColor: Colors.transparent,
      // canvasColor alimenta o fundo dos menus suspensos (DropdownButton2 e
      // PopupMenuButton herdam daqui quando não recebem cor própria).
      canvasColor: cores.campo,
      dividerColor: cores.borda,
      shadowColor: cores.sombra,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: cores.azul,
        selectionColor: cores.azul.withValues(alpha: 0.3),
        selectionHandleColor: cores.azul,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: cores.card,
        surfaceTintColor: Colors.transparent,
        textStyle: TextStyle(color: cores.texto, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.circularSmd),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cores.card,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: cores.texto,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(color: cores.textoSuave, fontSize: 14),
      ),
      // O date/time picker é um dos poucos lugares onde o Material pinta uma
      // tela inteira sem passar por nenhum widget do projeto.
      datePickerTheme: DatePickerThemeData(
        backgroundColor: cores.card,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: cores.azul,
        headerForegroundColor: cores.textoSobreCor,
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: cores.card,
        dialBackgroundColor: cores.campo,
        hourMinuteColor: cores.campo,
        hourMinuteTextColor: cores.texto,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        contentTextStyle: const TextStyle(color: Colors.white),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: cores.escuro ? cores.superficieAlta : const Color(0xFF1F2937),
          borderRadius: AppRadii.circularSm,
        ),
        textStyle: TextStyle(
          color: cores.escuro ? cores.texto : Colors.white,
          fontSize: 12,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: cores.azul),
      iconTheme: IconThemeData(color: cores.texto),
      // Texto sem cor explícita (ex: o corpo dos diálogos do Material) herda
      // daqui. Sem isso, no escuro ele continuaria preto e sumiria no fundo.
      textTheme: ThemeData(
        brightness: brilho,
      ).textTheme.apply(bodyColor: cores.texto, displayColor: cores.texto),
    );
  }
}
