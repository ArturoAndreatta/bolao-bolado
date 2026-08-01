import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Paleta semântica do app, resolvida por tema (claro/escuro).
///
/// Antes desta classe existir, cada widget escrevia o hex direto
/// (`Color(0xFFFEFEFE)` para fundo de card, `Color(0xFF1F2937)` para texto,
/// etc). Isso funcionava enquanto só havia um tema; com dark mode, o mesmo
/// hex passou a precisar de dois valores, e espalhar `isDark ? a : b` por 40
/// arquivos seria impossível de manter coerente.
///
/// Aqui cada cor vira um NOME do papel que ela cumpre (fundo de card, texto
/// primário, borda, sucesso...) e cada tema devolve o tom certo para aquele
/// papel. Os widgets pedem `AppCores.de(context).card` e nunca precisam saber
/// qual tema está ativo.
///
/// Uso:
/// ```dart
/// final cores = AppCores.de(context);
/// Container(color: cores.card);
/// ```
///
/// Os valores do tema claro são exatamente os hex que já estavam no código —
/// o tema claro não mudou de aparência ao ganhar dark mode.
/// É um [ThemeExtension] (e não uma classe solta) para que a troca de tema
/// seja ANIMADA. O `MaterialApp` interpola suas extensions durante
/// `themeAnimationDuration`, então [lerp] faz os ~50 campos daqui atravessarem
/// do claro para o escuro em conjunto.
///
/// A alternativa seria trocar `Container` por `AnimatedContainer` nos ~95
/// pontos que leem a paleta — inviável de manter, e ainda deixaria de fora o
/// que é pintado em `BoxDecoration`/`TextStyle`. Resolvendo no `Theme`, os
/// widgets continuam lendo `AppCores.de(context).card` sem saber que existe
/// animação: em cada frame da transição eles recebem a cor já interpolada.
@immutable
class AppCores extends ThemeExtension<AppCores> {
  // ── Superfícies ──────────────────────────────────────────────────────────
  /// Fundo dos cards brancos (CustomCard filho, diálogos, tabela).
  final Color card;

  /// Fundo do card externo/moldura, um tom off-white mais quente que [card].
  /// É a "capa" do fichário e o fundo dos cards de página.
  final Color cardExterno;

  /// Fundo de campos de formulário, tiles e cabeçalhos de seção.
  final Color campo;

  /// Fundo levemente mais escuro que [campo], usado no cabeçalho/rodapé da
  /// tabela e na pill de abas do fichário.
  final Color superficieAlta;

  /// Fundo da barra de navegação do fichário (capa onde as abas se apoiam).
  final Color ficharioFundo;

  // ── Texto ────────────────────────────────────────────────────────────────
  /// Texto principal (títulos, valores, nomes).
  final Color texto;

  /// Texto secundário (subtítulos, rótulos, legendas).
  final Color textoSuave;

  /// Texto terciário, ainda mais apagado (placeholders, carimbos de hora).
  final Color textoFraco;

  /// Texto/ícone sobre superfícies coloridas fortes (botão azul, aba ativa).
  final Color textoSobreCor;

  /// Cor da ação primária (botão "Confirmar", "Acessar", CTAs de tela cheia).
  ///
  /// No claro é o [azul] de sempre. No escuro é o [dourado]: sobre feltro, um
  /// bloco azul era a única coisa fria da tela e ficava órfão da paleta — e
  /// num app de bolão o gesto de confirmar dinheiro pede ouro, não azul de
  /// sistema. Havia também um problema objetivo: branco sobre o azul claro do
  /// escuro dava 2.74:1, reprovado em AA para o botão que confirma a aposta.
  ///
  /// É um campo próprio, e não `cores.escuro ? dourado : azul` espalhado pelos
  /// widgets, porque "cor da ação primária" é um papel — quem for criar um CTA
  /// novo deve pegar daqui sem precisar saber desta história.
  final Color acaoPrimaria;

  /// Texto/ícone sobre [acaoPrimaria]. Branco no claro, escuro no escuro (o
  /// dourado é claro demais para carregar texto branco).
  final Color textoSobreAcao;

  // ── Bordas e divisores ───────────────────────────────────────────────────
  /// Borda padrão de cards, tabelas e divisores.
  final Color borda;

  /// Borda de campos de formulário — um passo mais visível que [borda].
  final Color bordaCampo;

  /// Borda de campo em foco.
  final Color bordaCampoFoco;

  // ── Cores de marca / ação ────────────────────────────────────────────────
  /// Azul de ação primária (botões, links, ícones interativos).
  final Color azul;

  /// Verde-água do gradiente de fundo, usado como cor de seção.
  final Color verdeAgua;

  /// Dourado do gradiente de fundo, usado como cor de seção.
  final Color dourado;

  /// Roxo (mesma família do azul, um passo mais frio) — seções administrativas.
  final Color roxo;

  /// Coral (vermelho puxado para o quente do dourado) — seção de configurações.
  final Color coral;

  // ── Estados ──────────────────────────────────────────────────────────────
  /// Verde de sucesso/dinheiro (valores, apostas verificadas).
  final Color verde;

  /// Vermelho de erro/ação destrutiva.
  final Color vermelho;

  // ── Fundos de estado (linhas da tabela, chips, avisos) ───────────────────
  /// Fundo de linha verificada / participante em destaque.
  final Color fundoVerde;

  /// Borda do bloco em [fundoVerde].
  final Color bordaVerde;

  /// Texto sobre [fundoVerde].
  final Color textoVerde;

  /// Fundo de linha editada após verificação (atenção).
  final Color fundoAmarelo;

  /// Borda do bloco em [fundoAmarelo].
  final Color bordaAmarelo;

  /// Texto sobre [fundoAmarelo].
  final Color textoAmarelo;

  /// Fundo de bloco informativo azul (card "Prêmio por Cota", diálogos).
  final Color fundoAzul;

  /// Borda do bloco em [fundoAzul].
  final Color bordaAzul;

  /// Texto sobre [fundoAzul].
  final Color textoAzul;

  /// Fundo de bloco de alerta vermelho (diálogo destrutivo).
  final Color fundoVermelho;

  /// Borda do bloco em [fundoVermelho].
  final Color bordaVermelho;

  /// Fundo de bloco roxo (botão de estatísticas recolhíveis).
  final Color fundoRoxo;

  /// Borda do bloco em [fundoRoxo].
  final Color bordaRoxo;

  /// Texto sobre [fundoRoxo].
  final Color textoRoxo;

  // ── Zebra da tabela ──────────────────────────────────────────────────────
  /// Linha par da tabela (mesma cor do card).
  final Color linhaPar;

  /// Linha ímpar da tabela.
  final Color linhaImpar;

  /// Destaque temporário de linha recém-chegada (animação de entrada).
  final Color linhaNova;

  /// Largura da barra lateral que marca o estado de uma linha da tabela
  /// (verificada / editada após verificação).
  ///
  /// No tema claro é 0: lá o estado é comunicado pelo FUNDO pastel da linha
  /// (#DCFCE7 / #FEF3C7), que sobre branco fica discreto. No escuro esses
  /// mesmos fundos, traduzidos para tons escuros saturados, transformavam a
  /// tabela num tabuleiro de faixas verdes e marrons que competia com os
  /// dados — então lá o fundo fica quase igual ao card e o estado vira esta
  /// barra fina na borda esquerda. Ver [TabelaApostas] e [LinhaParticipante].
  final double larguraBarraEstado;

  // ── Chat ─────────────────────────────────────────────────────────────────
  /// Bolha das mensagens dos outros participantes.
  final Color bolhaOutro;

  /// Texto dentro de [bolhaOutro].
  final Color bolhaOutroTexto;

  // ── Skeleton ─────────────────────────────────────────────────────────────
  /// Base dos blocos de skeleton.
  final Color skeletonBase;

  /// Faixa clara que corre no shimmer.
  final Color skeletonBrilho;

  // ── Chrome / diversos ────────────────────────────────────────────────────
  /// Fundo do drawer lateral.
  final Color drawerFundo;

  /// Divisor dentro do drawer.
  final Color drawerBorda;

  /// Texto dos itens do drawer.
  final Color drawerTexto;

  /// Cor da sombra projetada por cards e botões.
  final Color sombra;

  /// Gradiente de fundo da aplicação (topo-esquerda → base-direita).
  final List<Color> gradienteFundo;

  /// Posições das duas paradas do [gradienteFundo].
  ///
  /// No claro são `[0.5, 0.9]`: as cores são luminosas e saturadas, então
  /// concentrar a transição no miolo da tela evita que ela domine tudo.
  ///
  /// No escuro a transição precisa ocupar a tela INTEIRA (`[0.0, 1.0]`). Com
  /// os stops do claro, metade do viewport ficava na cor de ouro chapada, sem
  /// variação — e como os dois tons escuros diferem por poucos níveis de RGB,
  /// o resultado lia como preto uniforme e a diagonal sumia. Espalhar o
  /// degradê é o que torna a variação perceptível apesar da amplitude curta.
  final List<double> paradasGradiente;

  /// Cor do PIX/QR (miras verdes) e selos "seguro".
  final Color pix;

  /// Fundo do selo do PIX.
  final Color pixFundo;

  /// `true` quando o tema ativo é o escuro. Útil para os poucos casos em que
  /// a decisão não é uma cor e sim uma medida (ex: elevação/opacidade).
  final bool escuro;

  const AppCores({
    required this.card,
    required this.cardExterno,
    required this.campo,
    required this.superficieAlta,
    required this.ficharioFundo,
    required this.texto,
    required this.textoSuave,
    required this.textoFraco,
    required this.textoSobreCor,
    required this.acaoPrimaria,
    required this.textoSobreAcao,
    required this.borda,
    required this.bordaCampo,
    required this.bordaCampoFoco,
    required this.azul,
    required this.verdeAgua,
    required this.dourado,
    required this.roxo,
    required this.coral,
    required this.verde,
    required this.vermelho,
    required this.fundoVerde,
    required this.bordaVerde,
    required this.textoVerde,
    required this.fundoAmarelo,
    required this.bordaAmarelo,
    required this.textoAmarelo,
    required this.fundoAzul,
    required this.bordaAzul,
    required this.textoAzul,
    required this.fundoVermelho,
    required this.bordaVermelho,
    required this.fundoRoxo,
    required this.bordaRoxo,
    required this.textoRoxo,
    required this.linhaPar,
    required this.linhaImpar,
    required this.linhaNova,
    required this.larguraBarraEstado,
    required this.bolhaOutro,
    required this.bolhaOutroTexto,
    required this.skeletonBase,
    required this.skeletonBrilho,
    required this.drawerFundo,
    required this.drawerBorda,
    required this.drawerTexto,
    required this.sombra,
    required this.gradienteFundo,
    required this.paradasGradiente,
    required this.pix,
    required this.pixFundo,
    required this.escuro,
  });

  /// Tema claro: os mesmos hex que já estavam espalhados pelo código antes de
  /// existir dark mode, agora com nome do papel que cada um cumpre.
  static const AppCores claro = AppCores(
    card: Color(0xFFFEFEFE),
    cardExterno: Color(0xFFF3F1EF),
    campo: Color(0xFFF3F4F6),
    superficieAlta: Color(0xFFE9EAEC),
    ficharioFundo: Color(0xFFEDEBE8),
    texto: Color(0xFF1F2937),
    textoSuave: Color(0xFF6B7280),
    textoFraco: Color(0xFF9CA3AF),
    textoSobreCor: Color(0xFFFEFEFE),
    // Claro: a ação primária é o azul de sempre — nada mudou aqui.
    acaoPrimaria: Color(0xFF487DE5),
    textoSobreAcao: Color(0xFFFEFEFE),
    borda: Color(0xFFE5E7EB),
    bordaCampo: Color(0xFFDDDDDD),
    bordaCampoFoco: Color(0xFFCCCCCC),
    azul: Color(0xFF487DE5),
    verdeAgua: Color(0xFF4FA98A),
    dourado: Color(0xFFDBA92E),
    roxo: Color(0xFF7C5CD6),
    coral: Color(0xFFE2685C),
    verde: Color(0xFF2E7D32),
    vermelho: Color(0xFFEF4444),
    fundoVerde: Color(0xFFDCFCE7),
    bordaVerde: Color(0xFFBFE0CB),
    textoVerde: Color(0xFF2E7D32),
    fundoAmarelo: Color(0xFFFEF3C7),
    bordaAmarelo: Color(0xFFF2D9A8),
    textoAmarelo: Color(0xFF8A6116),
    fundoAzul: Color(0xFFE3EDF8),
    bordaAzul: Color(0xFFBBD3EC),
    textoAzul: Color(0xFF2A5C94),
    fundoVermelho: Color(0xFFFEE2E2),
    bordaVermelho: Color(0xFFFECACA),
    fundoRoxo: Color(0xFFEEE9FB),
    bordaRoxo: Color(0xFFD3C4F2),
    textoRoxo: Color(0xFF6B46C1),
    linhaPar: Color(0xFFFEFEFE),
    linhaImpar: Color(0xFFF3F4F6),
    linhaNova: Color(0xFFBFDDFB),
    // Zero: no claro o estado da linha é o próprio fundo pastel (ver
    // [larguraBarraEstado]).
    larguraBarraEstado: 0,
    bolhaOutro: Color(0xFFF1F3F5),
    bolhaOutroTexto: Color(0xFF1F2937),
    skeletonBase: Color(0xFFE5E7EB),
    skeletonBrilho: Color(0xFFF3F4F6),
    drawerFundo: Color(0xFF1F2937),
    drawerBorda: Color(0xFF374151),
    drawerTexto: Color(0xFFD1D5DB),
    sombra: Color(0xFF000000),
    gradienteFundo: [Color(0xFFFFE082), Color(0xFF7CC8B5)],
    paradasGradiente: [0.5, 0.9],
    pix: Color(0xFF17A673),
    pixFundo: Color(0xFFE6F7F1),
    escuro: false,
  );

  /// Tema escuro.
  ///
  /// **A metáfora é mesa de jogo: feltro verde-escuro e metal dourado.** Ela
  /// não é decoração arbitrária — é a identidade que o tema claro já tem. O
  /// gradiente claro vai de `#FFE082` (ouro, 43°) a `#7CC8B5` (feltro, 165°),
  /// e o escuro é a versão profunda dos MESMOS matizes. Por isso os dois temas
  /// se reconhecem como o mesmo app, e por isso a paleta combina com um
  /// produto de bolão/aposta em vez de parecer um dashboard genérico.
  ///
  /// As superfícies são feltro (163°) com saturação 13–20%: cor suficiente
  /// para ter caráter, baixa o bastante para não competir com o conteúdo.
  /// Duas tentativas anteriores erraram os extremos disso — azul-ardósia a
  /// 25% brigava com o gradiente (~175° de distância, complementares), e o
  /// carvão neutro a 6% era correto porém sem personalidade nenhuma. Feltro
  /// resolve os dois: **tem cor, e a cor é a do próprio gradiente**, então
  /// não existe conflito de matiz possível.
  ///
  /// Não é o tema claro invertido: as superfícies nunca chegam a preto
  /// absoluto, o que evita o "buraco preto" que fundos #000 criam em telas
  /// OLED quando o conteúdo é denso como aqui.
  ///
  /// As superfícies sobem de tom conforme se aproximam do usuário
  /// (fundo < card externo < card < campo), que é como o Material 3 comunica
  /// elevação no escuro — sombra sozinha quase não aparece sobre fundo
  /// escuro, então a hierarquia precisa vir da luminosidade.
  ///
  /// As cores de marca foram clareadas em relação ao claro: o azul #487DE5 e
  /// o verde #2E7D32 originais têm contraste insuficiente sobre fundo escuro
  /// (o verde escuro chega a ~2:1, ilegível). Os tons daqui ficam acima de
  /// 4.5:1 sobre [card], mantendo o mesmo matiz da identidade visual.
  static const AppCores escuroTema = AppCores(
    // ── Superfícies ────────────────────────────────────────────────────────
    // Feltro: matiz 163°, o MESMO do `#7CC8B5` do gradiente claro, em versões
    // profundas. A saturação cai conforme a superfície sobe (20% no fundo →
    // 13% na mais alta): quanto mais perto do usuário, mais neutra, senão as
    // camadas de cima acumulam cor e a tela satura.
    //
    // O matiz único em toda a escala é o que faz o conflito com o
    // [gradienteFundo] ser impossível por construção — superfície e fundo são
    // literalmente a mesma cor em luminosidades diferentes.
    card: Color(0xFF222F2C),
    cardExterno: Color(0xFF192421),
    campo: Color(0xFF2D3C37),
    superficieAlta: Color(0xFF374843),
    ficharioFundo: Color(0xFF101916),
    // ── Texto ──────────────────────────────────────────────────────────────
    // Branco levemente frio em vez de #FFF puro: reduz o "brilho" agressivo
    // de branco absoluto sobre fundo escuro.
    // Texto puxado levemente para o verde do feltro em vez de branco frio:
    // texto neutro sobre superfície colorida lê como "colado por cima".
    texto: Color(0xFFEBF0ED),
    textoSuave: Color(0xFFA0B1AA),
    // Claro o bastante para passar AA (≥4.5) sobre [card] e [campo]: apesar do
    // nome, ele carrega informação real (cotas, timestamps na lista), não só
    // decoração. Clarear mais o aproximaria de [textoSuave] e apagaria a
    // distinção entre os dois níveis.
    textoFraco: Color(0xFF95A7A0),
    textoSobreCor: Color(0xFFFFFFFF),
    // Escuro: ouro. Texto quase-preto quente sobre ele (10.5:1) — ver o doc
    // de [acaoPrimaria] para o porquê da troca.
    acaoPrimaria: Color(0xFFE5C061),
    textoSobreAcao: Color(0xFF1A1408),
    borda: Color(0xFF3B4E49),
    bordaCampo: Color(0xFF495F59),
    bordaCampoFoco: Color(0xFF5C7A72),
    // ── Marca ──────────────────────────────────────────────────────────────
    // Mesmos matizes do claro, clareados para contraste sobre fundo escuro
    // (o #2E7D32 original fica em ~2:1 sobre o card, ilegível). Todas passam
    // AA (≥4.5:1) sobre [card].
    //
    // O [dourado] é a cor de acento do tema: sobre feltro ele lê como METAL,
    // e é o que dá o ar de riqueza que a paleta neutra anterior não tinha.
    // Por isso sua saturação (72%) é mais alta que a das outras — ouro
    // apagado vira apenas bege.
    azul: Color(0xFF749CE7),
    verdeAgua: Color(0xFF5CC1A5),
    dourado: Color(0xFFE5C061),
    roxo: Color(0xFFA789DC),
    coral: Color(0xFFE27E6F),
    verde: Color(0xFF64CE90),
    vermelho: Color(0xFFEA7B7B),
    // ── Blocos de estado ───────────────────────────────────────────────────
    // Usados em CARDS e diálogos (não nas linhas da tabela — ver
    // [larguraBarraEstado]). São a cor apenas insinuada sobre a superfície:
    // no escuro, um bloco chapado do tom cheio lê como erro de renderização.
    fundoVerde: Color(0xFF22352A),
    bordaVerde: Color(0xFF345542),
    textoVerde: Color(0xFF69D395),
    fundoAmarelo: Color(0xFF393323),
    bordaAmarelo: Color(0xFF5D5237),
    textoAmarelo: Color(0xFFDDBE6E),
    fundoAzul: Color(0xFF242B38),
    bordaAzul: Color(0xFF37445C),
    textoAzul: Color(0xFF7EA3E7),
    fundoVermelho: Color(0xFF382424),
    bordaVermelho: Color(0xFF5C3737),
    fundoRoxo: Color(0xFF2B2438),
    bordaRoxo: Color(0xFF45375C),
    textoRoxo: Color(0xFFAD90DF),
    // ── Zebra da tabela ────────────────────────────────────────────────────
    // Diferença mínima entre par e ímpar (4 pontos de luminosidade): serve
    // só para o olho seguir a linha na horizontal. No escuro, a mesma
    // diferença do tema claro viraria listras berrantes.
    linhaPar: Color(0xFF222F2C),
    linhaImpar: Color(0xFF273531),
    // Flash momentâneo de aposta nova. Sobre feltro o realce é DOURADO, não
    // azul: é a cor de acento do tema, e um brilho de ouro passando na linha
    // diz "entrou dinheiro" melhor que um azul de sistema.
    linhaNova: Color(0xFF4E452C),
    // A barra de estado substitui o fundo colorido da linha (ver o doc do
    // campo): 3px na borda esquerda, na cor do estado.
    larguraBarraEstado: 3,
    bolhaOutro: Color(0xFF32433E),
    bolhaOutroTexto: Color(0xFFEBF0ED),
    skeletonBase: Color(0xFF2E3E39),
    skeletonBrilho: Color(0xFF3C4E49),
    // Drawer já era escuro no tema claro; aqui desce mais um passo para
    // continuar se distinguindo do conteúdo, que agora também é escuro.
    drawerFundo: Color(0xFF0C1311),
    drawerBorda: Color(0xFF293834),
    drawerTexto: Color(0xFFC3D2CB),
    sombra: Color(0xFF000000),
    // ── Gradiente de fundo ─────────────────────────────────────────────────
    // A moldura da página é o único lugar onde o dourado→verde-água da marca
    // ainda aparece no escuro, então estes dois tons carregam sozinhos a
    // identidade visual do app no tema escuro.
    //
    // São os MATIZES EXATOS do gradiente claro — 43° do `#FFE082` e 163° do
    // `#7CC8B5` — em versão profunda. Manter o matiz é o que faz o fundo ainda
    // "ser" o gradiente do app.
    //
    // A saturação (~43%) é MAIS ALTA que a de qualquer superfície, e é daí que
    // vem o ar de riqueza. Não há risco de brigar com os cards porque o matiz
    // é o mesmo — é a vantagem de usar feltro na escala inteira.
    //
    // **Mais ESCURO que o card, de propósito** (contraste ~1.12). É o que faz
    // o card flutuar sobre a mesa em vez de se fundir nela: no escuro a sombra
    // quase não aparece, então a profundidade tem que vir da luminosidade.
    //
    // Estes dois valores são o equilíbrio de uma tensão real: clarear o fundo
    // para a diagonal ouro→feltro ficar mais óbvia faz o card AFUNDAR (as
    // luminosidades se encontram), e escurecer para destacar o card apaga a
    // diagonal e a tela vira quase preta. Ao mexer aqui, mexa junto no [card]
    // — os dois se movem em par.
    gradienteFundo: [Color(0xFF2A2311), Color(0xFF0F2720)],
    // Tela inteira, não só o miolo — ver [paradasGradiente].
    paradasGradiente: [0.0, 1.0],
    pix: Color(0xFF41C8A2),
    pixFundo: Color(0xFF1D302A),
    escuro: true,
  );

  /// Paleta do tema ativo neste ponto da árvore.
  ///
  /// Lê a extension registrada no [ThemeData], que DURANTE a troca de tema é
  /// uma paleta intermediária produzida por [lerp] — é isso que faz a
  /// transição claro↔escuro ser suave em todos os widgets de uma vez.
  ///
  /// O fallback pelo `brightness` cobre um `Theme` local que sobrescreva só o
  /// brilho sem carregar as extensions (usado, por ex., na medição de layout
  /// do MinhaApostaCard): sem ele, esse caso devolveria null e quebraria.
  static AppCores de(BuildContext context) {
    final tema = Theme.of(context);
    return tema.extension<AppCores>() ??
        (tema.brightness == Brightness.dark ? escuroTema : claro);
  }

  @override
  AppCores copyWith() => this;

  /// Interpola a paleta inteira entre dois temas.
  ///
  /// Campos `Color` e `double` interpolam continuamente. [escuro] é a exceção:
  /// sendo booleano, ele VIRA na metade da transição (`t < 0.5`). Quem decide
  /// por ele não escolhe uma cor e sim uma forma — largura de barra, elevação
  /// de card, se um campo recua ou salta — e essas decisões não têm meio-termo
  /// visual. Virar no meio, quando as cores já estão a meio caminho, é o
  /// momento em que a troca menos chama atenção.
  @override
  AppCores lerp(ThemeExtension<AppCores>? other, double t) {
    if (other is! AppCores) return this;
    final outro = other;
    return AppCores(
      card: Color.lerp(card, outro.card, t)!,
      cardExterno: Color.lerp(cardExterno, outro.cardExterno, t)!,
      campo: Color.lerp(campo, outro.campo, t)!,
      superficieAlta: Color.lerp(superficieAlta, outro.superficieAlta, t)!,
      ficharioFundo: Color.lerp(ficharioFundo, outro.ficharioFundo, t)!,
      texto: Color.lerp(texto, outro.texto, t)!,
      textoSuave: Color.lerp(textoSuave, outro.textoSuave, t)!,
      textoFraco: Color.lerp(textoFraco, outro.textoFraco, t)!,
      textoSobreCor: Color.lerp(textoSobreCor, outro.textoSobreCor, t)!,
      acaoPrimaria: Color.lerp(acaoPrimaria, outro.acaoPrimaria, t)!,
      textoSobreAcao: Color.lerp(textoSobreAcao, outro.textoSobreAcao, t)!,
      borda: Color.lerp(borda, outro.borda, t)!,
      bordaCampo: Color.lerp(bordaCampo, outro.bordaCampo, t)!,
      bordaCampoFoco: Color.lerp(bordaCampoFoco, outro.bordaCampoFoco, t)!,
      azul: Color.lerp(azul, outro.azul, t)!,
      verdeAgua: Color.lerp(verdeAgua, outro.verdeAgua, t)!,
      dourado: Color.lerp(dourado, outro.dourado, t)!,
      roxo: Color.lerp(roxo, outro.roxo, t)!,
      coral: Color.lerp(coral, outro.coral, t)!,
      verde: Color.lerp(verde, outro.verde, t)!,
      vermelho: Color.lerp(vermelho, outro.vermelho, t)!,
      fundoVerde: Color.lerp(fundoVerde, outro.fundoVerde, t)!,
      bordaVerde: Color.lerp(bordaVerde, outro.bordaVerde, t)!,
      textoVerde: Color.lerp(textoVerde, outro.textoVerde, t)!,
      fundoAmarelo: Color.lerp(fundoAmarelo, outro.fundoAmarelo, t)!,
      bordaAmarelo: Color.lerp(bordaAmarelo, outro.bordaAmarelo, t)!,
      textoAmarelo: Color.lerp(textoAmarelo, outro.textoAmarelo, t)!,
      fundoAzul: Color.lerp(fundoAzul, outro.fundoAzul, t)!,
      bordaAzul: Color.lerp(bordaAzul, outro.bordaAzul, t)!,
      textoAzul: Color.lerp(textoAzul, outro.textoAzul, t)!,
      fundoVermelho: Color.lerp(fundoVermelho, outro.fundoVermelho, t)!,
      bordaVermelho: Color.lerp(bordaVermelho, outro.bordaVermelho, t)!,
      fundoRoxo: Color.lerp(fundoRoxo, outro.fundoRoxo, t)!,
      bordaRoxo: Color.lerp(bordaRoxo, outro.bordaRoxo, t)!,
      textoRoxo: Color.lerp(textoRoxo, outro.textoRoxo, t)!,
      linhaPar: Color.lerp(linhaPar, outro.linhaPar, t)!,
      linhaImpar: Color.lerp(linhaImpar, outro.linhaImpar, t)!,
      linhaNova: Color.lerp(linhaNova, outro.linhaNova, t)!,
      larguraBarraEstado: lerpDouble(
        larguraBarraEstado,
        outro.larguraBarraEstado,
        t,
      )!,
      bolhaOutro: Color.lerp(bolhaOutro, outro.bolhaOutro, t)!,
      bolhaOutroTexto: Color.lerp(bolhaOutroTexto, outro.bolhaOutroTexto, t)!,
      skeletonBase: Color.lerp(skeletonBase, outro.skeletonBase, t)!,
      skeletonBrilho: Color.lerp(skeletonBrilho, outro.skeletonBrilho, t)!,
      drawerFundo: Color.lerp(drawerFundo, outro.drawerFundo, t)!,
      drawerBorda: Color.lerp(drawerBorda, outro.drawerBorda, t)!,
      drawerTexto: Color.lerp(drawerTexto, outro.drawerTexto, t)!,
      sombra: Color.lerp(sombra, outro.sombra, t)!,
      gradienteFundo: _lerpCores(gradienteFundo, outro.gradienteFundo, t),
      paradasGradiente: _lerpDoubles(
        paradasGradiente,
        outro.paradasGradiente,
        t,
      ),
      pix: Color.lerp(pix, outro.pix, t)!,
      pixFundo: Color.lerp(pixFundo, outro.pixFundo, t)!,
      escuro: t < 0.5 ? escuro : outro.escuro,
    );
  }

  /// Interpola listas de cores posição a posição (o gradiente de fundo).
  static List<Color> _lerpCores(List<Color> a, List<Color> b, double t) => [
    for (var i = 0; i < a.length; i++) Color.lerp(a[i], b[i], t)!,
  ];

  /// Idem para as paradas do gradiente — que também mudam entre os temas
  /// (`[0.5, 0.9]` no claro, `[0.0, 1.0]` no escuro), então o degradê se
  /// espalha progressivamente em vez de saltar.
  static List<double> _lerpDoubles(List<double> a, List<double> b, double t) =>
      [for (var i = 0; i < a.length; i++) lerpDouble(a[i], b[i], t)!];
}
