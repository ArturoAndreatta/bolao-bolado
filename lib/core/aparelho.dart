// Se o app está rodando num celular ou tablet (Android/iOS).
//
// Existe porque `defaultTargetPlatform` sozinho erra na web em simuladores de
// celular no computador (o modo dispositivo do Chrome, extensões com moldura
// de iPhone): eles trocam o user agent e o tamanho da tela, mas o
// `navigator.platform` continua dizendo Windows — e é por ele que o motor do
// Flutter decide o sistema. A implementação web olha o user agent também.
export 'aparelho_stub.dart' if (dart.library.js_interop) 'aparelho_web.dart';
