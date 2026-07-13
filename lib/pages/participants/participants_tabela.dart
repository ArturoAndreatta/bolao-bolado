import 'package:bolao_bolado/components/formatters/formatters.dart';
import 'package:bolao_bolado/core/app_radii.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Larguras fixas de cada coluna
const double wNome = 250;
const double wValor = 135;
const double wCotas = 100;
const double wPremio = 170;
const double wData = 190;
const double larguraTotal = wNome + wValor + wCotas + wPremio + wData;

// Compara o timestamp atual de um uid com o último visto e já atualiza o
// registro em `conhecidos`. Usado para decidir se uma linha deve animar a
// entrada (uid inédito, ou mesmo uid com timestamp diferente = reenviado).
bool detectarLinhaNova(
  Map<String, int?> conhecidos,
  String? uid,
  int? tsAtual,
) {
  if (uid == null) return false;
  final tsConhecido = conhecidos[uid];
  final isNova = !conhecidos.containsKey(uid) || tsConhecido != tsAtual;
  conhecidos[uid] = tsAtual;
  return isNova;
}

class TabelaApostas extends StatefulWidget {
  final List<Map<String, dynamic>> rows;
  final int colunaOrdenada;
  final bool ascendente;
  final void Function(int) onCabecalhoTap;
  final String? currentUid;
  final Widget? mensagemVazio;
  // Usado no card desktop, onde a tabela precisa ocupar o espaço disponível
  // e rolar internamente; no mobile a tabela cresce com o conteúdo.
  final bool alturaFixa;

  const TabelaApostas({
    super.key,
    required this.rows,
    required this.colunaOrdenada,
    required this.ascendente,
    required this.onCabecalhoTap,
    required this.currentUid,
    this.mensagemVazio,
    this.alturaFixa = false,
  });

  static const _corLinhaA = Color(0xFFFEFEFE);
  static const _corLinhaB = Color(0xFFF3F4F6);
  static const _corLinhaVerificada = Color(0xFFDCFCE7);
  static const _corLinhaAlterada = Color(0xFFFEF3C7);
  static const _corBorda = Color(0xFFE5E7EB);
  static const _corCabecalho = Color(0xFFE9EAEC);

  @override
  State<TabelaApostas> createState() => _TabelaApostasState();
}

class _TabelaApostasState extends State<TabelaApostas> {
  // Último `data-hora` (ms) visto para cada uid: usado para saber quais
  // linhas são novas (uid inédito) ou foram recriadas/reenviadas (mesmo uid,
  // timestamp diferente), e por isso devem animar a entrada. Evita reanimar
  // a cada rebuild quando nada mudou.
  final Map<String, int?> _timestampsConhecidos = {};

  List<Map<String, dynamic>> get rows => widget.rows;
  int get colunaOrdenada => widget.colunaOrdenada;
  bool get ascendente => widget.ascendente;
  void Function(int) get onCabecalhoTap => widget.onCabecalhoTap;
  String? get currentUid => widget.currentUid;
  Widget? get mensagemVazio => widget.mensagemVazio;
  bool get alturaFixa => widget.alturaFixa;

  @override
  Widget build(BuildContext context) {
    final formatoMoeda = Formatters.moeda;

    final tabela = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        constraints: const BoxConstraints(minWidth: larguraTotal),
        decoration: BoxDecoration(
          border: Border.all(color: TabelaApostas._corBorda, width: 1.5),
          borderRadius: AppRadii.circularSmd,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: alturaFixa ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CabecalhoTabela(
              colunaOrdenada: colunaOrdenada,
              ascendente: ascendente,
              onCabecalhoTap: onCabecalhoTap,
            ),
            const Divider(
              height: 1,
              thickness: 1,
              color: TabelaApostas._corBorda,
            ),
            if (alturaFixa)
              Expanded(
                child: SingleChildScrollView(child: _corpoTabela(formatoMoeda)),
              )
            else if (mensagemVazio == null)
              _corpoTabela(formatoMoeda),
            if (mensagemVazio == null) ...[
              const Divider(
                height: 1,
                thickness: 1,
                color: TabelaApostas._corBorda,
              ),
              RodapeTotalizador(rows: rows, formatoMoeda: formatoMoeda),
            ],
          ],
        ),
      ),
    );

    if (mensagemVazio == null) {
      return tabela;
    }

    if (alturaFixa) {
      return Stack(
        children: [
          tabela,
          Positioned.fill(child: Center(child: mensagemVazio!)),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(child: mensagemVazio!),
    );
  }

  Widget _corpoTabela(NumberFormat formatoMoeda) {
    return SelectionArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...rows.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isPar = index % 2 == 0;
            final isUsuarioLogado = item['uid'] == currentUid;
            final isVerificado = item['verificado'] == true;
            final isAlterada = item['editadoAposVerificacao'] == true;
            final uid = item['uid']?.toString();

            final nome = item['nome']?.toString() ?? '—';
            final valor = (item['valor'] as num?)?.toDouble() ?? 0;
            final cotas = (item['cotas'] as num?)?.toInt() ?? 0;
            final premio = (item['premio'] as num?)?.toDouble() ?? 0;
            final dataHora = item['data-hora'];

            String dataFormatada = '—';
            if (dataHora != null && dataHora is Timestamp) {
              dataFormatada = Formatters.dataHoraAno2.format(dataHora.toDate());
            }

            final tsAtual = dataHora is Timestamp
                ? dataHora.millisecondsSinceEpoch
                : null;
            final isNova = detectarLinhaNova(
              _timestampsConhecidos,
              uid,
              tsAtual,
            );

            // Prioridade visual: edição pós-verificação > verificado > zebra (par/ímpar)
            return LinhaEntrandoAnimada(
              key: ValueKey('$uid-${tsAtual ?? index}'),
              animar: isNova,
              corBase: isAlterada
                  ? TabelaApostas._corLinhaAlterada
                  : isVerificado
                  ? TabelaApostas._corLinhaVerificada
                  : (isPar
                        ? TabelaApostas._corLinhaA
                        : TabelaApostas._corLinhaB),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    color: Colors.transparent,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CelulaLinha(
                          texto: nome,
                          width: wNome,
                          alinhamento: TextAlign.left,
                          negrito: isUsuarioLogado,
                        ),
                        CelulaLinha(
                          texto: formatoMoeda.format(valor),
                          width: wValor,
                          alinhamento: TextAlign.right,
                        ),
                        CelulaLinha(
                          texto: cotas.toString(),
                          width: wCotas,
                          alinhamento: TextAlign.right,
                        ),
                        CelulaLinha(
                          texto: formatoMoeda.format(premio),
                          width: wPremio,
                          alinhamento: TextAlign.right,
                          destaque: true,
                        ),
                        CelulaLinha(
                          texto: dataFormatada,
                          width: wData,
                          alinhamento: TextAlign.right,
                          subTexto: true,
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
                  if (index < rows.length - 1)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: TabelaApostas._corBorda,
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Anima a entrada de uma linha recém-adicionada (nova aposta chegando via
/// stream em tempo real): fade-in + leve deslizamento vertical + destaque
/// temporário de fundo que se dissolve suavemente.
///
/// Quando [animar] é falso, o child é exibido direto, sem custo de animação
/// — assim apenas a linha nova paga o preço da transição, e a tabela toda
/// não é reconstruída/reanimada a cada emissão do stream.
class LinhaEntrandoAnimada extends StatefulWidget {
  final Widget child;
  final bool animar;
  final Color corBase;

  const LinhaEntrandoAnimada({
    super.key,
    required this.child,
    required this.animar,
    required this.corBase,
  });

  @override
  State<LinhaEntrandoAnimada> createState() => _LinhaEntrandoAnimadaState();
}

class _LinhaEntrandoAnimadaState extends State<LinhaEntrandoAnimada>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  );

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.7, curve: Curves.easeOut),
  );
  late final Animation<double> _slide = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  late final Animation<double> _destaque = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.15, 1, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animar) {
      _controller.forward();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animar) {
      return DecoratedBox(
        decoration: BoxDecoration(color: widget.corBase),
        child: widget.child,
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: _slide.value,
            child: Opacity(
              opacity: _fade.value,
              child: Transform.translate(
                offset: Offset(0, (1 - _slide.value) * -8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color.lerp(
                      const Color(0xFFBFDDFB),
                      widget.corBase,
                      _destaque.value,
                    ),
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Rodapé fixo da tabela com o total de "Valor" e "Cotas", alinhado às
/// mesmas larguras de coluna do corpo/cabeçalho.
class RodapeTotalizador extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final NumberFormat formatoMoeda;

  const RodapeTotalizador({
    super.key,
    required this.rows,
    required this.formatoMoeda,
  });

  @override
  Widget build(BuildContext context) {
    final totalValor = rows.fold<double>(
      0,
      (soma, item) => soma + ((item['valor'] as num?)?.toDouble() ?? 0),
    );
    final totalCotas = rows.fold<int>(
      0,
      (soma, item) => soma + ((item['cotas'] as num?)?.toInt() ?? 0),
    );

    return Container(
      color: TabelaApostas._corCabecalho,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CelulaLinha(
            texto:
                '${rows.length} ${rows.length == 1 ? 'participante' : 'participantes'}',
            width: wNome,
            alinhamento: TextAlign.left,
            paddingVertical: 4,
            fontSize: 12,
          ),
          CelulaLinha(
            texto: formatoMoeda.format(totalValor),
            width: wValor,
            alinhamento: TextAlign.right,
            negrito: true,
            paddingVertical: 4,
            fontSize: 12,
          ),
          CelulaLinha(
            texto: totalCotas.toString(),
            width: wCotas,
            alinhamento: TextAlign.right,
            negrito: true,
            paddingVertical: 4,
            fontSize: 12,
          ),
          CelulaLinha(
            texto: '',
            width: wPremio,
            alinhamento: TextAlign.right,
            paddingVertical: 4,
            fontSize: 12,
          ),
          CelulaLinha(
            texto: '',
            width: wData,
            alinhamento: TextAlign.right,
            isLast: true,
            paddingVertical: 4,
            fontSize: 12,
          ),
        ],
      ),
    );
  }
}

class CabecalhoTabela extends StatelessWidget {
  final int colunaOrdenada;
  final bool ascendente;
  final void Function(int) onCabecalhoTap;

  const CabecalhoTabela({
    super.key,
    required this.colunaOrdenada,
    required this.ascendente,
    required this.onCabecalhoTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: TabelaApostas._corCabecalho,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CelulaCabecalho(
            texto: 'Nome',
            width: wNome,
            alinhamento: TextAlign.left,
            indice: 0,
            colunaOrdenada: colunaOrdenada,
            ascendente: ascendente,
            onTap: onCabecalhoTap,
          ),
          CelulaCabecalho(
            texto: 'Valor',
            width: wValor,
            alinhamento: TextAlign.right,
            indice: 1,
            colunaOrdenada: colunaOrdenada,
            ascendente: ascendente,
            onTap: onCabecalhoTap,
          ),
          CelulaCabecalho(
            texto: 'Cotas',
            width: wCotas,
            alinhamento: TextAlign.right,
            indice: 2,
            colunaOrdenada: colunaOrdenada,
            ascendente: ascendente,
            onTap: onCabecalhoTap,
          ),
          CelulaCabecalho(
            texto: 'Prêmio',
            width: wPremio,
            alinhamento: TextAlign.right,
            indice: 3,
            colunaOrdenada: colunaOrdenada,
            ascendente: ascendente,
            onTap: onCabecalhoTap,
          ),
          CelulaCabecalho(
            texto: 'Última Alteração',
            width: wData,
            alinhamento: TextAlign.right,
            indice: 4,
            colunaOrdenada: colunaOrdenada,
            ascendente: ascendente,
            onTap: onCabecalhoTap,
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class CelulaCabecalho extends StatelessWidget {
  final String texto;
  final double width;
  final TextAlign alinhamento;
  final int indice;
  final int colunaOrdenada;
  final bool ascendente;
  final void Function(int) onTap;
  final bool isLast;

  const CelulaCabecalho({
    super.key,
    required this.texto,
    required this.width,
    required this.alinhamento,
    required this.indice,
    required this.colunaOrdenada,
    required this.ascendente,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final ativa = colunaOrdenada == indice;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(indice),
        child: Container(
          width: width,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: isLast
              ? null
              : const BoxDecoration(
                  border: Border(
                    right: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                  ),
                ),
          child: Row(
            mainAxisAlignment: alinhamento == TextAlign.right
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              if (alinhamento == TextAlign.right && ativa) ...[
                Icon(
                  ascendente ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 12,
                  color: const Color(0xFF487DE5),
                ),
                const SizedBox(width: 4),
              ],
              Text(
                texto,
                textAlign: alinhamento,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: ativa
                      ? const Color(0xFF487DE5)
                      : const Color(0xFF1F2937),
                ),
              ),
              if (alinhamento == TextAlign.left && ativa) ...[
                const SizedBox(width: 4),
                Icon(
                  ascendente ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 12,
                  color: const Color(0xFF487DE5),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class CelulaLinha extends StatelessWidget {
  final String texto;
  final double width;
  final TextAlign alinhamento;
  final bool destaque;
  final bool subTexto;
  final bool isLast;
  final bool negrito;
  final double paddingVertical;
  final double fontSize;

  const CelulaLinha({
    super.key,
    required this.texto,
    required this.width,
    required this.alinhamento,
    this.destaque = false,
    this.subTexto = false,
    this.isLast = false,
    this.negrito = false,
    this.paddingVertical = 7,
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: paddingVertical),
      decoration: isLast
          ? null
          : const BoxDecoration(
              border: Border(
                right: BorderSide(color: Color(0xFFE5E7EB), width: 1),
              ),
            ),
      child: Text(
        texto,
        textAlign: alinhamento,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: destaque
              ? FontWeight.w600
              : negrito
              ? FontWeight.w700
              : FontWeight.w400,
          color: destaque
              ? const Color(0xFF2E7D32)
              : subTexto
              ? Colors.grey
              : const Color(0xFF1F2937),
        ),
      ),
    );
  }
}
