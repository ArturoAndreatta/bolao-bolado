import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_cores.dart';

/// O "G" do Google.
///
/// **Isto é a marca de outra empresa, e a diretriz do Google é explícita: o
/// glifo não pode ser redesenhado, recolorido nem aproximado.** Por isso os
/// contornos abaixo não são "um G desenhado à mão" — são os quatro caminhos do
/// asset oficial (viewBox `0 0 48 48`), convertidos comando a comando para
/// [Path]. O `d` de origem de cada um está no comentário do próprio caminho,
/// então dá para conferir contra o arquivo do Google sem confiar em ninguém.
///
/// Continua em [CustomPaint], e não em imagem, porque assim é vetor de verdade:
/// nítido em qualquer densidade de tela, sem dependência de SVG e sem PNG em
/// três resoluções por causa de um glifo só.
class GoogleGlyph extends StatelessWidget {
  const GoogleGlyph({super.key, this.size = 18});

  /// 18 é o tamanho que a diretriz do Google especifica para o botão padrão.
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: const CustomPaint(
        painter: _GoogleGlyphPainter(),
        isComplex: false,
        // Sem semântica própria: quem tem rótulo é o botão em volta, e um
        // segundo texto no leitor de tela só repetiria "Google".
        child: SizedBox.expand(),
      ),
    );
  }
}

class _GoogleGlyphPainter extends CustomPainter {
  const _GoogleGlyphPainter();

  /// Lado do viewBox do asset oficial. Os caminhos são escritos nesta escala e
  /// o canvas é reduzido para o tamanho pedido — é o que mantém o glifo exato
  /// em vez de arredondado no meio do caminho.
  static const double _viewBox = 48;

  // d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0
  //    14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"
  static final Path _red = Path()
    ..moveTo(24, 9.5)
    ..cubicTo(27.54, 9.5, 30.71, 10.72, 33.21, 13.1)
    ..lineTo(40.06, 6.25)
    ..cubicTo(35.9, 2.38, 30.47, 0, 24, 0)
    ..cubicTo(14.62, 0, 6.51, 5.38, 2.56, 13.22)
    ..lineTo(10.54, 19.41)
    ..cubicTo(12.43, 13.72, 17.74, 9.5, 24, 9.5)
    ..close();

  // d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92
  //    16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"
  static final Path _yellow = Path()
    ..moveTo(10.53, 28.59)
    ..cubicTo(10.05, 27.14, 9.77, 25.6, 9.77, 24)
    ..cubicTo(9.77, 22.4, 10.04, 20.86, 10.53, 19.41)
    ..lineTo(2.55, 13.22)
    ..cubicTo(0.92, 16.46, 0, 20.12, 0, 24)
    ..cubicTo(0, 27.88, 0.92, 31.54, 2.56, 34.78)
    ..lineTo(10.53, 28.59)
    ..close();

  // d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16
  //    2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"
  static final Path _green = Path()
    ..moveTo(24, 48)
    ..cubicTo(30.48, 48, 35.93, 45.87, 39.89, 42.19)
    ..lineTo(32.16, 36.19)
    ..cubicTo(30.01, 37.64, 27.24, 38.49, 24, 38.49)
    ..cubicTo(17.74, 38.49, 12.43, 34.27, 10.53, 28.58)
    ..lineTo(2.55, 34.77)
    ..cubicTo(6.51, 42.62, 14.62, 48, 24, 48)
    ..close();

  // d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26
  //    5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"
  static final Path _blue = Path()
    ..moveTo(46.98, 24.55)
    ..cubicTo(46.98, 22.98, 46.83, 21.46, 46.6, 20)
    ..lineTo(24, 20)
    ..lineTo(24, 29.02)
    ..lineTo(36.94, 29.02)
    ..cubicTo(36.36, 31.98, 34.68, 34.5, 32.16, 36.2)
    ..lineTo(39.89, 42.2)
    ..cubicTo(44.4, 38.02, 46.98, 31.84, 46.98, 24.55)
    ..close();

  /// A ordem importa: os caminhos se tocam nas emendas, e é ela que decide
  /// quem fica por cima onde eles encostam.
  static final List<(Path, Color)> _parts = [
    (_red, AppBrandColors.googleRed),
    (_yellow, AppBrandColors.googleYellow),
    (_green, AppBrandColors.googleGreen),
    (_blue, AppBrandColors.googleBlue),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    canvas.save();
    canvas.translate((size.width - side) / 2, (size.height - side) / 2);
    canvas.scale(side / _viewBox);

    final paint = Paint()..isAntiAlias = true;
    for (final (path, color) in _parts) {
      canvas.drawPath(path, paint..color = color);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GoogleGlyphPainter oldDelegate) => false;
}
