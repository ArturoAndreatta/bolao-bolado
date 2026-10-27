import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// Os quatro nomes são combinados com o script de detecção em
/// `web/index.html`. Mudar um lado sem o outro faz o aviso nunca aparecer, sem
/// erro nenhum, e deixa todo mundo preso na versão velha.
const String _marcaEncontrada = 'bolaoUpdateFound';
const String _eventoEncontrada = 'bolao-update-found';
const String _marcaPronta = 'bolaoUpdateReady';
const String _eventoPronta = 'bolao-update-ready';

const bool suportado = true;

bool encontrada() => _marca(_marcaEncontrada);

bool pronta() => _marca(_marcaPronta);

Stream<void> aoEncontrar() => _evento(_eventoEncontrada);

Stream<void> aoFicarPronta() => _evento(_eventoPronta);

void recarregar() => web.window.location.reload();

bool _marca(String nome) {
  final valor = globalContext.getProperty<JSAny?>(nome.toJS);
  return valor.isA<JSBoolean>() && (valor as JSBoolean).toDart;
}

Stream<void> _evento(String nome) {
  // Não há o que fechar: o evento do `window` não termina, e quem controla a
  // vida do ouvinte é a assinatura — o `onCancel` tira ele do `window`.
  // ignore: close_sinks
  late final StreamController<void> controller;
  final ouvinte = ((web.Event _) => controller.add(null)).toJS;

  controller = StreamController<void>.broadcast(
    onListen: () => web.window.addEventListener(nome, ouvinte),
    onCancel: () => web.window.removeEventListener(nome, ouvinte),
  );
  return controller.stream;
}
