import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/models/mensagem.dart';
import 'package:bolao_bolado/services/chat/formatacao_mensagem.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// O texto de uma mensagem já com menções destacadas, links clicáveis e a
/// marcação `*negrito*` / `_itálico_` / `~riscado~` / `` `mono` ``.
///
/// É `StatefulWidget` por causa dos [TapGestureRecognizer] dos links: eles
/// precisam ser descartados junto com o widget, e um `TextSpan` criado a cada
/// build com recognizer novo vaza um por rebuild — num chat que reconstrói a
/// cada mensagem recebida, isso se acumula rápido.
class TextoMensagem extends StatefulWidget {
  final String texto;
  final List<Mencao> mencoes;

  /// Cor do texto comum, decidida pela bolha (ela sabe se o fundo é a cor da
  /// própria mensagem ou a da bolha dos outros).
  final Color corTexto;

  final bool isMinha;

  const TextoMensagem({
    super.key,
    required this.texto,
    required this.mencoes,
    required this.corTexto,
    required this.isMinha,
  });

  @override
  State<TextoMensagem> createState() => _TextoMensagemState();
}

class _TextoMensagemState extends State<TextoMensagem> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    _limparRecognizers();
    super.dispose();
  }

  void _limparRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  Future<void> _abrir(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    // Falha silenciosa (link torto, app sem navegador): o chat não é lugar
    // para um diálogo de erro por causa de um endereço mal colado.
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    _limparRecognizers();

    final base = TextStyle(fontSize: 14, height: 1.3, color: widget.corTexto);
    final trechos = formatarMensagem(widget.texto, mencoes: widget.mencoes);

    return Text.rich(
      TextSpan(
        children: [
          for (final trecho in trechos)
            TextSpan(
              text: trecho.texto,
              style: _estiloDe(trecho, base, cores),
              recognizer: trecho.tipo == TipoTrecho.link
                  ? _recognizerPara(trecho.alvo!)
                  : null,
            ),
        ],
      ),
      style: base,
    );
  }

  TapGestureRecognizer _recognizerPara(String url) {
    final recognizer = TapGestureRecognizer()..onTap = () => _abrir(url);
    _recognizers.add(recognizer);
    return recognizer;
  }

  TextStyle _estiloDe(TrechoMensagem trecho, TextStyle base, AppCores cores) {
    switch (trecho.tipo) {
      case TipoTrecho.mencao:
        return base.copyWith(
          fontWeight: FontWeight.w700,
          // Na bolha própria a paleta não ajuda: o fundo já é a cor de marca,
          // então o destaque vem de um véu do próprio texto por trás do token
          // (mesma ideia do `alphaBlend` da aba ativa do Fichario).
          color: widget.isMinha ? widget.corTexto : cores.mencaoTexto,
          backgroundColor: widget.isMinha
              ? widget.corTexto.withValues(alpha: 0.20)
              : cores.mencaoFundo,
        );
      case TipoTrecho.link:
        return base.copyWith(
          color: widget.isMinha ? widget.corTexto : cores.azul,
          decoration: TextDecoration.underline,
          decorationColor: widget.isMinha ? widget.corTexto : cores.azul,
        );
      case TipoTrecho.texto:
        return base.copyWith(
          fontWeight: trecho.negrito ? FontWeight.w700 : null,
          fontStyle: trecho.italico ? FontStyle.italic : null,
          decoration: trecho.riscado ? TextDecoration.lineThrough : null,
          decorationColor: trecho.riscado ? widget.corTexto : null,
          fontFamily: trecho.mono ? 'monospace' : null,
          fontSize: trecho.mono ? 13 : null,
        );
    }
  }
}
