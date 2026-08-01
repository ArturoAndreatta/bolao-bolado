import 'package:bolao_bolado/core/app_cores.dart';
import 'package:flutter/material.dart';

class CustomCard extends StatelessWidget {
  final List<Widget> children;

  /// Cor de fundo do card. Null (padrão) usa a superfície de card do tema
  /// ativo — antes era um `const Color(0xFFFEFEFE)` fixo, que no tema escuro
  /// deixaria todos os cards brancos. Quem passa cor explícita (Fichario,
  /// cards de página) continua mandando na cor.
  final Color? color;
  final bool isChild;
  final double maxWidth;
  // Altura fixa opcional do conteúdo interno. Sem isso, o SizedBox interno
  // só define width (não height), deixando a Column filha em altura livre
  // (shrink-wrap) — o que impede usar Expanded/Flexible nos `children`.
  // Passe quando algum filho precisar preencher o espaço restante do card.
  final double? height;
  // Zera o arredondamento do canto superior esquerdo/direito individualmente:
  // usado quando esse lado do card encosta em algo acima que já cobre a
  // borda (ex: a aba ativa do fichário, quando ela é a primeira/última da
  // fileira e por isso encosta na borda lateral do card). Uma aba do meio
  // não encosta em nenhuma borda lateral, então nenhum dos dois é setado.
  final bool cantoSuperiorEsquerdoReto;
  final bool cantoSuperiorDireitoReto;
  // Zera o arredondamento dos cantos inferiores: usado quando o card
  // encosta direto nas bordas da tela (sem nenhuma margem externa), onde
  // um canto arredondado deixaria um triângulo do gradiente de fundo
  // visível entre o card e a borda real da tela.
  final bool cantoInferiorEsquerdoReto;
  final bool cantoInferiorDireitoReto;
  // Quando true, o card ocupa toda a largura disponível do pai (até
  // maxWidth), em vez de encolher para o próprio conteúdo. Usado junto com
  // cantoSuperiorEsquerdoReto/cantoSuperiorDireitoReto: card e Fichario
  // acima dele precisam ter a mesma largura pra parecerem uma peça conectada.
  final bool esticarLargura;
  // Quando true, o card se expande para preencher a altura disponível do
  // pai (precisa estar dentro de um Expanded/Flexible/SizedBox com altura
  // definida) em vez de encolher pro tamanho do conteúdo. O(s) children
  // deste card também precisam ter um Expanded próprio se quiserem ocupar
  // o espaço extra (senão só sobra em branco embaixo deles).
  final bool esticarAltura;
  // Quando não-nula, substitui o padding lateral/inferior padrão de 10px
  // por este valor, revelando a cor de fundo por trás do card — usada no
  // layout fichário para mostrar uma faixa do pill cinza ao redor do card
  // ativo. Passe o mesmo valor usado no padding lateral do Fichario
  // (hoje 10) para as faixas ficarem do mesmo tamanho nos dois lugares.
  final double? margemFichario;

  const CustomCard({
    super.key,
    required this.children,
    this.color,
    this.isChild = false,
    this.maxWidth = 730,
    this.height,
    this.cantoSuperiorEsquerdoReto = false,
    this.cantoSuperiorDireitoReto = false,
    this.cantoInferiorEsquerdoReto = false,
    this.cantoInferiorDireitoReto = false,
    this.esticarLargura = false,
    this.esticarAltura = false,
    this.margemFichario,
  });

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    final maxWidthChild = maxWidth - 15;
    final padLateralInferior = margemFichario ?? 10;
    final temCantoRetoConectado =
        cantoSuperiorEsquerdoReto ||
        cantoSuperiorDireitoReto ||
        cantoInferiorEsquerdoReto ||
        cantoInferiorDireitoReto;
    // 12 é o radius padrão do Card do Material 3 (o mesmo usado quando
    // nenhum shape é passado): mantém os cantos não indicados idênticos ao
    // padrão, só zerando o(s) canto(s) marcado(s) como reto.
    const radius = Radius.circular(12);
    final shape = temCantoRetoConectado
        ? RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topLeft: cantoSuperiorEsquerdoReto ? Radius.zero : radius,
              topRight: cantoSuperiorDireitoReto ? Radius.zero : radius,
              bottomLeft: cantoInferiorEsquerdoReto ? Radius.zero : radius,
              bottomRight: cantoInferiorDireitoReto ? Radius.zero : radius,
            ),
          )
        : null;

    final card = Card(
      // Sem elevação quando o card está conectado ao Fichario acima
      // (cantos superiores retos): a sombra do Card é desenhada em volta de
      // toda a borda, inclusive no topo, o que criava uma faixa
      // escura/sombreada bem onde o card deve parecer uma peça só com a
      // pill de abas. Outros usos de esticarLargura (painel ADM,
      // participantes) não têm esse problema e devem manter a sombra normal.
      elevation: (cantoSuperiorEsquerdoReto || cantoSuperiorDireitoReto)
          ? 0
          // Sombra bem mais discreta no escuro: a sombra preta do tema claro
          // é praticamente invisível sobre fundo escuro e, na elevação 20 do
          // card externo, o Material ainda desenha um halo acinzentado em
          // volta que suja a borda. No escuro a hierarquia já vem da
          // luminosidade das superfícies (ver AppCores.escuroTema).
          : cores.escuro
          ? (isChild ? 0 : 2)
          : (isChild ? 3 : 20),
      color: color ?? cores.card,
      // surfaceTint zerado: no Material 3 o Card tinge a própria cor com o
      // primary conforme a elevação, o que no escuro empurrava todos os
      // cards para um azul lavado, diferente do tom definido na paleta.
      surfaceTintColor: Colors.transparent,
      shadowColor: cores.sombra,
      shape: shape,
      // Card usa margin:EdgeInsets.all(4) por padrão quando nenhum margin é
      // passado — some 4px em cada lado que nenhum Padding externo cobre.
      // Sem zerar isso, sobra uma faixa visível entre o card e qualquer
      // coisa que deveria encostar nele (ex: Fichario acima).
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: SizedBox(
          width: esticarLargura ? null : maxWidthChild,
          height: esticarAltura ? double.infinity : height,
          // O Align alinha pelo topo e passa constraints FROUXAS ao filho.
          // Como a Column é mainAxisSize.min — e portanto encolhe também na
          // largura, até o filho mais largo —, sem isto ela era ancorada à
          // esquerda do SizedBox de maxWidthChild: os campos/botões ficavam
          // centrados entre si, mas o bloco inteiro deslocado pra esquerda
          // dentro do card. topCenter recentra esse bloco sem mexer na
          // altura (a Column continua encolhendo pro conteúdo, não
          // esticando pro card todo).
          child: Align(
            alignment: esticarLargura
                ? AlignmentDirectional.topStart
                : Alignment.topCenter,
            // Sem isto o Align estica para as constraints do pai, o que faria
            // a Column mainAxisSize.min ocupar a altura toda do card.
            heightFactor: esticarAltura ? null : 1,
            child: Column(
              crossAxisAlignment: esticarLargura
                  ? CrossAxisAlignment.stretch
                  : CrossAxisAlignment.center,
              mainAxisSize: esticarAltura ? MainAxisSize.max : MainAxisSize.min,
              children: children,
            ),
          ),
        ),
      ),
    );

    final cardComLargura = esticarLargura
        ? SizedBox(width: double.infinity, child: card)
        : card;
    final cardEsticado = esticarAltura
        ? SizedBox(height: double.infinity, child: cardComLargura)
        : cardComLargura;

    final padded = Padding(
      padding: EdgeInsets.fromLTRB(
        padLateralInferior,
        0,
        padLateralInferior,
        padLateralInferior,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: cardEsticado,
      ),
    );

    return esticarAltura ? Expanded(child: padded) : padded;
  }
}
