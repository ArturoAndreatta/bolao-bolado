import 'dart:ui' as ui;

import 'package:bolao_bolado/components/shared/constants/phrases.dart';
import 'package:bolao_bolado/services/avatar/avatar_service.dart';
import 'package:bolao_bolado/services/chat/emoji_reacao.dart';
import 'package:flutter/foundation.dart';

// Na web o navegador não entrega os emojis do sistema ao CanvasKit: o motor do
// Flutter baixa a Noto Color Emoji do Google Fonts, fatiada em pedaços de
// ~100–350 KB, e só busca um pedaço quando um emoji dele aparece num texto.
// Na prática, abrir a lista de participantes ou um seletor de emoji mostrava
// os emojis surgindo aos poucos, pedaço a pedaço — e cada pedaço que chega faz
// o motor medir de novo todo o texto da tela.
//
// Aqui o download é adiantado. Não se desenha nada: medir um parágrafo com
// esses caracteres já leva o motor a notar que a fonte padrão não os tem e a
// buscar os pedaços que faltam. Pedaço já baixado não é pedido de novo, e o
// navegador guarda os arquivos em cache entre visitas.
//
// O custo é baixar tudo de uma vez: medido na primeira visita de um
// visitante no celular, os emojis iniciais somam 8 arquivos (~940 KB), contra
// ~650 KB que antes chegavam aos poucos (68 KB na Home e o resto ao entrar em
// Participantes, com os avatares surgindo na tela). A troca vale porque é só
// na primeira visita — depois tudo sai do cache do navegador — e porque vem
// de outro servidor (fonts.gstatic.com), fora da conexão do Firestore.
//
// Fora da web o emoji é da fonte do sistema e nada disto faz sentido.

/// Emojis das primeiras telas: avatares (participantes, chat, menu, seletor
/// de avatar), a barra rápida de reações e as frases da Home.
void preCarregarEmojisIniciais() {
  if (!kIsWeb) return;
  _medirTexto([...kEmojisAvatar, ...kReacoesRapidas, ...phrases]);
}

bool _catalogoPedido = false;

/// O catálogo inteiro do seletor de reações (~500 emojis, ~700 KB de fonte).
///
/// Fica separado dos iniciais porque, ao chegar, o motor precisa processar a
/// fonte e medir de novo o texto da tela — um quadro travado de 100–200 ms.
/// Pedido junto com os iniciais, esse quadro caía num momento qualquer (no
/// meio da rolagem da lista, por exemplo) e para todo visitante, inclusive
/// quem nunca vai reagir a nada. Por isso quem chama é o chat, quando é
/// montado para alguém que PODE reagir — no computador, ao abrir o painel; no
/// celular, junto com a tela de participantes, onde a seção do chat já nasce
/// montada. A trava acontece numa troca de tela, e os emojis já estão prontos
/// quando o seletor for aberto.
void preCarregarCatalogoEmoji() {
  if (!kIsWeb || _catalogoPedido) return;
  _catalogoPedido = true;
  _medirTexto([
    for (final categoria in kCatalogoEmoji) ...[
      categoria.icone,
      ...categoria.emojis,
    ],
  ]);
}

void _medirTexto(List<String> trechos) {
  final builder = ui.ParagraphBuilder(ui.ParagraphStyle())
    ..addText(trechos.join(' '));
  builder.build()
    ..layout(const ui.ParagraphConstraints(width: 4000))
    ..dispose();
}
