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
                title: showLogo
                    ? SizedBox(
                        height: 50,
                        child: Image.asset(
                          'images/logo4.png',
                          fit: BoxFit.contain,
                        ),
                      )
                    : null,
              )
            : null,
        // esticar: o child preenche 100% da área abaixo da AppBar (largura
        // E altura) — sem o SingleChildScrollView, que só cresce até o
        // tamanho do conteúdo e deixava sobrar gradiente de fundo embaixo.
        body: esticar
            ? SizedBox.expand(child: child)
            : Stack(
                children: [
                  SingleChildScrollView(
                    child: Center(child: Column(children: [child])),
                  ),
                ],
              ),
      ),
    );
  }
}
