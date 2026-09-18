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
  const DefaultLayout({
    super.key,
    required this.child,
    this.drawer,
    this.onDrawerChanged,
    this.showLogo = true,
    this.esticarLarguraCompact = false,
    this.bottomNavigationBar,
  });

  // A arte do logo tem 52px de altura EXATOS (images/logo_appbar.png, com as
  // variantes 2.0x/3.0x geradas em cima disso). Caixa menor que 52 faz o
  // Flutter reduzir a imagem na hora de desenhar, e o traço fino do "7", do
  // "13" e do trevo volta a borrar — que é o problema que este par
  // altura-da-caixa + variantes resolve. Mexer aqui obriga a regerar as três.
  //
  // Foi 72 até aqui, e encolher a arte SEM regerar as variantes é justamente
  // o que traria o borrão de volta: a nitidez vem de a caixa bater com o
  // tamanho do arquivo, não de filtro.
  static const double alturaLogoDesktop = 52;
  static const double alturaLogoCompacto = 44;

  // Folga vertical entre o logo e as bordas da barra, no desktop.
  //
  // Ela é o SALDO de encolher a arte, não margem nova: a barra continua com
  // a mesma altura total de antes (alturaLogoDesktop + folgaVerticalLogo),
  // então a página não cresce um pixel e o scroll de poucos pixels que já
  // apareceu em tela de notebook não volta. Ao mexer no logo, mexa aqui na
  // direção contrária para manter a soma.
  static const double folgaVerticalLogo = 22;

  /// Altura REAL da AppBar montada por este layout, na faixa de tela atual.
  ///
  /// Quem calcula altura de conteúdo na mão — o painel admin trava a altura
  /// do card na tela, por exemplo — precisa descontar ESTE valor e nunca
  /// `kToolbarHeight`: no desktop a barra tem 74px para caber o logo, não os
  /// 56 do padrão do Material, e descontar o valor errado sobra conteúdo
  /// para fora da janela e faz nascer scroll na página.
  static double alturaAppBar(BuildContext context) =>
      Responsive.isDesktop(context)
      ? alturaLogoDesktop + folgaVerticalLogo
      : kToolbarHeight;

  @override
  Widget build(BuildContext context) {
    final esticar = esticarLarguraCompact && Responsive.isCompact(context);
    final cores = AppCores.de(context);

    // Nitidez de arte bitmap é orçamento de pixel, não filtro: o que chega na
    // tela é `altura × devicePixelRatio`. No celular o DPR 3 rende 132 pixels
    // reais a partir de 44 e a arte aparece inteira; num monitor comum (DPR 1)
    // os mesmos 44 viram 44, e o "7", o "13" e o trevo borram. Era o sintoma
    // relatado — nítido no celular e no emulador de dispositivo do Chrome (que
    // força DPR alto), borrado no desktop. Filtro nenhum resolve, só altura, e
    // por isso a caixa cresce onde há espaço.
    //
    // Só o desktop cresce: no celular a barra é estreita, e lá o logo nunca
    // foi o problema.
    final ehDesktop = Responsive.isDesktop(context);
    final alturaLogo = ehDesktop ? alturaLogoDesktop : alturaLogoCompacto;

    return Container(
      decoration: GradientDecoration.backgroundGradient(context),
      child: Scaffold(
        drawer: drawer,
        onDrawerChanged: onDrawerChanged,
        bottomNavigationBar: bottomNavigationBar,
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
                // celular fica `null` de propósito: 44 cabe no padrão (56), e
                // passar altura ali engordava a barra do celular à toa.
                //
                // O valor sai de `alturaAppBar` e não de uma conta local: é o
                // mesmo número que as telas de altura calculada descontam da
                // janela, e as duas pontas divergirem é justamente o que
                // fazia nascer scroll no painel admin.
                toolbarHeight: ehDesktop ? alturaAppBar(context) : null,
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
                          // três: a de baixo tem a altura da MAIOR caixa (52,
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
