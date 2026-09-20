import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/core/app_radii.dart';
import 'package:flutter/material.dart';

/// Paleta de destaque reaproveitada por todas as abas do painel admin,
/// derivada da identidade do app (gradiente dourado→verde-água + azul de
/// ação primária). Fonte única para nenhum tom divergir entre um card e
/// outro do dashboard.
///
/// Com o dark mode, os campos deixaram de ser `static const` e passaram a
/// vir de uma instância resolvida por tema — `AdminCores.de(context)`. A
/// classe continua existindo (em vez de o painel usar [AppCores] direto)
/// porque ela dá NOMES DO PAINEL aos papéis (`fundoSecao`, `fundoTile`), e
/// trocar ~50 pontos de uso por nomes genéricos não tornaria nada mais claro.
@immutable
class AdminCores {
  final Color texto;
  final Color textoSuave;
  final Color azul;
  final Color verde;
  final Color verdeAgua;
  final Color dourado;
  final Color vermelho;

  /// Roxo (mesma família tonal do azul de ação, um passo mais frio):
  /// reservado para a seção "Sala" no dashboard, que é administrativa/config
  /// e não deveria repetir o azul já usado em "Visão geral".
  final Color roxo;

  /// Coral (o vermelho acima puxado para o quente do dourado do gradiente):
  /// seção "Configurações" no dashboard. Distinto de [vermelho], que é cor de
  /// estado (erro/pendência) — um cabeçalho de card nesse tom leria como
  /// alerta, e configurações não é um estado de erro.
  final Color coral;
  final Color fundoCard;
  final Color fundoTile;
  final Color fundoSecao;
  final Color borda;

  /// `true` quando o tema ativo é escuro — usado por [barraDeSecao].
  final bool escuro;

  const AdminCores._({
    required this.texto,
    required this.textoSuave,
    required this.azul,
    required this.verde,
    required this.verdeAgua,
    required this.dourado,
    required this.vermelho,
    required this.roxo,
    required this.coral,
    required this.fundoCard,
    required this.fundoTile,
    required this.fundoSecao,
    required this.borda,
    required this.escuro,
  });

  factory AdminCores.de(BuildContext context) {
    final c = AppCores.de(context);
    return AdminCores._(
      texto: c.texto,
      textoSuave: c.textoSuave,
      azul: c.azul,
      verde: c.verde,
      verdeAgua: c.verdeAgua,
      dourado: c.dourado,
      vermelho: c.vermelho,
      roxo: c.roxo,
      coral: c.coral,
      fundoCard: c.card,
      fundoTile: c.campo,
      fundoSecao: c.cardExterno,
      borda: c.borda,
      escuro: c.escuro,
    );
  }

  /// Versão de [cor] para pintar a BARRA de cabeçalho de uma seção — a faixa
  /// colorida com o título em branco por cima.
  ///
  /// Nos temas escuros as cores de marca são claras: elas precisam ser, para
  /// funcionarem como texto/ícone sobre o card escuro. Só que a mesma cor é
  /// usada cheia como fundo de barra, e aí branco por cima dela chegava a
  /// 1.5:1 — o título sumia dentro da própria faixa.
  ///
  /// Não dá para resolver mexendo na cor de marca: nenhum tom consegue estar
  /// 4.5:1 ACIMA do card e 4.5:1 ABAIXO do branco ao mesmo tempo (o melhor
  /// compromisso empata os dois em ~2.9:1, reprovado dos dois lados). Então a
  /// barra usa uma versão escurecida da mesma cor, e a cor de marca continua
  /// intacta onde é texto.
  ///
  /// A mistura a 50% com um quase-preto azulado mantém o matiz reconhecível
  /// (a barra continua "a verde", "a azul") e devolve branco a ~5:1.
  ///
  /// No tema claro nada muda: lá as cores de marca já são escuras o bastante
  /// para carregar branco, e escurecê-las mais deixaria o painel pesado.
  Color barraDeSecao(Color cor) =>
      escuro ? Color.alphaBlend(cor.withValues(alpha: 0.5), _baseBarra) : cor;

  /// Quase-preto azulado usado para escurecer as barras de seção. Não é preto
  /// puro: preto puro suja o matiz e a barra vira cinza-colorido.
  static const Color _baseBarra = Color(0xFF0E1219);
}

/// Título de uma seção interna de uma aba (ex: "Ações rápidas",
/// "Distribuição de cotas"): rótulo curto + opcional widget à direita.
class AdminTituloSecao extends StatelessWidget {
  final String texto;
  final IconData? icone;
  final Widget? trailing;

  const AdminTituloSecao({
    super.key,
    required this.texto,
    this.icone,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cores = AdminCores.de(context);
    return Row(
      children: [
        if (icone != null) ...[
          Icon(icone, size: 18, color: cores.textoSuave),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            texto,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: cores.texto,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Cartão de estatística do dashboard: ícone colorido + valor em destaque +
/// rótulo. Compartilhado pela grade da Visão Geral e por outras abas.
class AdminStatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const AdminStatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cores = AdminCores.de(context);
    const tamanhoIcone = 20.0;
    const tamanhoValor = 17.0;
    const tamanhoLabel = 12.0;
    final conteudo = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cores.fundoTile,
        borderRadius: AppRadii.circularMd,
        border: Border.all(color: cores.borda),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: AppRadii.circularSmd,
            ),
            child: Icon(icon, color: color, size: tamanhoIcone),
          ),
          const SizedBox(width: 12),
          // Valor e rótulo na MESMA linha, não empilhados. O tile é largo e
          // baixo: empilhado, ele gastava altura para deixar meia linha de
          // texto sobrando na largura, e a leitura saía em dois tempos ("4",
          // depois "Participantes"). Lado a lado ele lê como uma frase.
          Expanded(
            child: Row(
              // Pelo BASELINE, não pelo centro: as duas fontes têm tamanhos
              // bem diferentes, e centralizadas o rótulo flutua acima da
              // base do número. Precisa ficar num Row separado do ícone —
              // o chip é um Container, não tem baseline, e alinhar por
              // baseline com ele dentro estoura em tempo de layout.
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                // `height` explícito nos dois: sem ele a entrelinha vem do
                // tema (~1.43), e o tile fica mais alto do que a soma das
                // fontes sugere — o que já custou um overflow de 1.6px quando
                // ele vivia dentro de uma célula de altura fixa.
                Text(
                  value,
                  style: TextStyle(
                    fontSize: tamanhoValor,
                    fontWeight: FontWeight.w700,
                    color: color,
                    height: 1.15,
                  ),
                ),
                const SizedBox(width: 8),
                // Só o rótulo encolhe quando falta espaço: o número é o dado,
                // e cortá-lo com reticências entregaria uma quantia errada.
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: tamanhoLabel,
                      color: cores.textoSuave,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.chevron_right, size: 20, color: cores.textoSuave),
        ],
      ),
    );

    if (onTap == null) return conteudo;
    return Material(
      color: Colors.transparent,
      borderRadius: AppRadii.circularMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.circularMd,
        child: conteudo,
      ),
    );
  }
}

/// Tile de destaque para o número mais importante do dashboard (hoje: prêmio
/// total). Retângulo largo com ícone maior e valor em fonte bem acima dos
/// [AdminStatTile] normais — a assimetria de tamanho é o que sinaliza
/// hierarquia entre os números sem precisar de texto extra tipo "principal".
class AdminStatDestaque extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  // Linha extra abaixo do rótulo, só quando faz sentido (ex: preço da cota
  // junto do prêmio total) — dá contexto ao número sem inventar uma métrica
  // nova só pra preencher espaço.
  final String? sublabel;

  const AdminStatDestaque({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.sublabel,
  });

  @override
  Widget build(BuildContext context) {
    final cores = AdminCores.de(context);
    // O valor fica bem acima do dos tiles normais — é essa assimetria que
    // sinaliza qual número manda na tela.
    const tamanhoIcone = 28.0;
    const tamanhoValor = 26.0;
    const tamanhoLabel = 13.0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadii.circularLg,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: AppRadii.circularMd,
            ),
            child: Icon(icon, color: color, size: tamanhoIcone),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: tamanhoValor,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: tamanhoLabel,
                    fontWeight: FontWeight.w600,
                    color: cores.textoSuave,
                  ),
                ),
                if (sublabel != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    sublabel!,
                    style: TextStyle(
                      fontSize: tamanhoLabel - 2,
                      fontWeight: FontWeight.w500,
                      color: color,
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

/// Moldura padrão de uma seção do painel: fundo levemente destacado, borda
/// e cantos arredondados — o "quadro" onde cada bloco de conteúdo vive.
class AdminSecaoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const AdminSecaoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final cores = AdminCores.de(context);
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: cores.fundoSecao,
        borderRadius: AppRadii.circularLg,
        border: Border.all(color: cores.borda),
      ),
      child: child,
    );
  }
}

/// Estado centralizado (ícone + mensagem) para listas vazias ou em erro
/// dentro das abas do painel.
class AdminEstadoVazio extends StatelessWidget {
  final IconData icon;
  final Color cor;
  final String mensagem;

  const AdminEstadoVazio({
    super.key,
    required this.icon,
    required this.cor,
    required this.mensagem,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: cor),
            const SizedBox(height: 8),
            Text(
              mensagem,
              textAlign: TextAlign.center,
              style: TextStyle(color: AdminCores.de(context).textoSuave),
            ),
          ],
        ),
      ),
    );
  }
}

/// Barra de progresso horizontal com rótulo à esquerda e valor à direita,
/// usada na aba de Ranking para desenhar a distribuição de cotas por
/// participante. Fração já normalizada (0..1) pelo chamador.
class AdminBarraDistribuicao extends StatelessWidget {
  final String rotulo;
  final String valor;
  final double fracao;
  final Color cor;

  const AdminBarraDistribuicao({
    super.key,
    required this.rotulo,
    required this.valor,
    required this.fracao,
    required this.cor,
  });

  @override
  Widget build(BuildContext context) {
    final cores = AdminCores.de(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                rotulo,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cores.texto,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              valor,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: cor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: AppRadii.circularPill,
          child: LinearProgressIndicator(
            value: fracao.clamp(0.0, 1.0),
            // 20% mais fina que o padrão (8 → 6.4): ganha um pouco de altura
            // de volta pra página de 10 no Ranking caber sem cortar a
            // última posição, sem precisar apertar padding/espaçamento.
            minHeight: 6.4,
            backgroundColor: cores.borda,
            valueColor: AlwaysStoppedAnimation(cor),
          ),
        ),
      ],
    );
  }
}

/// Um número da faixa de indicadores do topo do painel (desktop).
///
/// [progresso] (0..1) acrescenta uma barra fina abaixo do número — usado no
/// indicador de apostas verificadas, onde "quanto da fila já foi conferida"
/// se lê de relance melhor como barra do que como texto.
///
/// [valorSecundario] entra na MESMA linha do número, menor e em tom suave —
/// é o total contra o qual o número se lê (o arrecadado confirmado vem
/// primeiro, o apostado inteiro logo depois). Fica junto de propósito, e não
/// numa linha de apoio embaixo: separado, vira legenda que ninguém lê; na
/// mesma linha, os dois se comparam de uma olhada só.
@immutable
class AdminIndicador {
  final IconData icone;
  final String rotulo;
  final String valor;
  final Color cor;
  final String? valorSecundario;
  final double? progresso;

  const AdminIndicador({
    required this.icone,
    required this.rotulo,
    required this.valor,
    required this.cor,
    this.valorSecundario,
    this.progresso,
  });
}

/// Faixa de indicadores do topo do painel no desktop: uma única régua com os
/// números da sala, separados por linhas finas.
///
/// É uma peça só, e não seis cards soltos, de propósito: com card próprio
/// cada número virava um bloco disputando atenção com a seção de trabalho
/// logo abaixo. Numa régua contínua eles leem como o painel de instrumentos
/// da tela — sempre visível, nunca no caminho.
///
/// Aqui o rótulo fica EM CIMA do valor (o contrário do [AdminStatTile], que
/// põe os dois na mesma linha). Não é incoerência: o tile é largo e baixo, a
/// célula da faixa é estreita e alta — empilhado é o que cabe sem cortar
/// "Participantes" no meio.
class AdminFaixaIndicadores extends StatelessWidget {
  final List<AdminIndicador> itens;

  const AdminFaixaIndicadores({super.key, required this.itens});

  @override
  Widget build(BuildContext context) {
    final cores = AdminCores.de(context);
    return Container(
      decoration: BoxDecoration(
        color: cores.fundoSecao,
        borderRadius: AppRadii.circularLg,
        border: Border.all(color: cores.borda),
      ),
      // IntrinsicHeight porque os divisores precisam da altura da célula mais
      // alta (só uma traz barra de progresso). É uma linha de cinco filhos
      // simples — o custo do segundo passe de layout aqui é irrelevante.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < itens.length; i++) ...[
              if (i > 0) Container(width: 1, color: cores.borda),
              Expanded(child: _CelulaIndicador(item: itens[i])),
            ],
          ],
        ),
      ),
    );
  }
}

class _CelulaIndicador extends StatelessWidget {
  final AdminIndicador item;

  const _CelulaIndicador({required this.item});

  @override
  Widget build(BuildContext context) {
    final cores = AdminCores.de(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: item.cor.withValues(alpha: 0.12),
              borderRadius: AppRadii.circularSmd,
            ),
            child: Icon(item.icone, color: item.cor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.rotulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                    height: 1.2,
                    color: cores.textoSuave,
                  ),
                ),
                const SizedBox(height: 2),
                // O número ENCOLHE em vez de virar reticências: cortar
                // "R$ 1.2..." entrega uma quantia errada, e a faixa aperta
                // conforme a janela. O rótulo acima é que pode elipsar.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text.rich(
                    TextSpan(
                      text: item.valor,
                      children: [
                        if (item.valorSecundario != null)
                          TextSpan(
                            text: ' ${item.valorSecundario}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: cores.textoSuave,
                            ),
                          ),
                      ],
                    ),
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                      color: item.cor,
                    ),
                  ),
                ),
                if (item.progresso != null) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: AppRadii.circularPill,
                    child: LinearProgressIndicator(
                      value: item.progresso!.clamp(0.0, 1.0),
                      minHeight: 5,
                      backgroundColor: item.cor.withValues(alpha: 0.18),
                      valueColor: AlwaysStoppedAnimation(item.cor),
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
