import 'package:bolao_bolado/core/responsive.dart';
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

    final isMobile = Responsive.isMobile(context);

    if (isMobile) {
      final diasRestantes = dataSorteio?.difference(DateTime.now()).inDays;
      final dataFormatada = dataSorteio != null
          ? DateFormat('dd/MM/yyyy').format(dataSorteio!)
          : '—';
      final premioPorCota = totalCotas > 0 ? premioSala / totalCotas : 0.0;
      final premioPorCotaFormatado = NumberFormat.currency(
        locale: 'pt_BR',
        symbol: 'R\$',
      ).format(premioPorCota);

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BannerChance(percentual: chancePercentual, fracao: chanceFracao),
          const SizedBox(height: 10),
          CardPremioTotal(premioSala: premioSala, mobile: true),
          const SizedBox(height: 10),
          CardEstatisticaIcone(
            icone: Icons.paid_outlined,
            corIcone: const Color(0xFF2E7D32),
            corFundoIcone: const Color(0xFFE3F3E9),
            titulo: 'Prêmio por Cota',
            valor: premioPorCotaFormatado,
            corValor: const Color(0xFF2E7D32),
          ),
          const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: CardEstatisticaIcone(
                    icone: Icons.local_activity_outlined,
                    corIcone: const Color(0xFFCB8A2C),
                    corFundoIcone: const Color(0xFFFBEED9),
                    titulo: 'Cotas',
                    valor: totalCotas.toString(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CardEstatisticaIcone(
                    icone: Icons.people_alt_outlined,
                    corIcone: const Color(0xFF487DE5),
                    corFundoIcone: const Color(0xFFE1E9FB),
                    titulo: 'Jogadores',
                    valor: rows.length.toString(),
                    corValor: const Color(0xFF487DE5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          CardEstatisticaIcone(
            icone: Icons.calendar_month_outlined,
            corIcone: const Color(0xFF7C5CD9),
            corFundoIcone: const Color(0xFFEAE3F8),
            titulo: 'Data do Sorteio',
            valor: dataFormatada,
            rodape: diasRestantes != null && diasRestantes >= 0
                ? 'Em $diasRestantes dias'
                : null,
          ),
        ],
      );
    }

    final cardChance = CardEstatistica(
      destaque: true,
      icone: Icons.emoji_events_outlined,
      titulo: 'Chance de ganhar',
      valor: '$chancePercentual%',
      fontSizeValor: 26,
      infoTooltip: 'Sua chance é calculada com base no total de cotas.',
      valorWidget: ChanceFracaoReveal(
        percentual: chancePercentual,
        fracao: chanceFracao,
        percentualStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1F2937),
        ),
        fracaoStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade600,
        ),
      ),
    );
    final cardCotas = CardEstatistica(
      titulo: 'Cotas',
      fontSizeValor: 20,
      valor: totalCotas.toString(),
    );
    final cardPremio = CardPremioTotal(premioSala: premioSala, mobile: false);
    final cardJogadores = CardEstatistica(
      titulo: 'Jogadores',
      valor: rows.length.toString(),
      fontSizeValor: 20,
      corValor: const Color(0xFF487DE5),
    );

    final cards = [cardChance, cardPremio, cardCotas, cardJogadores];
    const flexes = [2, 2, 1, 1];

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            Expanded(flex: flexes[i], child: cards[i]),
            if (i != cards.length - 1) const SizedBox(width: 12),
          ],
        ],
      ),
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
  final bool mobile;

  const CardPremioTotal({
    super.key,
    required this.premioSala,
    required this.mobile,
  });

  @override
  State<CardPremioTotal> createState() => _CardPremioTotalState();
}

class _CardPremioTotalState extends State<CardPremioTotal> {
  static final _formatoMoeda = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
  );

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
    final valor = _formatoMoeda.format(_premioExibido);

    return RepaintBoundary(
      child: widget.mobile
          ? CardEstatisticaIcone(
              icone: Icons.savings_outlined,
              corIcone: const Color(0xFF2E7D32),
              corFundoIcone: const Color(0xFFE3F3E9),
              titulo: 'Prêmio Total',
              valor: valor,
              corValor: const Color(0xFF2E7D32),
            )
          : CardEstatistica(
              titulo: 'Prêmio Total',
              fontSizeValor: 19,
              valor: valor,
              corValor: const Color(0xFF2E7D32),
            ),
    );
  }
}

class ChanceFracaoReveal extends StatefulWidget {
  final String percentual;
  final String fracao;
  final TextStyle percentualStyle;
  final TextStyle fracaoStyle;

  const ChanceFracaoReveal({
    super.key,
    required this.percentual,
    required this.fracao,
    required this.percentualStyle,
    required this.fracaoStyle,
  });

  @override
  State<ChanceFracaoReveal> createState() => _ChanceFracaoRevealState();
}

class _ChanceFracaoRevealState extends State<ChanceFracaoReveal> {
  bool _revelado = false;

  void _toggle() => setState(() => _revelado = !_revelado);

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _revelado = true),
      onExit: (_) => setState(() => _revelado = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _toggle,
        child: Column(
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
        ),
      ),
    );
  }
}

class BannerChance extends StatelessWidget {
  final String percentual;
  final String fracao;

  const BannerChance({
    super.key,
    required this.percentual,
    required this.fracao,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF4E3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF2D9A8), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFFBEED9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.emoji_events_outlined,
              size: 22,
              color: Color(0xFFCB8A2C),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Chance de ganhar',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF8A6116),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Tooltip(
                      message:
                          'Sua chance é calculada com base no total de cotas.',
                      child: Icon(
                        Icons.info_outline,
                        size: 13,
                        color: const Color(0xFF8A6116).withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ChanceFracaoReveal(
                  percentual: percentual,
                  fracao: fracao,
                  percentualStyle: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2937),
                  ),
                  fracaoStyle: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CardEstatisticaIcone extends StatelessWidget {
  final IconData icone;
  final Color corIcone;
  final Color corFundoIcone;
  final String titulo;
  final String valor;
  final Color? corValor;
  final String? rodape;

  const CardEstatisticaIcone({
    super.key,
    required this.icone,
    required this.corIcone,
    required this.corFundoIcone,
    required this.titulo,
    required this.valor,
    this.corValor,
    this.rodape,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEFEFE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: corFundoIcone,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icone, size: 22, color: corIcone),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  titulo,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Text(
                  valor,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: corValor ?? const Color(0xFF1F2937),
                  ),
                ),
                if (rodape != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAE3F8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      rodape!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF7C5CD9),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CardEstatistica extends StatelessWidget {
  final String titulo;
  final String valor;
  final bool destaque;
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
    this.icone,
    this.corValor,
    this.infoTooltip,
    this.fontSizeValor = 24,
    this.valorWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: destaque ? const Color(0xFFFDF4E3) : const Color(0xFFFEFEFE),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: destaque ? const Color(0xFFF2D9A8) : const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icone != null) ...[
                Icon(icone, size: 18, color: const Color(0xFFCB8A2C)),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  titulo,
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: destaque
                        ? const Color(0xFF8A6116)
                        : Colors.grey.shade600,
                  ),
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
            ],
          ),
          const SizedBox(height: 6),
          valorWidget ??
              Text(
                valor,
                softWrap: true,
                style: TextStyle(
                  fontSize: fontSizeValor,
                  fontWeight: FontWeight.w700,
                  color: corValor ?? const Color(0xFF1F2937),
                ),
              ),
        ],
      ),
    );
  }
}
