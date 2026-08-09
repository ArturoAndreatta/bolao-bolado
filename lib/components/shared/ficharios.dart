import 'package:bolao_bolado/components/shared/custom_card.dart';
import 'package:bolao_bolado/core/app_cores.dart';
import 'package:flutter/material.dart';

/// Descreve uma seção do [Fichario]: rótulo, ícone e o índice que ela
/// representa no estado da página — não precisa bater com a posição visual
/// na fileira. A cor NÃO é definida aqui: o [Fichario] atribui
/// automaticamente uma cor de [_paletaCores] pela posição visual da aba na
/// fileira (1ª verde-água, 2ª azul, 3ª dourado, 4ª roxo, 5ª coral), a menos
/// que [corAtiva] seja passada explicitamente para forçar uma cor fixa. A
/// paleta cobre 5 abas sem repetir; acima disso ela volta a ciclar, então ao
/// criar uma 6ª seção adicione um tom novo em [_paletaCores] em vez de
/// deixar a cor repetir.
class AbaFichario {
  final String texto;
  final IconData icone;
  final int indice;
  final Color? corAtiva;

  const AbaFichario({
    required this.texto,
    required this.icone,
    required this.indice,
    this.corAtiva,
  });
}

/// Paleta padrão das abas, na ordem em que se repetem pela fileira — cada
/// tom deriva da identidade visual do app (gradiente de fundo dourado→
/// verde-água em GradientDecoration + azul de ação primária dos botões),
/// nunca de cores genéricas sem relação com o resto do app.
///
/// Os três primeiros tons são os originais (verde-água, azul, dourado) e não
/// mudam de posição: as telas que já usavam o Fichario com até 3 abas
/// continuam pintadas exatamente como antes. Os dois últimos existem porque
/// a paleta era curta demais para o Painel ADM (5 seções) — a 4ª aba caía de
/// volta no verde-água e a 5ª no azul, repetindo cor com as duas primeiras.
/// Ambos seguem a mesma regra: derivados da paleta do app (o roxo é o mesmo
/// AdminCores.roxo já usado no card "Sala" do dashboard; o coral é o vermelho
/// AdminCores.vermelho puxado para um tom mais quente/terroso, coerente com o
/// dourado do gradiente) e com contraste suficiente para texto branco por
/// cima, já que a aba ativa desenha ícone e rótulo em branco.
///
/// Deixou de ser uma `const List` e virou função do tema: no escuro os cinco
/// tons são versões clareadas dos mesmos matizes (ver [AppCores]), senão as
/// abas ficariam escuras demais para o texto branco que elas desenham por
/// cima. A ORDEM é a mesma nos dois temas, então nenhuma aba troca de cor ao
/// alternar claro/escuro — só de tom.
List<Color> _paletaCores(AppCores cores) => [
  cores.verdeAgua, // verde-água do gradiente, mais saturado — sempre 1ª
  cores.azul, // azul de ação primária do app — sempre 2ª
  cores.dourado, // dourado do gradiente, mais saturado — sempre 3ª
  cores.roxo, // roxo (mesma família do azul, um passo mais frio)
  cores.coral, // coral: vermelho do app puxado para o quente do dourado
];

/// Layout de fichário mobile: pill de navegação encostada direto no
/// CustomCard pai (sem gap nem sombra entre os dois), com a cor da seção
/// ativa continuando como topo do card — como se a aba fosse literalmente
/// a borda superior do fichário. Segue o mesmo padrão de card usado em
/// todo o app: CustomCard pai (cor da seção) → CustomCard filho (branco).
///
/// [builder] recebe a seção selecionada e devolve só o CONTEÚDO dela (sem
/// nenhum CustomCard próprio — o Fichario já monta o par pai/filho).
///
/// Todas as abas são construídas de uma vez (via [builder] chamado para cada
/// item de [abas]) e mantidas montadas o tempo todo — só a ativa fica visível
/// ([Visibility] com maintainState esconde as outras sem desmontá-las). Isso
/// preserva StreamSubscriptions e estado (ex: streamBets, chat) entre trocas
/// de aba, em vez de recarregar tudo do zero a cada clique — era o que
/// acontecia antes, quando só a folha ativa era construída. O porquê de
/// Visibility e não Offstage está no build().
///
/// A troca de aba é resolvida DENTRO deste widget, por um [ValueNotifier]
/// interno, e só depois notificada ao pai via [onSelecionar]. O motivo é
/// latência percebida: quando o índice ativo morava no State da página, cada
/// toque disparava setState na raiz e rebuildava o [builder] das TRÊS abas
/// (lista de participantes, chat, minha aposta — cada uma com LayoutBuilder,
/// sorts e folds próprios) antes de a cor da aba selecionada mudar. A troca
/// de cor ficava esperando esse trabalho todo terminar, o que se sentia como
/// "lentidão" no toque. Agora o notifier reconstrói só a pill e o cromo
/// colorido; o conteúdo das abas entra pelo `child` dos
/// ValueListenableBuilder e não é reconstruído pela troca de aba.
///
/// A troca de cor não tem animação, por decisão de UX: já foi animada em
/// 200ms e em 120ms, e nos dois casos a interpolação lia como atraso mesmo
/// depois de o rebuild sair do caminho crítico.
class Fichario extends StatefulWidget {
  final List<AbaFichario> abas;
  final int abaAtiva;
  final void Function(int) onSelecionar;
  final Widget Function(BuildContext context, AbaFichario abaAtiva) builder;
  // Quando true, remove toda a margem externa (pill, faixa colorida e
  // CustomCard) — o fichário encosta nas 4 bordas da área disponível em vez
  // de sobrar um respiro de 10px mostrando o gradiente de fundo por trás.
  final bool semMargem;
  // Quando true, a folha ativa (CustomCard colorido + branco) se expande
  // para preencher toda a altura disponível do pai, em vez de encolher pro
  // tamanho do conteúdo — precisa estar dentro de algo com altura definida
  // (ex: SizedBox.expand ou Column com Expanded). O [builder] então recebe
  // a altura sobrando via LayoutBuilder embutido, então pode devolver
  // conteúdo com scroll interno sem precisar calcular altura manualmente.
  final bool esticarAltura;

  const Fichario({
    super.key,
    required this.abas,
    required this.abaAtiva,
    required this.onSelecionar,
    required this.builder,
    this.semMargem = false,
    this.esticarAltura = false,
  });

  @override
  State<Fichario> createState() => _FicharioState();
}

class _FicharioState extends State<Fichario> {
  // Índice ativo local. É o notifier — e não um campo com setState — que faz
  // a troca de aba repintar só a pill e o cromo colorido: setState aqui
  // rebuildaria também o Stack de conteúdo, que é justamente o trabalho
  // pesado que se quer manter fora do caminho do toque.
  late final ValueNotifier<int> _abaAtiva = ValueNotifier(widget.abaAtiva);

  @override
  void didUpdateWidget(covariant Fichario oldWidget) {
    super.didUpdateWidget(oldWidget);
    // O pai continua sendo dono da verdade: deep link (?aba=chat), troca de
    // aba programática (ex: onApostaConfirmada) e qualquer outro caminho
    // externo chegam por aqui e sobrescrevem o estado local.
    if (widget.abaAtiva != oldWidget.abaAtiva) {
      _abaAtiva.value = widget.abaAtiva;
    }
  }

  @override
  void dispose() {
    _abaAtiva.dispose();
    super.dispose();
  }

  // Pinta a aba na hora e só depois avisa o pai. O onSelecionar do pai faz
  // setState na página inteira, mas esse rebuild deixou de estar no caminho
  // da cor: quando ele roda, o notifier já mudou e a pill já foi remarcada
  // com a aba nova. Avisar o pai continua necessário para manter o estado
  // dele em sincronia (deep links, troca programática de aba).
  void _selecionar(int indice) {
    if (_abaAtiva.value == indice) return;
    _abaAtiva.value = indice;
    widget.onSelecionar(indice);
  }

  // Cor de cada aba pela posição na fileira (não pelo índice de estado):
  // a 1ª aba visível sempre recebe a mesma cor, a 2ª outra, etc. — mantém a
  // sequência coerente mesmo se abas forem adicionadas/removidas/reordenadas.
  Color _corPara(AppCores cores, int posicao, AbaFichario aba) {
    final paleta = _paletaCores(cores);
    return aba.corAtiva ?? paleta[posicao % paleta.length];
  }

  Color _corDaAbaAtiva(AppCores cores, int abaAtiva) {
    final posicao = widget.abas.indexWhere((a) => a.indice == abaAtiva);
    final aba = posicao == -1 ? widget.abas.first : widget.abas[posicao];
    return _corPara(cores, posicao == -1 ? 0 : posicao, aba);
  }

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    final margem = widget.semMargem ? 0.0 : 10.0;

    // Constrói TODAS as abas de uma vez (não só a ativa) e as mantém
    // montadas e "vivas" (streams, scroll position, campos de formulário)
    // por trás da ativa, em vez de recarregar tudo do zero a cada clique.
    // Cada uma carrega uma key estável pelo índice da aba para o Flutter
    // nunca as confundir/recriar ao reordenar.
    //
    // Visibility com maintainState (e NÃO Offstage): Offstage pula só a fase
    // de paint — o filho continua sendo medido e posicionado a cada frame.
    // Aqui isso custava caro, porque as abas escondidas são justamente as
    // mais pesadas de medir: a lista de participantes é uma Column dentro de
    // SingleChildScrollView (sem virtualização, toda linha é medida sempre)
    // e o chat tem seu próprio ListView. Visibility sem maintainSize tira o
    // filho invisível do layout também, mantendo só o State vivo — que é a
    // única parte que interessa preservar aqui.
    //
    // Só a visibilidade depende da aba ativa, então cada filho tem seu
    // próprio ValueListenableBuilder bem em volta: trocar de aba reconstrói
    // apenas esses widgets de uma linha, nunca o resultado do builder()
    // (lista de participantes, chat etc), que fica no `child` preservado.
    final conteudo = Stack(
      children: [
        for (final a in widget.abas)
          ValueListenableBuilder<int>(
            key: ValueKey(a.indice),
            valueListenable: _abaAtiva,
            child: Builder(builder: (context) => widget.builder(context, a)),
            builder: (context, abaAtiva, child) => Visibility(
              visible: a.indice == abaAtiva,
              maintainState: true,
              child: child!,
            ),
          ),
      ],
    );

    return SizedBox(
      width: double.infinity,
      height: widget.esticarAltura ? double.infinity : null,
      child: Column(
        // start: a pill agora encolhe pro tamanho do próprio conteúdo (não
        // tem mais width:double.infinity) — sem start, o Column centraliza
        // esse filho mais estreito horizontalmente em vez de alinhar à
        // esquerda como pedido.
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: widget.esticarAltura
            ? MainAxisSize.max
            : MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(margem, margem, margem, 0),
            child: ValueListenableBuilder<int>(
              valueListenable: _abaAtiva,
              builder: (context, abaAtiva, _) => _PillNavegacao(
                abas: widget.abas,
                abaAtiva: abaAtiva,
                onSelecionar: _selecionar,
                corPara: (posicao, aba) => _corPara(cores, posicao, aba),
                cantosSuperioresRetos: widget.semMargem,
              ),
            ),
          ),
          // Faixa colorida + CustomCard num ValueListenableBuilder só: os
          // dois pintam exatamente a mesma cor derivada da aba ativa, então
          // separá-los faria o mesmo indexWhere rodar duas vezes por troca
          // de aba e criaria dois pontos de rebuild onde um basta. O
          // conteúdo entra por `child`, fora do builder: a troca de cor não
          // arrasta junto o rebuild do Stack de abas, que é o trabalho caro.
          //
          // O Expanded aqui é obrigatório quando esticarAltura: a Column
          // interna abaixo usa MainAxisSize.max e o CustomCard devolve um
          // Expanded próprio, então sem esta restrição de altura a Column
          // externa recebe um filho pedindo altura infinita — o
          // "RenderFlex... unbounded height" que no Flutter web não estoura
          // visivelmente, só deixa a tela em branco.
          _TalvezExpandido(
            expandir: widget.esticarAltura,
            child: ValueListenableBuilder<int>(
              valueListenable: _abaAtiva,
              child: widget.esticarAltura
                  ? Expanded(child: conteudo)
                  : conteudo,
              builder: (context, abaAtiva, child) {
                final corAtiva = _corDaAbaAtiva(cores, abaAtiva);
                // Moldura da folha (faixa de 7px + borda do CustomCard pai).
                //
                // No claro é a própria cor da seção, e é ela que faz a folha
                // parecer uma peça só com a aba. No escuro a mesma cor cheia
                // vira uma tarja fluorescente contornando todo o conteúdo —
                // num app já denso de números, é a coisa mais chamativa da
                // tela. Aqui a cor entra só insinuada sobre a superfície: a
                // conexão com a aba continua legível, sem o brilho.
                final corMoldura = cores.escuro
                    ? Color.alphaBlend(
                        corAtiva.withValues(alpha: 0.22),
                        cores.cardExterno,
                      )
                    : corAtiva;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: widget.esticarAltura
                      ? MainAxisSize.max
                      : MainAxisSize.min,
                  children: [
                    // Faixa colorida entre a pill e o CustomCard abaixo, do
                    // mesmo tamanho da margem que já existia nas laterais/
                    // embaixo — sem isso, o respiro do topo era 0 (pill colada
                    // direto no card), bem menor que os outros três lados.
                    // Preenchida com a cor da seção (não o fundo da página)
                    // para não desconectar visualmente pill e card.
                    Padding(
                      padding: EdgeInsets.fromLTRB(margem, 0, margem, 0),
                      child: Container(height: 7, color: corMoldura),
                    ),
                    CustomCard(
                      // Sem key por aba.indice: isso trocaria a identidade do
                      // widget a cada troca de aba, desmontando o Stack de abas
                      // abaixo (e todo o estado/streams das inativas junto) — o
                      // oposto do que se quer aqui.
                      color: corMoldura,
                      maxWidth: double.infinity,
                      esticarLargura: true,
                      esticarAltura: widget.esticarAltura,
                      // Cantos superiores retos: a faixa colorida acima já cobre
                      // esse arredondamento, então o CustomCard só arredonda
                      // embaixo — sem isso sobraria uma quina clara entre os
                      // dois.
                      cantoSuperiorEsquerdoReto: true,
                      cantoSuperiorDireitoReto: true,
                      // Sem margem: o card encosta direto nas bordas da tela,
                      // então os cantos inferiores também ficam retos —
                      // arredondado aqui deixaria um triângulo do gradiente de
                      // fundo visível no canto.
                      cantoInferiorEsquerdoReto: widget.semMargem,
                      cantoInferiorDireitoReto: widget.semMargem,
                      margemFichario: margem,
                      children: [
                        CustomCard(
                          isChild: true,
                          maxWidth: double.infinity,
                          esticarLargura: true,
                          esticarAltura: widget.esticarAltura,
                          children: [child!],
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Envolve [child] num [Expanded] só quando [expandir] é true, devolvendo-o
/// intacto caso contrário. Existe porque o Fichario tem os dois modos: com
/// esticarAltura a folha ativa precisa do Expanded para receber altura
/// limitada dentro da Column; sem ele, um Expanded forçaria a folha a
/// ocupar altura infinita em vez de encolher pro conteúdo.
class _TalvezExpandido extends StatelessWidget {
  final bool expandir;
  final Widget child;

  const _TalvezExpandido({required this.expandir, required this.child});

  @override
  Widget build(BuildContext context) {
    return expandir ? Expanded(child: child) : child;
  }
}

/// Barra de navegação com os itens lado a lado, alinhados à ESQUERDA: cada
/// um assume a largura do seu próprio conteúdo (ícone + nome) — não
/// esticam para preencher a pill toda, então sobra espaço vazio à direita
/// quando há poucas abas (comportamento desejado).
/// Com muitas abas (soma maior que a largura disponível), a barra passa a
/// rolar horizontalmente em vez de espremer/estourar os itens. Cantos
/// inferiores retos: a base da pill precisa encostar sem quina no
/// CustomCard abaixo.
class _PillNavegacao extends StatelessWidget {
  final List<AbaFichario> abas;
  final int abaAtiva;
  final void Function(int) onSelecionar;
  final Color Function(int posicao, AbaFichario aba) corPara;
  // Zera o arredondamento dos cantos superiores da pill: usado quando o
  // Fichario roda em modo semMargem, onde a pill encosta direto na borda
  // superior da tela e um canto arredondado deixaria o gradiente de fundo
  // visível ali.
  final bool cantosSuperioresRetos;

  const _PillNavegacao({
    required this.abas,
    required this.abaAtiva,
    required this.onSelecionar,
    required this.corPara,
    this.cantosSuperioresRetos = false,
  });

  static const double _altura = 48;

  @override
  Widget build(BuildContext context) {
    // Sem RepaintBoundary aqui: ela existia para confinar a animação de
    // troca de aba numa camada própria, mas a animação foi removida (a cor
    // troca no mesmo frame do toque). Sem nada animando, a pill repinta uma
    // única vez por troca de aba, e manter a boundary só somaria uma camada
    // de composição extra a cada frame para economizar um repaint pontual.
    final cores = AppCores.de(context);
    return Container(
      // width infinity: sem isso, o Container encolhia para o tamanho do
      // conteúdo (SingleChildScrollView/Row das abas), então o fundo cinza
      // só cobria até onde as abas terminavam, sobrando o gradiente da
      // página visível no resto da largura — agora o fundo vai até a borda
      // direita, com as abas alinhadas à esquerda dentro dele.
      width: double.infinity,
      height: _altura,
      // Sem padding lateral: a borda do container precisa se alinhar
      // exatamente com a borda do CustomCard abaixo (ambos a 10px da
      // margem externa) — o respiro entre os itens e a borda da pill vem
      // da margem de cada _ItemNavegacao, não deste padding.
      padding: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        // Mesmo tom neutro usado em cards/fundos do app: a barra precisa se
        // integrar à paleta do tema ativo, não destoar como um bloco solto.
        color: cores.ficharioFundo,
        borderRadius: BorderRadius.only(
          topLeft: cantosSuperioresRetos
              ? Radius.zero
              : const Radius.circular(12),
          topRight: cantosSuperioresRetos
              ? Radius.zero
              : const Radius.circular(12),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < abas.length; i++)
              _ItemNavegacao(
                aba: abas[i],
                cor: corPara(i, abas[i]),
                ativo: abas[i].indice == abaAtiva,
                primeira: i == 0,
                onTap: () => onSelecionar(abas[i].indice),
              ),
          ],
        ),
      ),
    );
  }
}

class _ItemNavegacao extends StatelessWidget {
  final AbaFichario aba;
  final Color cor;
  final bool ativo;
  final bool primeira;
  final VoidCallback onTap;

  const _ItemNavegacao({
    required this.aba,
    required this.cor,
    required this.ativo,
    required this.primeira,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        // Container puro, NÃO AnimatedContainer: a troca de cor da aba
        // acontece no mesmo frame do toque, sem interpolação. Já foi animado
        // (200ms, depois 120ms) e nos dois casos a transição lia como
        // atraso — o olho só reconhece a aba selecionada quando a animação
        // passa da metade, então qualquer duração aqui trabalha contra a
        // sensação de resposta imediata. Trocar de volta por
        // AnimatedContainer traz esse atraso percebido de volta.
        child: Container(
          // Sem width fixo: o item encolhe/cresce para o tamanho do seu
          // próprio conteúdo (ícone + nome).
          padding: const EdgeInsets.symmetric(horizontal: 14),
          // Recuo antes da primeira aba: como num fichário físico, a
          // primeira etiqueta não começa exatamente na borda da capa, fica
          // um pouco recuada pra dentro — reforça a leitura de "aba" em vez
          // de um bloco colado na quina.
          margin: EdgeInsets.only(left: primeira ? 16 : 0, right: 0),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            // Item ativo vira um bloco cheio na cor da seção — a mesma cor
            // continua no topo do CustomCard logo abaixo, fundindo os dois
            // numa peça só. Gradiente sutil (mais claro em cima, mais
            // escuro embaixo) em vez de cor chapada: reforça a sensação de
            // volume/profundidade, como se a aba fosse fisicamente
            // "levantada" da capa do fichário.
            color: ativo ? null : Colors.transparent,
            gradient: ativo
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: cores.escuro
                        // Mesma tinta da moldura logo abaixo (22% sobre a
                        // superfície): aba e folha precisam ler como UMA peça,
                        // e a cor cheia deixava a aba fluorescente sobre o
                        // feltro enquanto a moldura já vinha suavizada.
                        // O volume continua vindo do degradê topo→base, agora
                        // entre dois tons insinuados em vez de dois berrantes.
                        ? [
                            Color.alphaBlend(
                              cor.withValues(alpha: 0.30),
                              cores.cardExterno,
                            ),
                            Color.alphaBlend(
                              cor.withValues(alpha: 0.22),
                              cores.cardExterno,
                            ),
                          ]
                        : [Color.lerp(cor, Colors.white, 0.12)!, cor],
                  )
                : null,
            // Contorno sutil nos itens inativos: sem isso, todos ficavam
            // visualmente fundidos numa única massa cinza contra o fundo
            // da pill (mesma cor), sem separação clara entre uma aba e
            // outra quando nenhuma delas está selecionada.
            // No escuro o contorno precisa CLAREAR a aba inativa: um preto
            // translúcido sobre superfície escura simplesmente some, e as
            // abas voltariam a se fundir numa massa só (o problema que este
            // contorno existe para resolver).
            border: ativo
                ? null
                : Border.all(
                    color: cores.escuro
                        ? Colors.white.withValues(alpha: 0.10)
                        : Colors.black.withValues(alpha: 0.08),
                  ),
            // Cantos inferiores sempre retos (ativa ou não): todas as abas
            // "descem" até a base da pill como divisórias planas, só o
            // topo arredonda — reforça a leitura de aba de fichário em vez
            // de pill/chip solto.
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(10),
              topRight: Radius.circular(10),
            ),
            // Sombra só na aba ativa: dá profundidade, como se ela
            // estivesse "por cima" das outras — nas inativas (planas,
            // sem sombra) reforça que só a selecionada se destaca da
            // capa do fichário, que é como abas de divisória real
            // funcionam (a aberta "salta" para frente).
            // No escuro o brilho colorido a 35% virava um halo em volta da
            // aba — sobre feltro a sombra é preta e discreta, como a de
            // qualquer outra superfície elevada.
            boxShadow: ativo
                ? [
                    BoxShadow(
                      color: cores.escuro
                          ? Colors.black.withValues(alpha: 0.35)
                          : cor.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Ícone e rótulo da aba ativa ficam brancos também no escuro.
              // Chegaram a usar a cor da seção (para compensar o fundo que
              // deixou de ser cor cheia), mas cor sobre a MESMA cor a 22% não
              // passa AA em nenhuma tinta testada — no roxo e no azul fica em
              // ~3.4:1. A identificação da seção vem do fundo tingido da aba e
              // da moldura logo abaixo.
              Icon(
                aba.icone,
                size: 17,
                color: ativo ? Colors.white : cores.textoFraco,
              ),
              // Nome sempre visível (ativa ou não): identifica cada seção
              // por extenso na fileira, não só pelo ícone.
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(
                  aba.texto,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ativo ? Colors.white : cores.textoSuave,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
