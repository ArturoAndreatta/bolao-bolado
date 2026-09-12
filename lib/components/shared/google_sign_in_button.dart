import 'package:flutter/material.dart';

import '../../core/app_cores.dart';
import '../../core/app_radii.dart';
import 'google_glyph.dart';

/// O botão "Continuar com o Google".
///
/// **Por que ele não é um `PrimaryButton`/`SecondaryButton` com um glifo
/// pendurado na frente.** O botão do Google não é um botão do app: ele é
/// reconhecido de relance por três coisas que a diretriz do Google fixa e que
/// não são nossas para escolher — o G oficial, o fundo neutro (branco no
/// claro, quase preto no escuro) e o rótulo em cinza neutro, nunca em
/// [AppCores.acaoPrimaria]. Pintá-lo com a paleta do bolão (dourado, azul...)
/// o transformaria em mais um CTA nosso usando a marca de outra empresa como
/// enfeite.
///
/// Por isso as cores vêm de [AppBrandColors], não de [AppCores], e o widget
/// existe fora de `buttons.dart` em vez de virar mais uma variante de
/// [PrimaryButton].
///
/// **O que continua sendo nosso:** a altura (54, igual ao [PrimaryButton]
/// padrão) e o raio do canto ([AppRadii.xl]) — a diretriz permite os dois, e
/// um botão de canto diferente do vizinho, sentado logo abaixo dele na tela
/// de login, chamaria atenção pelo motivo errado.
///
/// A decisão claro/escuro usa [AppCores.escuro] — o mesmo booleano que já
/// resolve os 7 temas do app para "essa decisão é forma, não cor" — em vez de
/// `Theme.of(context).brightness`: são os dois temas ÚNICOS claros (`papel`,
/// `bilhete`) que fariam a leitura de brilho divergir de `cores.escuro`.
///
/// **O texto.** "Continuar com o Google", com artigo, é a string oficial do
/// Google em pt-BR para esta tela (as duas outras oficiais são "Fazer login
/// com o Google" e "Inscrever-se com o Google", usadas noutros contextos).
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    this.onPressed,
    this.isLoading = false,
    this.expanded = false,
    this.label = 'Continuar com o Google',
  });

  final VoidCallback? onPressed;
  final bool isLoading;

  /// Ocupa toda a largura disponível, como os botões do formulário quando
  /// empilhados no mobile.
  final bool expanded;

  /// Só as strings oficiais do Google. Ver a nota sobre o texto acima.
  final String label;

  /// Alinha com a altura padrão de [PrimaryButton]/[SecondaryButton] — a
  /// diretriz do Google só exige 40 no mínimo.
  static const double _height = 54;

  /// 18 é o tamanho do glifo na diretriz, e 12 o respiro até o rótulo.
  static const double _glyph = 18;
  static const double _gap = 12;

  @override
  Widget build(BuildContext context) {
    final escuro = AppCores.de(context).escuro;
    final enabled = onPressed != null && !isLoading;

    final fill = escuro
        ? AppBrandColors.googleDarkFill
        : AppBrandColors.googleLightFill;
    final outline = escuro
        ? AppBrandColors.googleDarkOutline
        : AppBrandColors.googleLightOutline;
    final labelColor = escuro
        ? AppBrandColors.googleDarkLabel
        : AppBrandColors.googleLightLabel;

    // Desabilitado perde presença sem virar bloco cinza: a forma continua
    // legível e o G continua reconhecível.
    final opacity = enabled ? 1.0 : 0.38;

    final button = SizedBox(
      height: _height,
      child: TextButton(
        onPressed: enabled ? onPressed : null,
        style: ButtonStyle(
          backgroundColor: WidgetStatePropertyAll(fill),
          foregroundColor: WidgetStatePropertyAll(labelColor),
          overlayColor: WidgetStatePropertyAll(
            labelColor.withValues(alpha: 0.08),
          ),
          side: WidgetStatePropertyAll(
            BorderSide(color: outline.withValues(alpha: opacity)),
          ),
          elevation: const WidgetStatePropertyAll(0),
          shadowColor: const WidgetStatePropertyAll(Colors.transparent),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: AppRadii.circularXl),
          ),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: isLoading
            ? SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: labelColor,
                ),
              )
            : Opacity(
                opacity: opacity,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const GoogleGlyph(size: _glyph),
                    const SizedBox(width: _gap),
                    Text(
                      label,
                      style: TextStyle(
                        // A diretriz pede peso médio e nada de caixa alta —
                        // o w700 dos outros botões do app engrossa demais
                        // sobre o fundo neutro deste.
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                        letterSpacing: 0.1,
                        color: labelColor,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );

    if (!expanded) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}
