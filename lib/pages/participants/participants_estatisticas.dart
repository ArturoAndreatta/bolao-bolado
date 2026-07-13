import 'dart:async';

import 'package:bolao_bolado/components/formatters/formatters.dart';
import 'package:bolao_bolado/core/app_radii.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Probabilidade de acertar as 6 dezenas da Mega-Sena com um único jogo (1 em 50.063.860).
const double probabilidadeMega = 1 / 50063860;

/// Probabilidade de acertar as 15 dezenas da Lotofácil com um único jogo (1 em 3.268.760).
const double probabilidadeLotofacil = 1 / 3268760;

class PainelEstatisticas extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final String? currentUid;
  final String? sorteio;
  final DateTime? dataSorteio;
  final double premioSala;

  const PainelEstatisticas({
    super.key,
    required this.rows,
    required this.currentUid,
    this.sorteio,
    this.dataSorteio,
    this.premioSala = 0,
  });

  @override
  Widget build(BuildContext context) {
    final totalCotas = rows.fold<int>(
      0,
      (soma, item) => soma + ((item['cotas'] as num?)?.toInt() ?? 0),
    );
    final probabilidadeJogo = sorteio == 'lotofacil'
        ? probabilidadeLotofacil
        : probabilidadeMega;

    // Cada cota representa um jogo apostado no bolão, então a chance do
    // BOLÃO (todos os participantes juntos) é o total de cotas vezes a
    // probabilidade de acerto de um único jogo no tipo de sorteio da sala.
    final chance = totalCotas > 0 ? totalCotas * probabilidadeJogo : 0.0;
    final chancePercentualValor = chance * 100;
    final chancePercentual = chancePercentualValor == 0
        ? '0'
        : chancePercentualValor.toStringAsFixed(8);
    final chanceFracao = chance > 0
        ? '1 em ${NumberFormat.decimalPattern('pt_BR').format((1 / chance).round())}'
        : '0 em 0';

    final cardChance = CardEstatistica(
      destaque: true,
      titulo: 'Chance de Ganhar',
      valor: '$chancePercentual%',
      fontSizeValor: 16,
      valorWidget: ChanceFracaoReveal(
        percentual: chancePercentual,
        fracao: chanceFracao,
        horizontal: true,
        percentualStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1F2937),
        ),
        fracaoStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade600,
        ),
      ),
    );
    final cardPremio = CardPremioTotal(premioSala: premioSala);
    final premioPorCota = totalCotas > 0 ? premioSala / totalCotas : 0.0;
    final cardPremioPorCota = CardEstatistica(
      destaque: true,
      destaqueCor: DestaqueCor.azul,
      titulo: 'Prêmio por Cota',
      fontSizeValor: 15,
      valor: Formatters.moeda.format(premioPorCota),
    );

    final cards = [cardPremio, cardPremioPorCota, cardChance];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Abaixo dessa largura os cards espremidos lado a lado cortam texto;
        // empilha em coluna para manter cada card legível.
        if (constraints.maxWidth < 815) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                cards[i],
                if (i != cards.length - 1) const SizedBox(height: 10),
              ],
            ],
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                Expanded(child: cards[i]),
                if (i != cards.length - 1) const SizedBox(width: 12),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Card de "Prêmio Total" isolado dos demais indicadores.
///
/// O prêmio só muda quando o campo `premio` da sala é editado pelo admin —
/// nunca por causa de uma aposta sendo criada/editada/removida. Por isso,
/// este widget reconstrói apenas quando [premioSala] muda de valor, mesmo
/// que o painel de estatísticas como um todo seja reconstruído a cada
/// evento do stream de apostas.
class CardPremioTotal extends StatefulWidget {
  final double premioSala;

  const CardPremioTotal({super.key, required this.premioSala});

  @override
  State<CardPremioTotal> createState() => _CardPremioTotalState();
}

class _CardPremioTotalState extends State<CardPremioTotal> {
  late double _premioExibido = widget.premioSala;

  @override
  void didUpdateWidget(covariant CardPremioTotal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.premioSala != _premioExibido) {
      _premioExibido = widget.premioSala;
    }
  }

  @override
  Widget build(BuildContext context) {
    final valor = Formatters.moeda.format(_premioExibido);

    return RepaintBoundary(
      child: CardEstatistica(
        destaque: true,
        destaqueCor: DestaqueCor.verde,
        titulo: 'Prêmio Total',
        fontSizeValor: 15,
        valor: valor,
      ),
    );
  }
}

class ChanceFracaoReveal extends StatefulWidget {
  final String percentual;
  final String fracao;
  final TextStyle percentualStyle;
  final TextStyle fracaoStyle;
  final bool horizontal;

  const ChanceFracaoReveal({
    super.key,
    required this.percentual,
    required this.fracao,
    required this.percentualStyle,
    required this.fracaoStyle,
    this.horizontal = false,
  });

  @override
  State<ChanceFracaoReveal> createState() => _ChanceFracaoRevealState();
}

class _ChanceFracaoRevealState extends State<ChanceFracaoReveal> {
  bool _revelado = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) setState(() => _revelado = !_revelado);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.horizontal
        ? AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            layoutBuilder: (currentChild, previousChildren) => Stack(
              alignment: Alignment.centerRight,
              children: [
                ...previousChildren,
                if (currentChild != null) currentChild,
              ],
            ),
            child: _revelado
                ? Text(
                    widget.fracao,
                    key: const ValueKey('fracao'),
                    style: widget.percentualStyle,
                  )
                : Text(
                    '${widget.percentual}%',
                    key: const ValueKey('percentual'),
                    style: widget.percentualStyle,
                  ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${widget.percentual}%', style: widget.percentualStyle),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                layoutBuilder: (currentChild, previousChildren) =>
                    currentChild ?? const SizedBox.shrink(),
                child: _revelado
                    ? Padding(
                        key: const ValueKey('fracao'),
                        padding: EdgeInsets.zero,
                        child: Text(widget.fracao, style: widget.fracaoStyle),
                      )
                    : const SizedBox.shrink(key: ValueKey('vazio')),
              ),
            ],
          );
  }
}

enum DestaqueCor { amarelo, verde, azul }

class CardEstatistica extends StatelessWidget {
  final String titulo;
  final String valor;
  final bool destaque;
  final DestaqueCor destaqueCor;
  final IconData? icone;
  final Color? corValor;
  final String? infoTooltip;
  final double fontSizeValor;
  final Widget? valorWidget;

  const CardEstatistica({
    super.key,
    required this.titulo,
    required this.valor,
    this.destaque = false,
    this.destaqueCor = DestaqueCor.amarelo,
    this.icone,
    this.corValor,
    this.infoTooltip,
    this.fontSizeValor = 24,
    this.valorWidget,
  });

  @override
  Widget build(BuildContext context) {
    final corFundo = !destaque
        ? const Color(0xFFFEFEFE)
        : destaqueCor == DestaqueCor.verde
        ? const Color(0xFFE3F3E9)
        : destaqueCor == DestaqueCor.azul
        ? const Color(0xFFE3EDF8)
        : const Color(0xFFFDF4E3);
    final corBorda = !destaque
        ? const Color(0xFFE5E7EB)
        : destaqueCor == DestaqueCor.verde
        ? const Color(0xFFBFE0CB)
        : destaqueCor == DestaqueCor.azul
        ? const Color(0xFFBBD3EC)
        : const Color(0xFFF2D9A8);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: corFundo,
        borderRadius: AppRadii.circularSmd,
        border: Border.all(color: corBorda, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icone != null) ...[
            Icon(icone, size: 18, color: const Color(0xFFCB8A2C)),
            const SizedBox(width: 6),
          ],
          Text(
            titulo,
            softWrap: false,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: !destaque
                  ? Colors.grey.shade600
                  : destaqueCor == DestaqueCor.verde
                  ? const Color(0xFF2E7D32)
                  : destaqueCor == DestaqueCor.azul
                  ? const Color(0xFF2A5C94)
                  : const Color(0xFF8A6116),
            ),
          ),
          if (infoTooltip != null) ...[
            const SizedBox(width: 4),
            Tooltip(
              message: infoTooltip!,
              child: Icon(
                Icons.info_outline,
                size: 15,
                color: Colors.grey.shade500,
              ),
            ),
          ],
          const SizedBox(width: 10),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child:
                  valorWidget ??
                  Text(
                    valor,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: fontSizeValor,
                      fontWeight: FontWeight.w700,
                      color: corValor ?? const Color(0xFF1F2937),
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
