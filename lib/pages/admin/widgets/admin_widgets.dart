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
    );
  }
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
  // Estica o tile pra ocupar toda a altura da célula do bento grid da Visão
  // geral, em vez de encolher pro tamanho do próprio conteúdo — sem isso o
  // Container fica baixinho dentro do Expanded e sobra espaço vazio na
  // célula (o card inteiro já tem altura fixa, então a célula tem altura de
  // verdade pra preencher).
  final bool preencherAltura;

  const AdminStatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
    this.preencherAltura = false,
  });

  @override
  Widget build(BuildContext context) {
    final cores = AdminCores.de(context);
    // preencherAltura hoje só é usado nas células (altas) do bento grid da
    // Visão geral — nesse contexto o tile ganha texto/ícone maiores, senão o
    // conteúdo fica pequeno e centralizado sobrando bastante espaço vazio
    // acima e abaixo dele.
    final tamanhoIcone = preencherAltura ? 30.0 : 20.0;
    final tamanhoValor = preencherAltura ? 26.0 : 17.0;
    final tamanhoLabel = preencherAltura ? 14.0 : 12.0;
    final conteudo = Container(
      width: preencherAltura ? double.infinity : null,
      height: preencherAltura ? double.infinity : null,
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: preencherAltura ? 0 : 14,
      ),
      decoration: BoxDecoration(
        color: cores.fundoTile,
        borderRadius: AppRadii.circularMd,
        border: Border.all(color: cores.borda),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(preencherAltura ? 10 : 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: AppRadii.circularSmd,
            ),
            child: Icon(icon, color: color, size: tamanhoIcone),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: tamanhoValor,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: tamanhoLabel,
                    color: cores.textoSuave,
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
  // Ver AdminStatTile.preencherAltura — mesma ideia, pro destaque ocupar a
  // altura toda quando vive numa célula alta do bento grid da Visão geral.
  final bool preencherAltura;
  // Linha extra abaixo do rótulo, só quando faz sentido (ex: preço da cota
  // junto do prêmio total) — usa o espaço vertical que sobra numa célula
  // alta sem inventar uma métrica nova só pra preencher.
  final String? sublabel;

  const AdminStatDestaque({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.preencherAltura = false,
    this.sublabel,
  });

  @override
  Widget build(BuildContext context) {
    final cores = AdminCores.de(context);
    // Numa célula alta do bento grid (ver AdminStatTile.preencherAltura),
    // ícone/valor crescem bastante em vez de ficar pequenos e centralizados
    // sobrando espaço vazio acima e abaixo.
    final tamanhoIcone = preencherAltura ? 52.0 : 28.0;
    final tamanhoValor = preencherAltura ? 46.0 : 26.0;
    final tamanhoLabel = preencherAltura ? 17.0 : 13.0;
    return Container(
      width: double.infinity,
      height: preencherAltura ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadii.circularLg,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(preencherAltura ? 16 : 12),
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
                  const SizedBox(height: 10),
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
