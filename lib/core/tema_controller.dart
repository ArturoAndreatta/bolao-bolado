import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modo de tema escolhido pelo usuário (claro, escuro ou seguir o sistema).
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
/// para o escuro logo em seguida.
// ignore: close_sinks
final ValueNotifier<ThemeMode> temaModoGlobal = ValueNotifier(ThemeMode.system);

/// Chave usada no SharedPreferences. Alterá-la faz todo mundo voltar ao
/// padrão (system) na próxima abertura.
const String _chaveTema = 'tema_modo';

/// Lê o tema salvo e aplica em [temaModoGlobal].
///
/// Falha silenciosa de propósito: se o storage não estiver disponível (modo
/// privado do navegador, permissão negada), o app deve abrir no tema do
/// sistema em vez de não abrir.
Future<void> carregarTemaSalvo() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final salvo = prefs.getString(_chaveTema);
    temaModoGlobal.value = _paraThemeMode(salvo);
  } catch (_) {
    // Mantém ThemeMode.system.
  }
}

/// Persiste [modo] e já reflete na UI.
///
/// A escrita não é aguardada pelo chamador: a troca de tema precisa ser
/// instantânea no toque, e gravar a preferência é um efeito colateral que
/// pode terminar depois do frame.
Future<void> salvarTema(ThemeMode modo) async {
  temaModoGlobal.value = modo;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chaveTema, modo.name);
  } catch (_) {
    // Preferência não persistida; a sessão atual continua no tema escolhido.
  }
}

/// Alterna entre claro e escuro.
///
/// Quando o modo atual é [ThemeMode.system], o toggle resolve para o OPOSTO
/// do que está sendo exibido — quem toca no botão quer mudar o que está
/// vendo, não voltar para um "system" que já era o valor atual.
Future<void> alternarTema(BuildContext context) {
  final modo = temaModoGlobal.value;
  final estaEscuro = modo == ThemeMode.system
      ? MediaQuery.platformBrightnessOf(context) == Brightness.dark
      : modo == ThemeMode.dark;
  return salvarTema(estaEscuro ? ThemeMode.light : ThemeMode.dark);
}

ThemeMode _paraThemeMode(String? valor) {
  return switch (valor) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}
