import 'package:bolao_bolado/core/app_radii.dart';
import 'package:flutter/material.dart';

/// Paleta de destaque reaproveitada por todas as abas do painel admin,
/// derivada da identidade do app (gradiente dourado→verde-água + azul de
/// ação primária). Fonte única para nenhum tom divergir entre um card e
/// outro do dashboard.
class AdminCores {
  static const Color texto = Color(0xFF1F2937);
  static const Color textoSuave = Color(0xFF6B7280);
  static const Color azul = Color(0xFF487DE5);
  static const Color verde = Color(0xFF2E7D32);
  static const Color verdeAgua = Color(0xFF4FA98A);
  static const Color dourado = Color(0xFFDBA92E);
  static const Color vermelho = Color(0xFFEF4444);
  // Roxo (mesma família tonal do azul de ação, um passo mais frio):
  // reservado para a seção "Sala" no dashboard, que é administrativa/config
  // e não deveria repetir o azul já usado em "Visão geral".
  static const Color roxo = Color(0xFF7C5CD6);
  // Coral (o vermelho acima puxado para o quente do dourado do gradiente):
  // seção "Configurações" no dashboard. Distinto de [vermelho], que é cor de
  // estado (erro/pendência) — um cabeçalho de card nesse tom leria como
  // alerta, e configurações não é um estado de erro.
  static const Color coral = Color(0xFFE2685C);
  static const Color fundoCard = Color(0xFFFEFEFE);
  static const Color fundoTile = Color(0xFFF3F4F6);
  static const Color fundoSecao = Color(0xFFF3F1EF);
  static const Color borda = Color(0xFFE5E7EB);
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
    return Row(
      children: [
        if (icone != null) ...[
          Icon(icone, size: 18, color: AdminCores.textoSuave),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            texto,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AdminCores.texto,
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
    final conteudo = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AdminCores.fundoTile,
        borderRadius: AppRadii.circularMd,
        border: Border.all(color: AdminCores.borda),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: AppRadii.circularSmd,
            ),
            child: Icon(icon, color: color, size: 20),
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
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AdminCores.textoSuave,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: AdminCores.textoSuave,
            ),
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
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AdminCores.fundoSecao,
        borderRadius: AppRadii.circularLg,
        border: Border.all(color: AdminCores.borda),
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
              style: const TextStyle(color: AdminCores.textoSuave),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                rotulo,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AdminCores.texto,
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
            minHeight: 8,
            backgroundColor: AdminCores.borda,
            valueColor: AlwaysStoppedAnimation(cor),
          ),
        ),
      ],
    );
  }
}
