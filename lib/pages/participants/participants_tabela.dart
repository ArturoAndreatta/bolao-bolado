import 'dart:math' as math;

import 'package:bolao_bolado/components/formatters/formatters.dart';
import 'package:bolao_bolado/components/shared/selo_manual.dart';
import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/core/app_radii.dart';
import 'package:bolao_bolado/core/debug_flags.dart';
import 'package:bolao_bolado/pages/participants/participants_estilo_entrada.dart';
import 'package:bolao_bolado/pages/participants/participants_reordenacao.dart';
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

/// Altura de uma linha do corpo da tabela, incluindo o divisor.
///
/// É uma constante — e não uma medida — porque o corpo do desktop usa
/// `ListView.builder` com `itemExtent`: informar a altura é o que permite
/// montar só as linhas visíveis sem medir as demais. A altura é previsível
/// porque toda célula tem fonte 13, uma única linha de texto (nome usa
/// ellipsis, não quebra) e padding vertical 7.
///
/// O valor foi MEDIDO, não deduzido: 19 de texto + 7*2 de padding + 1 do
/// divisor. Há um teste que compara esta constante com a altura realmente
/// renderizada ([test/pages/participants/altura_linha_tabela_test.dart]) — se
/// algum padding ou tamanho de fonte mudar aqui, ele quebra em vez de a
/// tabela desalinhar silenciosamente.
const double kAlturaLinhaTabela = 34;

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

/// Descarta de `conhecidos` os uids que não estão mais em `rows`.
///
/// Sem isso o mapa só cresce, e — pior — um participante removido e recriado
/// com o mesmo valor não voltaria a animar, porque seu uid continuaria
/// registrado com o valor antigo. Aparece na prática com o simulador de
/// apostas, que remove e recria participantes fake o tempo todo.
void podarConhecidos(
  Map<String, Object?> conhecidos,
  List<Map<String, dynamic>> rows,
) {
  if (conhecidos.isEmpty) return;
  final presentes = rows
      .map((row) => row['uid']?.toString())
      .whereType<String>()
      .toSet();
  conhecidos.keys.toList().forEach((uid) {
    if (!presentes.contains(uid)) conhecidos.remove(uid);
  });
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

  /// Lista COMPLETA de apostas, antes do filtro de busca.
  ///
  /// Serve só para podar o registro de linhas já vistas: podar contra [rows]
  /// (que é a lista filtrada) faria o filtro de busca "esquecer" todo mundo
  /// que ele esconde, e limpar a busca reanimaria a tabela inteira. Quando
  /// não informada, cai em [rows] — comportamento certo para quem não filtra.
  final List<Map<String, dynamic>>? rowsCompletas;

  const TabelaApostas({
    super.key,
    required this.rows,
    required this.colunaOrdenada,
    required this.ascendente,
    required this.onCabecalhoTap,
    required this.currentUid,
    this.mensagemVazio,
    this.alturaFixa = false,
    this.rowsCompletas,
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

  // Em que índice cada linha estava, para calcular quantas posições ela andou
  // quando a lista reordena. Substitui a medição de posições no corpo do
  // desktop, que a reciclagem do ListView tornou inviável.
  final RastreadorDeIndices _rastreador = RastreadorDeIndices();

  // Deslocamento (em índices) de cada linha que trocou de lugar no build
  // atual. Preenchido por _corpoRolavel e lido por _linha.
  Map<Object, int> _deslocamentosDeslize = const {};

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
              Expanded(child: _corpoRolavel(context, formatoMoeda))
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

  /// Corpo rolável da tabela no desktop, reciclando as linhas.
  ///
  /// `ListView.builder` monta só o que está visível (~12 linhas), em vez das
  /// N linhas da sala. Com 500 apostas o `SingleChildScrollView` + `Column`
  /// anterior mantinha ~2500 células vivas e as reconstruía a cada emissão do
  /// Firestore — era isso, e não a animação em si, que deixava a entrada de
  /// uma aposta nova travada numa sala grande.
  ///
  /// O deslize de reordenação NÃO usa `ColunaReordenavel` aqui: ela mede as
  /// posições dos filhos, e numa lista reciclada a maioria das linhas nem
  /// existe na árvore para ser medida. Em vez disso o deslocamento é
  /// CALCULADO — `(índice antigo - índice novo) * kAlturaLinhaTabela` — via
  /// [RastreadorDeIndices]. Além de funcionar com reciclagem, isso resolve o
  /// "vai e volta": medir no meio de uma animação lê posições transitórias, e
  /// com apostas chegando em rajada nunca há um instante estável para medir.
  Widget _corpoRolavel(BuildContext context, NumberFormat formatoMoeda) {
    podarConhecidos(_valoresConhecidos, widget.rowsCompletas ?? rows);

    // A ordem é registrada no build, ANTES do layout: o deslocamento já sai
    // pronto no mesmo quadro em que a linha muda de lugar, sem depender de
    // um callback pós-frame.
    _deslocamentosDeslize = _rastreador.atualizar([
      for (var i = 0; i < rows.length; i++)
        rows[i]['uid']?.toString() ?? 'linha-$i',
    ]);

    return SelectionArea(
      // A tabela fica dentro de um SingleChildScrollView horizontal (para
      // janelas estreitas), que oferece largura ILIMITADA ao filho. Um
      // `Column` aceitava isso; um ListView não — viewport vertical precisa
      // de largura definida, senão o layout falha com "Vertical viewport was
      // given unbounded width". Como as colunas têm larguras fixas, a largura
      // da lista é justamente a soma delas.
      child: SizedBox(
        width: larguraTotal,
        child: ListView.builder(
          // A extensão fixa é o que dá a GRADE em que o deslize de
          // reordenação se apoia: sem ela, a altura de cada linha varia
          // enquanto outra entra, e o deslocamento calculado
          // (`índices * kAlturaLinhaTabela`) deixa de bater com o layout real
          // — a linha em movimento oscila durante uma rajada de apostas.
          //
          // Por isso a animação de ENTRADA não abre espaço no ListView: ela
          // revela o conteúdo DENTRO do item, que já nasce com a altura final.
          // Ver `_reservaAlturaFixa` em LinhaEntrandoAnimada.
          itemExtent: kAlturaLinhaTabela,
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final item = rows[index];
            final chave = item['uid']?.toString() ?? 'linha-$index';
            final andou = _deslocamentosDeslize[chave] ?? 0;

            return LinhaDeslizante(
              // A chave vai aqui para o estado do deslize acompanhar a LINHA,
              // não a posição: sem isso o ListView reaproveitaria o State de
              // outra linha ao reciclar.
              key: ValueKey(chave),
              deslocamento: andou * kAlturaLinhaTabela,
              child: _linha(
                context,
                formatoMoeda,
                index,
                item,
                emGradeFixa: true,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _corpoTabela(BuildContext context, NumberFormat formatoMoeda) {
    // Antes de reavaliar quem é novo: esquece quem saiu da lista, senão um
    // participante removido e recriado nunca mais animaria.
    podarConhecidos(_valoresConhecidos, widget.rowsCompletas ?? rows);
    return SelectionArea(
      child: ColunaReordenavel(
        children: [
          ...rows.asMap().entries.map(
            (entry) => _linha(context, formatoMoeda, entry.key, entry.value),
          ),
        ],
      ),
    );
  }

  /// Uma linha da tabela. Usada tanto pelo corpo reciclado (desktop) quanto
  /// pelo corpo que cresce com o conteúdo (mobile).
  Widget _linha(
    BuildContext context,
    NumberFormat formatoMoeda,
    int index,
    Map<String, dynamic> item, {
    // Verdadeiro no corpo reciclado, onde o ListView já reservou a altura da
    // linha (itemExtent) e a chegada precisa ser encenada por dentro.
    bool emGradeFixa = false,
  }) {
    final corBorda = TabelaApostas.corBorda(context);
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
      // Só o uid: a chave identifica QUAL participante é a linha, e
      // isso não muda. Incluir o `data-hora` fazia a chave mudar
      // quando o servidor confirmava o timestamp de uma aposta nova
      // (null → Timestamp), e o Flutter descartava o widget que
      // estava animando para construir outro — a animação recomeçava
      // no meio. Linha sem uid cai no índice, que é o melhor
      // identificador estável disponível nesse caso.
      key: ValueKey(uid ?? 'linha-$index'),
      animar: isNova,
      reservaAlturaFixa: emGradeFixa,
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
                  sufixo: isManual ? const SeloManual(tamanhoFonte: 9) : null,
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
  }
}

/// Anima a entrada de uma linha recém-adicionada (nova aposta chegando via
/// stream em tempo real).
///
/// A animação é dividida em dois tempos, com papéis distintos:
///
/// 1. **Chegada (0–320ms)** — a linha abre espaço (`heightFactor`) e entra
///    deslizando da esquerda. A abertura de espaço termina antes do deslize
///    (~500ms contra ~900ms): o empurrão nas linhas de baixo acaba cedo, e o
///    resto do movimento acontece com o layout já parado. A versão original
///    estendia o `heightFactor` pela animação inteira, e a tabela toda ficava
///    se reacomodando durante toda a transição.
/// 2. **Confirmação (330–1500ms)** — um brilho horizontal percorre a linha
///    uma vez e o destaque de fundo recua. É o tempo que comunica "isto é
///    novo" depois que a linha já está no lugar; separá-lo da chegada é o que
///    evita o efeito de "dissolver" do modelo antigo, onde o destaque sumia
///    junto com o movimento e a linha nunca parecia pousar.
///
/// Os tempos foram alongados de 1100ms para 1500ms: a chegada lia como
/// estalo, principalmente com várias apostas entrando em sequência.
///
/// Quando [animar] é falso, o child é exibido direto, sem custo de animação
/// — assim apenas a linha nova paga o preço da transição, e a tabela toda
/// não é reconstruída/reanimada a cada emissão do stream.
class LinhaEntrandoAnimada extends StatefulWidget {
  final Widget child;
  final bool animar;
  final Color corBase;

  /// A linha vive numa grade de altura fixa (o `itemExtent` do ListView do
  /// desktop)?
  ///
  /// Faz diferença em COMO a chegada é encenada. Fora da grade a linha abre
  /// espaço de fato, empurrando as de baixo (`heightFactor` de 0 a 1). Dentro
  /// da grade isso não funciona: o ListView já reservou a altura inteira, e
  /// insistir no heightFactor faria a linha nascer ocupando tudo — a chegada
  /// simplesmente sumia, sobrando só o fade.
  ///
  /// Na grade, então, o espaço é reservado e o CONTEÚDO é que se revela
  /// dentro dele, deslizando de baixo para cima atrás de um recorte. O efeito
  /// lido é o mesmo (a linha se forma), mas sem mexer no layout — que é
  /// justamente o que o deslize de reordenação precisa que fique parado.
  final bool reservaAlturaFixa;

  const LinhaEntrandoAnimada({
    super.key,
    required this.child,
    required this.animar,
    required this.corBase,
    this.reservaAlturaFixa = false,
  });

  @override
  State<LinhaEntrandoAnimada> createState() => _LinhaEntrandoAnimadaState();
}

class _LinhaEntrandoAnimadaState extends State<LinhaEntrandoAnimada>
    with SingleTickerProviderStateMixin {
  /// Estilo capturado no INÍCIO da animação, não lido a cada quadro.
  ///
  /// Trocar o estilo no Painel ADM com uma aposta a meio caminho mudaria
  /// duração e curva no ar, e a linha daria um salto. Congelando aqui, a
  /// troca vale a partir da próxima aposta — que é como o controle se
  /// comporta na prática (o admin muda e observa a seguinte).
  late final EstiloEntrada _estilo = estiloEntradaGlobal.value;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _estilo.duracao,
  );

  // ── Tempo 1: chegada ─────────────────────────────────────────────────────
  // Abertura do espaço vertical: 0 a 45% do controller (~520ms).
  //
  // O que importa aqui não é só a duração, é a FATIA do controller que o
  // movimento ocupa. Numa versão anterior o espaço abria em 33% de 1500ms:
  // a linha parava de se mexer aos ~500ms e sobrava mais de um segundo só de
  // brilho e destaque num layout parado — o que lê como "a animação sumiu",
  // porque a parte que o olho acompanha já tinha acabado.
  late final Animation<double> _espaco = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.45, curve: Curves.easeOutCubic),
  );

  // O movimento da chegada, terminando em 78% da animação. A curva vem do
  // estilo escolhido — é ela que diferencia um deslize suave (easeOutCubic)
  // de um com repique no fim (easeOutBack).
  //
  // Evite curvas que concentram tudo no começo, tipo easeOutQuint: o percurso
  // acaba nos primeiros quadros e, apesar de durar ~900ms no papel, o olho só
  // vê um borrão inicial seguido de tela parada.
  late final Animation<double> _entrada = CurvedAnimation(
    parent: _controller,
    curve: Interval(0.04, 0.78, curve: _estilo.curva),
  );

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.04, 0.45, curve: Curves.easeOut),
  );

  // ── Tempo 2: confirmação ─────────────────────────────────────────────────
  // Recuo do destaque de fundo, sobrepondo o fim da chegada em vez de esperar
  // ela terminar: encadeados, os dois tempos somavam uma espera longa demais.
  late final Animation<double> _destaque = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.35, 1, curve: Curves.easeInOutCubic),
  );

  // Varredura do brilho, da esquerda para a direita, uma única vez.
  late final Animation<double> _brilho = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.18, 0.8, curve: Curves.easeInOut),
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

  /// O efeito deste estilo é feito de pontos/traços finos, que precisam ficar
  /// NA FRENTE do conteúdo para serem vistos?
  ///
  /// Efeitos de luz (gradientes cobrindo a linha inteira) ficam atrás, senão
  /// lavam o texto. Partículas e anéis cobrem pouca área e sumiriam por trás
  /// dele.
  bool get _efeitoPorCima => switch (_estilo.efeito) {
    EfeitoEntrada.fatiasGlitch => true,
    EfeitoEntrada.brilhoVarrendo || EfeitoEntrada.ondaIncandescente => false,
  };

  Widget _pintura(double progresso, Color cor) => IgnorePointer(
    child: CustomPaint(
      painter: _PinturaEfeito(
        efeito: _estilo.efeito,
        progresso: progresso,
        cor: cor,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    // `animar` decide se a animação COMEÇA, não se ela continua: uma vez
    // iniciada, roda até o fim.
    //
    // Sem essa distinção a animação era cortada na aba que ESTÁ simulando.
    // Ali cada aposta chega duas vezes — o cache local pinta na hora e a
    // confirmação do servidor emite de novo — e no segundo build
    // `detectarLinhaNova` já conhece o valor, devolvendo `animar: false`.
    // O widget então trocava para o conteúdo estático, e o deslize morria
    // aos ~30ms de 1150ms. (Na aba que só observa isso não acontecia: lá
    // chega uma emissão só, já confirmada.)
    if (!widget.animar && !_controller.isAnimating) {
      return DecoratedBox(
        decoration: BoxDecoration(color: widget.corBase),
        child: widget.child,
      );
    }

    final corDestaque = AppCores.de(context).linhaNova;

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final entrada = _entrada.value;
        final brilho = _brilho.value;

        // Na grade de altura fixa o espaço já está reservado, então o recorte
        // fica parado no tamanho final. Fora da grade (lista mobile), o
        // próprio recorte cresce e empurra as linhas de baixo.
        //
        // Dentro da grade NÃO há movimento vertical nenhum: a chegada é só
        // lateral. Uma versão anterior fazia o conteúdo subir de baixo para
        // compensar o heightFactor que a grade anula, mas essa subida (34px)
        // competia com o deslize lateral (36px) acontecendo ao mesmo tempo —
        // o olho lia a vertical e a entrada pela margem sumia.
        final revelar = _espaco.value;

        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: widget.reservaAlturaFixa ? 1 : revelar,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color.lerp(corDestaque, widget.corBase, _destaque.value),
              ),
              // O brilho fica ENTRE o fundo e o conteúdo: passa por baixo do
              // texto, sem lavá-lo. Pintado por cima, os números da aposta
              // ficavam ilegíveis justamente no instante em que chamam
              // atenção.
              child: Stack(
                children: [
                  // Efeitos de LUZ ficam atrás do conteúdo: passam por baixo
                  // do texto sem lavá-lo. Pintados por cima, os números da
                  // aposta ficariam ilegíveis justamente no instante em que
                  // chamam atenção.
                  if (!_efeitoPorCima && brilho > 0 && brilho < 1)
                    Positioned.fill(child: _pintura(brilho, corDestaque)),

                  aplicarEstiloEntrada(
                    estilo: _estilo,
                    child: child!,
                    entrada: entrada,
                    opacidade: _fade.value,
                  ),

                  // Já os efeitos de PARTÍCULA ficam na frente: são pontos e
                  // traços finos, que atrás do texto simplesmente não seriam
                  // vistos. Não chegam a atrapalhar a leitura porque cobrem
                  // pouca área e somem antes do fim.
                  if (_efeitoPorCima && brilho > 0 && brilho < 1)
                    Positioned.fill(child: _pintura(brilho, corDestaque)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Aplica a um [child] as transformações de um [EstiloEntrada], no ponto
/// [entrada] da animação (0 = recém-chegando, 1 = assentado).
///
/// Fica fora do State para poder ser exercitado isoladamente e para deixar
/// claro que a encenação inteira sai da definição do estilo — nenhum estilo
/// tem código próprio espalhado pela animação.
Widget aplicarEstiloEntrada({
  required EstiloEntrada estilo,
  required Widget child,
  required double entrada,
  required double opacidade,
}) {
  final restante = 1 - entrada;
  var conteudo = child;

  // Dissolução: o conteúdo não faz fade uniforme, ele aparece atrás de uma
  // frente que avança. Nítido onde ela já passou, invisível à frente dela.
  //
  // A frente vai até 1.25, não até 1.0, e a faixa de transição (~25% da
  // largura) acompanha: é o que faz a máscara SAIR pela direita em vez de
  // parar nela. Com o limite em 1.0, os últimos 25% da linha ficavam presos
  // num gradiente até transparente para sempre — a coluna "Última Alteração"
  // terminava a animação opaca, sem nunca voltar ao normal.
  //
  // A partir de `entrada` ~0.8 a máscara já é inteiramente opaca, então o
  // ShaderMask sai da árvore: manter um filtro por linha só para pintar
  // branco sobre branco é custo à toa.
  if (estilo.dissolver) {
    final frente = entrada * 1.25;
    if (frente < 1.24) {
      conteudo = ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: const [Colors.white, Colors.white, Colors.transparent],
          stops: [0, (frente - 0.25).clamp(0.0, 1.0), frente.clamp(0.0, 1.0)],
        ).createShader(rect),
        child: conteudo,
      );
    }
  } else {
    conteudo = Opacity(opacity: opacidade, child: conteudo);
  }

  // Glitch: a linha é picada em faixas horizontais que se deslocam para
  // lados opostos e voltam a se alinhar.
  //
  // Cada faixa é o conteúdo inteiro recortado numa janela diferente
  // (`ClipRect` + `Align` com heightFactor), então o texto continua sendo o
  // texto — não é uma textura de ruído por cima. O deslocamento usa um seno
  // com fase por faixa: é determinístico (mesmo quadro, mesmo resultado) mas
  // não parece periódico ao olho.
  if (estilo.efeito == EfeitoEntrada.fatiasGlitch && restante > 0.02) {
    const fatias = 7;
    // A instabilidade cai rápido: a linha se estabiliza antes do fim, e o
    // resto da animação é o brilho terminando de assentar.
    final caos = math.pow(restante, 1.6).toDouble();

    conteudo = Stack(
      children: [
        for (var i = 0; i < fatias; i++)
          Transform.translate(
            offset: Offset(math.sin(entrada * 22 + i * 2.4) * 26 * caos, 0),
            child: ClipRect(
              clipper: _RecorteFatia(indice: i, total: fatias),
              child: conteudo,
            ),
          ),
      ],
    );
  }

  // O deslocamento vem por último para não ser afetado pelos recortes acima.
  // O ClipRect do pai recorta o que sai da linha, então o deslocamento
  // parece vir de fora da tabela.
  if (estilo.deslocamentoX != 0) {
    conteudo = Transform.translate(
      offset: Offset(restante * estilo.deslocamentoX, 0),
      child: conteudo,
    );
  }

  return conteudo;
}

/// Recorta uma faixa horizontal do conteúdo — a i-ésima de [total].
///
/// Usado pelo glitch: cada faixa é o conteúdo inteiro visto por uma janela
/// diferente, e deslocá-las em X separadamente é o que produz o
/// desalinhamento sem destruir o texto.
class _RecorteFatia extends CustomClipper<Rect> {
  final int indice;
  final int total;

  const _RecorteFatia({required this.indice, required this.total});

  @override
  Rect getClip(Size size) {
    final altura = size.height / total;
    return Rect.fromLTWH(0, indice * altura, size.width, altura);
  }

  @override
  bool shouldReclip(_RecorteFatia anterior) =>
      anterior.indice != indice || anterior.total != total;
}

/// Efeito pintado sobre a linha durante a entrada.
///
/// Todos os modos compartilham o mesmo `CustomPainter` porque todos são
/// desenhos em função do progresso. O `shouldRepaint` compara só o progresso
/// e a cor, então nada mais dispara repintura.
class _PinturaEfeito extends CustomPainter {
  final EfeitoEntrada efeito;
  final double progresso;
  final Color cor;

  _PinturaEfeito({
    required this.efeito,
    required this.progresso,
    required this.cor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    switch (efeito) {
      case EfeitoEntrada.brilhoVarrendo:
        _varredura(canvas, rect);
      case EfeitoEntrada.ondaIncandescente:
        _incandescencia(canvas, rect);
      case EfeitoEntrada.fatiasGlitch:
        _ruidoGlitch(canvas, rect);
    }
  }

  /// Onda de calor: uma frente intensa percorre a linha deixando rastro
  /// incandescente atrás, que esfria da cor quente até sumir.
  void _incandescencia(Canvas canvas, Rect rect) {
    final crista = (progresso * 1.35).clamp(0.0, 1.0);
    // O resfriamento é mais lento que a passagem: o rastro ainda brilha
    // depois que a frente já chegou ao fim.
    final calor = (1 - (progresso - 0.45) / 0.55).clamp(0.0, 1.0);
    if (calor <= 0) return;

    // Mistura da cor de destaque com branco-quente na crista: é o que faz
    // parecer metal aquecido em vez de um brilho colorido qualquer.
    final quente = Color.lerp(cor, const Color(0xFFFFF3C4), 0.75)!;

    _pintarGradiente(canvas, rect, [
      (cor.withValues(alpha: 0.1 * calor), 0),
      (quente.withValues(alpha: 0.55 * calor), (crista - 0.2).clamp(0.0, 1.0)),
      (quente.withValues(alpha: 0.95 * calor), crista),
      (cor.withValues(alpha: 0), (crista + 0.06).clamp(0.0, 1.0)),
    ]);
  }

  /// Faixas de ruído do glitch: blocos horizontais de cor sobre a linha,
  /// piscando em posições pseudo-aleatórias.
  ///
  /// Complementa o deslocamento das fatias (feito com widgets): sozinho, o
  /// desalinhamento parece um bug de layout; com as faixas de cor, lê como
  /// sinal com interferência.
  void _ruidoGlitch(Canvas canvas, Rect rect) {
    final caos = math.pow(1 - progresso, 1.4).toDouble();
    if (caos <= 0.02) return;

    // Semente derivada do progresso em passos discretos: o padrão troca a
    // cada ~8% da animação, o que dá o "chiado" sem tremer a cada quadro.
    final passo = (progresso * 12).floor();
    final aleatorio = math.Random(passo);
    final tinta = Paint();

    for (var i = 0; i < 4; i++) {
      final y = aleatorio.nextDouble() * rect.height;
      final altura = 1 + aleatorio.nextDouble() * 3;
      final largura = rect.width * (0.15 + aleatorio.nextDouble() * 0.5);
      final x = aleatorio.nextDouble() * (rect.width - largura);

      tinta.color = cor.withValues(alpha: (0.55 * caos).clamp(0.0, 1.0));
      canvas.drawRect(Rect.fromLTWH(x, y, largura, altura), tinta);
    }
  }

  /// Faixa de luz atravessando a linha uma vez, da esquerda para a direita.
  void _varredura(Canvas canvas, Rect rect) {
    // Vai de -0.3 a 1.3 para a faixa entrar e sair completamente da linha,
    // em vez de aparecer e sumir dentro dela.
    final centro = -0.3 + progresso * 1.6;
    const meiaLargura = 0.22;

    // A opacidade sobe e desce ao longo da passagem: a faixa nasce e morre
    // fora do campo de visão do olho, sem pop nas bordas.
    final intensidade = (1 - (progresso - 0.5).abs() * 2).clamp(0.0, 1.0);
    if (intensidade <= 0) return;

    _pintarGradiente(canvas, rect, [
      (cor.withValues(alpha: 0), (centro - meiaLargura).clamp(0.0, 1.0)),
      (cor.withValues(alpha: 0.55 * intensidade), centro.clamp(0.0, 1.0)),
      (cor.withValues(alpha: 0), (centro + meiaLargura).clamp(0.0, 1.0)),
    ]);
  }

  void _pintarGradiente(
    Canvas canvas,
    Rect rect,
    List<(Color, double)> paradas,
  ) {
    final gradiente = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [for (final p in paradas) p.$1],
      stops: [for (final p in paradas) p.$2],
    );
    canvas.drawRect(rect, Paint()..shader = gradiente.createShader(rect));
  }

  @override
  bool shouldRepaint(_PinturaEfeito anterior) =>
      anterior.progresso != progresso ||
      anterior.cor != cor ||
      anterior.efeito != efeito;
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
            texto: '',
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
            texto:
                '${rows.length} ${rows.length == 1 ? 'participante' : 'participantes'}',
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
