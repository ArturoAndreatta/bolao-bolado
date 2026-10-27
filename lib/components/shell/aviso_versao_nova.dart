import 'dart:async';

import 'package:bolao_bolado/components/shared/buttons.dart';
import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/core/app_radii.dart';
import 'package:bolao_bolado/core/atualizacao_app.dart';
import 'package:flutter/material.dart';

/// Quanto o botão espera o download antes de liberar de qualquer jeito. O
/// aviso não tem outra saída: um botão girando para sempre prenderia a pessoa.
const kPacienciaDownloadVersao = Duration(seconds: 20);

/// O aviso de "versão nova", no meio da tela, com fundo escurecido.
///
/// **Obrigatório de propósito.** Um botão só, "Atualizar agora"; tocar fora,
/// Esc e voltar não fecham. Aviso com saída se ignora, e quem ignora continua
/// apostando e conversando pela versão velha — e aqui a versão velha pode
/// gravar aposta num formato que as regras do Firestore já não aceitam.
///
/// **Abre na descoberta, não no fim do download**, com o botão girando;
/// quando o download termina (ou passa [kPacienciaDownloadVersao]), libera.
///
/// Montado no `builder` do `MaterialApp` ([BolaoBolado]), acima do
/// `Navigator`, para cobrir todas as rotas, login incluso. Por isso não usa
/// `showDialog` (não há contexto de página aqui): desenha a própria barreira
/// e embrulha tudo em `Overlay.wrap`, porque acima do `Navigator` ainda não há
/// `Overlay`.
class AvisoVersaoNova extends StatefulWidget {
  const AvisoVersaoNova({
    required this.child,
    this.ponte = const PonteAtualizacao(),
    super.key,
  });

  /// O app inteiro, que o aviso cobre por cima.
  final Widget child;

  final PonteAtualizacao ponte;

  @override
  State<AvisoVersaoNova> createState() => _AvisoVersaoNovaState();
}

class _AvisoVersaoNovaState extends State<AvisoVersaoNova> {
  /// Existe versão nova (descoberta ou já baixada).
  bool _encontrada = false;

  /// A versão nova terminou de baixar e assumiu.
  bool _pronta = false;

  /// Passou o tempo de espera sem o aviso de pronto: o botão libera.
  bool _cansouDeEsperar = false;

  bool _recarregando = false;
  Timer? _paciencia;
  final _assinaturas = <StreamSubscription<void>>[];

  @override
  void initState() {
    super.initState();
    final ponte = widget.ponte;
    if (!ponte.suportado) return;

    if (ponte.pronta) {
      _encontrada = true;
      _pronta = true;
    } else if (ponte.encontrada) {
      _marcarEncontrada();
    }
    _assinaturas
      ..add(ponte.aoEncontrar.listen((_) => setState(_marcarEncontrada)))
      ..add(
        ponte.aoFicarPronta.listen((_) {
          setState(() {
            _encontrada = true;
            _pronta = true;
          });
        }),
      );
  }

  /// Chamado dentro de `setState` pelo ouvinte, e direto no `initState`.
  void _marcarEncontrada() {
    if (_encontrada) return;
    _encontrada = true;
    _paciencia = Timer(kPacienciaDownloadVersao, () {
      if (mounted) setState(() => _cansouDeEsperar = true);
    });
  }

  @override
  void dispose() {
    for (final assinatura in _assinaturas) {
      unawaited(assinatura.cancel());
    }
    _paciencia?.cancel();
    super.dispose();
  }

  void _recarregar() {
    setState(() => _recarregando = true);
    widget.ponte.recarregar();
  }

  @override
  Widget build(BuildContext context) {
    final movimento = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 280);

    return Overlay.wrap(
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          // Escondido, o filho é um `SizedBox` vazio: não pinta e deixa o
          // toque passar para o app embaixo.
          AnimatedSwitcher(
            duration: movimento,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeOutCubic,
            child: _encontrada
                ? _CaixaVersaoNova(
                    key: const ValueKey('aviso-versao-nova'),
                    ocupado: _recarregando || (!_pronta && !_cansouDeEsperar),
                    movimento: movimento,
                    aoAtualizar: _recarregar,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

/// Barreira e cartão. Só desenho: o estado mora em [AvisoVersaoNova].
class _CaixaVersaoNova extends StatelessWidget {
  const _CaixaVersaoNova({
    required this.ocupado,
    required this.movimento,
    required this.aoAtualizar,
    super.key,
  });

  /// Download em curso ou recarga já pedida: o botão gira e não aceita toque.
  final bool ocupado;
  final Duration movimento;
  final VoidCallback aoAtualizar;

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);

    // `PopScope` segura o voltar do Android e o Esc do teclado, que chegam
    // como pedido de pop ao `Navigator` embaixo.
    return PopScope(
      canPop: false,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Engole o toque (tocar fora não fecha) e esconde o app do leitor
          // de tela enquanto o aviso está de pé.
          BlockSemantics(
            child: ModalBarrier(
              color: cores.sombra.withValues(alpha: 0.55),
              dismissible: false,
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  // Cresce um pouco ao entrar, junto do fade do
                  // `AnimatedSwitcher`: o aviso chega, não aparece.
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.92, end: 1),
                    duration: movimento,
                    curve: Curves.easeOutCubic,
                    builder: (context, escala, child) =>
                        Transform.scale(scale: escala, child: child),
                    // Acima do `Navigator` não há `Material`: sem ele o
                    // `Text` herda o estilo de erro do `WidgetsApp`
                    // (sublinhado amarelo).
                    child: Material(
                      color: cores.card,
                      elevation: 18,
                      shadowColor: cores.sombra,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadii.circularXxl,
                        side: BorderSide(color: cores.borda),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Bloco de ícone na cor de AÇÃO do tema, a mesma
                            // do botão logo abaixo. Com o par azul da paleta
                            // (fundoAzul/bordaAzul) ele destoava nos temas
                            // cujo CTA não é azul: no Cyber virava um
                            // quadrado azul apagado ao lado de um botão
                            // magenta. A bola do 7 também foi tentada aqui e
                            // repetia a marca que já está na barra de cima.
                            // Tinta a 18% e borda a 45%: a faixa em que o
                            // alphaBlend ainda recorta sobre o card nos
                            // temas escuros (ver CLAUDE.md, cores).
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: Color.alphaBlend(
                                  cores.acaoPrimaria.withValues(alpha: 0.18),
                                  cores.card,
                                ),
                                borderRadius: AppRadii.circularLg,
                                border: Border.all(
                                  color: cores.acaoPrimaria.withValues(
                                    alpha: 0.45,
                                  ),
                                ),
                              ),
                              // `file_download_rounded`, e não o
                              // `download_rounded` (mesmo desenho): trocar o
                              // glifo muda o arquivo da fonte de ícones, e só
                              // assim o service worker baixa ela de novo.
                              // Quem atualizou enquanto o Hosting ainda
                              // deixava `assets/` em cache de 1h guardou a
                              // fonte ANTIGA (sem o ícone deste aviso) sob o
                              // hash da nova, e o quadrado aparecia vazio; com
                              // o hash igual, o worker nunca a buscaria outra
                              // vez. Hoje `assets/` é no-cache (CLAUDE.md, aviso
                              // de versão nova), então isso não se repete.
                              child: Icon(
                                Icons.file_download_rounded,
                                size: 28,
                                color: cores.acaoPrimaria,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Versão nova!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: cores.texto,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Atualize antes de qualquer ação.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                height: 1.35,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: cores.textoSuave,
                              ),
                            ),
                            const SizedBox(height: 22),
                            Semantics(
                              button: true,
                              enabled: !ocupado,
                              label: ocupado
                                  ? 'Baixando a versão nova'
                                  : 'Atualizar agora',
                              excludeSemantics: true,
                              child: PrimaryButton(
                                text: 'Atualizar agora',
                                width: double.infinity,
                                compact: false,
                                loading: ocupado,
                                onTap: aoAtualizar,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
