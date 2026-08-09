import 'package:flutter/material.dart';

/// Como uma aposta nova entra na tabela.
///
/// Cada estilo é uma encenação completa — não só uma direção de deslocamento.
/// A definição fica aqui, junto do enum, e a montagem em
/// `aplicarEstiloEntrada`: adicionar um estilo é uma entrada nesta lista mais
/// (quando ele precisar) um ramo no `switch` do efeito.
enum EstiloEntrada {
  /// Desliza da esquerda e quica no fim, como carta batendo na mesa.
  ///
  /// É o padrão e o mais sóbrio: os demais são deliberadamente exagerados, e
  /// este é o que se usa quando a tabela precisa ser levada a sério.
  batida(
    rotulo: 'Batida',
    descricao: 'Desliza e quica no fim, como carta batendo na mesa.',
    duracaoMs: 1000,
    deslocamentoX: -90,
    curva: Curves.easeOutBack,
  ),

  /// Falha de sinal: a linha pisca, se desloca em fatias horizontais
  /// desalinhadas e se estabiliza — estética de transmissão com ruído.
  ///
  /// O deslocamento das fatias é pseudo-aleatório mas determinístico por
  /// quadro, para o efeito ser reprodutível em vez de tremer sem controle.
  glitch(
    rotulo: 'Glitch',
    descricao: 'Entra com falha de sinal: fatias desalinhadas e ruído.',
    duracaoMs: 1000,
    efeito: EfeitoEntrada.fatiasGlitch,
    curva: Curves.easeOutCubic,
  ),

  /// A linha é forjada: uma onda de calor percorre da esquerda para a
  /// direita deixando o rastro incandescente, que esfria até a cor normal.
  ///
  /// Combina uma frente de luz intensa com o conteúdo emergindo atrás dela e
  /// um resfriamento lento do brilho — o oposto de um fade discreto.
  forja(
    rotulo: 'Forja',
    descricao: 'Onda incandescente percorre a linha e esfria até assentar.',
    duracaoMs: 1500,
    efeito: EfeitoEntrada.ondaIncandescente,
    dissolver: true,
    // Deslocamento curto: quem conduz é a onda de calor, e um percurso longo
    // competiria com ela. Sem nenhum, porém, a linha fica parada demais e a
    // luz lê como reflexo sobre algo que já estava lá.
    deslocamentoX: -30,
    curva: Curves.easeOutCubic,
  );

  const EstiloEntrada({
    required this.rotulo,
    required this.descricao,
    required this.duracaoMs,
    required this.curva,
    this.deslocamentoX = 0,
    this.dissolver = false,
    this.efeito = EfeitoEntrada.brilhoVarrendo,
  });

  final String rotulo;
  final String descricao;

  /// Duração total, incluindo o tempo de confirmação (efeito + recuo do
  /// destaque de fundo), não só o movimento de chegada.
  final int duracaoMs;

  final Curve curva;

  /// De onde a linha parte, em pixels. Negativo vem da esquerda.
  ///
  /// O ClipRect da linha recorta o que sai dela, então o deslocamento parece
  /// vir de fora da tabela.
  final double deslocamentoX;

  /// O conteúdo aparece por trás de uma máscara que avança, em vez de um fade
  /// uniforme. Usado pela [forja].
  final bool dissolver;

  /// Que efeito é pintado junto com a chegada.
  final EfeitoEntrada efeito;

  Duration get duracao => Duration(milliseconds: duracaoMs);
}

/// O que é pintado sobre a linha durante a entrada, além do movimento.
enum EfeitoEntrada {
  /// Faixa de luz que percorre a linha uma vez, da esquerda para a direita.
  brilhoVarrendo,

  /// Fatias horizontais deslocadas e faixas de ruído colorido.
  fatiasGlitch,

  /// Frente de calor intensa deixando rastro incandescente que esfria.
  ondaIncandescente,
}
