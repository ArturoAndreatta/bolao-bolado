import 'package:bolao_bolado/components/shared/skeletons.dart';
import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/core/app_radii.dart';
import 'package:bolao_bolado/pages/participants/participants_estatisticas.dart';
import 'package:bolao_bolado/pages/participants/participants_lista.dart';
import 'package:bolao_bolado/pages/participants/participants_tabela.dart';
import 'package:flutter/material.dart';

/// Placeholder de um card de estatística — mesma moldura e as MESMAS cores
/// do [CardEstatistica] real (o par fundo/borda vem de [paletaDestaque]).
///
/// Os três cards reais são coloridos (prêmio em verde, prêmio por cota em
/// azul, chance em dourado). Um placeholder neutro no lugar deles troca a
/// tela inteira de cor no instante em que os números chegam — aqui a cor já
/// nasce certa e só o número entra.
class SkeletonCardEstatistica extends StatelessWidget {
  final DestaqueCor destaqueCor;

  /// Largura do bloco do título e do valor. Os três cards têm textos de
  /// tamanhos bem diferentes, e blocos iguais fariam a régua parecer outra
  /// coisa quando os rótulos reais aparecem.
  final double larguraTitulo;
  final double larguraValor;

  const SkeletonCardEstatistica({
    super.key,
    required this.destaqueCor,
    required this.larguraTitulo,
    required this.larguraValor,
  });

  /// Os três cards do painel real, na ordem em que aparecem.
  static const List<SkeletonCardEstatistica> trio = [
    SkeletonCardEstatistica(
      destaqueCor: DestaqueCor.verde,
      larguraTitulo: 84,
      larguraValor: 152,
    ),
    SkeletonCardEstatistica(
      destaqueCor: DestaqueCor.azul,
      larguraTitulo: 104,
      larguraValor: 108,
    ),
    SkeletonCardEstatistica(
      destaqueCor: DestaqueCor.amarelo,
      larguraTitulo: 118,
      larguraValor: 96,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    final paleta = paletaDestaque(cores, destaqueCor);
    return Container(
      // Mesmo padding do card real (v9, não v14): 5px a mais por card
      // empilhavam 15px de salto no celular, onde eles ficam um sobre o
      // outro.
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: paleta.fundo,
        borderRadius: AppRadii.circularSmd,
        border: Border.all(color: paleta.borda, width: 1),
      ),
      // O Shimmer fica DENTRO do card, sobre os blocos: envolvendo o card
      // inteiro, o gradiente pintaria por cima do fundo colorido e da borda,
      // e o placeholder voltaria a ser cinza.
      child: Shimmer(
        // A altura é a da LINHA de texto do card real (valor em corpo 15,
        // com a entrelinha do tema), não a do bloco: medindo pelo bloco, o
        // card sai 6px mais baixo, e no celular os três empilhados somavam
        // quase 20px de salto quando os números entravam.
        child: SizedBox(
          height: 21,
          child: Row(
            children: [
              SkeletonBox(width: larguraTitulo, height: 14),
              const SizedBox(width: 10),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: SkeletonBox(width: larguraValor, height: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton do painel de estatísticas no desktop: os TRÊS cards lado a lado,
/// com o mesmo espaçamento do [PainelEstatisticas] real.
class SkeletonEstatisticasDesktop extends StatelessWidget {
  const SkeletonEstatisticasDesktop({super.key});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < SkeletonCardEstatistica.trio.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: SkeletonCardEstatistica.trio[i]),
          ],
        ],
      ),
    );
  }
}

/// Skeleton da tabela de apostas (desktop).
///
/// O CABEÇALHO é o de verdade ([CabecalhoTabela]): os nomes das colunas não
/// dependem de dado nenhum, e mostrá-los enquanto as linhas carregam diz o
/// que está vindo em vez de esconder. O resto repete a anatomia da tabela —
/// mesmas larguras de coluna, mesma altura de linha ([kAlturaLinhaTabela]),
/// mesma zebra, divisores e o rodapé totalizador.
///
/// [alturaFixa] acompanha o mesmo parâmetro de [TabelaApostas]: com altura
/// cedida pelo pai, as linhas preenchem o que sobrar; sem ela, a tabela
/// cresce com um punhado de linhas.
class SkeletonTabela extends StatelessWidget {
  final bool alturaFixa;

  const SkeletonTabela({super.key, this.alturaFixa = false});

  /// Larguras dos blocos dentro de cada coluna, na ordem das colunas. São
  /// menores que a célula de propósito: bloco ocupando a célula inteira
  /// apaga a grade e a tabela vira um retângulo cinza só.
  static const List<double> blocos = [150, 74, 30, 112, 96];
  static const List<double> larguras = [wNome, wValor, wCotas, wPremio, wData];

  @override
  Widget build(BuildContext context) {
    final corBorda = TabelaApostas.corBorda(context);
    final corpo = _Corpo(alturaFixa: alturaFixa);

    return SingleChildScrollView(
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
              colunaOrdenada: 0,
              ascendente: true,
              // Ordenar uma tabela que ainda não tem linha nenhuma não faz
              // nada — o cabeçalho está aqui pelo texto, não pelo clique.
              onCabecalhoTap: (_) {},
            ),
            Divider(height: 1, thickness: 1, color: corBorda),
            if (alturaFixa) Expanded(child: corpo) else corpo,
            Divider(height: 1, thickness: 1, color: corBorda),
            // Rodapé totalizador: mesma faixa e altura do real (padding
            // vertical 4 sobre a cor de cabeçalho).
            Container(
              color: TabelaApostas.corCabecalho(context),
              child: Shimmer(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    celula(context, indice: 0, bloco: 0),
                    celula(context, indice: 1, bloco: 64, rodape: true),
                    celula(context, indice: 2, bloco: 34, rodape: true),
                    celula(context, indice: 3, bloco: 0),
                    celula(
                      context,
                      indice: 4,
                      bloco: 88,
                      rodape: true,
                      ultima: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Uma célula do skeleton, com a mesma largura, padding e borda direita da
  /// [CelulaLinha] real. [bloco] zero desenha célula vazia (colunas que o
  /// rodapé real não preenche).
  static Widget celula(
    BuildContext context, {
    required int indice,
    required double bloco,
    bool rodape = false,
    bool ultima = false,

    /// Camada de cima do corpo: a borda de coluna já foi desenhada embaixo,
    /// e repeti-la aqui a deixaria dentro do shimmer.
    bool semBorda = false,
  }) {
    final cores = AppCores.de(context);
    return Container(
      width: larguras[indice],
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: rodape ? 4 : 7),
      decoration: (ultima || semBorda || indice == 4)
          ? null
          : BoxDecoration(
              border: Border(right: BorderSide(color: cores.borda, width: 1)),
            ),
      alignment: indice == 0 ? Alignment.centerLeft : Alignment.centerRight,
      child: bloco == 0
          ? const SizedBox(height: 12)
          : SkeletonBox(width: bloco, height: rodape ? 11 : 12),
    );
  }
}

/// Corpo da tabela do skeleton, em DUAS camadas.
///
/// O [Shimmer] pinta com o gradiente tudo que estiver dentro dele — zebra,
/// divisores e bordas de coluna inclusive —, e uma tabela inteira dentro
/// dele vira um retângulo cinza uniforme, sem grade nenhuma. Então a grade
/// (cores das linhas, divisores, bordas verticais) fica numa camada de
/// baixo, sem shimmer, e só os blocos de conteúdo brilham por cima.
class _Corpo extends StatelessWidget {
  final bool alturaFixa;

  const _Corpo({required this.alturaFixa});

  /// Quantidade de linhas quando a altura não é cedida pelo pai.
  static const int _linhasSoltas = 8;

  @override
  Widget build(BuildContext context) {
    final corBorda = TabelaApostas.corBorda(context);
    final cores = AppCores.de(context);

    Widget grade(int i) => Container(
      color: i.isEven ? cores.linhaPar : cores.linhaImpar,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var c = 0; c < SkeletonTabela.larguras.length; c++)
                SkeletonTabela.celula(context, indice: c, bloco: 0),
            ],
          ),
          Divider(height: 1, thickness: 1, color: corBorda),
        ],
      ),
    );

    Widget blocos(int i) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var c = 0; c < SkeletonTabela.larguras.length; c++)
          SkeletonTabela.celula(
            context,
            indice: c,
            bloco: SkeletonTabela.blocos[c],
            semBorda: true,
          ),
      ],
    );

    Widget camada(Widget Function(int) linha) => alturaFixa
        // itemExtent igual ao da tabela real, e o ListView corta na altura
        // que houver — o placeholder enche a tabela inteira em vez de
        // terminar no meio com um vazio embaixo.
        ? ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemExtent: kAlturaLinhaTabela,
            itemCount: 40,
            itemBuilder: (_, i) => linha(i),
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _linhasSoltas; i++)
                SizedBox(height: kAlturaLinhaTabela, child: linha(i)),
            ],
          );

    final corpo = Stack(
      children: [
        camada(grade),
        Positioned.fill(child: Shimmer(child: camada(blocos))),
      ],
    );

    return SizedBox(
      width: larguraTotal,
      child: alturaFixa
          ? corpo
          : SizedBox(height: kAlturaLinhaTabela * _linhasSoltas, child: corpo),
    );
  }
}

/// Placeholder de uma linha de participante na lista mobile — mesma altura
/// ([kAlturaLinhaLista]), mesmo padding e mesma anatomia da linha real:
/// avatar, nome com o prêmio embaixo e, à direita, valor e cotas.
class SkeletonLinhaParticipante extends StatelessWidget {
  /// Quanto da largura livre o nome ocupa — nomes reais têm tamanhos
  /// diferentes, e todos iguais viram um código de barras.
  final double fatorNome;

  const SkeletonLinhaParticipante({super.key, this.fatorNome = 0.85});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kAlturaLinhaLista,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonBox(width: 32, height: 32, radius: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: fatorNome,
                    child: const SkeletonBox(
                      width: double.infinity,
                      height: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: fatorNome * 0.62,
                    child: const SkeletonBox(
                      width: double.infinity,
                      height: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: const [
                SkeletonBox(width: 62, height: 14),
                SizedBox(height: 4),
                SkeletonBox(width: 44, height: 12),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder de uma bolha de mensagem do chat, nas medidas da
/// [BolhaMensagem] real: avatar de 28, nome do autor acima da primeira
/// bolha do bloco e o mesmo respiro entre blocos (8) e dentro deles (2).
class SkeletonBolhaMensagem extends StatelessWidget {
  final bool isMinha;
  final double largura;

  /// Primeira bolha de uma sequência do mesmo autor — é ela que mostra o
  /// avatar e o nome; as seguintes só reservam o espaço do avatar.
  final bool iniciaBloco;

  const SkeletonBolhaMensagem({
    super.key,
    required this.isMinha,
    required this.largura,
    this.iniciaBloco = true,
  });

  /// Altura do corpo da bolha de uma linha: padding 7+7 da bolha real mais a
  /// linha de texto.
  static const double _alturaBolha = 33;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: iniciaBloco ? 8 : 2, bottom: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isMinha
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isMinha) ...[
            iniciaBloco
                ? const SkeletonBox(width: 28, height: 28, radius: 14)
                : const SizedBox(width: 28),
            const SizedBox(width: 8),
          ],
          Column(
            crossAxisAlignment: isMinha
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (!isMinha && iniciaBloco)
                const Padding(
                  padding: EdgeInsets.only(left: 10, bottom: 3),
                  child: SkeletonBox(width: 64, height: 11),
                ),
              SkeletonBox(width: largura, height: _alturaBolha, radius: 16),
            ],
          ),
        ],
      ),
    );
  }
}

/// A conversa que os dois skeletons de chat desenham (o card inteiro e só a
/// lista de mensagens). Fica em um lugar só para as duas telas mostrarem a
/// mesma coisa, agrupada como uma conversa de verdade: alguém fala duas
/// vezes seguidas, você responde, e por aí.
const List<SkeletonBolhaMensagem> kConversaSkeleton = [
  SkeletonBolhaMensagem(isMinha: false, largura: 150),
  SkeletonBolhaMensagem(isMinha: false, largura: 104, iniciaBloco: false),
  SkeletonBolhaMensagem(isMinha: true, largura: 126),
  SkeletonBolhaMensagem(isMinha: false, largura: 168),
  SkeletonBolhaMensagem(isMinha: true, largura: 92),
  SkeletonBolhaMensagem(isMinha: true, largura: 140, iniciaBloco: false),
];

/// Skeleton do card de chat da sala (desktop), reproduzindo cabeçalho,
/// bolhas de mensagem e rodapé de envio bloqueado.
class SkeletonChatSala extends StatelessWidget {
  const SkeletonChatSala({super.key});

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    return SizedBox.expand(
      child: Material(
        color: cores.card,
        elevation: 3,
        shadowColor: cores.sombra,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.circularSmd,
          side: BorderSide(color: cores.borda, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: cores.campo,
                border: Border(
                  bottom: BorderSide(color: cores.borda, width: 1),
                ),
              ),
              child: Row(
                children: [
                  // Ícone e título com a MESMA cor e tamanho do cabeçalho
                  // real (_CabecalhoChat): esta faixa não está carregando
                  // nada, é a moldura do chat — desbotá-la fazia o cabeçalho
                  // acender quando as mensagens chegavam.
                  Icon(Icons.chat_bubble_outline, size: 16, color: cores.azul),
                  const SizedBox(width: 8),
                  Text(
                    'Chat da Sala',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: cores.texto,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Shimmer(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    // A lista real é reverse:true — as mensagens ficam
                    // ancoradas no PÉ do chat, não no topo. Com as bolhas
                    // em cima, elas desciam de uma vez quando as mensagens
                    // chegavam.
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: kConversaSkeleton,
                  ),
                ),
              ),
            ),
            Container(
              // Mesmo padding/estrutura do estado "campo de texto liberado"
              // de _CampoEnvioChat (não o estado "sem permissão", mais baixo):
              // é esse o estado que a maioria dos usuários vê ao abrir o chat,
              // e a diferença de altura entre os dois fazia o card "pular" ao
              // trocar do skeleton para o ChatSala real.
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: cores.borda, width: 1)),
              ),
              child: Shimmer(
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: cores.campo,
                          borderRadius: AppRadii.circularPill,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: cores.campo,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton completo do painel de participantes.
///
/// Reproduz a estrutura final no mobile (os três cards de estatística, a
/// barra de busca e ordenação, a lista com rodapé) já no primeiro frame,
/// para o carregamento parecer uma transição de conteúdo e não a montagem
/// tardia da tela inteira.
class SkeletonParticipantes extends StatelessWidget {
  final bool mobile;

  const SkeletonParticipantes({super.key, required this.mobile});

  /// Variação de largura dos nomes na lista.
  static const List<double> _fatoresNome = [0.86, 0.5, 0.62, 0.74, 0.44];

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    if (!mobile) return const SkeletonEstatisticasDesktop();

    // Os três cards empilhados (é assim que PainelEstatisticas fica em
    // largura de celular) e, abaixo, a barra de busca + ordenação.
    final cabecalho = <Widget>[
      for (final card in SkeletonCardEstatistica.trio) ...[
        card,
        const SizedBox(height: 8),
      ],
      const SizedBox(height: 4),
      Shimmer(
        child: Row(
          children: const [
            Expanded(
              child: SkeletonBox(
                width: double.infinity,
                height: 44,
                radius: AppRadii.smd,
              ),
            ),
            SizedBox(width: 8),
            SkeletonBox(width: 44, height: 44, radius: AppRadii.smd),
            SizedBox(width: 8),
            SkeletonBox(width: 78, height: 44, radius: AppRadii.smd),
          ],
        ),
      ),
      const SizedBox(height: 12),
    ];

    // Lista + rodapé (total | cotas | contagem), na mesma moldura de
    // participants_painel.dart. A lista real não tem divisor entre linhas:
    // quem separa é a cor de fundo de cada aposta.
    final listaComRodape = Container(
      decoration: BoxDecoration(
        border: Border.all(color: cores.borda, width: 1.5),
        borderRadius: AppRadii.circularSmd,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Shimmer(
              child: ListView.builder(
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemExtent: kAlturaLinhaLista,
                itemCount: 30,
                itemBuilder: (_, i) => SkeletonLinhaParticipante(
                  fatorNome: _fatoresNome[i % _fatoresNome.length],
                ),
              ),
            ),
          ),
          Divider(height: 1, thickness: 1, color: cores.borda),
          Container(
            color: cores.superficieAlta,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Shimmer(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: const [
                  SkeletonBox(width: 110, height: 11),
                  SizedBox(width: 12),
                  SkeletonBox(width: 90, height: 11),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    // LayoutBuilder distingue os dois modos de montagem do painel real
    // (participants_painel.dart): dentro do card de seção a altura é fixa
    // (maxHeight finito) e a lista precisa caber no que sobra; fora dele a
    // altura é livre e a coluna cresce. Sem isso, a pilha de estatísticas +
    // busca + linhas estoura a altura do card.
    return LayoutBuilder(
      builder: (context, constraints) {
        final alturaLimitada = constraints.maxHeight.isFinite;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: alturaLimitada ? MainAxisSize.max : MainAxisSize.min,
          children: [
            ...cabecalho,
            alturaLimitada
                ? Expanded(child: listaComRodape)
                : SizedBox(height: 320, child: listaComRodape),
          ],
        );
      },
    );
  }
}
