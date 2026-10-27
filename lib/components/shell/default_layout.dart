import 'dart:async';
import 'dart:math' as math;

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
  // A bola tem 40px de altura EXATOS (images/bola_appbar.png, com as
  // variantes 2.0x/3.0x geradas em cima disso a partir de images/icone.png).
  // Caixa diferente faz o Flutter reescalar a arte na hora de desenhar e o
  // brilho e o traço do "7" amolecem. Mexer aqui obriga a regerar as três.
  //
  // Foi 32 na primeira versão e lia como ícone solto, menor que o próprio
  // nome ao lado. 40 ainda cabe na barra padrão do celular (56).
  static const double alturaBola = 40;

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
///
/// Não é só imagem e texto: a bola entra rolando na primeira vez que a barra
/// aparece e gira quando o mouse passa por cima. É a marca do app, e parada
/// ao lado de um texto comum ela lia como ícone de sistema.
class _MarcaAppBar extends StatefulWidget {
  final bool mostrarNome;
  final Color cor;

  const _MarcaAppBar({required this.mostrarNome, required this.cor});

  @override
  State<_MarcaAppBar> createState() => _MarcaAppBarState();
}

class _MarcaAppBarState extends State<_MarcaAppBar>
    with TickerProviderStateMixin {
  // A entrada roda uma vez por sessão, não por tela: as trocas de rota são
  // instantâneas e cada tela monta a sua AppBar, então sem isto a bola
  // voltaria a rolar a cada navegação, e animação repetida em todo clique
  // cansa em vez de enfeitar.
  static bool _jaEntrou = false;

  late final AnimationController _entrada = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );
  late final AnimationController _giro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  @override
  void initState() {
    super.initState();
    if (_jaEntrou) {
      _entrada.value = 1;
    } else {
      _jaEntrou = true;
      // O valor de "reduzir movimento" só pode ser lido depois do primeiro
      // build (MediaQuery depende do contexto montado).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (MediaQuery.disableAnimationsOf(context)) {
          _entrada.value = 1;
        } else {
          unawaited(_entrada.forward());
        }
      });
    }
  }

  @override
  void dispose() {
    _entrada.dispose();
    _giro.dispose();
    super.dispose();
  }

  void _girar() {
    if (_giro.isAnimating || MediaQuery.disableAnimationsOf(context)) return;
    unawaited(_giro.forward(from: 0));
  }

  @override
  Widget build(BuildContext context) {
    // Rola da esquerda dando uma volta e meia, assenta com um leve passo
    // além do ponto (easeOutBack) como bola que para de rolar.
    final rolar = CurvedAnimation(
      parent: _entrada,
      curve: const Interval(0, 0.8, curve: Curves.easeOutBack),
    );
    // O nome entra só depois que a bola está quase parada, para os dois
    // movimentos não disputarem o olho.
    final nomeEntra = CurvedAnimation(
      parent: _entrada,
      curve: const Interval(0.45, 1, curve: Curves.easeOutCubic),
    );
    final girar = CurvedAnimation(parent: _giro, curve: Curves.easeOutCubic);

    final bola = AnimatedBuilder(
      animation: Listenable.merge([rolar, girar]),
      builder: (context, filho) {
        final t = rolar.value;
        return Opacity(
          opacity: _entrada.value.clamp(0, 0.25) * 4,
          child: Transform.translate(
            offset: Offset((t - 1) * 28, 0),
            child: Transform.rotate(
              angle: (t - 1) * 3 * math.pi + girar.value * 2 * math.pi,
              child: filho,
            ),
          ),
        );
      },
      child: DecoratedBox(
        // Sombra curta embaixo da bola para ela pousar na barra em vez de
        // flutuar recortada; preta e fraca funciona nos fundos claros e
        // escuros, já que a barra é transparente sobre o gradiente.
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Image.asset(
          // As variantes 2.0x/3.0x ao lado do arquivo é que resolvem o
          // tamanho: o Flutter escolhe sozinho pelo DPR e cada tela desenha
          // perto de 1:1. Foram reduzidas do icone.png em Lanczos com
          // unsharp leve; ao mexer em `alturaBola`, regere as três (1×, 2×
          // e 3× a caixa).
          'images/bola_appbar.png',
          height: DefaultLayout.alturaBola,
          width: DefaultLayout.alturaBola,
          // medium (bilinear) e não high (cúbico): perto de 1:1, que é onde
          // as variantes deixam o desenho, o cúbico amolece.
          filterQuality: FilterQuality.medium,
        ),
      ),
    );

    // Duas espessuras no mesmo nome dão o desenho de marca que um texto de
    // peso único não tem, sem precisar de fonte nova nem de cor extra (a
    // cor saturada do tema já é do botão principal).
    final nome = Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'Bolão ',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          TextSpan(
            text: 'Bolado',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
      maxLines: 1,
      softWrap: false,
      style: TextStyle(
        color: widget.cor,
        fontSize: 22,
        letterSpacing: -0.3,
        height: 1,
      ),
    );

    // Um rótulo só para o conjunto: sem isso o leitor de tela anunciaria a
    // imagem e depois o mesmo nome em texto.
    return Semantics(
      label: DefaultLayout.nomeApp,
      header: true,
      child: ExcludeSemantics(
        child: MouseRegion(
          onEnter: (_) => _girar(),
          child: GestureDetector(
            onTap: _girar,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                bola,
                // Ao redimensionar a janela pela fronteira do celular o nome
                // entra e sai deslizando, em vez de saltar e arrastar a bola
                // de uma vez para o lado.
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: widget.mostrarNome
                        ? Padding(
                            key: const ValueKey('nome'),
                            padding: const EdgeInsets.only(left: 12),
                            child: FadeTransition(
                              opacity: nomeEntra,
                              child: SlideTransition(
                                position: Tween(
                                  begin: const Offset(-0.08, 0),
                                  end: Offset.zero,
                                ).animate(nomeEntra),
                                child: nome,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(key: ValueKey('sem-nome')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
