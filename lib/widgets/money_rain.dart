import 'dart:math';

import 'package:flutter/material.dart';

// Ordena por raridade crescente (menor primeiro, mais raro por último —
// logo desenhado por cima na Stack); ordemCriacao desempata moedas do
// mesmo nível, preservando a ordem de queda entre elas.
int _compararPorRaridade(_Moeda a, _Moeda b) {
  final porRaridade = a.raridade.compareTo(b.raridade);
  return porRaridade != 0
      ? porRaridade
      : a.ordemCriacao.compareTo(b.ordemCriacao);
}

// Pilha de dinheiro que cresce conforme o valor apostado aumenta. Cada
// emoji novo "cai" e se acomoda no monte, dando feedback visual lúdico
// enquanto o usuário preenche o valor em "Minha Aposta".
//
// Nota histórica (não repetir estas tentativas):
// - Chuva contínua em loop com até 1000 emojis: travava o Flutter Web.
// - CustomPainter desenhando TextPainter cru, ou pré-rasterizar via
//   Overlay+RepaintBoundary+toImage e desenhar com canvas.drawAtlas:
//   ambos quebravam a cor do emoji (tofu / ruído de pixels) no CanvasKit.
// - Um AnimationController por moeda: satura o scheduler quando muitas
//   moedas nascem de uma vez.
// - Um único controller compartilhado por TODAS as moedas, resetado a
//   cada novo lote: reseta também a curva das moedas já acomodadas.
// - Debounce na sincronização: resolvia o custo, mas criava uma sensação
//   de UI "atrasada"/morta enquanto o usuário digitava — pior que o
//   travamento em si.
//
// Solução atual: dois grupos de widgets, fisicamente separados em
// Stacks diferentes, para o Flutter nunca precisar sequer considerar
// reconstruir o grupo estático ao processar o dinâmico:
// - _PilhaEstatica: moedas já acomodadas. É um StatefulWidget próprio que
//   guarda sua PRÓPRIA lista interna e só ganha itens (nunca é
//   substituído/reconstruído do zero pelo pai) — o "monte" cresce sem
//   nunca re-percorrer o que já existe.
// - Lote dinâmico: só as poucas moedas em queda agora (as do lote mais
//   recente), com sua própria pequena Stack e AnimationController. Ao
//   concluir a queda, o lote inteiro migra para a pilha estática de uma
//   vez (uma única operação O(tamanho do lote), não O(pilha inteira)).
// Estilo de escalonamento da animação de entrada/saída das moedas:
// - [esquerdaParaDireita]: atraso segue a posição na fileira (varredura
//   da esquerda para a direita na entrada; invertida na saída).
// - [aleatorioDoTopo]: atraso sorteado por moeda, sem relação com X — cada
//   moeda cai em um instante aleatório, independente da posição horizontal.
enum MoneyRainEstiloAnimacao { esquerdaParaDireita, aleatorioDoTopo }

// Configuração temporária para comparar os dois estilos em produção sem
// precisar editar código: o painel admin expõe um seletor que altera este
// notifier, e MinhaApostaCard escuta ele para decidir o estiloAnimacao.
// Remover quando a escolha final for definida.
final ValueNotifier<MoneyRainEstiloAnimacao> moneyRainEstiloGlobal =
    ValueNotifier(MoneyRainEstiloAnimacao.esquerdaParaDireita);

class MoneyRain extends StatefulWidget {
  final int quantidade;
  // Valor apostado em reais, usado só para decidir a raridade dos emojis
  // (ver _limiaresDesbloqueio) — independente de `quantidade`, que satura
  // bem antes (ver MinhaApostaCard._quantidadeEmojis) e não consegue mais
  // distinguir valores altos entre si depois desse teto.
  final double valorReais;
  final MoneyRainEstiloAnimacao estiloAnimacao;

  const MoneyRain({
    super.key,
    required this.quantidade,
    this.valorReais = 0,
    this.estiloAnimacao = MoneyRainEstiloAnimacao.esquerdaParaDireita,
  });

  static const maxQuantidade = 1000;
  // Meio-termo entre as duas tentativas anteriores: 350 moedas pequenas
  // (16-24px) ainda pesava perceptivelmente até em produção; 150 moedas
  // grandes (32-46px) ficavam maiores do que o ideal. 220@22-30px busca
  // equilíbrio entre densidade visual e performance real.
  static const _maxMoedasVisiveis = 230;

  // Ordem de "raridade": dinheiro comum aparece desde valores baixos;
  // conforme o valor sobe, a progressão passa por luxo (iate, avião) e
  // por fim "conquistou o mundo" (foguete) nos valores mais altos.
  static const _emojis = ['💵', '🪙', '💰', '💎', '🛥️', '✈️', '🚀'];

  @override
  State<MoneyRain> createState() => _MoneyRainState();
}

class _MoneyRainState extends State<MoneyRain> with TickerProviderStateMixin {
  final _random = Random();
  final GlobalKey<_PilhaEstaticaState> _pilhaKey =
      GlobalKey<_PilhaEstaticaState>();

  int _totalCriado = 0;
  AnimationController? _controllerLoteAtivo;
  List<_Moeda> _loteAtivo = const [];

  @override
  void initState() {
    super.initState();
    _sincronizarMoedas();
  }

  @override
  void didUpdateWidget(covariant MoneyRain oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.quantidade != widget.quantidade) {
      _sincronizarMoedas();
    }
  }

  void _sincronizarMoedas() {
    final alvo = _moedasVisiveisPara(widget.quantidade);
    if (alvo > _totalCriado) {
      _abrirNovoLote(alvo);
    } else if (alvo < _totalCriado) {
      _encolherPara(alvo);
    }
  }

  void _abrirNovoLote(int alvo) {
    // Lote anterior (se ainda em queda) é enviado direto para a pilha
    // estática, sem esperar terminar a animação — evita acumular
    // controllers/lotes concorrentes quando o valor muda rápido.
    _finalizarLoteAtivo();

    final baseAnterior = _totalCriado;
    final controllerLote = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    final novoLote = <_Moeda>[
      for (var i = baseAnterior; i < alvo; i++)
        _novaMoeda(i, baseAnterior, alvo, controllerLote),
    ];

    setState(() {
      _controllerLoteAtivo = controllerLote;
      _loteAtivo = novoLote;
      _totalCriado = alvo;
    });

    controllerLote.forward().whenComplete(_finalizarLoteAtivo);
  }

  // Move o lote ativo (só ele, não a pilha inteira) para dentro da pilha
  // estática — que nunca reconstrói o que já tinha — e libera o
  // controller. Cada moeda tem sua curva congelada em 1 (já pousada)
  // ANTES do controller ser descartado — senão ficaria referenciando um
  // Animation ligado a um AnimationController já disposed.
  void _finalizarLoteAtivo() {
    if (_loteAtivo.isEmpty) return;
    for (final moeda in _loteAtivo) {
      moeda.acomodar();
    }
    _pilhaKey.currentState?.adicionar(_loteAtivo);
    _controllerLoteAtivo?.dispose();
    if (mounted) {
      setState(() {
        _loteAtivo = const [];
        _controllerLoteAtivo = null;
      });
    } else {
      _loteAtivo = const [];
      _controllerLoteAtivo = null;
    }
  }

  void _encolherPara(int alvo) {
    _controllerLoteAtivo?.dispose();
    _controllerLoteAtivo = null;
    _loteAtivo = const [];
    _totalCriado = alvo;
    _pilhaKey.currentState?.encolherPara(
      alvo,
      vsync: this,
      estiloAnimacao: widget.estiloAnimacao,
    );
    setState(() {});
  }

  // Linear: a curva de "quando a pilha enche" é responsabilidade de quem
  // calcula `quantidade` (ver MinhaApostaCard._quantidadeEmojis) — este
  // widget só mapeia proporcionalmente quantidade (0..maxQuantidade) para
  // moedas visíveis (0.._maxMoedasVisiveis), sem aplicar outra curva por
  // cima (evita compor duas curvas e achatar demais o crescimento).
  int _moedasVisiveisPara(int quantidade) {
    final alvo = quantidade.clamp(0, MoneyRain.maxQuantidade);
    final proporcao = alvo / MoneyRain.maxQuantidade;
    return (proporcao * MoneyRain._maxMoedasVisiveis).round();
  }

  // Emoji por "raridade": do mais comum (índice 0) ao mais raro (último).
  // Limiares em reais, degraus de R$60 — um por emoji, na mesma ordem de
  // MoneyRain._emojis: 💵 R$0, 🪙 R$60, 💰 R$120, 💎 R$180, 🛥️ R$240,
  // ✈️ R$300, 🚀 R$360.
  static const _degrauDesbloqueioReais = 60.0;

  // Peso de sorteio por emoji (mesma ordem de MoneyRain._emojis). 💵 é o
  // mais comum; 🪙 e 💰 aparecem menos que a cédula (🪙 reduzida ainda mais,
  // por pedido, para não dominar a pilha); a partir de 💎 o peso cai bem
  // mais (geométrico, e 💎 também reduzida), então mesmo desbloqueados,
  // iate/avião/foguete aparecem raramente — sem isso, valores altos
  // enchiam a pilha de foguete.
  static const _pesos = [10.0, 3.0, 6.0, 2.0, 2.0, 1.0, 0.5];

  int _indiceEmojiPara(double valorReais) {
    final totalEmojis = MoneyRain._emojis.length;
    final desbloqueados = (1 + (valorReais / _degrauDesbloqueioReais).floor())
        .clamp(1, totalEmojis);

    final pesoTotal = _pesos
        .take(desbloqueados)
        .fold<double>(0, (soma, peso) => soma + peso);
    var sorteio = _random.nextDouble() * pesoTotal;

    for (var i = 0; i < desbloqueados; i++) {
      sorteio -= _pesos[i];
      if (sorteio <= 0) return i;
    }
    return desbloqueados - 1;
  }

  _Moeda _novaMoeda(
    int indice,
    int inicioLote,
    int fimLote,
    AnimationController controllerLote,
  ) {
    const moedasPorFileira = 20;
    final fileira = indice ~/ moedasPorFileira;
    final posicaoNaFileira = indice % moedasPorFileira;

    final tamanhoLote = (fimLote - inicioLote).clamp(1, 1 << 30);
    final posicaoNoLote = indice - inicioLote;
    const duracaoQuedaFracao = 0.4;
    final atraso =
        widget.estiloAnimacao == MoneyRainEstiloAnimacao.aleatorioDoTopo
        ? _random.nextDouble()
        : posicaoNoLote / tamanhoLote;
    final inicio = (atraso * (1 - duracaoQuedaFracao)).clamp(0.0, 1.0);
    final fim = (inicio + duracaoQuedaFracao).clamp(0.0, 1.0);

    final raridade = _indiceEmojiPara(widget.valorReais);
    final x = widget.estiloAnimacao == MoneyRainEstiloAnimacao.aleatorioDoTopo
        ? _random.nextDouble()
        : (posicaoNaFileira + 0.5) / moedasPorFileira +
              (_random.nextDouble() - 0.5) * 0.05;

    return _Moeda(
      curva: CurvedAnimation(
        parent: controllerLote,
        curve: Interval(inicio, fim, curve: Curves.easeOutBack),
      ),
      x: x,
      camada: fileira,
      // Meio-termo: nem tão pequenas quanto 16-24, nem tão grandes
      // quanto 32-46 da versão anterior.
      tamanho: 22.0 + _random.nextDouble() * 8,
      rotacao: (_random.nextDouble() - 0.5) * 0.6,
      emoji: MoneyRain._emojis[raridade],
      raridade: raridade,
      ordemCriacao: _proximaOrdemCriacao++,
    );
  }

  // Contador global de criação (não reinicia por lote) usado só como
  // critério de desempate estável ao ordenar por raridade — sort() do
  // Dart não garante estabilidade, então sem isso moedas do mesmo nível
  // de raridade poderiam trocar de posição de desenho entre rebuilds.
  int _proximaOrdemCriacao = 0;

  @override
  void dispose() {
    _controllerLoteAtivo?.dispose();
    super.dispose();
  }

  // Altura de referência usada para calibrar os tamanhos de moeda em
  // _novaMoeda (22-30px). Quando a área disponível é maior (ex: aba
  // "Aposta" ocupando a tela cheia no mobile), a escala cresce
  // proporcionalmente para preencher o espaço extra sem aumentar a
  // quantidade de emojis.
  static const _alturaReferencia = 230.0;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tamanhoArea = constraints.biggest;
          final escala = tamanhoArea.height > 0
              ? (tamanhoArea.height / _alturaReferencia).clamp(1.0, 2.5)
              : 1.0;
          // Lote ativo também desenhado com as mais raras por cima,
          // consistente com a pilha estática.
          final loteOrdenado = [..._loteAtivo]..sort(_compararPorRaridade);
          return Stack(
            children: [
              _PilhaEstatica(
                key: _pilhaKey,
                tamanhoArea: tamanhoArea,
                escala: escala,
              ),
              for (final moeda in loteOrdenado)
                _MoedaWidget(
                  key: ValueKey(moeda),
                  moeda: moeda,
                  tamanhoArea: tamanhoArea,
                  escala: escala,
                ),
            ],
          );
        },
      ),
    );
  }
}

// Guarda as moedas já acomodadas em seu PRÓPRIO estado interno. Como o
// pai (_MoneyRainState) nunca reconstrói este widget com uma nova lista
// (só chama adicionar()/encolherPara() via GlobalKey), o Flutter nunca
// precisa reconciliar/percorrer o histórico inteiro a cada novo lote —
// só o novo pedaço é adicionado à Stack interna via setState local.
class _PilhaEstatica extends StatefulWidget {
  final Size tamanhoArea;
  final double escala;

  const _PilhaEstatica({
    super.key,
    required this.tamanhoArea,
    required this.escala,
  });

  @override
  State<_PilhaEstatica> createState() => _PilhaEstaticaState();
}

class _PilhaEstaticaState extends State<_PilhaEstatica> {
  final List<_Moeda> _moedas = [];
  // Moedas que estão saindo (valor diminuiu): caem para fora da tela em
  // vez de simplesmente desaparecer. Guardadas à parte de `_moedas` para
  // não reintroduzir a moeda na pilha estática enquanto ela ainda anima.
  final List<_MoedaSaindo> _saindo = [];

  void adicionar(List<_Moeda> novas) {
    if (!mounted) return;
    setState(() => _moedas.addAll(novas));
  }

  // Remove as moedas do topo (índice >= alvo) da pilha, mas em vez de
  // sumirem instantaneamente elas ganham uma animação de queda/saída —
  // mesma sensação de "dinheiro caindo" do lote que entra, só que invertida
  // (cai para baixo e desaparece, ao invés de subir e pousar). Caem uma a
  // uma (a do topo da pilha primeiro), não todas de uma vez: cada moeda
  // recebe seu próprio Interval dentro do controller compartilhado do lote.
  final _random = Random();

  void encolherPara(
    int alvo, {
    required TickerProvider vsync,
    required MoneyRainEstiloAnimacao estiloAnimacao,
  }) {
    if (!mounted || alvo >= _moedas.length) return;
    // Do topo da pilha para a base (ordem inversa à de entrada), para a
    // queda seguir a ordem visual natural de "desmontar" o monte. No estilo
    // aleatório essa ordem não importa (o atraso já é sorteado por moeda).
    final removidas = _moedas.sublist(alvo).reversed.toList();
    setState(() => _moedas.removeRange(alvo, _moedas.length));

    const duracaoQuedaFracao = 0.5;
    // Duração total tem um teto: sem isso, remover muitas moedas de uma
    // vez (ex: 230) faria a animação escalonada durar vários segundos —
    // parecendo "travado" em vez de rápido. Cresce com a quantidade até um
    // limite, depois o escalonamento por moeda fica mais apertado.
    final duracaoTotal = Duration(
      milliseconds: (150 + removidas.length * 60).clamp(150, 700),
    );
    final controller = AnimationController(
      vsync: vsync,
      duration: duracaoTotal,
    );

    final n = removidas.length;
    final aleatorio = estiloAnimacao == MoneyRainEstiloAnimacao.aleatorioDoTopo;
    final curvas = <Animation<double>>[
      for (var i = 0; i < n; i++)
        () {
          final atraso = aleatorio
              ? _random.nextDouble()
              : (n <= 1 ? 0.0 : (i / (n - 1)));
          final inicio = (atraso * (1 - duracaoQuedaFracao)).clamp(0.0, 1.0);
          final fim = (inicio + duracaoQuedaFracao).clamp(0.0, 1.0);
          return CurvedAnimation(
            parent: controller,
            curve: Interval(inicio, fim, curve: Curves.easeIn),
          );
        }(),
    ];

    final saida = _MoedaSaindo(
      moedas: removidas,
      curvas: curvas,
      controller: controller,
    );
    setState(() => _saindo.add(saida));

    controller.forward().whenComplete(() {
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() => _saindo.remove(saida));
      controller.dispose();
    });
  }

  @override
  void dispose() {
    for (final saida in _saindo) {
      saida.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Desenha moedas mais raras por cima: ordena por raridade crescente
    // (a última da lista fica no topo da Stack). Não reordena `_moedas`
    // em si — só a lista usada pra montar os widgets — pra manter
    // `adicionar`/`encolherPara` simples (sempre no fim da lista real).
    final ordenadas = [..._moedas]..sort(_compararPorRaridade);

    return Stack(
      children: [
        for (final moeda in ordenadas)
          _MoedaWidget(
            key: ValueKey(moeda),
            moeda: moeda,
            tamanhoArea: widget.tamanhoArea,
            escala: widget.escala,
          ),
        for (final saida in _saindo)
          for (var i = 0; i < saida.moedas.length; i++)
            _MoedaSaindoWidget(
              key: ValueKey(saida.moedas[i]),
              moeda: saida.moedas[i],
              curva: saida.curvas[i],
              tamanhoArea: widget.tamanhoArea,
              escala: widget.escala,
            ),
      ],
    );
  }
}

// Agrupa um lote de moedas removidas de uma vez com o controller
// compartilhado e a curva individual de cada uma (escalonadas — ver
// encolherPara), para que caiam uma a uma em vez de todas juntas.
class _MoedaSaindo {
  final List<_Moeda> moedas;
  final List<Animation<double>> curvas;
  final AnimationController controller;

  _MoedaSaindo({
    required this.moedas,
    required this.curvas,
    required this.controller,
  });
}

class _MoedaWidget extends StatelessWidget {
  final _Moeda moeda;
  final Size tamanhoArea;
  final double escala;

  const _MoedaWidget({
    super.key,
    required this.moeda,
    required this.tamanhoArea,
    this.escala = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final tamanho = moeda.tamanho * escala;
    return AnimatedBuilder(
      animation: moeda.curva,
      child: RepaintBoundary(
        child: Transform.rotate(
          angle: moeda.rotacao,
          child: Text(moeda.emoji, style: TextStyle(fontSize: tamanho)),
        ),
      ),
      builder: (context, child) {
        // Cai de fora da área (acima) até pousar na sua camada da pilha,
        // com leve overshoot (easeOutBack) simulando o "baque" da moeda.
        // Camadas maiores (moedas mais recentes) pousam mais alto,
        // formando um monte que cresce, não uma faixa uniforme no fundo.
        final progresso = moeda.curva.value;
        final alturaPorCamada = tamanho * 0.5;
        final destinoTop =
            tamanhoArea.height - tamanho * 1.1 - moeda.camada * alturaPorCamada;
        final top = -tamanho + (destinoTop + tamanho) * progresso;
        final opacidade = progresso.clamp(0.0, 1.0);

        return Positioned(
          top: top.clamp(-tamanho, tamanhoArea.height),
          left: moeda.x * (tamanhoArea.width - tamanho),
          child: Opacity(opacity: opacidade, child: child),
        );
      },
    );
  }
}

// Igual a _MoedaWidget, mas anima na direção oposta: parte da posição
// pousada (progresso 1) e cai para fora da área (abaixo), sumindo — como
// se a moeda tivesse sido "puxada" da pilha quando o valor diminui.
class _MoedaSaindoWidget extends StatelessWidget {
  final _Moeda moeda;
  final Animation<double> curva;
  final Size tamanhoArea;
  final double escala;

  const _MoedaSaindoWidget({
    super.key,
    required this.moeda,
    required this.curva,
    required this.tamanhoArea,
    this.escala = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final tamanho = moeda.tamanho * escala;
    return AnimatedBuilder(
      animation: curva,
      child: RepaintBoundary(
        child: Transform.rotate(
          angle: moeda.rotacao,
          child: Text(moeda.emoji, style: TextStyle(fontSize: tamanho)),
        ),
      ),
      builder: (context, child) {
        final alturaPorCamada = tamanho * 0.5;
        final posicaoPousada =
            tamanhoArea.height - tamanho * 1.1 - moeda.camada * alturaPorCamada;

        final progresso = curva.value;
        final top =
            posicaoPousada +
            (tamanhoArea.height - posicaoPousada + tamanho) * progresso;
        final opacidade = (1 - progresso).clamp(0.0, 1.0);

        return Positioned(
          top: top,
          left: moeda.x * (tamanhoArea.width - tamanho),
          child: Opacity(opacity: opacidade, child: child),
        );
      },
    );
  }
}

class _Moeda {
  // Mutável: acomodar() troca a referência para uma curva constante,
  // desconectando a moeda do controller do lote antes dele ser
  // descartado — sem precisar recriar o objeto nem o widget.
  Animation<double> curva;
  final double x;
  final int camada;
  final double tamanho;
  final double rotacao;
  final String emoji;
  // Índice na lista MoneyRain._emojis: quanto maior, mais raro/valioso.
  // Usado para desenhar moedas raras sempre por cima das comuns.
  final int raridade;
  // Desempate estável ao ordenar por raridade (sort() do Dart não é
  // garantidamente estável) — preserva a ordem de queda dentro do mesmo
  // nível de raridade.
  final int ordemCriacao;

  _Moeda({
    required this.curva,
    required this.x,
    required this.camada,
    required this.tamanho,
    required this.rotacao,
    required this.emoji,
    required this.raridade,
    required this.ordemCriacao,
  });

  void acomodar() {
    curva = const AlwaysStoppedAnimation<double>(1);
  }
}
