import 'dart:async';
import 'dart:math' as math;

import 'package:bolao_bolado/components/shell/gradient_decoration.dart';
import 'package:bolao_bolado/components/shell/truques_bola.dart';
import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/core/responsive.dart';
import 'package:flutter/gestures.dart' show kTouchSlop;
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
  // Toque em qualquer ponto do body (inclusive o gradiente em volta dos
  // cards), mas NÃO na AppBar nem no Drawer, com a posição global do toque.
  // Serve para fechar painel sobreposto clicando fora dele; quem recebe
  // decide pela posição o que conta como "dentro" (o próprio painel, o botão
  // que o abre).
  //
  // Ouve o ponteiro cru ([_ToqueNoCorpo]) e não um GestureDetector: um
  // detector aqui disputa o toque com tudo que é clicável embaixo, e perde
  // para todos eles — clicar numa linha da tabela, que tem toque próprio, não
  // fechava nada.
  final ValueChanged<Offset>? onToqueNoCorpo;
  const DefaultLayout({
    super.key,
    required this.child,
    this.drawer,
    this.onDrawerChanged,
    this.showLogo = true,
    this.esticarLarguraCompact = false,
    this.bottomNavigationBar,
    this.extendBody = false,
    this.onToqueNoCorpo,
  });

  // A marca da barra é a bola do "7" (a mesma do ícone da aba e do app
  // instalado), com o nome escrito ao lado fora do celular. A logo ilustrada
  // completa (logo4.png) saiu daqui: com texto curvo, bolinhas e contorno,
  // espremida na altura de uma AppBar ela virava mancha e o nome não se lia.
  // Ela continua no splash e na tela inicial, onde tem espaço.
  //
  // A bola tem 40px de altura EXATOS (images/bola7.png, com as
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
                    ? _MarcaAppBar(mostrarNome: mostrarNome, cores: cores)
                    : null,
              )
            : null,
        // esticar: o child preenche 100% da área abaixo da AppBar (largura
        // E altura) — sem o SingleChildScrollView, que só cresce até o
        // tamanho do conteúdo e deixava sobrar gradiente de fundo embaixo.
        // Por isso ele também fica de fora do respiro abaixo: ali encostar na
        // AppBar é o efeito pretendido, não descuido.
        body: _ToqueNoCorpo(aoTocar: onToqueNoCorpo, child: _corpo(esticar)),
      ),
    );
  }

  Widget _corpo(bool esticar) {
    return esticar
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
          );
  }
}

/// Avisa toque (apertar e soltar quase no mesmo ponto) em qualquer lugar do
/// filho, sem entrar na disputa de gestos: o que está embaixo continua
/// recebendo o clique normalmente.
///
/// Arrastar além de [kTouchSlop] não conta — rolar a tabela não é clicar
/// fora.
class _ToqueNoCorpo extends StatefulWidget {
  final ValueChanged<Offset>? aoTocar;
  final Widget child;

  const _ToqueNoCorpo({required this.aoTocar, required this.child});

  @override
  State<_ToqueNoCorpo> createState() => _ToqueNoCorpoState();
}

class _ToqueNoCorpoState extends State<_ToqueNoCorpo> {
  final Map<int, Offset> _inicios = {};

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) => _inicios[e.pointer] = e.position,
      onPointerCancel: (e) => _inicios.remove(e.pointer),
      onPointerUp: (e) {
        final inicio = _inicios.remove(e.pointer);
        final aoTocar = widget.aoTocar;
        if (inicio == null || aoTocar == null) return;
        if ((e.position - inicio).distance > kTouchSlop) return;
        aoTocar(e.position);
      },
      child: widget.child,
    );
  }
}

/// Bola do "7" com o nome do app ao lado (o nome some no celular).
///
/// Não é só imagem e texto: a bola entra rolando na primeira vez que a barra
/// aparece e, a cada passada do mouse, faz um truque diferente
/// ([truquesBola], sempre na mesma ordem). É a marca do app, e parada
/// ao lado de um texto comum ela lia como ícone de sistema.
class _MarcaAppBar extends StatefulWidget {
  final bool mostrarNome;
  final AppCores cores;

  const _MarcaAppBar({required this.mostrarNome, required this.cores});

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
  late final AnimationController _truque = AnimationController(vsync: this);

  // Próximo truque da fila. Estático pelo mesmo motivo de `_jaEntrou`: cada
  // tela monta a sua AppBar, e sem isto a fila recomeçaria do primeiro a
  // cada navegação, e quem passa o mouse só veria os primeiros truques.
  static int _proximo = 0;
  TruqueBola _atual = truquesBola.first;

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
    _truque.dispose();
    super.dispose();
  }

  // Passar o mouse de novo no meio de um truque não corta nem enfileira:
  // o truque termina, e a próxima passada já pega o seguinte.
  void _fazerTruque() {
    if (_truque.isAnimating || MediaQuery.disableAnimationsOf(context)) return;
    _atual = truquesBola[_proximo];
    _proximo = (_proximo + 1) % truquesBola.length;
    _truque.duration = _atual.duracao;
    unawaited(_truque.forward(from: 0));
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

    final imagemBola = Image.asset(
      // As variantes 2.0x/3.0x ao lado do arquivo é que resolvem o tamanho:
      // o Flutter escolhe sozinho pelo DPR e cada tela desenha perto de 1:1.
      // Foram reduzidas do icone.png em Lanczos com unsharp leve; ao mexer
      // em `alturaBola`, regere as três (1×, 2× e 3× a caixa).
      //
      // O nome mudou de bola_appbar.png para bola7.png quando a sombra da
      // arte saiu: navegadores que já tinham o arquivo antigo guardado
      // continuaram mostrando a bola com sombra mesmo depois do deploy.
      // Imagem nova com desenho diferente pede nome novo.
      'images/bola7.png',
      height: DefaultLayout.alturaBola,
      width: DefaultLayout.alturaBola,
      // medium (bilinear) e não high (cúbico): perto de 1:1, que é onde as
      // variantes deixam o desenho, o cúbico amolece.
      filterQuality: FilterQuality.medium,
    );

    // A sombra vive FORA da imagem e fora do giro. A arte original trazia a
    // sombra pintada dentro do PNG, e aí ela girava junto com a bola (e lia
    // como mancha grudada nela); por isso foi recortada da arte
    // (images/icone.png e tudo gerado dele). Aqui ela é uma elipse borrada
    // embaixo, de contato com o "chão" da barra: acompanha a bola quando ela
    // rola para o lugar, mas não roda, e encolhe quando a bola pula.
    //
    // O sombreado escuro DENTRO da bola é do desenho e fica: clarear ele foi
    // tentado e a bola perdeu volume e detalhe.
    final corSombra = widget.cores.sombra.withValues(
      alpha: widget.cores.escuro ? 0.9 : 0.6,
    );

    final bola = AnimatedBuilder(
      animation: Listenable.merge([rolar, _truque]),
      builder: (context, filho) {
        final t = rolar.value;
        // Fora de truque a pose é a de repouso. Não basta confiar em
        // `pose(1)`: o controller parado em 1 de um truque antigo não pode
        // deixar a bola torta.
        final pose = _truque.isAnimating
            ? _atual.pose(_truque.value)
            : const PoseBola();
        // A sombra encolhe e clareia com a altura: é ela que faz o pulo
        // parecer pulo, e não a bola deslizando para cima.
        final alturaSombra =
            (1 - pose.altura / 22).clamp(0.35, 1.0) *
            (0.4 + 0.6 * pose.opacidade);
        // Giro de lado (moeda) com perspectiva. O ângulo é dobrado para
        // dentro de ±90°: de costas o "7" apareceria espelhado.
        final giroY = (pose.giroY + math.pi / 2) % math.pi - math.pi / 2;
        return Opacity(
          opacity: _entrada.value.clamp(0, 0.25) * 4,
          child: Transform.translate(
            offset: Offset((t - 1) * 28, 0),
            child: SizedBox.square(
              dimension: DefaultLayout.alturaBola,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  // Círculo com degradê radial achatado na vertical: vira
                  // uma elipse de borda macia, centrada na base
                  // da bola para ficar colada nela (sombra de contato).
                  // Degradê e não BoxShadow porque o desfoque do BoxShadow
                  // muda de um renderizador para outro e saía duro.
                  Positioned(
                    left: pose.dx,
                    right: -pose.dx,
                    top: DefaultLayout.alturaBola - 18,
                    height: 36,
                    child: Transform.scale(
                      scaleX: alturaSombra * pose.escalaX.clamp(0.6, 1.4),
                      scaleY: 0.28 * alturaSombra,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              corSombra.withValues(
                                alpha: corSombra.a * alturaSombra,
                              ),
                              corSombra.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(pose.dx, -pose.altura),
                    child: CustomPaint(
                      // Anel e faíscas atrás da bola, na posição dela.
                      painter: EfeitosBolaPainter(
                        anel: pose.anel,
                        faiscas: pose.faiscas,
                        cor: widget.cores.acaoPrimaria,
                        corAlternada: widget.cores.azul,
                      ),
                      child: Opacity(
                        opacity: pose.opacidade.clamp(0.0, 1.0),
                        child: Transform.rotate(
                          angle: pose.inclinacao,
                          alignment: Alignment.bottomCenter,
                          child: Transform.scale(
                            scaleX: pose.escalaX,
                            scaleY: pose.escalaY,
                            alignment: Alignment.bottomCenter,
                            child: CustomPaint(
                              foregroundPainter: BrilhoBolaPainter(pose.brilho),
                              child: Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.identity()
                                  ..setEntry(3, 2, 0.0025)
                                  ..rotateY(giroY),
                                child: Transform.rotate(
                                  angle: (t - 1) * 3 * math.pi + pose.angulo,
                                  child: filho,
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
            ),
          ),
        );
      },
      child: imagemBola,
    );

    // O nome é montado como marca, não como frase: "BOLÃO" pequeno e
    // espaçado em cima, "Bolado" grande embaixo na cor de ação do tema. As
    // duas linhas juntas têm a altura da bola, e o conjunto fecha num bloco
    // só. Em uma linha, com o mesmo peso e a cor do texto, ele lia como
    // título de tela qualquer.
    //
    // A cor de ação é a única cor saturada de cada tema (botão Confirmar),
    // então usá-la aqui não acrescenta cor nova: amarra a marca ao tema
    // escolhido. Em tamanho grande e peso 900 vale o mínimo de 3:1 de texto
    // grande, e todas as paletas passam sobre o topo do gradiente; o claro
    // é o mais justo (azul sobre amarelo, 3.04:1). Ao mexer no `acaoPrimaria`
    // ou no gradiente do claro, remeça.
    final acao = widget.cores.acaoPrimaria;
    final hslAcao = HSLColor.fromColor(acao);
    final acaoFundo = hslAcao
        .withLightness((hslAcao.lightness - 0.12).clamp(0.0, 1.0))
        .toColor();
    // Sombra curta e mais forte no escuro (lá a sombra fraca some no fundo);
    // é o que tira o texto de "impresso no fundo" e o põe na mesma camada
    // da bola.
    Shadow sombraTexto(double intensidade) => Shadow(
      color: widget.cores.sombra.withValues(
        alpha: (widget.cores.escuro ? 0.7 : 0.3) * intensidade,
      ),
      offset: Offset(0, 2 * intensidade),
      blurRadius: 4 * intensidade,
    );

    final estiloBolado = TextStyle(
      color: acao,
      fontSize: 26,
      fontWeight: FontWeight.w900,
      fontStyle: FontStyle.italic,
      letterSpacing: -0.6,
      height: 1,
    );

    final nome = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'BOLÃO',
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            color: widget.cores.textoSuave,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 3.2,
            height: 1,
            shadows: [sombraTexto(0.5)],
          ),
        ),
        const SizedBox(height: 2),
        // Degradê do tom do tema (em cima) para uma versão mais escura dele
        // (embaixo): dá o volume de letreiro que a cor chapada não tem. Desce
        // para o escuro, e não sobe para o claro, porque o claro é o tema mais
        // justo em contraste e escurecer só aumenta a folga.
        // Sombra e degradê em camadas SEPARADAS. O ShaderMask pinta tudo
        // que o filho desenha, inclusive a sombra do texto: com os dois
        // juntos a sombra virava uma névoa da cor do tema em volta das
        // letras, que no escuro (sombra mais forte) aparecia como um
        // borrão rosa/dourado. Embaixo vai só a sombra (texto
        // transparente), em cima só o degradê.
        Stack(
          children: [
            Text(
              'Bolado',
              maxLines: 1,
              softWrap: false,
              style: estiloBolado.copyWith(
                color: acao.withValues(alpha: 0),
                shadows: [sombraTexto(1)],
              ),
            ),
            ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (area) => LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [acao, acaoFundo],
              ).createShader(area),
              child: Text(
                'Bolado',
                maxLines: 1,
                softWrap: false,
                style: estiloBolado,
              ),
            ),
          ],
        ),
      ],
    );

    // Um rótulo só para o conjunto: sem isso o leitor de tela anunciaria a
    // imagem e depois o mesmo nome em texto.
    return Semantics(
      label: DefaultLayout.nomeApp,
      header: true,
      child: ExcludeSemantics(
        child: MouseRegion(
          onEnter: (_) => _fazerTruque(),
          child: GestureDetector(
            onTap: _fazerTruque,
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
