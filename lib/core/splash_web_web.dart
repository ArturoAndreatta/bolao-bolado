import 'package:web/web.dart' as web;

/// Avisa o `web/index.html` que o app já tem conteúdo na tela.
///
/// O nome do evento é o único contrato entre os dois lados: o HTML só escuta
/// `bolao-app-pronto`, e renomear aqui sem renomear lá deixa o splash HTML
/// cobrindo o app para sempre.
void dispensarSplashWeb() {
  web.window.dispatchEvent(web.Event('bolao-app-pronto'));
}
