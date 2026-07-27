import 'dart:math' as math;

import 'package:bolao_bolado/core/app_radii.dart';
import 'package:bolao_bolado/services/pix/pix_payload.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

// Bloco com QR code + chave PIX da sala, exibido abaixo do botão
// Confirmar em MinhaApostaCard, para o usuário pagar sem sair da tela.
class PixInfo extends StatefulWidget {
  final String chavePix;
  final double? valor;

  /// Multiplica proporcionalmente todas as medidas do card (QR, fontes,
  /// paddings, espaçamentos). Serve para o card do Pix esticar e preencher a
  /// folga vertical que sobra acima dele no mobile, sem redesenhar o layout:
  /// quem calcula o fator é quem conhece a altura disponível (MinhaApostaCard).
  final double escala;

  const PixInfo({
    super.key,
    required this.chavePix,
    this.valor,
    this.escala = 1,
  });

  @override
  State<PixInfo> createState() => _PixInfoState();
}

class _PixInfoState extends State<PixInfo> {
  bool _copiado = false;

  // Atalho: medida do design (escala 1) convertida para a escala atual.
  double _e(double medida) => medida * widget.escala;

  Future<void> _copiar() async {
    await Clipboard.setData(ClipboardData(text: widget.chavePix));
    if (!mounted) return;
    setState(() => _copiado = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copiado = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.chavePix.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      // Horizontal sem escala: a largura do card é dada pelo pai, então
      // inflar padding lateral só rouba espaço da chave PIX ao lado do QR.
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: _e(8)),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: AppRadii.circularMd,
        border: Border.all(color: const Color(0xFFDDDDDD), width: 1.5),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mostrarQrCode = constraints.maxWidth >= 330;
          return mostrarQrCode
              ? _buildComQrCode(context, constraints.maxWidth)
              : _buildSemQrCode(context);
        },
      ),
    );
  }

  // Layout usado quando o card tem espaço pro QR code (>= 330): QR com
  // cantos de mira à esquerda, chave PIX + instrução à direita (separados
  // por uma linha tracejada vertical), e o botão de copiar embaixo dos
  // dois, ocupando a largura toda.
  Widget _buildComQrCode(BuildContext context, double larguraDisponivel) {
    // A escala existe para preencher folga VERTICAL, mas o QR é quadrado:
    // crescer sem teto empurraria a coluna de texto ao lado até estourar a
    // largura do card. Limita-se o QR a ~40% da largura disponível, e as
    // gutters/padding horizontais ficam sem escala pelo mesmo motivo — o
    // ganho de altura vem do QR e dos espaçamentos verticais.
    final tamanhoQr = math.min(_e(130), larguraDisponivel * 0.4);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(left: 0, top: _e(2), right: 16, bottom: _e(2)),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: AppRadii.circularMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _QrComCantosDeMira(
                  tamanho: tamanhoQr,
                  escala: widget.escala,
                  data: PixPayload.gerar(
                    chave: widget.chavePix,
                    valor: widget.valor,
                  ),
                ),
                const SizedBox(width: 16),
                CustomPaint(
                  size: const Size(1, double.infinity),
                  painter: _LinhaTracejadaPainter(
                    color: Colors.grey.shade300,
                    vertical: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: _e(22),
                            height: _e(22),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE6F7F1),
                              borderRadius: AppRadii.circularSm,
                            ),
                            child: Icon(
                              Icons.vpn_key_outlined,
                              size: _e(13),
                              color: const Color(0xFF17A673),
                            ),
                          ),
                          SizedBox(width: _e(8)),
                          // Flexible + ellipsis: com a escala alta o rótulo
                          // cresce junto do ícone e passava da largura da
                          // coluna, estourando o Row.
                          Flexible(
                            child: Text(
                              'Chave PIX',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: _e(13),
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: _e(6)),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          widget.chavePix,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: _e(18),
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1F2937),
                          ),
                        ),
                      ),
                      SizedBox(height: _e(12)),
                      Text(
                        'Escaneie o QR Code com o app do seu banco ou copie a chave PIX.',
                        style: TextStyle(
                          fontSize: _e(12),
                          color: Colors.grey.shade600,
                          height: 1.3,
                        ),
                      ),
                      SizedBox(height: _e(12)),
                      _botaoCopiar(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Layout usado quando o card fica estreito demais para o QR code (< 330):
  // logo do Pix + selo "Seguro e rápido" no topo, chave PIX em destaque no
  // meio e o botão de copiar embaixo, empilhados verticalmente.
  Widget _buildSemQrCode(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: _e(8)),
        Row(
          children: [
            Image.asset('images/pix_logo.png', width: _e(28), height: _e(28)),
            SizedBox(width: _e(8)),
            Text(
              'Pagamento via\nPIX',
              style: TextStyle(
                fontSize: _e(12),
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
                height: 1.1,
              ),
            ),
            const Spacer(),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: _e(10),
                vertical: _e(6),
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFE6F7F1),
                borderRadius: AppRadii.circularXl,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle,
                    size: _e(14),
                    color: const Color(0xFF17A673),
                  ),
                  SizedBox(width: _e(4)),
                  Text(
                    'Seguro e rápido',
                    style: TextStyle(
                      fontSize: _e(12),
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF17A673),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: _e(12)),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: _e(14), vertical: _e(10)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadii.circularMd,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'CHAVE PIX',
                style: TextStyle(
                  fontSize: _e(11),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: Colors.grey.shade600,
                ),
              ),
              SizedBox(height: _e(4)),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.chavePix,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: _e(18),
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1F2937),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: _e(12)),
        _botaoCopiar(),
        SizedBox(height: _e(8)),
      ],
    );
  }

  Widget _botaoCopiar() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: SizedBox(
        width: double.infinity,
        height: _e(34),
        child: OutlinedButton.icon(
          onPressed: _copiar,
          icon: Icon(
            _copiado ? Icons.check : Icons.copy_outlined,
            size: _e(15),
            color: _copiado ? Colors.green : const Color(0xFF487DE5),
          ),
          label: Text(
            _copiado ? 'Copiado!' : 'Copiar chave PIX',
            style: TextStyle(fontSize: _e(13)),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: _copiado ? Colors.green : const Color(0xFF487DE5),
            side: BorderSide(
              color: _copiado ? Colors.green : const Color(0xFF487DE5),
              width: 2,
            ),
            shape: RoundedRectangleBorder(borderRadius: AppRadii.circularXl),
            padding: EdgeInsets.symmetric(horizontal: _e(10)),
          ),
        ),
      ),
    );
  }
}

// QR code com "cantos de mira" (4 L's verdes nos cantos), como um scanner
// de leitura — usado no card do Pix quando há espaço suficiente pro QR.
class _QrComCantosDeMira extends StatelessWidget {
  final double tamanho;
  final String data;
  final double escala;

  const _QrComCantosDeMira({
    required this.tamanho,
    required this.data,
    this.escala = 1,
  });

  static const _corMira = Color(0xFF4FA98A);
  static const _espacamento = 4.0;

  @override
  Widget build(BuildContext context) {
    final espacamento = _espacamento * escala;
    return SizedBox(
      width: tamanho + espacamento * 2,
      height: tamanho + espacamento * 2,
      child: Stack(
        children: [
          Center(
            child: SizedBox(
              width: tamanho,
              height: tamanho,
              child: QrImageView(data: data),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            child: _Mira(
              corner: _MiraCorner.topLeft,
              cor: _corMira,
              escala: escala,
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: _Mira(
              corner: _MiraCorner.topRight,
              cor: _corMira,
              escala: escala,
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            child: _Mira(
              corner: _MiraCorner.bottomLeft,
              cor: _corMira,
              escala: escala,
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: _Mira(
              corner: _MiraCorner.bottomRight,
              cor: _corMira,
              escala: escala,
            ),
          ),
        ],
      ),
    );
  }
}

enum _MiraCorner { topLeft, topRight, bottomLeft, bottomRight }

class _Mira extends StatelessWidget {
  final _MiraCorner corner;
  final Color cor;
  final double escala;

  const _Mira({required this.corner, required this.cor, this.escala = 1});

  static const _tamanho = 18.0;

  @override
  Widget build(BuildContext context) {
    final isTop =
        corner == _MiraCorner.topLeft || corner == _MiraCorner.topRight;
    final isLeft =
        corner == _MiraCorner.topLeft || corner == _MiraCorner.bottomLeft;

    return SizedBox(
      width: _tamanho * escala,
      height: _tamanho * escala,
      child: CustomPaint(
        painter: _MiraPainter(
          isTop: isTop,
          isLeft: isLeft,
          cor: cor,
          escala: escala,
        ),
      ),
    );
  }
}

class _MiraPainter extends CustomPainter {
  final bool isTop;
  final bool isLeft;
  final Color cor;
  final double escala;

  _MiraPainter({
    required this.isTop,
    required this.isLeft,
    required this.cor,
    this.escala = 1,
  });

  static const _radius = 5.0;
  static const _espessura = 2.5;

  @override
  void paint(Canvas canvas, Size size) {
    final raio = _radius * escala;
    final paint = Paint()
      ..color = cor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _espessura * escala
      ..strokeCap = StrokeCap.round;

    final x = isLeft ? 0.0 : size.width;
    final y = isTop ? 0.0 : size.height;
    final signX = isLeft ? 1.0 : -1.0;
    final signY = isTop ? 1.0 : -1.0;

    final path = Path()
      ..moveTo(x, y + signY * size.height)
      ..lineTo(x, y + signY * raio)
      ..arcToPoint(
        Offset(x + signX * raio, y),
        radius: Radius.circular(raio),
        clockwise: isTop == isLeft,
      )
      ..lineTo(x + signX * size.width, y);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MiraPainter oldDelegate) =>
      oldDelegate.isTop != isTop ||
      oldDelegate.isLeft != isLeft ||
      oldDelegate.cor != cor ||
      oldDelegate.escala != escala;
}

// Linha tracejada usada como separador — horizontal (entre a chave PIX e o
// texto de instrução) ou vertical (entre o QR code e o bloco de texto ao
// lado), no estilo "recibo" do mockup.
class _LinhaTracejadaPainter extends CustomPainter {
  final Color color;
  final bool vertical;

  _LinhaTracejadaPainter({required this.color, this.vertical = false});

  static const _larguraTraco = 5.0;
  static const _espacamento = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    final comprimento = vertical ? size.height : size.width;
    var d = 0.0;
    while (d < comprimento) {
      final fim = math.min(d + _larguraTraco, comprimento);
      final inicio = vertical ? Offset(0, d) : Offset(d, 0);
      final termino = vertical ? Offset(0, fim) : Offset(fim, 0);
      canvas.drawLine(inicio, termino, paint);
      d += _larguraTraco + _espacamento;
    }
  }

  @override
  bool shouldRepaint(covariant _LinhaTracejadaPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.vertical != vertical;
}
