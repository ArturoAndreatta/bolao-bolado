import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Chave de SITE do reCAPTCHA Enterprise registrada no App Check do
/// Firebase (Console > App Check > Apps > web).
///
/// Chave de site é pública por natureza — vai no HTML de qualquer página que
/// usa reCAPTCHA —, então mora no código. Vazia, o App Check fica desligado e
/// o app se comporta exatamente como antes.
///
/// Por que existe: a configuração do Firebase (chave de API, id do projeto)
/// está no bundle da web, e com ela qualquer script fala com o Firestore e o
/// Auth sem passar pelo app — criando contas anônimas sem fim, lendo tudo o
/// que as regras deixam ler, tentando senhas. Com o App Check EXIGIDO no
/// console, só pedidos com um token emitido para o app publicado passam.
const String kChaveSiteRecaptcha = '6LenMcQtAAAAACDkO8MEK-kOk0FC1S0HMghW5Gnx';

/// Liga o App Check na web, se a chave estiver preenchida.
///
/// Precisa rodar depois do `Firebase.initializeApp` e antes da primeira
/// leitura do Firestore: pedido que sai antes vai sem token e, com o App
/// Check exigido, é recusado.
///
/// Só a web por enquanto: é onde o app é usado de verdade. Android e iOS
/// precisam de Play Integrity / App Attest registrados no console, e ligar o
/// App Check neles sem esse registro faria os apps nativos pararem de
/// funcionar no dia em que a exigência fosse ativada.
Future<void> ativarAppCheck() async {
  if (!kIsWeb || kChaveSiteRecaptcha.isEmpty) return;
  await FirebaseAppCheck.instance.activate(
    providerWeb: ReCaptchaEnterpriseProvider(kChaveSiteRecaptcha),
  );
}
