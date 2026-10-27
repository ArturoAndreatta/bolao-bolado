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
  // pro tamanho intrínseco do filho) — usado por páginas cujo card ocupa a
  // altura toda da tela (ex: Participants), com rolagem só dentro dele.
  final bool esticarLarguraCompact;
  // Repassado ao Scaffold. Fica FORA do body de propósito: é o Scaffold que
  // sabe esconder a barra atrás do teclado e encolher só o conteúdo quando
  // ele abre — montada dentro do body, ela subiria junto com o teclado e
  // roubaria altura do campo que está sendo digitado.
  final Widget? bottomNavigationBar;
  // Repassado ao Scaffold: o body continua por trás da barra inferior até a
  // borda da tela. Para barra FLUTUANTE, que não tem fundo próprio de ponta a
  // ponta — sem isso sobra, em volta dela, uma faixa do fundo da página. Com
  // isso o Scaffold soma a altura da barra ao MediaQuery.padding.bottom do
  // body, e quem está por baixo precisa descontar esse valor.
  final bool extendBody;
  const DefaultLayout({
    super.key,
    required this.child,
    this.drawer,
    this.onDrawerChanged,
    this.showLogo = true,
    this.esticarLarguraCompact = false,
    this.bottomNavigationBar,
    this.extendBody = false,
  });

  // A marca da barra é a bola do "7" (a mesma do ícone da aba e do app
  // instalado), com o nome escrito ao lado fora do celular. A logo ilustrada
  // completa (logo4.png) saiu daqui: com texto curvo, bolinhas e contorno,
  // espremida na altura de uma AppBar ela virava mancha e o nome não se lia.
  // Ela continua no splash e na tela inicial, onde tem espaço.
  //
  // A bola tem 32px de altura EXATOS (images/bola_appbar.png, com as
  // variantes 2.0x/3.0x geradas em cima disso a partir de images/icone.png).
  // Caixa diferente faz o Flutter reescalar a arte na hora de desenhar e o
  // brilho e o traço do "7" amolecem. Mexer aqui obriga a regerar as três.
  static const double alturaBola = 32;

  // Altura da barra no desktop. Fica nos 74 da logo antiga mesmo com a bola
  // menor: as telas de altura calculada já foram acertadas contra esse
  // número, e o respiro sobra em volta da marca em vez de mexer no resto da
  // página.
  static const double alturaBarraDesktop = 74;

  static const String nomeApp = 'Bolão Bolado';

  /// Altura REAL da AppBar montada por este layout, na faixa de tela atual.
  ///
  /// Quem calcula altura de conteúdo na mão — o painel admin trava a altura
  /// do card na tela, por exemplo — precisa descontar ESTE valor e nunca
  /// `kToolbarHeight`: no desktop a barra tem 74px, não os 56 do padrão do
  /// Material, e descontar o valor errado sobra conteúdo para fora da janela
  /// e faz nascer scroll na página.
  static double alturaAppBar(BuildContext context) =>
      Responsive.isDesktop(context) ? alturaBarraDesktop : kToolbarHeight;

  @override
  Widget build(BuildContext context) {
    final esticar = esticarLarguraCompact && Responsive.isCompact(context);
    final cores = AppCores.de(context);
    final ehDesktop = Responsive.isDesktop(context);
    // No celular o nome não cabe com folga entre o menu e a borda, e a bola
    // sozinha já é reconhecível (é o ícone do app). Do tablet para cima
    // sobra largura, e quem chega pela primeira vez lê onde está.
    final mostrarNome = !Responsive.isMobile(context);

    return Container(
      decoration: GradientDecoration.backgroundGradient(context),
      child: Scaffold(
        drawer: drawer,
        onDrawerChanged: onDrawerChanged,
        bottomNavigationBar: bottomNavigationBar,
        extendBody: extendBody,
        backgroundColor: Colors.transparent,
        appBar: drawer != null
            ? AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
                automaticallyImplyLeading: true,
                iconTheme: IconThemeData(color: cores.texto),
                centerTitle: true,
                // No celular fica `null` de propósito: a bola cabe no padrão
                // (56), e passar altura ali engordava a barra do celular à toa.
                //
                // O valor sai de `alturaAppBar` e não de uma conta local: é o
                // mesmo número que as telas de altura calculada descontam da
                // janela, e as duas pontas divergirem é justamente o que
                // fazia nascer scroll no painel admin.
                toolbarHeight: ehDesktop ? alturaAppBar(context) : null,
                title: showLogo
                    ? _MarcaAppBar(mostrarNome: mostrarNome, cor: cores.texto)
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
                    // Sem respiro entre a AppBar e o primeiro card: no desktop
                    // a soma barra + card passava da altura da janela por
                    // poucos pixels e a página inteira ganhava scroll — um
                    // scroll de ~7px, que não rola nada de útil e só suja a
                    // tela com a barrinha na lateral. Estes 8px eram o único
                    // corte disponível que não encolhe o logo (a arte tem 72px
                    // de altura exatos) nem a altura dos cards.
                    //
                    // A separação entre barra e conteúdo agora vem só do
                    // contraste: a AppBar é transparente sobre o gradiente e o
                    // card é uma superfície clara com sombra.
                    padding: EdgeInsets.zero,
                    child: Center(child: Column(children: [child])),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Bola do "7" com o nome do app ao lado (o nome some no celular).
class _MarcaAppBar extends StatelessWidget {
  final bool mostrarNome;
  final Color cor;

  const _MarcaAppBar({required this.mostrarNome, required this.cor});

  @override
  Widget build(BuildContext context) {
    // Um rótulo só para o conjunto: sem isso o leitor de tela anunciaria a
    // imagem e depois o mesmo nome em texto.
    return Semantics(
      label: DefaultLayout.nomeApp,
      header: true,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              // As variantes 2.0x/3.0x ao lado do arquivo é que resolvem o
              // tamanho: o Flutter escolhe sozinho pelo DPR e cada tela
              // desenha perto de 1:1. Foram reduzidas do icone.png em
              // Lanczos com unsharp leve; ao mexer em `alturaBola`, regere as
              // três (1×, 2× e 3× a caixa).
              'images/bola_appbar.png',
              height: DefaultLayout.alturaBola,
              width: DefaultLayout.alturaBola,
              // medium (bilinear) e não high (cúbico): perto de 1:1, que é
              // onde as variantes deixam o desenho, o cúbico amolece.
              filterQuality: FilterQuality.medium,
            ),
            // Ao redimensionar a janela pela fronteira do celular o nome
            // entra e sai deslizando, em vez de saltar e arrastar a bola de
            // uma vez para o lado.
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: mostrarNome
                    ? Padding(
                        key: const ValueKey('nome'),
                        padding: const EdgeInsets.only(left: 10),
                        child: Text(
                          DefaultLayout.nomeApp,
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            color: cor,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('sem-nome')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
