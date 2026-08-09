import 'package:bolao_bolado/core/app_cores.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Um tema selecionável pelo usuário.
///
/// Antes existiam só três estados (claro/escuro/sistema) e um `ThemeMode` dava
/// conta. Com os temas únicos (Cassino, Meia-noite, Cyber, Papel, Bilhete) a
/// escolha deixou de ser "qual brilho" e virou "qual paleta", então o valor
/// persistido passou a ser um enum próprio.
///
/// [seguirSistema] continua sendo um estado de primeira classe — quem tem o
/// celular agendado para escurecer à noite quer que o app acompanhe, e forçar
/// uma escolha fixa obrigaria a trocar manualmente duas vezes por dia. Ele é
/// o padrão de fábrica, e é o único item cuja paleta depende do SO (ver
/// [paletaDe]).
enum TemaApp {
  /// Segue o brilho do sistema operacional: [AppCores.claro] ou
  /// [AppCores.escuroTema].
  seguirSistema(rotulo: 'Auto', icone: Icons.brightness_auto_outlined),

  claro(rotulo: 'Claro', icone: Icons.light_mode_outlined),
  escuro(rotulo: 'Escuro', icone: Icons.dark_mode_outlined),

  // ── Temas únicos (escolhidos em "Mais") ──────────────────────────────────
  cassino(
    rotulo: 'Cassino',
    icone: Icons.casino_outlined,
    descricao: 'Feltro de mesa e metal dourado',
    unico: true,
  ),
  meiaNoite(
    rotulo: 'Meia-noite',
    icone: Icons.nightlight_outlined,
    descricao: 'Azul profundo com neon ciano',
    unico: true,
  ),
  cyber(
    rotulo: 'Cyber',
    icone: Icons.bolt_outlined,
    descricao: 'Quase preto com magenta e ciano',
    unico: true,
  ),
  papel(
    rotulo: 'Papel',
    icone: Icons.menu_book_outlined,
    descricao: 'Bege de caderneta e tinta marrom',
    unico: true,
  ),
  bilhete(
    rotulo: 'Bilhete',
    icone: Icons.confirmation_number_outlined,
    descricao: 'O volante da loteria, claro e sóbrio',
    unico: true,
  );

  /// Nome exibido no seletor.
  final String rotulo;

  /// Ícone do seletor.
  final IconData icone;

  /// Linha de apoio, mostrada só na lista de temas únicos (o trio do rodapé
  /// do drawer não tem espaço para ela).
  final String? descricao;

  /// `true` para os temas que vivem atrás do botão "Mais".
  ///
  /// São separados dos três principais porque têm natureza diferente: os
  /// principais respondem "quão claro", os únicos respondem "qual
  /// personalidade". Misturar os oito num pill só transformaria a decisão
  /// mais comum (escurecer a tela) num menu.
  final bool unico;

  const TemaApp({
    required this.rotulo,
    required this.icone,
    this.descricao,
    this.unico = false,
  });

  /// Os temas únicos, na ordem em que aparecem no diálogo.
  static List<TemaApp> get unicos =>
      values.where((tema) => tema.unico).toList(growable: false);
}

/// Tema escolhido pelo usuário.
///
/// É um [ValueNotifier] global — e não um provider/InheritedWidget — pelo
/// mesmo motivo dos outros notifiers do app (ver `core/debug_flags.dart`): o
/// valor é único para o app inteiro e quem escuta é só o [MaterialApp] na
/// raiz, então injetar isso pela árvore não traria nada além de cerimônia.
///
/// A preferência PERSISTE entre sessões (SharedPreferences → localStorage na
/// web). Sem isso, quem escolhesse o tema escuro voltaria ao claro a cada
/// abertura do app — e no iPhone, onde o atalho do Safari recarrega a página
/// toda vez, isso aconteceria várias vezes por dia.
///
/// A leitura da preferência é feita em [carregarTemaSalvo] antes do primeiro
/// frame (ver `main.dart`), para o app não pintar no tema claro e "piscar"
/// para o escolhido logo em seguida.
// ignore: close_sinks
final ValueNotifier<TemaApp> temaGlobal = ValueNotifier(TemaApp.seguirSistema);

/// Chave usada no SharedPreferences. Alterá-la faz todo mundo voltar ao
/// padrão (seguir sistema) na próxima abertura.
///
/// É a MESMA chave da versão anterior, que guardava um `ThemeMode.name`
/// (`light`/`dark`/`system`). [_paraTema] reconhece esses três valores
/// antigos, então quem já tinha um tema salvo não é jogado de volta ao
/// padrão ao atualizar o app.
const String _chaveTema = 'tema_modo';

/// Lê o tema salvo e aplica em [temaGlobal].
///
/// Falha silenciosa de propósito: se o storage não estiver disponível (modo
/// privado do navegador, permissão negada), o app deve abrir no tema do
/// sistema em vez de não abrir.
Future<void> carregarTemaSalvo() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    temaGlobal.value = _paraTema(prefs.getString(_chaveTema));
  } catch (_) {
    // Mantém TemaApp.seguirSistema.
  }
}

/// Persiste [tema] e já reflete na UI.
///
/// A escrita não é aguardada pelo chamador: a troca de tema precisa ser
/// instantânea no toque, e gravar a preferência é um efeito colateral que
/// pode terminar depois do frame.
Future<void> salvarTema(TemaApp tema) async {
  temaGlobal.value = tema;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chaveTema, tema.name);
  } catch (_) {
    // Preferência não persistida; a sessão atual continua no tema escolhido.
  }
}

/// Alterna entre claro e escuro.
///
/// Quando o tema atual é [TemaApp.seguirSistema] ou um tema único, o toggle
/// resolve para o OPOSTO do que está sendo exibido — quem toca no botão quer
/// mudar o que está vendo, não voltar para um estado que já era o atual.
Future<void> alternarTema(BuildContext context) {
  final escuroAgora = paletaDe(
    temaGlobal.value,
    MediaQuery.platformBrightnessOf(context),
  ).escuro;
  return salvarTema(escuroAgora ? TemaApp.claro : TemaApp.escuro);
}

/// Paleta correspondente a [tema].
///
/// [brilhoSistema] só é consultado por [TemaApp.seguirSistema]; para os
/// demais o tema já determina a paleta sozinho.
AppCores paletaDe(TemaApp tema, Brightness brilhoSistema) {
  return switch (tema) {
    TemaApp.seguirSistema =>
      brilhoSistema == Brightness.dark ? AppCores.escuroTema : AppCores.claro,
    TemaApp.claro => AppCores.claro,
    TemaApp.escuro => AppCores.escuroTema,
    TemaApp.cassino => AppCores.cassino,
    TemaApp.meiaNoite => AppCores.meiaNoite,
    TemaApp.cyber => AppCores.cyber,
    TemaApp.papel => AppCores.papel,
    TemaApp.bilhete => AppCores.bilhete,
  };
}

/// Converte o valor persistido em [TemaApp], aceitando também os três nomes
/// de `ThemeMode` gravados pela versão anterior do seletor.
TemaApp _paraTema(String? valor) {
  return switch (valor) {
    'light' => TemaApp.claro,
    'dark' => TemaApp.escuro,
    'system' => TemaApp.seguirSistema,
    _ => TemaApp.values.firstWhere(
      (tema) => tema.name == valor,
      orElse: () => TemaApp.seguirSistema,
    ),
  };
}
