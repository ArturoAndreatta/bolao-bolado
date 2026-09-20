import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/core/app_radii.dart';
import 'package:flutter/material.dart';

/// Efeito shimmer aplicado a qualquer child (usado nos placeholders de skeleton).
class Shimmer extends StatefulWidget {
  final Widget child;

  const Shimmer({super.key, required this.child});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final dx = _controller.value * 2 - 1;
            return LinearGradient(
              begin: Alignment(-1 + dx, 0),
              end: Alignment(1 + dx, 0),
              colors: [
                cores.skeletonBase,
                cores.skeletonBrilho,
                cores.skeletonBase,
              ],
              stops: const [0.35, 0.5, 0.65],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Bloco retangular usado como placeholder de texto/ícone dentro do skeleton.
class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppCores.de(context).skeletonBase,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Placeholder de um campo de formulário: a moldura REAL do campo (mesmo
/// fundo, raio e altura) com o ícone e a linha de texto brilhando por dentro.
///
/// O [Shimmer] fica dentro, e não em volta: envolvendo o campo inteiro, o
/// gradiente pintava a moldura e o conteúdo com a mesma cor, e o campo virava
/// um retângulo chapado — um formulário de seis retângulos iguais, que não
/// lembra em nada o formulário que chega depois.
class SkeletonCampoFormulario extends StatelessWidget {
  final double maxWidth;

  /// Altura do campo real (CustomField e os InputDecorator com a mesma
  /// decoração), medida do widget de verdade.
  static const double altura = 55;

  const SkeletonCampoFormulario({super.key, this.maxWidth = 480});

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        height: altura,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: cores.campo,
          borderRadius: AppRadii.circularLg,
          border: Border.all(color: cores.bordaCampo),
        ),
        child: Shimmer(
          child: Row(
            children: [
              const SkeletonBox(width: 20, height: 20, radius: 5),
              const SizedBox(width: 12),
              Expanded(
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: 0.6,
                  child: const SkeletonBox(width: double.infinity, height: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton da faixa de indicadores do topo do painel admin (desktop).
///
/// Tem a altura da faixa real (ícone de 38 + as três linhas de texto ao
/// lado): se o placeholder fosse mais baixo, a seção inteira abaixo dele
/// pularia para cima no instante em que os números chegassem.
class SkeletonFaixaIndicadores extends StatelessWidget {
  /// Mesma quantidade de indicadores da faixa real.
  static const int _celulas = 5;

  const SkeletonFaixaIndicadores({super.key});

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cores.cardExterno,
        borderRadius: AppRadii.circularLg,
        border: Border.all(color: cores.borda),
      ),
      child: Shimmer(
        child: Row(
          children: [
            for (var i = 0; i < _celulas; i++) ...[
              if (i > 0) const SizedBox(width: 28),
              Expanded(
                child: Row(
                  children: [
                    const SkeletonBox(width: 38, height: 38, radius: 10),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          SkeletonBox(width: 64, height: 11),
                          SizedBox(height: 2),
                          SkeletonBox(width: double.infinity, height: 23),
                          // A faixa real não tem mais linha de apoio: a
                          // última barra imita a barrinha de progresso do
                          // indicador de verificadas, que é o que define a
                          // altura da régua. Barra de altura errada aqui
                          // vira salto na hora que os números entram.
                          SizedBox(height: 6),
                          SkeletonBox(width: double.infinity, height: 5),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Skeleton da seção Resumo no celular — os números da sala empilhados.
///
/// As medidas saem dos blocos reais (ver AdminCardStats com `faixa: false`):
/// destaque de prêmio, módulo de verificado com a barra de progresso e os
/// quatro tiles, um por linha. Já foi uma grade de dois por linha de blocos
/// maciços, que não correspondia a nada — o conteúdo real nunca teve dois
/// blocos lado a lado no celular, e a tela se reorganizava inteira no
/// instante em que os números chegavam.
class SkeletonDashboardStats extends StatelessWidget {
  const SkeletonDashboardStats({super.key});

  static const double _respiro = 12;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Destaque do prêmio: chip grande do ícone, o valor em corpo 26 e
          // o rótulo embaixo.
          _MolduraSkeleton(
            raio: AppRadii.lg,
            child: Row(
              children: const [
                SkeletonBox(width: 52, height: 52, radius: AppRadii.md),
                SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SkeletonBox(width: 156, height: 26),
                    SizedBox(height: 4),
                    SkeletonBox(width: 92, height: 13),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: _respiro),
          // Módulo de verificado: mesma linha deitada, mais a barra de
          // progresso da fila e a legenda de porcentagem.
          _MolduraSkeleton(
            raio: AppRadii.lg,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: const [
                Row(
                  children: [
                    SkeletonBox(width: 44, height: 44, radius: AppRadii.smd),
                    SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SkeletonBox(width: 128, height: 26),
                        SizedBox(height: 2),
                        SkeletonBox(width: 74, height: 12),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 12),
                SkeletonBox(
                  width: double.infinity,
                  height: 6,
                  radius: AppRadii.pill,
                ),
                SizedBox(height: 5),
                SkeletonBox(width: 136, height: 11),
              ],
            ),
          ),
          // Tiles: chip do ícone, valor e rótulo na mesma linha.
          for (var i = 0; i < 4; i++) ...[
            const SizedBox(height: _respiro),
            _MolduraSkeleton(
              raio: AppRadii.md,
              child: Row(
                children: [
                  const SkeletonBox(
                    width: 36,
                    height: 36,
                    radius: AppRadii.smd,
                  ),
                  const SizedBox(width: 12),
                  SkeletonBox(width: _valores[i], height: 17),
                  const SizedBox(width: 8),
                  SkeletonBox(width: _rotulos[i], height: 12),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Largura do número e do rótulo de cada tile (participantes, arrecadado,
  /// cotas, verificadas) — são dados de tamanhos bem diferentes, e todos do
  /// mesmo tamanho fariam os quatro tiles lerem como um só bloco listrado.
  static const List<double> _valores = [22, 96, 44, 58];
  static const List<double> _rotulos = [86, 104, 88, 74];
}

/// Moldura neutra de um bloco de skeleton: mesmo fundo, borda e raio dos
/// cards reais, com o conteúdo cinza por dentro.
///
/// A moldura fica FORA do [Shimmer] de quem usa? Não: aqui ela entra junto,
/// de propósito — no celular os blocos reais são tingidos com a cor do
/// indicador (dourado, verde), e uma moldura de cor fixa no lugar deles
/// prometeria um card que não é o que chega.
class _MolduraSkeleton extends StatelessWidget {
  final Widget child;
  final double raio;
  final EdgeInsets padding;

  const _MolduraSkeleton({
    required this.child,
    required this.raio,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  });

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: cores.skeletonBase.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(raio),
      ),
      child: child,
    );
  }
}

/// Placeholder de um card de sala (mesmo formato de _SalaCard em consultar_salas.dart).
class SkeletonCardSala extends StatelessWidget {
  const SkeletonCardSala({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppCores.de(context).card,
          borderRadius: AppRadii.circularMd,
          border: Border.all(
            color: AppCores.de(context).bordaCampo,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                // Nome em corpo 16 e descrição em 14, separados por 4 — as
                // mesmas medidas do card real.
                children: const [
                  SkeletonBox(width: 160, height: 16),
                  SizedBox(height: 4),
                  SkeletonBox(width: 108, height: 14),
                ],
              ),
            ),
            const SkeletonBox(width: 16, height: 16, radius: 4),
          ],
        ),
      ),
    );
  }
}

/// Skeleton de uma lista de salas (usado enquanto a lista carrega).
class SkeletonListaSalas extends StatelessWidget {
  final int itens;

  const SkeletonListaSalas({super.key, this.itens = 5});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [for (var i = 0; i < itens; i++) const SkeletonCardSala()],
      ),
    );
  }
}

/// Skeleton de um formulário genérico: uma sequência de linhas de campos +
/// botão de ação, na mesma proporção usada pelos formulários de Aposta e
/// Cadastro de Sala. Cada item de `linhas` é uma lista de larguras dos campos
/// daquela linha — uma linha com 2 larguras reproduz campos lado a lado
/// (ex: Data + Hora).
class SkeletonFormulario extends StatelessWidget {
  final List<List<double>> linhas;
  final double maxWidth;

  /// Espaço entre as linhas de campos — o mesmo do formulário que ele
  /// substitui (15 nos cadastros, 14 no painel admin).
  final double gap;

  /// Botão do fim do formulário. Null desenha o botão largo padrão; a aba
  /// Sala do painel, por exemplo, tem um botão compacto alinhado à direita.
  final Widget? botao;

  const SkeletonFormulario({
    super.key,
    required this.linhas,
    this.maxWidth = 480,
    this.gap = 15,
    this.botao,
  });

  @override
  Widget build(BuildContext context) {
    // Sem Shimmer em volta: cada campo traz o seu, por dentro da moldura —
    // envolvendo o formulário todo, o gradiente apagaria as molduras.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (final linha in linhas) ...[
          if (linha.length == 1)
            SkeletonCampoFormulario(maxWidth: linha.first)
          else
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Row(
                children: [
                  for (var i = 0; i < linha.length; i++) ...[
                    Expanded(
                      child: SkeletonCampoFormulario(maxWidth: linha[i]),
                    ),
                    if (i != linha.length - 1) const SizedBox(width: 15),
                  ],
                ],
              ),
            ),
          SizedBox(height: gap),
        ],
        botao ??
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: const Shimmer(
                child: SkeletonBox(
                  width: double.infinity,
                  height: 54,
                  radius: 12,
                ),
              ),
            ),
      ],
    );
  }
}

// =============================================================================
// Painel ADM — skeletons que espelham o layout do painel no desktop.
//
// Um skeleton só vale a pena se o que ele desenha estiver ONDE o conteúdo vai
// aparecer. O painel já mostrou, enquanto carregava, apenas a régua de
// indicadores esticada no meio de um card vazio: nada ali ficava naquela
// posição depois de carregado, e a tela inteira se reorganizava de uma vez.
// Por isso estes placeholders repetem a estrutura real — faixa no topo, menu
// lateral à esquerda, seção de Participantes ocupando o resto — com as mesmas
// medidas dos widgets de verdade.
// =============================================================================

/// Skeleton do Painel ADM no desktop: faixa de números + menu lateral + a
/// seção de Participantes, que é a que o painel abre.
class SkeletonPainelAdmin extends StatelessWidget {
  /// Mesma largura do menu real (PainelAdmin._larguraMenu) — quem sabe dela é
  /// a tela, então ela vem de lá em vez de ser copiada aqui e envelhecer.
  final double larguraMenu;

  const SkeletonPainelAdmin({super.key, required this.larguraMenu});

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SkeletonFaixaIndicadores(),
        const SizedBox(height: 14),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: larguraMenu, child: const _SkeletonMenuAdmin()),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _SkeletonCabecalhoSecao(),
                    Divider(height: 1, thickness: 1, color: cores.borda),
                    const Expanded(
                      child: SkeletonSecaoParticipantes(rolando: true),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Menu lateral do painel: a moldura de verdade (fundo e borda) com quatro
/// itens cinza dentro, nas mesmas medidas de _ItemMenu.
class _SkeletonMenuAdmin extends StatelessWidget {
  const _SkeletonMenuAdmin();

  /// Largura do rótulo de cada seção, na ordem de kAbasAdmin (Participantes,
  /// Ranking, Sala, Configurações) — proporcional ao texto real, para o menu
  /// não virar quatro barras idênticas.
  static const List<double> _rotulos = [104, 64, 44, 96];

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cores.cardExterno,
        borderRadius: AppRadii.circularLg,
        border: Border.all(color: cores.borda),
      ),
      child: Shimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _rotulos.length; i++) ...[
              if (i > 0) const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                child: SizedBox(
                  height: 22,
                  child: Row(
                    children: [
                      // O espaço do traço de 3px do item ativo mais o respiro
                      // dele: sem isso os ícones nascem 12px à esquerda de
                      // onde vão ficar.
                      const SizedBox(width: 12),
                      const SkeletonBox(width: 19, height: 19, radius: 5),
                      const SizedBox(width: 10),
                      SkeletonBox(width: _rotulos[i], height: 13),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Cabeçalho da seção (ícone + título + a linha de descrição).
class _SkeletonCabecalhoSecao extends StatelessWidget {
  const _SkeletonCabecalhoSecao();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 2, 16, 10),
      child: Shimmer(
        child: Row(
          children: [
            SkeletonBox(width: 20, height: 20, radius: 5),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SkeletonBox(width: 140, height: 16),
                SizedBox(height: 6),
                SkeletonBox(width: 210, height: 12),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton da seção de Participantes: barra de ferramentas (busca, filtro e
/// botão) e o card da lista preenchido com linhas de aposta.
///
/// [rolando] segue a mesma regra da seção real: no desktop a lista desce até
/// a base do painel e carrega a contagem no rodapé; nas faixas estreitas ela
/// tem respiro embaixo e a contagem fica de fora.
class SkeletonSecaoParticipantes extends StatelessWidget {
  final bool rolando;

  const SkeletonSecaoParticipantes({super.key, this.rolando = false});

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    return Padding(
      padding: rolando
          ? const EdgeInsets.fromLTRB(16, 16, 16, 0)
          : const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SkeletonBarraFerramentas(),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
              decoration: BoxDecoration(
                color: cores.cardExterno,
                borderRadius: AppRadii.circularLg,
                border: Border.all(color: cores.borda),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Shimmer(
                      // ListView, e não Column: ele constrói só o que cabe e
                      // corta o resto sozinho, então o card fica cheio em
                      // qualquer altura de janela — é como a lista real
                      // termina, meia linha cortada no pé.
                      child: ListView.separated(
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        itemCount: 20,
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          thickness: 1,
                          color: cores.borda,
                        ),
                        itemBuilder: (_, i) => _SkeletonLinhaParticipante(
                          fatorNome: _fatoresNome[i % _fatoresNome.length],
                        ),
                      ),
                    ),
                  ),
                  if (rolando) ...[
                    Divider(height: 1, thickness: 1, color: cores.borda),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(10, 7, 10, 3),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Shimmer(
                          child: SkeletonBox(width: 104, height: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Quanto da largura livre cada nome ocupa. Nomes reais têm tamanhos
  /// diferentes; com todos iguais a lista vira um código de barras.
  static const List<double> _fatoresNome = [0.52, 0.34, 0.44, 0.61, 0.38];
}

/// Barra de busca + filtro + botão de lançar, no mesmo arranjo da seção real
/// (tudo numa linha quando há largura; busca sozinha em cima quando não há).
class _SkeletonBarraFerramentas extends StatelessWidget {
  const _SkeletonBarraFerramentas();

  static const double _altura = 44;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: LayoutBuilder(
        builder: (context, restricoes) {
          const busca = SkeletonBox(
            width: double.infinity,
            height: _altura,
            radius: AppRadii.md,
          );
          const acoes = SkeletonBox(
            width: 88,
            height: _altura,
            radius: AppRadii.md,
          );

          // Mesmo limiar de _barraFerramentas: abaixo dele a busca não serve
          // para digitar nome espremida entre o filtro e o botão.
          if (restricoes.maxWidth >= 640) {
            return const Row(
              children: [
                Expanded(child: busca),
                SizedBox(width: 12),
                SkeletonBox(width: 190, height: _altura, radius: AppRadii.md),
                SizedBox(width: 12),
                SkeletonBox(width: 1, height: 28, radius: 1),
                SizedBox(width: 12),
                acoes,
              ],
            );
          }

          return const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              busca,
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SkeletonBox(
                      width: double.infinity,
                      height: 36,
                      radius: AppRadii.md,
                    ),
                  ),
                  SizedBox(width: 12),
                  SkeletonBox(width: 1, height: 28, radius: 1),
                  SizedBox(width: 12),
                  acoes,
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Uma linha da lista de apostas: avatar, nome, valor, cotas e os dois botões
/// de ação. A altura de 48 do conteúdo é a dos IconButton reais, que são o
/// que define a altura da linha — não o avatar de 36.
class _SkeletonLinhaParticipante extends StatelessWidget {
  final double fatorNome;

  const _SkeletonLinhaParticipante({required this.fatorNome});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            const SkeletonBox(width: 36, height: 36, radius: 18),
            const SizedBox(width: 12),
            Expanded(
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: fatorNome,
                child: const SkeletonBox(width: double.infinity, height: 15),
              ),
            ),
            const SizedBox(width: 12),
            const SkeletonBox(width: 84, height: 14),
            const SizedBox(width: 16),
            const SkeletonBox(width: 52, height: 13),
            const SizedBox(width: 8),
            // Os dois botões ocupam 48 de largura cada, como os IconButton.
            const SizedBox(
              width: 48,
              child: Center(
                child: SkeletonBox(width: 22, height: 22, radius: 11),
              ),
            ),
            const SizedBox(
              width: 48,
              child: Center(
                child: SkeletonBox(width: 20, height: 20, radius: 5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton da seção Ranking: o card com as barras de distribuição, no mesmo
/// formato de AdminBarraDistribuicao (rótulo + valor em cima, barra embaixo).
class SkeletonListaRanking extends StatelessWidget {
  final bool rolando;

  const SkeletonListaRanking({super.key, this.rolando = false});

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    return Padding(
      padding: rolando
          ? const EdgeInsets.fromLTRB(16, 16, 16, 0)
          : const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cores.cardExterno,
          borderRadius: AppRadii.circularLg,
          border: Border.all(color: cores.borda),
        ),
        child: Shimmer(
          child: ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            // Alto o bastante para encher qualquer altura de janela: o
            // ListView constrói só o que cabe e corta o resto.
            itemCount: 24,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (_, i) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _fatoresNome[i % _fatoresNome.length],
                        child: const SkeletonBox(
                          width: double.infinity,
                          height: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const SkeletonBox(width: 120, height: 12),
                  ],
                ),
                const SizedBox(height: 6),
                // A barra encurta conforme a posição, como o ranking real —
                // quem lidera ocupa a linha inteira.
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: (1 - i * 0.12).clamp(0.12, 1.0),
                  child: const SkeletonBox(
                    width: double.infinity,
                    height: 6.4,
                    radius: AppRadii.pill,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static const List<double> _fatoresNome = [0.46, 0.3, 0.38, 0.55, 0.34];
}
