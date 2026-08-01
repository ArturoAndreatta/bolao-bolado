import 'package:bolao_bolado/components/formatters/formatters.dart';
import 'package:bolao_bolado/components/shared/selo_manual.dart';
import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/core/app_radii.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Larguras fixas de cada coluna
const double wNome = 250;
const double wValor = 135;
const double wCotas = 100;
const double wPremio = 198;
const double wData = 190;
const double larguraTotal = wNome + wValor + wCotas + wPremio + wData;

// Compara o valor apostado atual de um uid com o último visto e já atualiza
// o registro em `conhecidos`. Usado para decidir se uma linha deve animar a
// entrada (uid inédito, ou mesmo uid com valor diferente = aposta alterada).
// Comparar por valor (não por timestamp) evita animar de novo quando o
// usuário só reabre/reenvia o formulário sem mudar a quantia.
bool detectarLinhaNova(
  Map<String, Object?> conhecidos,
  String? uid,
  Object? valorAtual,
) {
  if (uid == null) return false;
  final valorConhecido = conhecidos[uid];
  final isNova = !conhecidos.containsKey(uid) || valorConhecido != valorAtual;
  conhecidos[uid] = valorAtual;
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

  // As cores da tabela deixaram de ser `static const` com o dark mode: cada
  // uma vem da paleta do tema ativo (zebra, borda e cabeçalho).
  static Color corLinhaA(BuildContext c) => AppCores.de(c).linhaPar;
  static Color corLinhaB(BuildContext c) => AppCores.de(c).linhaImpar;
  static Color corBorda(BuildContext c) => AppCores.de(c).borda;
  static Color corCabecalho(BuildContext c) => AppCores.de(c).superficieAlta;

  /// Fundo de uma linha verificada / editada após verificação.
  ///
  /// No CLARO devolve o pastel de sempre (verde/âmbar), que sobre branco é
  /// discreto. No ESCURO devolve a própria zebra: lá o estado é comunicado
  /// pela barra lateral ([corBarraEstado]), porque pintar a linha inteira
  /// transformava a tabela num tabuleiro de faixas que competia com os dados.
  static Color corLinhaEstado(
    BuildContext c, {
    required bool verificada,
    required bool alterada,
    required bool isPar,
  }) {
    final cores = AppCores.de(c);
    if (cores.escuro || (!verificada && !alterada)) {
      return isPar ? cores.linhaPar : cores.linhaImpar;
    }
    return alterada ? cores.fundoAmarelo : cores.fundoVerde;
  }

  /// Cor da barra lateral de estado, ou `null` quando a linha não tem estado
  /// (ou quando o tema comunica o estado pelo fundo, como no claro).
  static Color? corBarraEstado(
    BuildContext c, {
    required bool verificada,
    required bool alterada,
  }) {
    final cores = AppCores.de(c);
    if (cores.larguraBarraEstado == 0) return null;
    if (alterada) return cores.dourado;
    if (verificada) return cores.verde;
    return null;
  }

  @override
  State<TabelaApostas> createState() => _TabelaApostasState();
}

class _TabelaApostasState extends State<TabelaApostas> {
  // Último `data-hora` (ms) visto para cada uid: usado para saber quais
  // linhas são novas (uid inédito) ou foram recriadas/reenviadas (mesmo uid,
  // timestamp diferente), e por isso devem animar a entrada. Evita reanimar
  // a cada rebuild quando nada mudou.
  final Map<String, Object?> _valoresConhecidos = {};

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
    final corBorda = TabelaApostas.corBorda(context);

    final tabela = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        constraints: const BoxConstraints(minWidth: larguraTotal),
        decoration: BoxDecoration(
          border: Border.all(color: corBorda, width: 1.5),
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
            Divider(height: 1, thickness: 1, color: corBorda),
            if (alturaFixa)
              Expanded(
                child: SingleChildScrollView(
                  child: _corpoTabela(context, formatoMoeda),
                ),
              )
            else if (mensagemVazio == null)
              _corpoTabela(context, formatoMoeda),
            if (mensagemVazio == null) ...[
              Divider(height: 1, thickness: 1, color: corBorda),
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

  Widget _corpoTabela(BuildContext context, NumberFormat formatoMoeda) {
    final corBorda = TabelaApostas.corBorda(context);
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
            final isManual = item['criadoPeloAdmin'] == true;
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
            final isNova = detectarLinhaNova(_valoresConhecidos, uid, valor);

            // Prioridade visual: edição pós-verificação > verificado > zebra
            // (par/ímpar). No escuro o estado não pinta o fundo — vira a
            // barra lateral montada logo abaixo (ver corBarraEstado).
            final corBarra = TabelaApostas.corBarraEstado(
              context,
              verificada: isVerificado,
              alterada: isAlterada,
            );

            return LinhaEntrandoAnimada(
              key: ValueKey('$uid-${tsAtual ?? index}'),
              animar: isNova,
              corBase: TabelaApostas.corLinhaEstado(
                context,
                verificada: isVerificado,
                alterada: isAlterada,
                isPar: isPar,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    color: Colors.transparent,
                    // A barra entra como borda esquerda do próprio Container
                    // da linha (não como um filho da Row): assim ela ocupa a
                    // altura real da linha, sem depender de IntrinsicHeight
                    // nem alterar as larguras fixas das colunas.
                    foregroundDecoration: corBarra == null
                        ? null
                        : BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                color: corBarra,
                                width: AppCores.de(context).larguraBarraEstado,
                              ),
                            ),
                          ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CelulaLinha(
                          texto: nome,
                          width: wNome,
                          alinhamento: TextAlign.left,
                          negrito: isUsuarioLogado,
                          sufixo: isManual
                              ? const SeloManual(tamanhoFonte: 9)
                              : null,
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
                    Divider(height: 1, thickness: 1, color: corBorda),
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
                      AppCores.de(context).linhaNova,
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
      color: TabelaApostas.corCabecalho(context),
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
      color: TabelaApostas.corCabecalho(context),
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
    final cores = AppCores.de(context);
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
              : BoxDecoration(
                  border: Border(
                    right: BorderSide(color: cores.borda, width: 1),
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
                  color: cores.azul,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                texto,
                textAlign: alinhamento,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: ativa ? cores.azul : cores.texto,
                ),
              ),
              if (alinhamento == TextAlign.left && ativa) ...[
                const SizedBox(width: 4),
                Icon(
                  ascendente ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 12,
                  color: cores.azul,
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

  /// Widget opcional colado à direita do texto (ex.: o selo de aposta
  /// manual). Fica dentro da célula para herdar borda e padding dela.
  final Widget? sufixo;

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
    this.sufixo,
  });

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    return Container(
      width: width,
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: paddingVertical),
      decoration: isLast
          ? null
          : BoxDecoration(
              border: Border(right: BorderSide(color: cores.borda, width: 1)),
            ),
      child: _comSufixo(
        Text(
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
                ? cores.textoVerde
                : subTexto
                ? cores.textoFraco
                : cores.texto,
          ),
        ),
      ),
    );
  }

  /// Sem sufixo devolve o texto puro, preservando o comportamento de largura
  /// fixa das demais colunas. Com sufixo, o texto passa a ser Flexible para
  /// encolher com reticências em vez de estourar a largura da célula.
  Widget _comSufixo(Widget texto) {
    if (sufixo == null) return texto;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: texto),
        const SizedBox(width: 6),
        sufixo!,
      ],
    );
  }
}
