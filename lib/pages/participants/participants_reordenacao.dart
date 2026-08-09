import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Guarda em que índice cada linha estava, para saber quantas posições ela
/// andou quando a lista é reordenada.
///
/// É a alternativa a MEDIR posições (o que [ColunaReordenavel] faz): num
/// `ListView.builder` a maioria das linhas nem existe na árvore, então não há
/// o que medir. Com altura de linha uniforme, saber o índice antigo e o novo
/// já dá a distância exata: `(antigo - novo) * altura`.
///
/// Isso também elimina a fragilidade da medição. Medir no meio de uma
/// animação lê posições transitórias, e com duas apostas entrando ao mesmo
/// tempo nunca existe um instante estável — era essa a origem do efeito de
/// "vai e volta" ao simular apostas em rajada. Índice não é transitório.
class RastreadorDeIndices {
  final Map<Object, int> _indices = {};

  /// Registra a ordem atual e devolve, para cada chave que trocou de posição
  /// RELATIVA, quantos índices ela andou (positivo = subiu na lista).
  ///
  /// Linha nova (sem índice anterior) não entra no resultado: quem cuida da
  /// chegada dela é a animação de entrada, não o deslize.
  ///
  /// **Ser empurrado não é reordenar.** Quando uma aposta entra no topo — o
  /// caso normal ao ordenar por "última alteração" — todas as outras descem
  /// uma posição de uma vez. Nenhuma trocou de lugar com nenhuma: a lista só
  /// andou junto. Animar isso punha a tela inteira em movimento no mesmo
  /// quadro em que a linha nova entrava (medido: 9 de 13 linhas deslizando ao
  /// mesmo tempo), e o resultado era uma confusão que encobria a animação de
  /// entrada.
  ///
  /// Por isso o empurrão comum é descontado: se TODAS as linhas antigas
  /// andaram o mesmo tanto na mesma direção, esse tanto é deslocamento de
  /// lista, não de linha. O que sobra depois do desconto é a reordenação de
  /// verdade — a aposta que passou na frente da outra.
  Map<Object, int> atualizar(List<Object> chavesEmOrdem) {
    final brutos = <Object, int>{};
    final tamanhoAnterior = _indices.length;

    for (var i = 0; i < chavesEmOrdem.length; i++) {
      final chave = chavesEmOrdem[i];
      final anterior = _indices[chave];
      if (anterior != null) brutos[chave] = anterior - i;
    }

    _indices
      ..clear()
      ..addEntries(
        chavesEmOrdem.asMap().entries.map((e) => MapEntry(e.value, e.key)),
      );

    if (brutos.isEmpty) return const {};

    // O desconto do empurrão vale só quando a lista CRESCEU. Aí o movimento
    // coletivo é consequência de alguém entrar, e a chegada dessa linha já é
    // a animação da vez.
    //
    // Encolhendo é o oposto: as linhas de baixo sobem para fechar o vazio
    // deixado pela aposta removida, e esse fechamento é justamente o que
    // precisa ser visto. Sem esta distinção, remover uma aposta virava um
    // salto seco.
    final cresceu = chavesEmOrdem.length > tamanhoAnterior;
    if (!cresceu) {
      return Map.fromEntries(brutos.entries.where((e) => e.value != 0));
    }

    // O empurrão comum é o deslocamento que a MAIORIA sofreu. Usar a maioria
    // (e não o mínimo) é o que faz uma linha isolada trocando de lugar
    // continuar deslizando enquanto o resto da lista só desceu.
    final frequencia = <int, int>{};
    for (final valor in brutos.values) {
      frequencia[valor] = (frequencia[valor] ?? 0) + 1;
    }
    var comum = 0;
    var maiorFrequencia = 0;
    frequencia.forEach((valor, vezes) {
      if (vezes > maiorFrequencia) {
        maiorFrequencia = vezes;
        comum = valor;
      }
    });

    // Só desconta se o empurrão for mesmo coletivo (mais da metade das
    // linhas). Numa reordenação de verdade os deslocamentos são variados e
    // nenhum domina.
    if (comum == 0 || maiorFrequencia * 2 <= brutos.length) {
      return Map.fromEntries(brutos.entries.where((e) => e.value != 0));
    }

    // O desconto vale só para quem andou EXATAMENTE o empurrão comum: essas
    // foram carregadas pela lista e ficam paradas. Quem andou diferente
    // trocou de posição de verdade e mantém o deslocamento bruto — descontar
    // dela encurtaria um deslize que precisa acontecer inteiro.
    final deslocamentos = <Object, int>{};
    brutos.forEach((chave, bruto) {
      if (bruto == comum) return;
      if (bruto != 0) deslocamentos[chave] = bruto;
    });
    return deslocamentos;
  }

  /// Índice registrado de uma chave, ou null se ela é nova.
  int? indiceDe(Object chave) => _indices[chave];

  void limpar() => _indices.clear();
}

/// Desliza um filho a partir de um deslocamento em PIXELS já conhecido.
///
/// Diferente de [ColunaReordenavel], não mede nada: quem chama informa quanto
/// a linha andou. Serve para listas recicladas (`ListView.builder`), onde as
/// linhas fora da tela não existem para serem medidas.
class LinhaDeslizante extends StatefulWidget {
  final Widget child;

  /// Distância que a linha percorreu, em pixels. Positivo = veio de baixo
  /// (estava num índice maior), então entra deslocada para baixo e sobe.
  final double deslocamento;

  final Duration duracao;
  final Curve curva;

  const LinhaDeslizante({
    super.key,
    required this.child,
    required this.deslocamento,
    this.duracao = const Duration(milliseconds: 550),
    this.curva = Curves.easeOutCubic,
  });

  @override
  State<LinhaDeslizante> createState() => _LinhaDeslizanteState();
}

class _LinhaDeslizanteState extends State<LinhaDeslizante>
    with SingleTickerProviderStateMixin {
  // Criado sob demanda: a maioria das linhas nunca desliza, e um `late final`
  // acabaria sendo inicializado dentro do próprio dispose() — montar ticker em
  // elemento desativado lança.
  AnimationController? _controller;
  double _deslocamento = 0;

  AnimationController _garantir() => _controller ??= AnimationController(
    vsync: this,
    duration: widget.duracao,
  );

  @override
  void initState() {
    super.initState();
    _iniciar(widget.deslocamento);
  }

  @override
  void didUpdateWidget(covariant LinhaDeslizante oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.deslocamento != oldWidget.deslocamento) {
      _iniciar(widget.deslocamento);
    }
  }

  void _iniciar(double alvo) {
    if (alvo == 0) return;
    final controller = _garantir();
    // Reordenou de novo no meio de um deslize: soma o trecho que faltava, para
    // a linha continuar de onde está em vez de saltar.
    final restante = _deslocamento * (1 - controller.value);
    _deslocamento = alvo + restante;
    controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_deslocamento == 0 || controller == null) return widget.child;

    return AnimatedBuilder(
      animation: controller,
      child: widget.child,
      builder: (context, child) {
        final t = widget.curva.transform(controller.value);
        final offset = _deslocamento * (1 - t);
        if (offset == 0) return child!;
        return Transform.translate(offset: Offset(0, offset), child: child);
      },
    );
  }
}

/// Coluna que ANIMA a troca de posição dos filhos.
///
/// Existe porque um `Column` comum não tem noção de filho que se move: quando
/// a lista é reordenada (o usuário edita a aposta e ela muda de valor, ou o
/// `data-hora` é reescrito), o Flutter reaproveita os widgets pela chave e
/// simplesmente desenha cada um na posição nova no frame seguinte. Não há
/// estado intermediário, então a linha "teleporta".
///
/// Aqui cada filho continua sendo posicionado pelo layout normal do Column —
/// o que muda é que, ao detectar que um filho saiu do índice A para o índice
/// B, ele é desenhado com um deslocamento igual à distância que percorreu e
/// esse deslocamento é animado até zero. O resultado visual é a linha
/// deslizando do lugar antigo para o novo, enquanto o layout real já está no
/// destino.
///
/// **Por que deslocar em vez de posicionar num `Stack`:** com `Stack` +
/// `AnimatedPositioned` seria preciso conhecer a altura de cada linha ANTES
/// de montar, o que obrigaria a fixar a altura no código (e a quebrar sempre
/// que um padding mudasse). Deslocando, a altura continua sendo decidida pelo
/// conteúdo, como hoje, e as posições são MEDIDAS depois de cada layout.
///
/// Cada filho precisa de uma [Key] estável que identifique a linha (o uid da
/// aposta) — é ela que permite saber que "esta linha aqui é a mesma que
/// estava três posições acima".
class ColunaReordenavel extends StatefulWidget {
  final List<Widget> children;
  final Duration duracao;
  final Curve curva;

  /// Desliga a animação (usada quando a lista é longa demais para valer o
  /// custo, ou em testes que não querem lidar com frames pendentes).
  final bool animar;

  const ColunaReordenavel({
    super.key,
    required this.children,
    this.duracao = const Duration(milliseconds: 550),
    this.curva = Curves.easeOutCubic,
    this.animar = true,
  });

  @override
  State<ColunaReordenavel> createState() => _ColunaReordenavelState();
}

class _ColunaReordenavelState extends State<ColunaReordenavel> {
  // Deslocamento vertical (em pixels) que cada linha ainda precisa percorrer
  // até chegar ao lugar real dela. Só contém as linhas que estão em
  // movimento; quem está parado nem aparece aqui.
  final Map<Key, double> _deslocamentos = {};

  // Posição vertical (topo) de cada linha no último layout concluído. É a
  // referência para calcular a distância percorrida quando a ordem muda.
  final Map<Key, double> _posicoesAnteriores = {};

  // Altura de cada linha na última medição. Serve só para detectar que
  // alguma está no meio da animação de ENTRADA (altura crescendo) e, nesse
  // caso, segurar o disparo dos deslizes — ver _medirEAnimar.
  final Map<Key, double> _alturasAnteriores = {};

  // Sequência das linhas (de cima para baixo) na última medição. Comparar
  // com a atual é o que distingue reordenação de verdade do empurrão que a
  // animação de entrada causa — ver _medirEAnimar.
  List<Key> _ordemAnterior = const [];

  /// As duas sequências mantêm a mesma ordem RELATIVA?
  ///
  /// Considera só as linhas presentes nas duas: quem entrou ou saiu não conta.
  /// Uma aposta nova aparecendo muda a lista, mas não reordena ninguém — e
  /// comparar as listas cruas acusaria reordenação em toda inserção.
  static bool _mesmaOrdem(List<Key> a, List<Key> b) {
    final comuns = b.toSet();
    final filtradaA = a.where(comuns.contains).toList();
    final conjuntoA = a.toSet();
    final filtradaB = b.where(conjuntoA.contains).toList();

    if (filtradaA.length != filtradaB.length) return false;
    for (var i = 0; i < filtradaA.length; i++) {
      if (filtradaA[i] != filtradaB[i]) return false;
    }
    return true;
  }

  // Uma GlobalKey por linha para conseguir medir o RenderBox dela depois do
  // layout. Mantida entre builds para a medição sobreviver à reordenação.
  final Map<Key, GlobalKey> _chavesMedicao = {};

  @override
  void initState() {
    super.initState();
    _agendarMedicao();
  }

  @override
  void didUpdateWidget(covariant ColunaReordenavel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _prepararDeslizeDaTroca(oldWidget.children, widget.children);
    _agendarMedicao();
  }

  /// Detecta reordenação pela ORDEM DOS FILHOS, ainda no `didUpdateWidget` —
  /// isto é, ANTES de o quadro novo ser desenhado.
  ///
  /// A medição pós-frame não serve para isto: quando ela roda, o Flutter já
  /// pintou a linha na posição nova, e o deslize só poderia começar no quadro
  /// seguinte, partindo de um lugar que já é o destino. Era por isso que uma
  /// reordenação caindo no meio da animação de entrada de outra linha
  /// aparecia como salto seco.
  ///
  /// Aqui a troca é conhecida antes do layout, e a distância vem das posições
  /// medidas no quadro anterior (`_posicoesAnteriores`), que continuam
  /// válidas porque as alturas não mudaram entre um quadro e outro. Assim o
  /// `Transform` já sai montado no mesmo quadro em que a ordem muda.
  void _prepararDeslizeDaTroca(List<Widget> antes, List<Widget> depois) {
    if (!widget.animar) return;

    final chavesAntes = [
      for (final f in antes)
        if (f.key != null) f.key!,
    ];
    final chavesDepois = [
      for (final f in depois)
        if (f.key != null) f.key!,
    ];
    if (chavesAntes.isEmpty || chavesDepois.isEmpty) return;

    // Só interessa quem existe nos dois: entrada e saída são tratadas pela
    // animação de entrada e pela medição pós-frame, respectivamente.
    final comuns = chavesDepois.toSet();
    final ordemAntes = chavesAntes.where(comuns.contains).toList();
    final conjuntoAntes = chavesAntes.toSet();
    final ordemDepois = chavesDepois.where(conjuntoAntes.contains).toList();
    if (_mesmaOrdem(ordemAntes, ordemDepois)) return;

    // Posições do quadro anterior, na ordem em que as linhas estavam. O lugar
    // que o índice N ocupava é o N-ésimo valor desta lista.
    final lugares = [
      for (final chave in ordemAntes)
        if (_posicoesAnteriores[chave] != null) _posicoesAnteriores[chave]!,
    ];
    if (lugares.length != ordemAntes.length) return;

    final indiceAntes = {
      for (var i = 0; i < ordemAntes.length; i++) ordemAntes[i]: i,
    };

    final deslocamentos = <Key, double>{};
    for (var novoIndice = 0; novoIndice < ordemDepois.length; novoIndice++) {
      final chave = ordemDepois[novoIndice];
      final velhoIndice = indiceAntes[chave];
      if (velhoIndice == null || velhoIndice == novoIndice) continue;

      // A linha sai do lugar que ocupava e vai para o lugar do índice novo:
      // a distância é entre esses dois pontos do quadro anterior.
      final distancia = lugares[velhoIndice] - lugares[novoIndice];
      if (distancia.abs() < 1) continue;
      deslocamentos[chave] = distancia;
    }

    if (deslocamentos.isEmpty) return;
    _deslocamentos
      ..clear()
      ..addAll(deslocamentos);
  }

  /// Mede as posições depois que o frame atual terminar de desenhar.
  ///
  /// Precisa ser pós-frame: durante o build as linhas ainda não têm
  /// RenderBox na posição nova, então não há distância para calcular.
  void _agendarMedicao() {
    if (!widget.animar) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _medirEAnimar();
    });
  }

  void _medirEAnimar() {
    // O próprio box é a referência de todas as medições, então é resolvido
    // uma vez só — e serve de porta de saída: se a coluna já saiu da árvore
    // (troca de aba, sala recarregada), não há o que medir.
    //
    // `mounted` não basta aqui: entre o frame e este callback pós-frame o
    // elemento pode ter sido desativado, e aí `findRenderObject()` lança
    // "Looking up a deactivated widget's ancestor is unsafe".
    final proprioBox = mounted ? context.findRenderObject() : null;
    if (proprioBox is! RenderBox || !proprioBox.attached) return;

    final posicoesAtuais = <Key, double>{};
    final alturasAtuais = <Key, double>{};
    final novosDeslocamentos = <Key, double>{};

    for (final entry in _chavesMedicao.entries) {
      final contexto = entry.value.currentContext;
      if (contexto == null) continue;
      final box = contexto.findRenderObject();
      // `attached` descarta a linha que saiu da árvore neste mesmo frame
      // (aposta removida): ela ainda tem RenderBox, mas medi-la lançaria.
      if (box is! RenderBox || !box.hasSize || !box.attached) continue;

      final topo = _topoNoLayout(box, proprioBox);
      if (topo == null) continue;
      posicoesAtuais[entry.key] = topo;
      alturasAtuais[entry.key] = box.size.height;

      final anterior = _posicoesAnteriores[entry.key];
      // Linha que acabou de nascer não tem posição anterior: quem cuida da
      // entrada dela é a animação de linha nova, não esta.
      if (anterior == null) continue;

      final distancia = anterior - topo;
      // Sub-pixel não é reordenação, é ruído de arredondamento do layout.
      if (distancia.abs() < 1) continue;
      novosDeslocamentos[entry.key] = distancia;
    }

    // Esquece linhas que saíram da árvore, senão os mapas crescem para sempre.
    _chavesMedicao.removeWhere(
      (chave, _) => !posicoesAtuais.containsKey(chave),
    );
    _posicoesAnteriores.removeWhere(
      (chave, _) => !posicoesAtuais.containsKey(chave),
    );
    _alturasAnteriores.removeWhere(
      (chave, _) => !posicoesAtuais.containsKey(chave),
    );

    // Linha nova ainda não tem posição registrada: registra agora para ela
    // ter referência no próximo quadro, sem disparar deslize (quem cuida da
    // chegada dela é a animação de entrada).
    for (final e in posicoesAtuais.entries) {
      _posicoesAnteriores.putIfAbsent(e.key, () => e.value);
    }

    _alturasAnteriores
      ..clear()
      ..addAll(alturasAtuais);

    // Reordenação já foi tratada em _prepararDeslizeDaTroca, no quadro em que
    // a ordem mudou. Sobra para cá o caso que só o layout revela: alguém SAIU
    // da lista (aposta removida) e quem estava abaixo subiu para ocupar o
    // espaço — a ordem relativa dos que ficaram não muda, então comparar a
    // sequência dos filhos não acusaria nada.
    final ordemAtual = posicoesAtuais.keys.toList()
      ..sort(
        (x, y) => (posicoesAtuais[x] ?? 0).compareTo(posicoesAtuais[y] ?? 0),
      );
    final anterior = _ordemAnterior;
    _ordemAnterior = ordemAtual;

    final atuais = ordemAtual.toSet();
    final saiuAlguem = anterior.any((chave) => !atuais.contains(chave));

    // As posições sempre passam a valer o lugar novo: é delas que
    // _prepararDeslizeDaTroca tira a distância no próximo quadro. Congelar o
    // registro (o que eu fazia antes) desatualizava essa referência.
    _posicoesAnteriores
      ..clear()
      ..addAll(posicoesAtuais);

    if (!saiuAlguem || novosDeslocamentos.isEmpty) return;

    setState(() {
      _deslocamentos
        ..clear()
        ..addAll(novosDeslocamentos);
    });
  }

  /// Distância do topo de [box] até o topo de [ancestral) segundo o LAYOUT,
  /// ignorando qualquer `Transform` no caminho.
  ///
  /// É a peça central da correção do "tremido". `localToGlobal` devolve a
  /// posição PINTADA, que inclui o `Transform.translate` da animação em
  /// curso: medir com ele fazia a linha em movimento ser lida no meio do
  /// deslize, esse ponto virava a "posição anterior" e a animação passava a
  /// perseguir o próprio resultado — um laço de realimentação que aparecia
  /// como a linha indo e voltando.
  ///
  /// Somar os offsets do `parentData` sobe a árvore usando só o que o layout
  /// decidiu. O valor é estável durante toda a animação, então uma linha
  /// parada mede sempre igual e não gera deslocamento nenhum.
  double? _topoNoLayout(RenderBox box, RenderBox ancestral) {
    var y = 0.0;
    RenderObject? atual = box;

    while (atual != null && !identical(atual, ancestral)) {
      final dados = atual.parentData;
      if (dados is BoxParentData) y += dados.offset.dy;
      atual = atual.parent;
    }

    // Não chegou no ancestral: a linha está em outra sub-árvore (ou saiu da
    // árvore neste frame). Sem referência comum, a medida não vale nada.
    return atual == null ? null : y;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final filho in widget.children)
          _LinhaDeslocada(
            // A chave do filho identifica a linha; a GlobalKey serve só para
            // medir. Reaproveitada entre builds para não perder o estado.
            key: filho.key,
            chaveMedicao: _chavesMedicao.putIfAbsent(filho.key!, GlobalKey.new),
            deslocamentoInicial: _deslocamentos[filho.key] ?? 0,
            duracao: widget.duracao,
            curva: widget.curva,
            child: filho,
          ),
      ],
    );
  }
}

/// Desenha um filho deslocado verticalmente e anima esse deslocamento até
/// zero — ou seja, faz a linha deslizar da posição antiga até a real.
class _LinhaDeslocada extends StatefulWidget {
  final Widget child;
  final GlobalKey chaveMedicao;
  final double deslocamentoInicial;
  final Duration duracao;
  final Curve curva;

  const _LinhaDeslocada({
    super.key,
    required this.child,
    required this.chaveMedicao,
    required this.deslocamentoInicial,
    required this.duracao,
    required this.curva,
  });

  @override
  State<_LinhaDeslocada> createState() => _LinhaDeslocadaState();
}

class _LinhaDeslocadaState extends State<_LinhaDeslocada>
    with SingleTickerProviderStateMixin {
  // Criado sob demanda, e NÃO com `late final`: a maioria das linhas nunca se
  // move, e um `late final` só é inicializado no primeiro acesso — o que
  // incluía o `dispose()`. Uma linha descartada sem nunca ter animado
  // acabava CRIANDO o controller dentro do próprio dispose, e montar um
  // ticker num elemento já desativado lança "Looking up a deactivated
  // widget's ancestor is unsafe".
  AnimationController? _controller;

  double _deslocamento = 0;

  AnimationController _garantirController() {
    return _controller ??= AnimationController(
      vsync: this,
      duration: widget.duracao,
    );
  }

  @override
  void initState() {
    super.initState();
    _deslocamento = widget.deslocamentoInicial;
    if (_deslocamento != 0) _garantirController().forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant _LinhaDeslocada oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.deslocamentoInicial != oldWidget.deslocamentoInicial &&
        widget.deslocamentoInicial != 0) {
      // Reordenou de novo no meio de um deslize: parte da posição em que a
      // linha está AGORA, somando o que ainda faltava percorrer. Sem isso a
      // linha daria um salto ao receber o novo destino.
      final controller = _garantirController();
      final restante = _deslocamento * (1 - controller.value);
      _deslocamento = widget.deslocamentoInicial + restante;
      controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // KeyedSubtree com a GlobalKey embrulha o filho para permitir a medição
    // sem interferir no layout dele.
    final medido = KeyedSubtree(key: widget.chaveMedicao, child: widget.child);

    final controller = _controller;
    if (_deslocamento == 0 || controller == null) return medido;

    return AnimatedBuilder(
      animation: controller,
      child: medido,
      builder: (context, child) {
        final t = widget.curva.transform(controller.value);
        final offset = _deslocamento * (1 - t);
        if (offset == 0) return child!;
        return Transform.translate(offset: Offset(0, offset), child: child);
      },
    );
  }
}
