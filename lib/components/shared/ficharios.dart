import 'package:bolao_bolado/components/shared/custom_card.dart';
import 'package:flutter/material.dart';

/// Descreve uma seção do [Fichario]: rótulo, ícone e o índice que ela
/// representa no estado da página — não precisa bater com a posição visual
/// na fileira. A cor NÃO é definida aqui: o [Fichario] atribui
/// automaticamente uma cor de [_paletaCores] pela posição visual da aba na
/// fileira (1ª aba sempre verde, 2ª sempre azul, 3ª sempre dourado, e assim
/// por diante, ciclando se houver mais abas que cores), a menos que
/// [corAtiva] seja passada explicitamente para forçar uma cor fixa.
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
const List<Color> _paletaCores = [
  Color(0xFF4FA98A), // verde-água do gradiente, mais saturado — sempre 1ª
  Color(0xFF487DE5), // azul de ação primária do app — sempre 2ª
  Color(0xFFDBA92E), // dourado do gradiente, mais saturado — sempre 3ª
];

/// Layout de fichário mobile: pill de navegação encostada direto no
/// CustomCard pai (sem gap nem sombra entre os dois), com a cor da seção
/// ativa continuando como topo do card — como se a aba fosse literalmente
/// a borda superior do fichário. Segue o mesmo padrão de card usado em
/// todo o app: CustomCard pai (cor da seção) → CustomCard filho (branco).
///
/// [builder] recebe a seção selecionada e devolve só o CONTEÚDO dela (sem
/// nenhum CustomCard próprio — o Fichario já monta o par pai/filho).
class Fichario extends StatelessWidget {
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

  // Cor de cada aba pela posição na fileira (não pelo índice de estado):
  // a 1ª aba visível sempre recebe a mesma cor, a 2ª outra, etc. — mantém a
  // sequência coerente mesmo se abas forem adicionadas/removidas/reordenadas.
  Color _corPara(int posicao, AbaFichario aba) {
    return aba.corAtiva ?? _paletaCores[posicao % _paletaCores.length];
  }

  @override
  Widget build(BuildContext context) {
    final posicaoAtiva = abas.indexWhere((a) => a.indice == abaAtiva);
    final aba = posicaoAtiva == -1 ? abas.first : abas[posicaoAtiva];
    final corAtiva = _corPara(posicaoAtiva == -1 ? 0 : posicaoAtiva, aba);
    final margem = semMargem ? 0.0 : 10.0;

    final conteudo = Builder(builder: (context) => builder(context, aba));

    return SizedBox(
      width: double.infinity,
      height: esticarAltura ? double.infinity : null,
      child: Column(
        // start: a pill agora encolhe pro tamanho do próprio conteúdo (não
        // tem mais width:double.infinity) — sem start, o Column centraliza
        // esse filho mais estreito horizontalmente em vez de alinhar à
        // esquerda como pedido.
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: esticarAltura ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(margem, margem, margem, 0),
            child: _PillNavegacao(
              abas: abas,
              abaAtiva: abaAtiva,
              onSelecionar: onSelecionar,
              corPara: _corPara,
              cantosSuperioresRetos: semMargem,
            ),
          ),
          // Faixa colorida (mesma cor da aba ativa) entre a pill e o
          // CustomCard abaixo, do mesmo tamanho da margem que já existia
          // nas laterais/embaixo — sem isso, o respiro do topo era 0 (pill
          // colada direto no card), bem menor que os outros três lados.
          // Preenchida com a cor da seção (não o fundo da página) para não
          // desconectar visualmente pill e card.
          Padding(
            padding: EdgeInsets.fromLTRB(margem, 0, margem, 0),
            child: Container(height: 7, color: corAtiva),
          ),
          CustomCard(
            key: ValueKey(aba.indice),
            color: corAtiva,
            maxWidth: double.infinity,
            esticarLargura: true,
            esticarAltura: esticarAltura,
            // Cantos superiores retos: a faixa colorida acima já cobre
            // esse arredondamento, então o CustomCard só arredonda
            // embaixo — sem isso sobraria uma quina clara entre os dois.
            cantoSuperiorEsquerdoReto: true,
            cantoSuperiorDireitoReto: true,
            // Sem margem: o card encosta direto nas bordas da tela, então
            // os cantos inferiores também ficam retos — arredondado aqui
            // deixaria um triângulo do gradiente de fundo visível no canto.
            cantoInferiorEsquerdoReto: semMargem,
            cantoInferiorDireitoReto: semMargem,
            margemFichario: margem,
            children: [
              CustomCard(
                isChild: true,
                maxWidth: double.infinity,
                esticarLargura: true,
                esticarAltura: esticarAltura,
                children: [
                  esticarAltura ? Expanded(child: conteudo) : conteudo,
                ],
              ),
            ],
          ),
        ],
      ),
    );
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
  // Cinza claro (mesmo tom neutro usado em cards/fundos do app inteiro):
  // a barra de navegação precisa se integrar à paleta clara existente, não
  // destoar como um elemento de dark-mode isolado no meio da tela.
  static const Color _corFundo = Color(0xFFEDEBE8);

  @override
  Widget build(BuildContext context) {
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
        color: _corFundo,
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
                ehPrimeira: i == 0,
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
  final bool ehPrimeira;
  final VoidCallback onTap;

  const _ItemNavegacao({
    required this.aba,
    required this.cor,
    required this.ativo,
    required this.ehPrimeira,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          // Sem width fixo: o item encolhe/cresce para o tamanho do seu
          // próprio conteúdo (ícone + nome) — a cor de fundo/borda ainda
          // muda ao trocar de aba, então a largura varia sutilmente com o
          // padding/peso do texto, e o AnimatedContainer anima essa
          // transição de forma fluida.
          padding: const EdgeInsets.symmetric(horizontal: 14),
          // Recuo antes da primeira aba: como num fichário físico, a
          // primeira etiqueta não começa exatamente na borda da capa, fica
          // um pouco recuada pra dentro — reforça a leitura de "aba" em vez
          // de um bloco colado na quina.
          margin: EdgeInsets.only(left: ehPrimeira ? 16 : 0, right: 0),
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
                    colors: [Color.lerp(cor, Colors.white, 0.12)!, cor],
                  )
                : null,
            // Contorno sutil nos itens inativos: sem isso, todos ficavam
            // visualmente fundidos numa única massa cinza contra o fundo
            // da pill (mesma cor), sem separação clara entre uma aba e
            // outra quando nenhuma delas está selecionada.
            border: ativo
                ? null
                : Border.all(color: Colors.black.withValues(alpha: 0.08)),
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
            boxShadow: ativo
                ? [
                    BoxShadow(
                      color: cor.withValues(alpha: 0.35),
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
              Icon(
                aba.icone,
                size: 17,
                color: ativo ? Colors.white : Colors.grey.shade500,
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
                    color: ativo ? Colors.white : Colors.grey.shade600,
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
