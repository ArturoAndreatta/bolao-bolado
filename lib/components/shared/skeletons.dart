import 'package:flutter/material.dart';

/// Efeito shimmer aplicado a qualquer child (usado nos placeholders de skeleton).
class Shimmer extends StatefulWidget {
  final Widget child;

  const Shimmer({super.key, required this.child});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final dx = _controller.value * 2 - 1;
            return LinearGradient(
              begin: Alignment(-1 + dx, 0),
              end: Alignment(1 + dx, 0),
              colors: const [
                Color(0xFFE5E7EB),
                Color(0xFFF3F4F6),
                Color(0xFFE5E7EB),
              ],
              stops: const [0.35, 0.5, 0.65],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Bloco retangular usado como placeholder de texto/ícone dentro do skeleton.
class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Placeholder de um campo de formulário (ícone + retângulo do tamanho do
/// campo real), usado em telas com Form que carregam dados antes de exibir.
class SkeletonCampoFormulario extends StatelessWidget {
  final double maxWidth;

  const SkeletonCampoFormulario({super.key, this.maxWidth = 480});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const SkeletonBox(width: 20, height: 20, radius: 5),
            const SizedBox(width: 12),
            SkeletonBox(width: maxWidth * 0.4, height: 14),
          ],
        ),
      ),
    );
  }
}

/// Placeholder de um _StatTile do painel admin (ícone + valor + label).
class SkeletonStatTile extends StatelessWidget {
  const SkeletonStatTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          const SkeletonBox(width: 36, height: 36, radius: 10),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: const [
                SkeletonBox(width: 90, height: 17),
                SizedBox(height: 6),
                SkeletonBox(width: 110, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton dos 4 cards de estatística do painel admin.
class SkeletonDashboardStats extends StatelessWidget {
  const SkeletonDashboardStats({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          SkeletonStatTile(),
          SizedBox(height: 12),
          SkeletonStatTile(),
          SizedBox(height: 12),
          SkeletonStatTile(),
          SizedBox(height: 12),
          SkeletonStatTile(),
        ],
      ),
    );
  }
}

/// Placeholder de uma linha de aposta pendente (nome + valor + botão).
class SkeletonLinhaApostaPendente extends StatelessWidget {
  const SkeletonLinhaApostaPendente({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEFEFE),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: const [
                SkeletonBox(width: 130, height: 15),
                SizedBox(height: 6),
                SkeletonBox(width: 70, height: 13),
              ],
            ),
          ),
          const SkeletonBox(width: 22, height: 22, radius: 11),
        ],
      ),
    );
  }
}

/// Skeleton da lista de apostas pendentes do painel admin.
class SkeletonListaApostasPendentes extends StatelessWidget {
  const SkeletonListaApostasPendentes({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            const SkeletonLinhaApostaPendente(),
          ],
        ],
      ),
    );
  }
}

/// Skeleton de um formulário genérico: uma sequência de linhas de campos +
/// botão de ação, na mesma proporção usada pelos formulários de Aposta e
/// Cadastro de Sala. Cada item de `linhas` é uma lista de larguras dos campos
/// daquela linha — uma linha com 2 larguras reproduz campos lado a lado
/// (ex: Data + Hora).
class SkeletonFormulario extends StatelessWidget {
  final List<List<double>> linhas;
  final double maxWidth;

  const SkeletonFormulario({
    super.key,
    required this.linhas,
    this.maxWidth = 480,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final linha in linhas) ...[
            if (linha.length == 1)
              SkeletonCampoFormulario(maxWidth: linha.first)
            else
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Row(
                  children: [
                    for (var i = 0; i < linha.length; i++) ...[
                      Expanded(child: SkeletonCampoFormulario(maxWidth: linha[i])),
                      if (i != linha.length - 1) const SizedBox(width: 15),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 15),
          ],
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: const SkeletonBox(
              width: double.infinity,
              height: 48,
              radius: 12,
            ),
          ),
        ],
      ),
    );
  }
}
