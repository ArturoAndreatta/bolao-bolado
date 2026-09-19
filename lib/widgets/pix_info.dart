import 'dart:math' as math;

import 'package:bolao_bolado/core/aparelho.dart';
import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/core/app_radii.dart';
import 'package:bolao_bolado/services/pix/pix_payload.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

// Bloco de pagamento PIX da sala, exibido abaixo do botão Confirmar em
// MinhaApostaCard, para o usuário pagar sem sair da tela: QR code + chave no
// computador, código Copia e Cola no celular.
class PixInfo extends StatefulWidget {
  final String chavePix;
  final double? valor;

  const PixInfo({super.key, required this.chavePix, this.valor});

  @override
  State<PixInfo> createState() => _PixInfoState();
}

// O que foi copiado por último, para o botão certo mostrar "Copiado!".
enum _Copiado { nada, chave, codigo }

class _PixInfoState extends State<PixInfo> {
  _Copiado _copiado = _Copiado.nada;

  Future<void> _copiar(String texto, _Copiado qual) async {
    await Clipboard.setData(ClipboardData(text: texto));
    if (!mounted) return;
    setState(() => _copiado = qual);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _copiado == qual) {
        setState(() => _copiado = _Copiado.nada);
      }
    });
  }

  // Celular ou tablet: o aparelho que mostra o QR é o mesmo que teria de
  // escaneá-lo, então o QR não serve para nada. Decide pelo APARELHO, e não
  // pela largura da tela: uma janela estreita no computador continua podendo
  // ser escaneada pelo celular.
  static bool get _aparelhoMovel => aparelhoMovel;

  @override
  Widget build(BuildContext context) {
    if (widget.chavePix.isEmpty) return const SizedBox.shrink();

    final cores = AppCores.de(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cores.campo,
        borderRadius: AppRadii.circularMd,
        border: Border.all(color: cores.bordaCampo, width: 1.5),
      ),
      // No celular a decisão sai ANTES do LayoutBuilder, que não mede altura
      // natural: a tela de aposta precisa dela para repartir a sobra da tela
      // (ver preencherAltura em MinhaApostaCard).
      child: _aparelhoMovel
          ? _buildCopiaECola(context)
          : LayoutBuilder(
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
  // cantos de mira à esquerda, logo do Pix + chave + instrução à direita
  // (separados por uma linha tracejada vertical), e o botão de copiar
  // embaixo dos dois, ocupando a largura toda.
  Widget _buildComQrCode(BuildContext context, double larguraDisponivel) {
    // QR limitado a ~40% da largura: maior que isso, a coluna de texto ao
    // lado fica sem espaço para a chave.
    final cores = AppCores.de(context);
    final tamanhoQr = math.min(130.0, larguraDisponivel * 0.4);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(left: 0, top: 2, right: 16, bottom: 2),
      decoration: BoxDecoration(
        color: cores.campo,
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
                  corMira: cores.pix,
                  data: PixPayload.gerar(
                    chave: widget.chavePix,
                    valor: widget.valor,
                  ),
                ),
                const SizedBox(width: 16),
                CustomPaint(
                  size: const Size(1, double.infinity),
                  painter: _LinhaTracejadaPainter(
                    color: cores.borda,
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
                          Image.asset(
                            'images/pix_logo.png',
                            width: 22,
                            height: 22,
                          ),
                          SizedBox(width: 8),
                          // Flexible: com fonte do sistema aumentada o rótulo
                          // passa da largura da coluna e estouraria o Row.
                          Flexible(
                            child: Text(
                              'Pagamento via PIX',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: cores.textoSuave,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          widget.chavePix,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: cores.texto,
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Escaneie o QR Code com o app do seu banco ou copie a chave PIX.',
                        style: TextStyle(
                          fontSize: 12,
                          color: cores.textoSuave,
                          height: 1.3,
                        ),
                      ),
                      SizedBox(height: 12),
                      _botaoCopiar(context),
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
  // logo do Pix no topo, chave PIX em destaque no meio e o botão de copiar
  // embaixo, empilhados verticalmente.
  Widget _buildSemQrCode(BuildContext context) {
    final cores = AppCores.de(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 8),
        Row(
          children: [
            Image.asset('images/pix_logo.png', width: 28, height: 28),
            SizedBox(width: 8),
            Text(
              'Pagamento via\nPIX',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: cores.textoSuave,
                height: 1.1,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: cores.card,
            borderRadius: AppRadii.circularMd,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'CHAVE PIX',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: cores.textoSuave,
                ),
              ),
              SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.chavePix,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: cores.texto,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        _botaoCopiar(context),
        SizedBox(height: 8),
      ],
    );
  }

  // Layout do celular: sem QR code, com o "Pix Copia e Cola" como ação
  // principal. O código é o MESMO payload do QR (ver PixPayload), e colado no
  // app do banco ele já chega com o valor da aposta preenchido — copiando só
  // a chave, a pessoa digita o valor na mão, e é aí que se paga errado. A
  // chave aparece em texto acima do botão, para conferir o destinatário.
  Widget _buildCopiaECola(BuildContext context) {
    final cores = AppCores.de(context);
    final valor = widget.valor;
    final codigoCopiado = _copiado == _Copiado.codigo;
    final corBotao = codigoCopiado ? cores.verde : cores.azul;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Image.asset('images/pix_logo.png', width: 22, height: 22),
              const SizedBox(width: 8),
              Text(
                'Pagamento via PIX',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: cores.texto,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // A chave fica à vista, acima do botão: quem paga confere para quem
          // está mandando antes de copiar, e o código Copia e Cola é um
          // amontoado de caracteres onde ela não se reconhece.
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'Chave PIX: ',
                  style: TextStyle(color: cores.textoSuave),
                ),
                TextSpan(
                  text: widget.chavePix,
                  style: TextStyle(
                    color: cores.texto,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 46,
            child: OutlinedButton.icon(
              onPressed: () => _copiar(
                PixPayload.gerar(chave: widget.chavePix, valor: valor),
                _Copiado.codigo,
              ),
              icon: Icon(
                codigoCopiado ? Icons.check : Icons.copy_outlined,
                size: 18,
                color: corBotao,
              ),
              label: Text(
                codigoCopiado ? 'Código copiado!' : 'Copiar código PIX',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: corBotao,
                side: BorderSide(color: corBotao, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadii.circularXl,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _botaoCopiar(BuildContext context) {
    final cores = AppCores.de(context);
    final copiado = _copiado == _Copiado.chave;
    final corBotao = copiado ? cores.verde : cores.azul;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: SizedBox(
        width: double.infinity,
        height: 34,
        child: OutlinedButton.icon(
          onPressed: () => _copiar(widget.chavePix, _Copiado.chave),
          icon: Icon(
            copiado ? Icons.check : Icons.copy_outlined,
            size: 15,
            color: corBotao,
          ),
          label: Text(
            copiado ? 'Copiado!' : 'Copiar chave PIX',
            style: TextStyle(fontSize: 13),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: corBotao,
            side: BorderSide(color: corBotao, width: 2),
            shape: RoundedRectangleBorder(borderRadius: AppRadii.circularXl),
            padding: EdgeInsets.symmetric(horizontal: 10),
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

  /// Cor das quatro miras. Vem de fora (não mais uma const interna) porque no
  /// tema escuro ela precisa do verde clareado da paleta para não sumir.
  final Color corMira;

  const _QrComCantosDeMira({
    required this.tamanho,
    required this.data,
    required this.corMira,
  });

  static const _espacamento = 4.0;

  @override
  Widget build(BuildContext context) {
    const espacamento = _espacamento;
    return SizedBox(
      width: tamanho + espacamento * 2,
      height: tamanho + espacamento * 2,
      child: Stack(
        children: [
          Center(
            child: SizedBox(
              width: tamanho,
              height: tamanho,
              // Fundo branco e módulos pretos SEMPRE, mesmo no tema escuro: o
              // QR precisa do contraste original para os leitores dos bancos
              // funcionarem. Invertê-lo (claro sobre escuro) quebra a leitura
              // em boa parte dos apps, então aqui o card é que abre uma
              // "janela" branca em volta do código.
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: AppRadii.circularSm,
                ),
                child: QrImageView(
                  data: data,
                  backgroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            child: _Mira(corner: _MiraCorner.topLeft, cor: corMira),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: _Mira(corner: _MiraCorner.topRight, cor: corMira),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            child: _Mira(corner: _MiraCorner.bottomLeft, cor: corMira),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: _Mira(corner: _MiraCorner.bottomRight, cor: corMira),
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

  const _Mira({required this.corner, required this.cor});

  static const _tamanho = 18.0;

  @override
  Widget build(BuildContext context) {
    final isTop =
        corner == _MiraCorner.topLeft || corner == _MiraCorner.topRight;
    final isLeft =
        corner == _MiraCorner.topLeft || corner == _MiraCorner.bottomLeft;

    return SizedBox(
      width: _tamanho,
      height: _tamanho,
      child: CustomPaint(
        painter: _MiraPainter(isTop: isTop, isLeft: isLeft, cor: cor),
      ),
    );
  }
}

class _MiraPainter extends CustomPainter {
  final bool isTop;
  final bool isLeft;
  final Color cor;

  _MiraPainter({required this.isTop, required this.isLeft, required this.cor});

  static const _radius = 5.0;
  static const _espessura = 2.5;

  @override
  void paint(Canvas canvas, Size size) {
    const raio = _radius;
    final paint = Paint()
      ..color = cor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _espessura
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
      oldDelegate.cor != cor;
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
