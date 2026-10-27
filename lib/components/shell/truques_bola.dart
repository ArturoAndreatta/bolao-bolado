import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Os truques que a bola do "7" da AppBar faz quando o mouse passa por cima.
///
/// Cada passada roda o PRÓXIMO da lista, sempre na mesma ordem, e depois do
/// último volta ao primeiro. A ordem alterna truque grande (pulo, viagem) com
/// truque pequeno (brilho, gelatina) de propósito: dois pulos seguidos liam
/// como o mesmo truque repetido.
///
/// Um truque não anima nada sozinho: é uma função pura do progresso (0 a 1)
/// para uma [PoseBola], e quem desenha é o `_MarcaAppBar`. Assim todos
/// passam pela mesma pilha de transformações e pela mesma sombra, e truque
/// novo é só mais uma função aqui, sem controller nem widget novo.
///
/// Toda pose em `t = 1` precisa ser a de repouso (`const PoseBola()`): o
/// controller para ali, e qualquer resto apareceria como salto no fim.
class TruqueBola {
  final String nome;
  final Duration duracao;
  final PoseBola Function(double t) pose;

  const TruqueBola(this.nome, this.duracao, this.pose);
}

/// Como a bola está num instante de um truque.
///
/// [altura] é para CIMA (a sombra encolhe com ela); [inclinacao] gira pelo
/// pé da bola, como joão-bobo, e [angulo] pelo centro, como roda; as
/// escalas também partem do pé, para o achatamento parecer contato com o
/// chão. [anel], [faiscas] e [brilho] são progressos (0 = desligado) dos
/// efeitos pintados em volta e por cima da bola.
class PoseBola {
  final double dx;
  final double altura;
  final double angulo;
  final double inclinacao;
  final double escalaX;
  final double escalaY;
  final double giroY;
  final double opacidade;
  final double anel;
  final double faiscas;
  final double brilho;

  const PoseBola({
    this.dx = 0,
    this.altura = 0,
    this.angulo = 0,
    this.inclinacao = 0,
    this.escalaX = 1,
    this.escalaY = 1,
    this.giroY = 0,
    this.opacidade = 1,
    this.anel = 0,
    this.faiscas = 0,
    this.brilho = 0,
  });
}

const double _pi = math.pi;

// Progresso de `t` dentro do trecho [inicio, fim], preso em 0..1.
double _trecho(double t, double inicio, double fim) =>
    ((t - inicio) / (fim - inicio)).clamp(0.0, 1.0);

// Arco de pulo: 0 nas pontas, 1 no meio (parábola, como queda de verdade).
double _arco(double p) => 4 * p * (1 - p);

// Achatamento que some balançando depois de um impacto.
double _amortece(double p, {double ciclos = 1.5}) =>
    math.sin(p * _pi * 2 * ciclos) * math.pow(1 - p, 2);

/// A lista, na ordem em que roda. O primeiro é o giro antigo, melhorado.
final List<TruqueBola> truquesBola = [
  TruqueBola('pirueta', const Duration(milliseconds: 900), _pirueta),
  TruqueBola('quique', const Duration(milliseconds: 1300), _quique),
  TruqueBola('brilho', const Duration(milliseconds: 900), _brilho),
  TruqueBola('moeda', const Duration(milliseconds: 1100), _moeda),
  TruqueBola('gelatina', const Duration(milliseconds: 900), _gelatina),
  TruqueBola('sorteio', const Duration(milliseconds: 1300), _sorteio),
  TruqueBola('vai e vem', const Duration(milliseconds: 1300), _vaiEVem),
  TruqueBola('coração', const Duration(milliseconds: 1100), _coracao),
  TruqueBola('mortal', const Duration(milliseconds: 1000), _mortal),
  TruqueBola('joão-bobo', const Duration(milliseconds: 1500), _joaoBobo),
  TruqueBola('teletransporte', const Duration(milliseconds: 1200), _teleporte),
  TruqueBola('estouro', const Duration(milliseconds: 1100), _estouro),
];

// Recua um pouco no sentido contrário (o "carregar" da pirueta), solta duas
// voltas inteiras num salto baixo e assenta com um balanço curto. O giro
// antigo era uma volta seca sem preparo, e por isso parecia tremido.
PoseBola _pirueta(double t) {
  final preparo = _trecho(t, 0, 0.2);
  final giro = _trecho(t, 0.2, 0.85);
  final assenta = _trecho(t, 0.85, 1);
  final recuo = math.sin(preparo * _pi / 2) * (1 - giro) * -0.35;
  final voltas = Curves.easeOutCubic.transform(giro) * 4 * _pi;
  final balanco = _amortece(assenta, ciclos: 1) * 0.12;
  return PoseBola(
    angulo: recuo + voltas + balanco,
    altura: _arco(giro) * 5,
    escalaX: 1 + 0.08 * preparo * (1 - giro),
    escalaY: 1 - 0.1 * preparo * (1 - giro),
  );
}

// Três quiques que perdem força, achatando a cada toque no chão. A duração
// de cada um segue a raiz da altura, como numa queda de verdade.
PoseBola _quique(double t) {
  const quiques = [(0.0, 0.42, 13.0), (0.42, 0.72, 6.5), (0.72, 0.9, 2.5)];
  for (final (inicio, fim, alturaMax) in quiques) {
    if (t < fim) {
      final p = _trecho(t, inicio, fim);
      // Achata perto do chão (pontas do trecho) e estica no ar subindo. A
      // saída do primeiro não achata: a bola parte parada, sem impacto.
      final borda = inicio == 0 ? 1 - p : math.min(p, 1 - p);
      final perto = (1 - borda * 7).clamp(0.0, 1.0);
      final forca = alturaMax / 13;
      final achata = perto * 0.22 * forca;
      final partida = inicio == 0 ? (p * 6).clamp(0.0, 1.0) : 1.0;
      final estica = (1 - perto) * 0.07 * forca * (1 - _arco(p)) * partida;
      return PoseBola(
        altura: _arco(p) * alturaMax,
        escalaX: 1 + achata - estica,
        escalaY: 1 - achata + estica,
      );
    }
  }
  final p = _trecho(t, 0.9, 1);
  final resto = _amortece(p, ciclos: 1) * 0.05;
  return PoseBola(escalaX: 1 + resto, escalaY: 1 - resto);
}

// Um reflexo de luz atravessa a bola na diagonal, como bola nova saindo da
// caixa, enquanto ela se inclina de leve para a luz.
PoseBola _brilho(double t) {
  final onda = math.sin(t * _pi);
  return PoseBola(
    brilho: Curves.easeInOutCubic.transform(t),
    angulo: -0.18 * onda,
    escalaX: 1 + 0.06 * onda,
    escalaY: 1 + 0.06 * onda,
  );
}

// Cara ou coroa: sobe girando de lado como moeda jogada e cai de volta.
PoseBola _moeda(double t) {
  final voo = _trecho(t, 0, 0.85);
  final pouso = _trecho(t, 0.85, 1);
  final achata = math.sin(pouso * _pi) * 0.14;
  return PoseBola(
    altura: _arco(Curves.easeOut.transform(voo)) * 12,
    giroY: Curves.easeInOutSine.transform(voo) * 6 * _pi,
    escalaX: 1 + achata,
    escalaY: 1 - achata,
  );
}

// Aperto rápido e a bola treme como gelatina até parar.
PoseBola _gelatina(double t) {
  final aperto = _trecho(t, 0, 0.15);
  final treme = _trecho(t, 0.15, 1);
  if (t < 0.15) {
    final a = Curves.easeOut.transform(aperto);
    return PoseBola(escalaX: 1 + 0.2 * a, escalaY: 1 - 0.22 * a);
  }
  final onda = math.cos(treme * _pi * 7) * math.pow(1 - treme, 2.2);
  return PoseBola(
    escalaX: 1 + 0.2 * onda,
    escalaY: 1 - 0.22 * onda,
    angulo: math.sin(treme * _pi * 5) * 0.08 * (1 - treme),
  );
}

// Globo da loteria: a bola sacode cada vez mais forte, como no sorteio, e
// salta para fora com um estouro de confete. É o truque mais da casa.
PoseBola _sorteio(double t) {
  if (t < 0.6) {
    final p = _trecho(t, 0, 0.6);
    final forca = Curves.easeIn.transform(p);
    return PoseBola(
      angulo: math.sin(p * 70) * 0.35 * forca,
      dx: math.sin(p * 53) * 2.5 * forca,
      altura: math.sin(p * 61).abs() * 2.5 * forca,
    );
  }
  final p = _trecho(t, 0.6, 1);
  final salto = _arco(_trecho(p, 0, 0.7)) * 10;
  final pop = math.sin(p * _pi) * (1 - p) * 0.45;
  return PoseBola(
    altura: salto,
    escalaX: 1 + pop,
    escalaY: 1 + pop,
    angulo: Curves.easeOutBack.transform(p) * 2 * _pi,
    faiscas: Curves.easeOut.transform(p),
  );
}

// Rola até perto do nome, volta além do ponto e assenta. O ângulo sai do
// deslocamento dividido pelo raio, então a bola rola sem patinar.
PoseBola _vaiEVem(double t) {
  final dx = math.sin(t * _pi * 3) * 13 * math.pow(1 - t, 1.3);
  return PoseBola(dx: dx, angulo: dx / 20);
}

// Bate como coração, dois pulsos (tum-tum), e solta uma onda em volta.
PoseBola _coracao(double t) {
  double pulso(double inicio, double fim, double forca) =>
      math.sin(_trecho(t, inicio, fim) * _pi) * forca;
  final escala = 1 + pulso(0, 0.22, 0.2) + pulso(0.22, 0.42, 0.13);
  return PoseBola(
    escalaX: escala,
    escalaY: escala,
    anel: _trecho(t, 0.08, 0.95),
  );
}

// Agacha fundo, pula alto dando um mortal para trás e cai achatando.
PoseBola _mortal(double t) {
  if (t < 0.22) {
    final a = Curves.easeOut.transform(_trecho(t, 0, 0.22));
    return PoseBola(escalaX: 1 + 0.18 * a, escalaY: 1 - 0.24 * a);
  }
  if (t < 0.8) {
    final p = _trecho(t, 0.22, 0.8);
    // Estica ao sair do chão e encolhe de volta no topo do pulo.
    final estica = math.max(0.0, 1 - p * 3) * 0.16;
    return PoseBola(
      altura: _arco(p) * 14,
      angulo: -Curves.easeInOutCubic.transform(p) * 2 * _pi,
      escalaX: 1 - estica,
      escalaY: 1 + estica,
    );
  }
  final queda = _amortece(_trecho(t, 0.8, 1), ciclos: 1) * 0.2;
  return PoseBola(escalaX: 1 + queda, escalaY: 1 - queda);
}

// João-bobo: tomba para um lado pelo pé, volta, tomba para o outro, e o
// balanço morre devagar como brinquedo de peso no fundo.
PoseBola _joaoBobo(double t) {
  final balanco = math.sin(t * _pi * 5) * 0.5 * math.pow(1 - t, 1.6);
  return PoseBola(inclinacao: balanco, dx: balanco * 4);
}

// Some esticando num fio, como teletransporte, e cai de cima no lugar.
PoseBola _teleporte(double t) {
  if (t < 0.3) {
    final p = Curves.easeIn.transform(_trecho(t, 0, 0.3));
    return PoseBola(
      escalaX: 1 - 0.95 * p,
      escalaY: 1 + 0.5 * p,
      opacidade: 1 - p,
      brilho: p * 0.5,
    );
  }
  if (t < 0.45) return const PoseBola(opacidade: 0, escalaX: 0.05);
  final p = _trecho(t, 0.45, 1);
  final queda = Curves.bounceOut.transform(p);
  // O primeiro toque do bounceOut no chão é perto de 36% do trecho: é dali
  // que sai o achatamento, que some balançando até o fim.
  final achata = _amortece(_trecho(p, 0.36, 1), ciclos: 1) * 0.16;
  return PoseBola(
    altura: (1 - queda) * 16,
    opacidade: _trecho(p, 0, 0.25),
    escalaX: 1 + achata,
    escalaY: 1 - achata,
  );
}

// Encolhe tremendo como quem prende o ar e estoura de volta em faíscas.
PoseBola _estouro(double t) {
  if (t < 0.35) {
    final p = Curves.easeIn.transform(_trecho(t, 0, 0.35));
    return PoseBola(
      escalaX: 1 - 0.4 * p,
      escalaY: 1 - 0.4 * p,
      dx: math.sin(t * 160) * 1.5 * p,
      angulo: math.sin(t * 130) * 0.12 * p,
    );
  }
  final p = _trecho(t, 0.35, 1);
  final escala = 0.6 + 0.4 * Curves.elasticOut.transform(p);
  return PoseBola(
    escalaX: escala,
    escalaY: escala,
    faiscas: Curves.easeOut.transform(_trecho(p, 0, 0.8)),
    anel: _trecho(p, 0, 0.7),
  );
}

/// Anel que se espalha e faíscas que voam em volta da bola. Pintado atrás
/// dela, na mesma posição (acompanha pulo e deslocamento).
class EfeitosBolaPainter extends CustomPainter {
  final double anel;
  final double faiscas;
  final Color cor;
  final Color corAlternada;

  const EfeitosBolaPainter({
    required this.anel,
    required this.faiscas,
    required this.cor,
    required this.corAlternada,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centro = size.center(Offset.zero);
    final raio = size.shortestSide / 2;
    if (anel > 0 && anel < 1) {
      final p = Curves.easeOutCubic.transform(anel);
      canvas.drawCircle(
        centro,
        raio + 16 * p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * (1 - p) + 0.5
          ..color = cor.withValues(alpha: 0.8 * (1 - anel)),
      );
    }
    if (faiscas > 0 && faiscas < 1) {
      const quantidade = 12;
      for (var i = 0; i < quantidade; i++) {
        // Distância desigual entre faíscas vizinhas: anel perfeito de
        // pontos lia como engrenagem, não como estouro.
        final longe = i.isEven ? 1.0 : 0.7;
        final angulo = i * 2 * _pi / quantidade + 0.2;
        final distancia = raio + 4 + 18 * faiscas * longe;
        final ponto =
            centro + Offset(math.cos(angulo), math.sin(angulo)) * distancia;
        canvas.drawCircle(
          ponto,
          2.6 * (1 - faiscas) + 0.4,
          Paint()
            ..color = (i.isEven ? cor : corAlternada).withValues(
              alpha: 1 - faiscas,
            ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(EfeitosBolaPainter antigo) =>
      antigo.anel != anel ||
      antigo.faiscas != faiscas ||
      antigo.cor != cor ||
      antigo.corAlternada != corAlternada;
}

/// Faixa de luz que atravessa a bola na diagonal. Recortada no círculo da
/// bola e pintada POR CIMA do giro: a luz vem de um ponto fixo, então ela
/// não pode rodar junto com o desenho.
class BrilhoBolaPainter extends CustomPainter {
  final double progresso;

  const BrilhoBolaPainter(this.progresso);

  @override
  void paint(Canvas canvas, Size size) {
    if (progresso <= 0 || progresso >= 1) return;
    final area = Offset.zero & size;
    canvas
      ..save()
      ..clipPath(Path()..addOval(area.deflate(size.width * 0.06)));
    // A faixa anda deslocando o retângulo do degradê, e não as paradas:
    // parada fora de 0..1 é descartada pelo CanvasKit e a luz sumia.
    // De ±0.7 da largura o meio da faixa vai de um canto ao outro, com
    // folga para ela entrar e sair inteira.
    final passo = (-0.7 + 1.4 * progresso) * size.width;
    final faixa = area.shift(Offset(passo, passo));
    canvas.drawRect(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.85),
            Colors.white.withValues(alpha: 0),
          ],
          stops: const [0.4, 0.5, 0.6],
        ).createShader(faixa),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(BrilhoBolaPainter antigo) => antigo.progresso != progresso;
}
