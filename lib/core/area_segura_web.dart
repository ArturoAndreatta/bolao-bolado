import 'package:web/web.dart' as web;

// Elemento invisível com `padding-bottom: env(safe-area-inset-bottom)`: o
// navegador resolve o env() e o estilo computado devolve o valor em px. Não
// dá para ler o env() direto do JavaScript, só através de um elemento.
// Criado uma vez e mantido no DOM; o valor muda ao girar o aparelho, e cada
// leitura pega o atual.
web.HTMLDivElement? _sonda;

/// Altura, em px lógicos, da área segura na base da tela (0 fora do iPhone).
double margemInferiorNavegador() {
  final sonda = _sonda ??= _criarSonda();
  final valor = web.window.getComputedStyle(sonda).paddingBottom;
  return double.tryParse(valor.replaceAll('px', '')) ?? 0;
}

web.HTMLDivElement _criarSonda() {
  final div = web.document.createElement('div') as web.HTMLDivElement;
  div.style
    ..position = 'fixed'
    ..visibility = 'hidden'
    ..pointerEvents = 'none'
    ..paddingBottom = 'env(safe-area-inset-bottom)';
  web.document.body!.append(div);
  return div;
}
