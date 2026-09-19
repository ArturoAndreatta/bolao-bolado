import 'package:flutter/material.dart';

/// Texto de número em que cada dígito que muda GIRA como a roleta de um
/// caça-níquel: passa por uma volta inteira de algarismos e desacelera até
/// parar no novo. Os dígitos param da esquerda para a direita, cada um um
/// pouco depois do anterior, como os rolos de uma máquina de sorteio.
///
/// Só os dígitos que mudaram giram — de R$ 126 para R$ 132 giram as dezenas
/// e as unidades, e o resto fica parado. Quando o valor sobe o rolo gira para
/// cima, quando desce gira para baixo.
///
/// Os caracteres são casados pela posição a partir da DIREITA: é assim que
/// unidade continua unidade quando o número ganha uma casa (de 9 para 10), em
/// vez de todos os dígitos escorregarem uma posição. Pontuação, espaço e
/// símbolo da moeda não giram.
///
/// Espera um [estilo] com dígitos tabulares (`FontFeature.tabularFigures`):
/// com largura variável, a linha tremeria de largura durante o giro.
class NumeroRolante extends StatefulWidget {
  final String texto;
  final double valor;
  final TextStyle estilo;

  const NumeroRolante({
    super.key,
    required this.texto,
    required this.valor,
    required this.estilo,
  });

  @override
  State<NumeroRolante> createState() => _NumeroRolanteState();
}

class _NumeroRolanteState extends State<NumeroRolante> {
  // Sentido do giro da última troca: subindo, o rolo gira para cima.
  bool _subindo = true;

  @override
  void didUpdateWidget(covariant NumeroRolante antigo) {
    super.didUpdateWidget(antigo);
    if (widget.valor != antigo.valor) _subindo = widget.valor > antigo.valor;
  }

  @override
  Widget build(BuildContext context) {
    final caracteres = widget.texto.characters.toList();
    final total = caracteres.length;
    return Semantics(
      // O leitor de tela lê o valor inteiro de uma vez, e não dígito a dígito.
      label: widget.texto,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < total; i++)
            KeyedSubtree(
              key: ValueKey(total - i),
              child: _ehDigito(caracteres[i])
                  ? _RoloDigito(
                      digito: int.parse(caracteres[i]),
                      subindo: _subindo,
                      // Posição da esquerda para a direita: define a ordem
                      // em que os rolos param.
                      ordem: i,
                      estilo: widget.estilo,
                    )
                  : Text(caracteres[i], style: widget.estilo),
            ),
        ],
      ),
    );
  }

  static bool _ehDigito(String c) =>
      c.codeUnitAt(0) >= 0x30 && c.codeUnitAt(0) <= 0x39;
}

/// Um rolo: posição contínua [_posicao] ao longo de uma fita de algarismos
/// sem fim (…8, 9, 0, 1…). O dígito na tela é `posição % 10`, e a parte
/// fracionária é o quanto o rolo está entre um algarismo e o seguinte.
class _RoloDigito extends StatefulWidget {
  final int digito;
  final bool subindo;
  final int ordem;
  final TextStyle estilo;

  const _RoloDigito({
    required this.digito,
    required this.subindo,
    required this.ordem,
    required this.estilo,
  });

  @override
  State<_RoloDigito> createState() => _RoloDigitoState();
}

class _RoloDigitoState extends State<_RoloDigito>
    with SingleTickerProviderStateMixin {
  // Um giro base mais um tempinho por rolo: o da esquerda para primeiro e os
  // seguintes vão parando em sequência.
  static const _duracaoBase = 520;
  static const _atrasoPorRolo = 45;
  static const _atrasoMaximo = 12;

  // Criado no initState, e NÃO preguiçosamente (`late final` com
  // inicializador): rolo que nunca girou só o criaria no dispose, e criar o
  // ticker ali consulta o TickerMode de uma árvore já desmontada — erro toda
  // vez que o número perde uma casa.
  late final AnimationController _controle;
  late double _posicao = widget.digito.toDouble();
  // Curva e trajeto do giro em andamento. Trocados a cada giro novo; o
  // listener é um só, registrado aqui, e lê sempre o trajeto atual.
  CurvedAnimation? _curva;
  Animation<double>? _giro;

  @override
  void initState() {
    super.initState();
    _controle = AnimationController(vsync: this)
      ..addListener(() {
        final giro = _giro;
        if (giro != null) setState(() => _posicao = giro.value);
      });
  }

  @override
  void didUpdateWidget(covariant _RoloDigito antigo) {
    super.didUpdateWidget(antigo);
    if (widget.digito == antigo.digito) return;

    // Parte de onde o rolo ESTÁ (mesmo no meio de outro giro, quando o + é
    // tocado várias vezes seguidas) e dá uma volta inteira a mais antes de
    // chegar no algarismo novo, no sentido da mudança do valor.
    final inicio = _posicao;
    final atual = inicio.round() % 10;
    final double fim;
    if (widget.subindo) {
      final passos = (widget.digito - atual) % 10;
      fim = inicio.roundToDouble() + passos + 10;
    } else {
      final passos = (atual - widget.digito) % 10;
      fim = inicio.roundToDouble() - passos - 10;
    }

    _controle.duration = Duration(
      milliseconds:
          _duracaoBase +
          _atrasoPorRolo * (widget.ordem.clamp(0, _atrasoMaximo)),
    );
    // Desacelera forte no fim, como um rolo mecânico perdendo embalo.
    _curva?.dispose();
    _curva = CurvedAnimation(parent: _controle, curve: Curves.easeOutQuart);
    _giro = Tween<double>(begin: inicio, end: fim).animate(_curva!);
    _controle.forward(from: 0);
  }

  @override
  void dispose() {
    _curva?.dispose();
    _controle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = _posicao.floor();
    final fracao = _posicao - base;
    final atual = base % 10;
    final seguinte = (base + 1) % 10;

    // ClipRect: só um algarismo aparece por vez, na "janelinha" do rolo. O
    // Text invisível dá a largura e a altura exatas de um algarismo; os dois
    // visíveis correm por cima dele.
    return ClipRect(
      child: Stack(
        children: [
          Opacity(opacity: 0, child: Text('0', style: widget.estilo)),
          Positioned.fill(
            child: FractionalTranslation(
              translation: Offset(0, -fracao),
              child: Text('$atual', style: widget.estilo),
            ),
          ),
          if (fracao > 0)
            Positioned.fill(
              child: FractionalTranslation(
                translation: Offset(0, 1 - fracao),
                child: Text('$seguinte', style: widget.estilo),
              ),
            ),
        ],
      ),
    );
  }
}
