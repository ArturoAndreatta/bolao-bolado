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
  // Cache por paleta. `_construir` devolve uma instância nova a cada chamada,
  // e o AnimatedTheme de [BolaoBolado] compara `data` por `!=` — ThemeData
  // novo nunca é igual ao anterior, então sem cache ele reiniciaria a
  // animação de 450ms a cada rebuild da árvore.
  //
  // A chave é a própria paleta (AppCores é `@immutable` e as instâncias são
  // const), então cada tema é montado no máximo uma vez por sessão — e só se
  // for realmente usado, que importa agora que existem 7 paletas.
  static final Map<AppCores, ThemeData> _cache = {};

  /// [ThemeData] da paleta informada, montado sob demanda e memoizado.
  static ThemeData de(AppCores cores) => _cache.putIfAbsent(
    cores,
    () => _construir(cores, cores.escuro ? Brightness.dark : Brightness.light),
  );

  static ThemeData claro() => de(AppCores.claro);

  static ThemeData escuro() => de(AppCores.escuroTema);

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
      // Date e time picker do Material continuam tematizados por garantia,
      // mas hoje NENHUMA tela do app os abre: os campos de data e hora usam o
      // `board_datetime_picker` (ver
      // [seletor_data_hora.dart](lib/components/shared/seletor_data_hora.dart)).
      // Se voltar a chamar `showDatePicker`/`showTimePicker`, tematize por
      // completo — o que ficar de fora cai no ColorScheme derivado do seed e
      // traz tons do Material, não os do app.
      datePickerTheme: DatePickerThemeData(
        backgroundColor: cores.card,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: cores.campo,
        headerForegroundColor: cores.texto,
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: cores.card,
        dialBackgroundColor: cores.campo,
        dialHandColor: cores.acaoPrimaria,
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
