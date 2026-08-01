import 'package:shared_preferences/shared_preferences.dart';

/// Lembra se a última tela visitada pelo usuário foi o Painel ADM, para
/// reabrir direto nela da próxima vez que ele entrar logado — em vez de cair
/// sempre em Participantes (ver [AppRoutes] em app_router.dart: o redirect de
/// `_guestOnlyRoutes` decide o destino a partir deste valor).
///
/// PERSISTE entre sessões (SharedPreferences → localStorage na web), mesmo
/// padrão do [temaModoGlobal] em tema_controller.dart, e pelo mesmo motivo: a
/// leitura acontece ANTES do primeiro frame (ver main.dart) para o redirect
/// do router já ter a resposta pronta na primeira navegação, sem round-trip.
///
/// Só marca `true`/`false` — não guarda qual admin ou qual sala, porque quem
/// decide se a rota pode mesmo abrir o Painel ADM é o próprio redirect de
/// auth e a verificação de `isAdmin` dentro da tela; este flag só escolhe
/// PARA ONDE mandar quem já está logado, nunca libera acesso sozinho.
bool ultimaRotaFoiPainelAdmin = false;

const String _chave = 'ultima_rota_painel_admin';

/// Lê a preferência salva. Falha silenciosa de propósito (mesmo padrão do
/// tema): se o storage não estiver disponível, o app assume `false` e cai no
/// destino padrão de sempre.
Future<void> carregarUltimaRotaAdmin() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    ultimaRotaFoiPainelAdmin = prefs.getBool(_chave) ?? false;
  } catch (_) {
    ultimaRotaFoiPainelAdmin = false;
  }
}

/// Marca [valor] em memória (efeito imediato no próximo redirect) e persiste
/// em segundo plano — sem aguardar, pelo mesmo motivo de [salvarTema]: a
/// navegação não deve esperar uma escrita em disco.
void marcarUltimaRotaAdmin(bool valor) {
  // Só grava quando muda: o redirect roda em toda navegação, e sem esta
  // checagem cada clique dentro do app viraria uma escrita no storage à toa.
  if (valor == ultimaRotaFoiPainelAdmin) return;
  ultimaRotaFoiPainelAdmin = valor;
  SharedPreferences.getInstance()
      .then((prefs) => prefs.setBool(_chave, valor))
      .catchError((_) => false);
}
