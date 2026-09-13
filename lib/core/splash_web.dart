// Tira da tela o splash HTML de `web/index.html`.
//
// O `web/index.html` tem uma cópia da `SplashScreen` em HTML e CSS puro, que
// aparece antes de o motor do Flutter montar o primeiro quadro — sem ela, esse
// intervalo é tela vazia. Quem decide quando ela sai é o app, e não o motor:
// o primeiro quadro do Flutter quase sempre é a própria `SplashScreen`, então
// esperar só o motor trocaria um splash por outro quase igual, com uma piscada
// no meio. Ver o comentário em `web/index.html`.
//
// Fora da web não existe HTML nenhum, e a implementação é vazia.
export 'splash_web_stub.dart'
    if (dart.library.js_interop) 'splash_web_web.dart';
