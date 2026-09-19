// Margem que a barrinha de gestos do iPhone (e o recorte da tela) ocupa
// embaixo, quando o app roda na web.
//
// Fora da web o Flutter já entrega isso em `MediaQuery.padding`. Na web não:
// o `web/index.html` usa `viewport-fit=cover` (o app vai até a borda da tela),
// e o motor não repassa o `env(safe-area-inset-bottom)` do navegador — o
// padding chega zerado e a barra inferior fica por baixo da barrinha do
// iPhone. A implementação web lê o valor direto do CSS.
export 'area_segura_stub.dart'
    if (dart.library.js_interop) 'area_segura_web.dart';
