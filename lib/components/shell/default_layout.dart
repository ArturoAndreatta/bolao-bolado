import 'package:bolao_bolado/components/shell/gradient_decoration.dart';
import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/core/responsive.dart';
import 'package:flutter/material.dart';

class DefaultLayout extends StatelessWidget {
  final Widget child;
  final Widget? drawer;
  final void Function(bool isOpened)? onDrawerChanged;
  final bool showLogo;
  // Quando true, na faixa compact (mobile + tablet/janela estreita) o
  // conteúdo ocupa 100% da largura da tela (sem o Center/Column encolhendo
  // pro tamanho intrínseco do filho) — usado por páginas com layout de
  // fichário (ex: Participants), pra não sobrar gradiente de fundo nas
  // laterais/embaixo do card.
  final bool esticarLarguraCompact;
  const DefaultLayout({
    super.key,
    required this.child,
    this.drawer,
    this.onDrawerChanged,
    this.showLogo = true,
    this.esticarLarguraCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final esticar = esticarLarguraCompact && Responsive.isCompact(context);
    final cores = AppCores.de(context);

    // Nitidez de arte bitmap é orçamento de pixel, não filtro: o que chega na
    // tela é `altura × devicePixelRatio`. No celular o DPR 3 rende 162 pixels
    // reais a partir de 54 e a arte aparece inteira; num monitor comum (DPR 1)
    // os mesmos 54 viram 54, e o "7", o "13" e o trevo borram. Era o sintoma
    // relatado — nítido no celular e no emulador de dispositivo do Chrome (que
    // força DPR alto), borrado no desktop. Filtro nenhum resolve, só altura, e
    // por isso a caixa cresce onde há espaço.
    //
    // Só o desktop cresce: no celular a barra é estreita, e lá o logo nunca
    // foi o problema.
    final ehDesktop = Responsive.isDesktop(context);
    final alturaLogo = ehDesktop ? 72.0 : 54.0;

    return Container(
      decoration: GradientDecoration.backgroundGradient(context),
      child: Scaffold(
        drawer: drawer,
        onDrawerChanged: onDrawerChanged,
        backgroundColor: Colors.transparent,
        appBar: drawer != null
            ? AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
                automaticallyImplyLeading: true,
                iconTheme: IconThemeData(color: cores.texto),
                centerTitle: true,
                // O título é posicionado DENTRO do toolbarHeight, então uma
                // caixa maior que ele sai recortada em cima e embaixo. No
                // celular fica `null` de propósito: 54 cabe no padrão (56), e
                // passar altura ali engordava a barra do celular à toa.
                toolbarHeight: ehDesktop ? alturaLogo + 8 : null,
                title: showLogo
                    ? SizedBox(
                        height: alturaLogo,
                        child: Image.asset(
                          // As variantes 2.0x/3.0x ao lado do arquivo é que
                          // resolvem o tamanho: o Flutter escolhe sozinho pelo
                          // DPR e cada tela desenha perto de 1:1, em vez de o
                          // app encolher a maior na hora de exibir. As três
                          // foram reduzidas do logo3.png em Lanczos com
                          // unsharp leve, porque o resample de passe único do
                          // decodificador amassa traço fino nessa faixa de
                          // redução e offline dá pra escolher filtro melhor.
                          //
                          // Ao mexer em `alturaLogo` ou na arte, regere as
                          // três: a de baixo tem a altura da MAIOR caixa (72,
                          // do desktop), as outras 2× e 3× isso. Menos que
                          // isso e o Flutter amplia a arte no desktop.
                          'images/logo_appbar.png',
                          fit: BoxFit.contain,
                          // medium (bilinear) e não high (cúbico): perto de
                          // 1:1, que é onde as variantes deixam o desenho, o
                          // cúbico amolece em vez de ajudar.
                          filterQuality: FilterQuality.medium,
                        ),
                      )
                    : null,
              )
            : null,
        // esticar: o child preenche 100% da área abaixo da AppBar (largura
        // E altura) — sem o SingleChildScrollView, que só cresce até o
        // tamanho do conteúdo e deixava sobrar gradiente de fundo embaixo.
        // Por isso ele também fica de fora do respiro abaixo: ali encostar na
        // AppBar é o efeito pretendido, não descuido.
        body: esticar
            ? SizedBox.expand(child: child)
            : Stack(
                children: [
                  SingleChildScrollView(
                    // Respiro entre a AppBar e o primeiro card. Sem ele o card
                    // encosta na barra e o logo parece pousado em cima do
                    // conteúdo, sem separar uma coisa da outra. Só quando há
                    // AppBar: sem barra, o conteúdo já começa no topo da tela
                    // e o recuo viraria uma faixa de gradiente sem motivo.
                    padding: EdgeInsets.only(top: drawer != null ? 8 : 0),
                    child: Center(child: Column(children: [child])),
                  ),
                ],
              ),
      ),
    );
  }
}
