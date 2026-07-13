import 'package:bolao_bolado/components/shared/skeletons.dart';
import 'package:bolao_bolado/core/app_radii.dart';
import 'package:bolao_bolado/pages/participants/participants_tabela.dart';
import 'package:flutter/material.dart';

/// Placeholder de um card de estatística (mesmo formato de [CardEstatistica]).
class SkeletonCardEstatistica extends StatelessWidget {
  final bool destaque;

  const SkeletonCardEstatistica({super.key, this.destaque = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: destaque ? const Color(0xFFFDF4E3) : const Color(0xFFFEFEFE),
        borderRadius: AppRadii.circularSmd,
        border: Border.all(
          color: destaque ? const Color(0xFFF2D9A8) : const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SkeletonBox(width: 80, height: 12),
          const SizedBox(height: 10),
          SkeletonBox(width: destaque ? 90 : 50, height: 24),
        ],
      ),
    );
  }
}

/// Skeleton do painel de estatísticas no desktop (4 cards lado a lado).
class SkeletonEstatisticasDesktop extends StatelessWidget {
  const SkeletonEstatisticasDesktop({super.key});

  @override
  Widget build(BuildContext context) {
    const flexes = [2, 2, 1, 1];
    return Shimmer(
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < flexes.length; i++) ...[
              Expanded(
                flex: flexes[i],
                child: SkeletonCardEstatistica(destaque: i == 0),
              ),
              if (i != flexes.length - 1) const SizedBox(width: 12),
            ],
          ],
        ),
      ),
    );
  }
}

/// Skeleton da tabela de apostas (desktop): cabeçalho + linhas fixas.
class SkeletonTabela extends StatelessWidget {
  const SkeletonTabela({super.key});

  // Reusa as mesmas larguras de coluna de TabelaApostas para que o skeleton
  // não "pule" quando os dados reais chegam e substituem o placeholder.
  static const List<double> _larguras = [wNome, wValor, wCotas, wPremio, wData];

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      // Mesma rolagem horizontal da tabela real (participants_tabela.dart):
      // sem ela, o Container com minWidth: larguraTotal estoura em telas
      // menores que 690px (RenderFlex overflow no mobile).
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          constraints: const BoxConstraints(minWidth: larguraTotal),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
            borderRadius: AppRadii.circularSmd,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                color: const Color(0xFFE9EAEC),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final w in _larguras)
                      Container(
                        width: w,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        child: const SkeletonBox(width: 60, height: 12),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
              for (var linha = 0; linha < 6; linha++) ...[
                Container(
                  color: linha % 2 == 0
                      ? const Color(0xFFFEFEFE)
                      : const Color(0xFFF3F4F6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final w in _larguras)
                        Container(
                          width: w,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 13,
                          ),
                          child: SkeletonBox(width: w * 0.6, height: 12),
                        ),
                    ],
                  ),
                ),
                if (linha < 5)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFE5E7EB),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Placeholder de uma linha de participante na lista mobile.
class SkeletonLinhaParticipante extends StatelessWidget {
  const SkeletonLinhaParticipante({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SkeletonBox(width: 22, height: 12),
          const SizedBox(width: 6),
          const SkeletonBox(width: 32, height: 32, radius: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 120, height: 13),
                const SizedBox(height: 6),
                SkeletonBox(width: 70, height: 11),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: const [
              SkeletonBox(width: 60, height: 13),
              SizedBox(height: 6),
              SkeletonBox(width: 45, height: 11),
            ],
          ),
        ],
      ),
    );
  }
}

/// Placeholder de uma bolha de mensagem do chat.
class SkeletonBolhaMensagem extends StatelessWidget {
  final bool isMinha;
  final double largura;

  const SkeletonBolhaMensagem({
    super.key,
    required this.isMinha,
    required this.largura,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isMinha
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isMinha) ...[
            const SkeletonBox(width: 24, height: 24, radius: 12),
            const SizedBox(width: 8),
          ],
          SkeletonBox(width: largura, height: 36, radius: 14),
        ],
      ),
    );
  }
}

/// Skeleton do card de chat da sala (desktop), reproduzindo cabeçalho,
/// bolhas de mensagem e rodapé de envio bloqueado.
class SkeletonChatSala extends StatelessWidget {
  const SkeletonChatSala({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Material(
        color: const Color(0xFFFEFEFE),
        elevation: 3,
        shadowColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.circularSmd,
          side: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF3F4F6),
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 18,
                    color: const Color(0xFF487DE5).withValues(alpha: 0.4),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Chat da Sala',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade400,
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
                    children: const [
                      SkeletonBolhaMensagem(isMinha: false, largura: 140),
                      SkeletonBolhaMensagem(isMinha: false, largura: 100),
                      SkeletonBolhaMensagem(isMinha: true, largura: 120),
                      SkeletonBolhaMensagem(isMinha: false, largura: 160),
                      SkeletonBolhaMensagem(isMinha: true, largura: 90),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SkeletonBox(width: double.infinity, height: 12),
                  ),
                ],
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
/// Reproduz a estrutura final (cabeçalho, estatísticas, busca, lista/tabela)
/// já no primeiro frame, para que o carregamento pareça uma transição de
/// conteúdo e não a montagem tardia da tela inteira.
class SkeletonParticipantes extends StatelessWidget {
  final bool mobile;

  const SkeletonParticipantes({super.key, required this.mobile});

  @override
  Widget build(BuildContext context) {
    if (!mobile) return const SkeletonEstatisticasDesktop();

    return Shimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SkeletonBox(width: double.infinity, height: 72, radius: 14),
          const SizedBox(height: 10),
          Row(children: [Expanded(child: SkeletonCardEstatistica())]),
          const SizedBox(height: 10),
          const SkeletonCardEstatistica(),
          const SizedBox(height: 10),
          const SkeletonCardEstatistica(),
          const SizedBox(height: 14),
          const SkeletonBox(width: double.infinity, height: 44, radius: 10),
          const SizedBox(height: 12),
          for (var i = 0; i < 6; i++) ...[
            const SkeletonLinhaParticipante(),
            if (i < 5)
              Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
          ],
        ],
      ),
    );
  }
}
