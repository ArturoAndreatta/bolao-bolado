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

  /// Superfície atrás do conteúdo das seções no celular (aposta,
  /// participantes, chat), que ali não ficam dentro de card. Nos temas
  /// CLAROS é a cor do [card]: o gradiente de fundo claro é vivo demais, e o
  /// amarelo/verde vazava entre os campos e por dentro das linhas da lista.
  /// Nos ESCUROS é transparente: o gradiente escuro é sóbrio, e o conteúdo
  /// direto sobre ele era o visual desejado.
  final Color fundoConteudoMobile;

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

  /// Texto do token `@Nome` dentro de [bolhaOutro].
  ///
  /// Campo próprio, e não [textoAzul]: aquele é calibrado contra [fundoAzul],
  /// e a menção vive sobre [mencaoFundo], que por sua vez precisa se destacar
  /// da BOLHA (e não do card). São duas medidas diferentes — reaproveitar o
  /// par de blocos de estado deixava a menção quase invisível nos temas
  /// escuros, onde a bolha já é mais clara que o card.
  final Color mencaoTexto;

  /// Fundo tingido atrás do token `@Nome`, sobre [bolhaOutro].
  final Color mencaoFundo;

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
    required this.fundoConteudoMobile,
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
    required this.mencaoTexto,
    required this.mencaoFundo,
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
    fundoConteudoMobile: Color(0xFFFEFEFE),
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
    mencaoTexto: Color(0xFF23548C),
    mencaoFundo: Color(0xFFDEE9FA),
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

  /// Tema escuro PADRÃO — o que o botão "Escuro" do drawer aplica.
  ///
  /// **A regra é: este é o tema claro com a luz apagada.** Não é uma paleta
  /// nova, não é um dark mode genérico de dashboard — é o MESMO app, com os
  /// mesmos matizes, visto em ambiente escuro. Duas tentativas anteriores
  /// falharam justamente por esquecer isso:
  ///
  /// - A primeira trocou os matizes da marca por cinza-azulado neutro (220°) e
  ///   pintou o gradiente de fundo de azul-noite. O resultado parecia outro
  ///   produto: o tema claro é ouro e verde-água, e no escuro não sobrava
  ///   nada disso — a tela lia como preto morto.
  /// - A segunda foi na direção oposta (feltro verde em tudo) e saturou
  ///   demais. Virou o tema [cassino].
  ///
  /// O que esta paleta preserva do claro, item por item:
  ///
  /// 1. **Os matizes.** As superfícies usam 210° (o mesmo giro frio do
  ///    `#1F2937` que é o texto do tema claro), o gradiente mantém 43° e 163°
  ///    exatos do `#FFE082`→`#7CC8B5`, e cada cor de marca guarda o matiz da
  ///    sua correspondente clara. O que muda é luminosidade e saturação, nunca
  ///    o matiz.
  /// 2. **O gradiente da marca continua visível.** Ouro→verde-água ainda
  ///    percorre a tela; ele é a única assinatura visual que o app tem, e
  ///    apagá-lo foi o erro mais visível da tentativa anterior. A saturação
  ///    aqui (~30%) é o teto antes de virar marrom-esverdeado nessa faixa
  ///    escura.
  /// 3. **Hierarquia clara → escura preservada.** No claro o card é o mais
  ///    CLARO da tela e o fundo é colorido; aqui o card continua sendo o mais
  ///    claro dos blocos e o fundo continua sendo o colorido, só que abaixo
  ///    dele.
  ///
  /// E o que a legibilidade exige, medido e não estimado:
  ///
  /// - [texto] ~13:1 sobre [card], [textoSuave] ~8:1, [textoFraco] ~6:1 — os
  ///   dois últimos carregam cota, prêmio e horário na tabela, então "passar
  ///   raspando" no AA ali produz uma tela cansativa. Nenhuma cor de marca
  ///   fica abaixo de 6:1 sobre [card].
  /// - A escala de superfícies foi montada em **L\* (lightness perceptual do
  ///   CIELab)**, não em razão WCAG: perto do preto a razão satura — dois tons
  ///   claramente distintos na tela dão 1.05:1, número que sugere
  ///   "idênticos". Em L\* a escala é gradiente 18 → fichário 19 → card
  ///   externo 20 → card 25 → linha ímpar 29 → campo 31 → superfície alta 38.
  ///   Use L\* para superfícies e razão WCAG para texto e borda; cada métrica
  ///   vale numa faixa.
  /// - [borda] fica ~1.9:1 contra [card]. É ela que desenha a grade da tabela
  ///   e o recorte dos cards, já que sombra praticamente não aparece no
  ///   escuro.
  ///
  /// As superfícies nunca chegam a preto absoluto: fundo #000 com conteúdo
  /// denso como este vira "buraco preto" em tela OLED, e cada card passa a
  /// parecer uma janela recortada no vazio.
  static const AppCores escuroTema = AppCores(
    // ── Superfícies ────────────────────────────────────────────────────────
    // Matiz 216°, saturação ~20%: azul-ardósia quente o bastante para
    // conversar com o ouro do gradiente. O card é o mais claro dos blocos
    // grandes de propósito — é o "papel" onde o conteúdo mora, e no escuro
    // quem sobe de luminosidade é quem se aproxima do usuário.
    //
    // Esta escala inteira é MAIS CLARA que a primeira versão (card L\* 20 →
    // 25). Ela subiu junto com o gradiente: clarear só o fundo teria
    // encostado ele no card e afundado o conteúdo. Distância entre fundo e
    // card é o que não pode encolher — os dois se movem em par.
    card: Color(0xFF333C4D),
    cardExterno: Color(0xFF28303E),
    fundoConteudoMobile: Color(0x00000000),
    campo: Color(0xFF3F4A5E),
    superficieAlta: Color(0xFF4E5A70),
    ficharioFundo: Color(0xFF262F3C),
    // ── Texto ──────────────────────────────────────────────────────────────
    // Branco levemente frio, nunca #FFF puro: branco absoluto sobre fundo
    // escuro produz halo (o texto "vaza" para fora das hastes) em telas LCD.
    texto: Color(0xFFF5F8FC),
    // ~7:1 sobre [card]. Rótulos, subtítulos e cabeçalhos de coluna.
    textoSuave: Color(0xFFC9D2DE),
    // Apesar do nome, carrega dado real (cotas, horários da lista) — o nível
    // que as versões anteriores deixavam apagado demais. Calibrado contra
    // [campo], que é a superfície mais clara onde ele aparece: sobre o card
    // sobra folga, sobre o campo fica no alvo.
    textoFraco: Color(0xFFB7BFCC),
    textoSobreCor: Color(0xFFFFFFFF),
    // Âmbar-laranja (28°), com texto quase-preto quente por cima (9.3:1).
    //
    // A escolha é por ELIMINAÇÃO, e o critério é: **nenhum tema pode repetir a
    // `acaoPrimaria` de outro**, senão dois temas diferentes acabam com o
    // mesmo botão. Ocupado hoje: 43° (cassino), 78° (papel), 186°
    // (meiaNoite), 210° (bilhete), 220° (claro), 314° (cyber). Dentro da
    // própria paleta ainda estão tomados 144°/164° (verde do dinheiro e pix,
    // que num app de pagamento não podem se confundir com o botão), 258°
    // (roxo) e 9°/352° (coral e vermelho de erro).
    //
    // 28° é o que sobra com folga em todos os lados: 15° do ouro do cassino
    // (perto, mas laranja e ouro não se confundem lado a lado), 19° do coral
    // e mais de 100° de qualquer cor fria da base.
    //
    // Também não pode ser o [azul]: nas luminosidades em que um azul se
    // destaca do card, branco por cima reprova (2.5:1), e nas que carregam
    // branco ele afunda no fundo (2.9:1 vs card). O âmbar escapa disso porque
    // é claro o bastante para carregar texto ESCURO com folga.
    //
    // Sendo a única cor quente sobre uma base inteiramente fria (204°→233°),
    // ele é o ponto mais visível da tela — que é exatamente o papel de um
    // botão que confirma dinheiro.
    acaoPrimaria: Color(0xFFF6A35A),
    textoSobreAcao: Color(0xFF1C0D02),
    // Bordas propositalmente acima do "quase invisível": são elas que
    // desenham a grade da tabela e o recorte dos cards.
    borda: Color(0xFF5C6980),
    bordaCampo: Color(0xFF6E7C96),
    bordaCampoFoco: Color(0xFF95A3BB),
    // ── Marca ──────────────────────────────────────────────────────────────
    // Cada uma guarda o MATIZ da sua correspondente no tema claro, clareada
    // até ≥6:1 sobre [card]. O verde é o mais claro do conjunto porque é a cor
    // do dinheiro — a coluna de prêmio é o dado mais consultado da tela.
    azul: Color(0xFFA2C0F8),
    verdeAgua: Color(0xFF77D9BE),
    dourado: Color(0xFFF2D07C),
    roxo: Color(0xFFC7B6EE),
    coral: Color(0xFFF3AEA2),
    verde: Color(0xFF8CE3AF),
    vermelho: Color(0xFFF5ACAC),
    // ── Blocos de estado ───────────────────────────────────────────────────
    // Fundo tingido + borda na cor: no escuro um retângulo chapado do tom
    // cheio lê como erro de renderização, mas um fundo tênue DEMAIS (foi o
    // caso na versão anterior, a 7% de mistura) some junto com o card e o
    // bloco deixa de existir. O ponto de equilíbrio está aqui: o fundo é
    // reconhecivelmente colorido e a borda fecha o recorte.
    fundoVerde: Color(0xFF2C503F),
    bordaVerde: Color(0xFF529078),
    textoVerde: Color(0xFF9BEDBE),
    fundoAmarelo: Color(0xFF50442B),
    bordaAmarelo: Color(0xFF917C47),
    textoAmarelo: Color(0xFFF3D999),
    fundoAzul: Color(0xFF2B476E),
    bordaAzul: Color(0xFF5780B4),
    textoAzul: Color(0xFFB6D0FB),
    fundoVermelho: Color(0xFF603A3C),
    bordaVermelho: Color(0xFFA36164),
    fundoRoxo: Color(0xFF4A3E75),
    bordaRoxo: Color(0xFF7E6AB8),
    textoRoxo: Color(0xFFD6C6F7),
    // ── Zebra da tabela ────────────────────────────────────────────────────
    // Diferença pequena mas perceptível entre par e ímpar: serve para o olho
    // seguir a linha na horizontal numa tabela de 5 colunas. Mais que isso
    // viraria listra e competiria com a barra de estado.
    linhaPar: Color(0xFF333C4D),
    linhaImpar: Color(0xFF3A4456),
    // Flash momentâneo de aposta nova, na cor de acento do tema — segue a
    // [acaoPrimaria] para o realce ler como "o app agiu", e não como uma
    // sexta cor solta na tabela.
    linhaNova: Color(0xFF7E5530),
    // A barra de estado substitui o fundo colorido da linha (ver o doc do
    // campo): 3px na borda esquerda, na cor do estado.
    larguraBarraEstado: 3,
    bolhaOutro: Color(0xFF434E63),
    bolhaOutroTexto: Color(0xFFF5F8FC),
    mencaoTexto: Color(0xFFD0E1FD),
    mencaoFundo: Color(0xFF4E6289),
    skeletonBase: Color(0xFF3F4A5E),
    skeletonBrilho: Color(0xFF52607A),
    // Drawer mais escuro que qualquer superfície de conteúdo: é o que o
    // mantém lendo como painel por trás da página, e não como mais um card.
    drawerFundo: Color(0xFF161B24),
    drawerBorda: Color(0xFF39445A),
    drawerTexto: Color(0xFFD3DBE6),
    sombra: Color(0xFF000000),
    // ── Gradiente de fundo ─────────────────────────────────────────────────
    // Ardósia → anil: o EIXO FRIO da própria base deste tema, não os matizes
    // ouro/verde-água da marca.
    //
    // Este é o único ponto em que o escuro padrão se afasta do tema claro, e
    // é de propósito. A versão anterior usava 43°→163° — exatamente os
    // matizes do [cassino], só que um pouco mais claros —, então os dois
    // temas tinham praticamente o MESMO fundo: alternar entre "Escuro" e
    // "Cassino" trocava os cards e deixava a moldura idêntica, o que apagava
    // a diferença entre eles. Como o Cassino existe para ser a versão
    // ouro-e-feltro do app, o ouro ficou com ele.
    //
    // O 205° do início fica na vizinhança do matiz das superfícies (o [card]
    // está em 219°), então a moldura lê como continuação do tema em vez de
    // peça colada por cima. O 232° do fim é o desvio que torna a diagonal
    // perceptível: ~27° de giro bastam para o olho ver movimento sem
    // introduzir uma cor estranha à paleta.
    //
    // **A saturação (32%) é o que separa este fundo do [meiaNoite]**, que
    // ocupa faixa de matiz parecida (248°→215°). Lá ela é 55–67% e a tela
    // inteira é azul vibrante, porque o tema é sobre isso; aqui o fundo é
    // discreto de propósito — o escuro padrão não deve ter opinião, e a única
    // cor forte da tela é o dourado do CTA.
    //
    // L\* ~18: a diagonal precisa ser VISTA. Uma versão anterior ficou em
    // L\* 8–11 "para o card flutuar" e o resultado foi um fundo que lia como
    // preto chapado. A profundidade veio de subir o card junto, não de
    // afundar o fundo.
    //
    // Continua mais escuro que o [card] — é o que faz o card FLUTUAR, já que
    // no escuro a profundidade vem da luminosidade e não da sombra. Ao mexer
    // aqui, mexa junto no [card]: os dois se movem em par, e a distância
    // entre eles é o que não pode encolher.
    gradienteFundo: [Color(0xFF1D2E39), Color(0xFF242846)],
    // Tela inteira, não só o miolo — ver [paradasGradiente].
    paradasGradiente: [0.0, 1.0],
    pix: Color(0xFF5FE2C0),
    pixFundo: Color(0xFF265046),
    escuro: true,
  );

  /// Tema único **Cassino** — feltro de mesa de jogo e metal dourado.
  ///
  /// Era o tema escuro padrão do app; virou tema único quando o escuro passou
  /// a ser a base neutra ([escuroTema]). O motivo da mudança de papel: a
  /// metáfora é forte e combina com o produto, mas um dark mode padrão não
  /// deve ter opinião — todo mundo que só quer "a tela escura" recebia junto
  /// uma decisão estética. Como tema OPCIONAL ele fica melhor: quem escolhe
  /// "Cassino" está pedindo exatamente essa personalidade.
  ///
  /// A metáfora não é decoração arbitrária: o gradiente do tema claro vai de
  /// `#FFE082` (ouro, 43°) a `#7CC8B5` (feltro, 165°), e aqui está a versão
  /// profunda dos MESMOS matizes.
  ///
  /// Toda a escala de superfícies usa o matiz 163° com saturação caindo de
  /// 20% (fundo) a 13% (mais alta) — quanto mais perto do usuário, mais
  /// neutra, senão as camadas de cima acumulam cor e a tela satura. O matiz
  /// único em toda a escala é o que torna o conflito com o [gradienteFundo]
  /// impossível por construção: superfície e fundo são literalmente a mesma
  /// cor em luminosidades diferentes.
  static const AppCores cassino = AppCores(
    card: Color(0xFF222F2C),
    cardExterno: Color(0xFF192421),
    fundoConteudoMobile: Color(0x00000000),
    campo: Color(0xFF2D3C37),
    superficieAlta: Color(0xFF374843),
    ficharioFundo: Color(0xFF101916),
    // Texto puxado levemente para o verde do feltro em vez de branco frio:
    // texto neutro sobre superfície colorida lê como "colado por cima".
    texto: Color(0xFFEBF0ED),
    textoSuave: Color(0xFFA0B1AA),
    textoFraco: Color(0xFF95A7A0),
    textoSobreCor: Color(0xFFFFFFFF),
    acaoPrimaria: Color(0xFFE5C061),
    textoSobreAcao: Color(0xFF1A1408),
    borda: Color(0xFF3B4E49),
    bordaCampo: Color(0xFF495F59),
    bordaCampoFoco: Color(0xFF5C7A72),
    // O [dourado] é a cor de acento do tema: sobre feltro ele lê como METAL,
    // e é o que dá o ar de riqueza. Por isso sua saturação (72%) é mais alta
    // que a das outras — ouro apagado vira apenas bege.
    azul: Color(0xFF749CE7),
    verdeAgua: Color(0xFF5CC1A5),
    dourado: Color(0xFFE5C061),
    roxo: Color(0xFFA789DC),
    coral: Color(0xFFE27E6F),
    verde: Color(0xFF64CE90),
    vermelho: Color(0xFFEA7B7B),
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
    linhaPar: Color(0xFF222F2C),
    linhaImpar: Color(0xFF273531),
    linhaNova: Color(0xFF4E452C),
    larguraBarraEstado: 3,
    bolhaOutro: Color(0xFF32433E),
    bolhaOutroTexto: Color(0xFFEBF0ED),
    mencaoTexto: Color(0xFFC3D6F8),
    mencaoFundo: Color(0xFF3B4A5C),
    skeletonBase: Color(0xFF2E3E39),
    skeletonBrilho: Color(0xFF3C4E49),
    drawerFundo: Color(0xFF0C1311),
    drawerBorda: Color(0xFF293834),
    drawerTexto: Color(0xFFC3D2CB),
    sombra: Color(0xFF000000),
    // Saturação (~43%) MAIS ALTA que a de qualquer superfície — é daí que vem
    // o ar de riqueza. Sem risco de brigar com os cards porque o matiz é o
    // mesmo. Mais escuro que o [card] de propósito (contraste ~1.12), para o
    // card flutuar sobre a mesa.
    gradienteFundo: [Color(0xFF2A2311), Color(0xFF0F2720)],
    paradasGradiente: [0.0, 1.0],
    pix: Color(0xFF41C8A2),
    pixFundo: Color(0xFF1D302A),
    escuro: true,
  );

  /// Tema único **Meia-noite** — azul-marinho profundo com neon ciano.
  ///
  /// A referência é app de aposta esportiva moderno: base fria muito escura
  /// (matiz 225°, saturação 30–38% — bem mais colorida que a do
  /// [escuroTema]) e um ciano elétrico como ação primária. É o tema para quem
  /// quer o escuro VIBRANTE em vez do discreto.
  ///
  /// O ciano #35D6E8 sobre o card dá ~9:1 e carrega texto quase-preto com
  /// folga — é o que permite usá-lo como CTA sem o problema que o azul de
  /// marca tinha no escuro (branco sobre ele dava 2.74:1).
  ///
  /// O violeta entra só como segunda cor de acento (seções, roxo do painel):
  /// ciano e violeta a ~60° de distância no círculo é o par que dá o ar
  /// "neon" sem virar arco-íris.
  static const AppCores meiaNoite = AppCores(
    // Escala subida em bloco (card L* 13 -> 21): na primeira versão o card
    // ficava a 2.8 pontos de L* do gradiente e praticamente não se destacava
    // do fundo. Como sempre, fundo e card se movem em par — ver o doc de
    // [escuroTema].
    card: Color(0xFF203159),
    cardExterno: Color(0xFF182749),
    fundoConteudoMobile: Color(0x00000000),
    campo: Color(0xFF2A3F6C),
    superficieAlta: Color(0xFF374D7B),
    ficharioFundo: Color(0xFF111E3F),
    texto: Color(0xFFEDF2FB),
    textoSuave: Color(0xFFBAC6DE),
    textoFraco: Color(0xFFA5B2CB),
    textoSobreCor: Color(0xFFFFFFFF),
    // Ciano elétrico com texto quase-preto por cima: é a assinatura do tema.
    acaoPrimaria: Color(0xFF35D6E8),
    textoSobreAcao: Color(0xFF04161A),
    borda: Color(0xFF324670),
    bordaCampo: Color(0xFF3F5483),
    bordaCampoFoco: Color(0xFF546CA3),
    azul: Color(0xFF69B9F6),
    verdeAgua: Color(0xFF3FD6C0),
    dourado: Color(0xFFF2C75C),
    roxo: Color(0xFFBCA5F7),
    coral: Color(0xFFF29B94),
    verde: Color(0xFF4ED8A0),
    vermelho: Color(0xFFF398A4),
    fundoVerde: Color(0xFF19423E),
    bordaVerde: Color(0xFF2A6E64),
    textoVerde: Color(0xFF5CE0AB),
    fundoAmarelo: Color(0xFF3F3C24),
    bordaAmarelo: Color(0xFF6D6337),
    textoAmarelo: Color(0xFFEFC96D),
    fundoAzul: Color(0xFF1E3B68),
    bordaAzul: Color(0xFF3664A3),
    textoAzul: Color(0xFF78C1F7),
    fundoVermelho: Color(0xFF533142),
    bordaVermelho: Color(0xFF8D5166),
    fundoRoxo: Color(0xFF393371),
    bordaRoxo: Color(0xFF6356B2),
    textoRoxo: Color(0xFFB69AF7),
    linhaPar: Color(0xFF203159),
    linhaImpar: Color(0xFF263861),
    // Ciano no flash de linha nova: é a cor de acento do tema.
    linhaNova: Color(0xFF2A5F75),
    larguraBarraEstado: 3,
    bolhaOutro: Color(0xFF2F446D),
    bolhaOutroTexto: Color(0xFFEDF2FB),
    mencaoTexto: Color(0xFFC6DEFB),
    mencaoFundo: Color(0xFF3A578F),
    skeletonBase: Color(0xFF2A3F6C),
    skeletonBrilho: Color(0xFF384F80),
    drawerFundo: Color(0xFF0B152C),
    drawerBorda: Color(0xFF243560),
    drawerTexto: Color(0xFFBFCDE6),
    sombra: Color(0xFF000000),
    // Violeta → azul-marinho: a diagonal do tema. Mais escura que o card,
    // pela mesma razão do [escuroTema] (profundidade vem da luminosidade).
    gradienteFundo: [Color(0xFF1F1750), Color(0xFF0A1B33)],
    paradasGradiente: [0.0, 1.0],
    pix: Color(0xFF3FD6C0),
    pixFundo: Color(0xFF19403C),
    escuro: true,
  );

  /// Tema único **Cyber** — quase preto com magenta e ciano.
  ///
  /// O mais chamativo do conjunto: base neutra escuríssima (matiz 260° a
  /// saturação baixa, quase carvão arroxeado) para os dois neons — magenta
  /// #F45FD0 e ciano #4FE3E3 — terem onde brilhar. Sobre base clara ou
  /// colorida esses tons vibram e cansam; é a base quase preta que os
  /// segura.
  ///
  /// O magenta é a ação primária e o ciano a cor de dado/valor. Manter os
  /// dois em papéis fixos evita o efeito "letreiro de fliperama" que aparece
  /// quando neons diferentes disputam a mesma função na tela.
  static const AppCores cyber = AppCores(
    // Escala subida em bloco (card L* 7.5 -> 20). Na primeira versão o card
    // era mais ESCURO que o gradiente e literalmente afundava no fundo. A
    // saturação da base também caiu (~22%): o matiz 260° a saturação alta,
    // quando clareado, vira lilás forte e rouba o palco dos neons — que é
    // justamente o que o tema tem de próprio.
    card: Color(0xFF352C45),
    cardExterno: Color(0xFF292238),
    fundoConteudoMobile: Color(0x00000000),
    campo: Color(0xFF423955),
    superficieAlta: Color(0xFF514667),
    ficharioFundo: Color(0xFF211A2D),
    texto: Color(0xFFF2EDF8),
    textoSuave: Color(0xFFC8C0D6),
    textoFraco: Color(0xFFB3ABC2),
    textoSobreCor: Color(0xFFFFFFFF),
    // Magenta com texto quase-preto: sobre ele, branco daria ~3:1 e reprovaria
    // AA justamente no botão que confirma dinheiro.
    acaoPrimaria: Color(0xFFF45FD0),
    textoSobreAcao: Color(0xFF1A0715),
    borda: Color(0xFF4A3F62),
    bordaCampo: Color(0xFF594C74),
    bordaCampoFoco: Color(0xFF736293),
    azul: Color(0xFF89ADFF),
    verdeAgua: Color(0xFF4FE3E3),
    dourado: Color(0xFFEFC55F),
    roxo: Color(0xFFC49CFB),
    coral: Color(0xFFF98A93),
    verde: Color(0xFF5BE0A8),
    vermelho: Color(0xFFFA8EA1),
    fundoVerde: Color(0xFF1D3F38),
    bordaVerde: Color(0xFF326A5D),
    textoVerde: Color(0xFF68E7B3),
    fundoAmarelo: Color(0xFF423826),
    bordaAmarelo: Color(0xFF6F5F3A),
    textoAmarelo: Color(0xFFEDC76B),
    fundoAzul: Color(0xFF2B3663),
    bordaAzul: Color(0xFF4B5DA2),
    textoAzul: Color(0xFF95B4FF),
    fundoVermelho: Color(0xFF532D41),
    bordaVermelho: Color(0xFF8F4B67),
    fundoRoxo: Color(0xFF412E69),
    bordaRoxo: Color(0xFF6E4FAC),
    textoRoxo: Color(0xFFC79EFB),
    linhaPar: Color(0xFF352C45),
    linhaImpar: Color(0xFF3B324D),
    // Magenta no flash: a cor de ação do tema.
    linhaNova: Color(0xFF5C2F63),
    larguraBarraEstado: 3,
    bolhaOutro: Color(0xFF473D5C),
    bolhaOutroTexto: Color(0xFFF2EDF8),
    mencaoTexto: Color(0xFFC9CFFC),
    mencaoFundo: Color(0xFF4E4A7E),
    skeletonBase: Color(0xFF423955),
    skeletonBrilho: Color(0xFF54486A),
    drawerFundo: Color(0xFF15111F),
    drawerBorda: Color(0xFF352C49),
    drawerTexto: Color(0xFFCBBFDD),
    sombra: Color(0xFF000000),
    // Magenta profundo → azul-petróleo: os dois neons do tema em versão
    // dessaturada, para a moldura insinuar o par sem competir com os cards.
    gradienteFundo: [Color(0xFF35133A), Color(0xFF0B1F2B)],
    paradasGradiente: [0.0, 1.0],
    pix: Color(0xFF4FE3E3),
    pixFundo: Color(0xFF1A3E44),
    escuro: true,
  );

  /// Tema único **Papel** — bege de caderneta e tinta marrom.
  ///
  /// Tema CLARO alternativo, e o mais confortável do conjunto para leitura
  /// longa: fundo bege-papel (matiz 40°, saturação baixa) em vez de branco
  /// puro, que sob luz forte reflete e cansa. A referência é a caderneta de
  /// bolão anotada à mão — o que este app é, digitalizado.
  ///
  /// Texto marrom-tinta em vez de preto pelo mesmo motivo do bege: o par
  /// preto-sobre-branco tem contraste maior do que o olho precisa (21:1),
  /// e reduzi-lo para ~11:1 mantém a folga sobre AA sem o "vibrar" que
  /// contraste máximo produz em texto denso como o desta tabela.
  ///
  /// Como é tema claro, [larguraBarraEstado] é 0: aqui o estado da linha volta
  /// a ser o fundo pastel, como no [claro] (ver o doc do campo).
  static const AppCores papel = AppCores(
    card: Color(0xFFFBF6EC),
    cardExterno: Color(0xFFF2EADB),
    fundoConteudoMobile: Color(0xFFFBF6EC),
    campo: Color(0xFFF0E8D8),
    superficieAlta: Color(0xFFE6DCC7),
    ficharioFundo: Color(0xFFEDE3D0),
    texto: Color(0xFF3B3226),
    textoSuave: Color(0xFF6E6252),
    textoFraco: Color(0xFF877A66),
    textoSobreCor: Color(0xFFFBF6EC),
    // Verde-oliva escuro: a tinta de carimbo da caderneta. Sobre ele, o
    // bege-papel dá 7.4:1.
    acaoPrimaria: Color(0xFF5A6B33),
    textoSobreAcao: Color(0xFFFBF6EC),
    borda: Color(0xFFDDD2BC),
    bordaCampo: Color(0xFFD2C6AC),
    bordaCampoFoco: Color(0xFFB9AA8B),
    azul: Color(0xFF3E6A8F),
    verdeAgua: Color(0xFF3F8574),
    dourado: Color(0xFFB0842A),
    roxo: Color(0xFF6E538F),
    coral: Color(0xFFBC5A46),
    verde: Color(0xFF4A6B32),
    vermelho: Color(0xFFB4432F),
    fundoVerde: Color(0xFFE6EBD3),
    bordaVerde: Color(0xFFC7D2A9),
    textoVerde: Color(0xFF44622E),
    fundoAmarelo: Color(0xFFF6E9C4),
    bordaAmarelo: Color(0xFFE0CB98),
    textoAmarelo: Color(0xFF7E5F17),
    fundoAzul: Color(0xFFE0E8EF),
    bordaAzul: Color(0xFFBCCBDA),
    textoAzul: Color(0xFF2F5A7D),
    fundoVermelho: Color(0xFFF6DFD8),
    bordaVermelho: Color(0xFFE3BFB4),
    fundoRoxo: Color(0xFFE9E3EF),
    bordaRoxo: Color(0xFFCEC1DC),
    textoRoxo: Color(0xFF5E4580),
    linhaPar: Color(0xFFFBF6EC),
    linhaImpar: Color(0xFFF4EDDF),
    linhaNova: Color(0xFFEBE0BB),
    // Tema claro: estado de linha é o fundo pastel, não barra lateral.
    larguraBarraEstado: 0,
    bolhaOutro: Color(0xFFF0E8D8),
    bolhaOutroTexto: Color(0xFF3B3226),
    // Azul de tinta esferográfica, o único frio que a caderneta admite: o
    // token precisa se separar do texto marrom sem virar outra paleta.
    mencaoTexto: Color(0xFF2F5A7D),
    mencaoFundo: Color(0xFFE2E7EE),
    skeletonBase: Color(0xFFE6DCC7),
    skeletonBrilho: Color(0xFFF2EADB),
    // Drawer marrom-escuro em vez do cinza-azulado dos outros temas: dentro de
    // uma paleta inteiramente quente, um drawer frio lê como peça de outro
    // app.
    drawerFundo: Color(0xFF33291D),
    drawerBorda: Color(0xFF4A3D2C),
    drawerTexto: Color(0xFFDDD2BC),
    sombra: Color(0xFF6B5A3E),
    gradienteFundo: [Color(0xFFF3E2B8), Color(0xFFCFD9B4)],
    paradasGradiente: [0.5, 0.9],
    pix: Color(0xFF2F7A5E),
    pixFundo: Color(0xFFE2EEE4),
    escuro: false,
  );

  /// Tema único **Bilhete** — o volante da loteria.
  ///
  /// Tema CLARO institucional, inspirado no bilhete impresso: branco-creme de
  /// papel térmico, azul e verde da Caixa como cores de seção, laranja como
  /// acento. É o mais "sério" do conjunto — quem quer o app com cara de
  /// serviço financeiro em vez de jogo.
  ///
  /// O laranja fica só como acento (chips, destaques), nunca como ação
  /// primária: laranja saturado carrega texto mal nos dois sentidos (branco
  /// por cima dá ~2.6:1, preto dá ~7:1 mas parece aviso), e um CTA de dinheiro
  /// não é lugar para essa ambiguidade. A ação primária é o azul institucional.
  static const AppCores bilhete = AppCores(
    card: Color(0xFFFFFDF8),
    cardExterno: Color(0xFFF4F1E9),
    fundoConteudoMobile: Color(0xFFFFFDF8),
    campo: Color(0xFFF1EFE7),
    superficieAlta: Color(0xFFE6E3D9),
    ficharioFundo: Color(0xFFEDEAE1),
    texto: Color(0xFF1D2B36),
    textoSuave: Color(0xFF5C6B77),
    textoFraco: Color(0xFF7C8A95),
    textoSobreCor: Color(0xFFFFFDF8),
    // Azul institucional: 6.9:1 com o creme por cima.
    acaoPrimaria: Color(0xFF12569B),
    textoSobreAcao: Color(0xFFFFFDF8),
    borda: Color(0xFFDFDCD2),
    bordaCampo: Color(0xFFD2CFC4),
    bordaCampoFoco: Color(0xFFB4B1A6),
    azul: Color(0xFF12569B),
    verdeAgua: Color(0xFF13866B),
    dourado: Color(0xFFCC7A16),
    roxo: Color(0xFF6A4CA8),
    coral: Color(0xFFD1543C),
    verde: Color(0xFF157A3C),
    vermelho: Color(0xFFC4342A),
    fundoVerde: Color(0xFFDCF0E2),
    bordaVerde: Color(0xFFB4DCC2),
    textoVerde: Color(0xFF126134),
    fundoAmarelo: Color(0xFFFCECCF),
    bordaAmarelo: Color(0xFFEFD3A0),
    textoAmarelo: Color(0xFF8A5810),
    fundoAzul: Color(0xFFDCE9F6),
    bordaAzul: Color(0xFFB2CDE8),
    textoAzul: Color(0xFF0F4A85),
    fundoVermelho: Color(0xFFF9DEDB),
    bordaVermelho: Color(0xFFEDBCB6),
    fundoRoxo: Color(0xFFE7E1F4),
    bordaRoxo: Color(0xFFC9BCE6),
    textoRoxo: Color(0xFF553B8C),
    linhaPar: Color(0xFFFFFDF8),
    linhaImpar: Color(0xFFF4F2EA),
    linhaNova: Color(0xFFCFE3F7),
    larguraBarraEstado: 0,
    bolhaOutro: Color(0xFFF1EFE7),
    bolhaOutroTexto: Color(0xFF1D2B36),
    mencaoTexto: Color(0xFF0F4A85),
    mencaoFundo: Color(0xFFDCE9F6),
    skeletonBase: Color(0xFFE6E3D9),
    skeletonBrilho: Color(0xFFF4F1E9),
    drawerFundo: Color(0xFF12283A),
    drawerBorda: Color(0xFF244057),
    drawerTexto: Color(0xFFD3DEE7),
    sombra: Color(0xFF000000),
    gradienteFundo: [Color(0xFFEFE6D2), Color(0xFFBFD8CE)],
    paradasGradiente: [0.5, 0.9],
    pix: Color(0xFF0E7A5F),
    pixFundo: Color(0xFFDDEFE9),
    escuro: false,
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
      fundoConteudoMobile: Color.lerp(
        fundoConteudoMobile,
        outro.fundoConteudoMobile,
        t,
      )!,
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
      mencaoTexto: Color.lerp(mencaoTexto, outro.mencaoTexto, t)!,
      mencaoFundo: Color.lerp(mencaoFundo, outro.mencaoFundo, t)!,
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

/// Cores de marca de terceiros.
///
/// Não são um papel de [AppCores] e não mudam com o tema (além do par
/// claro/escuro que a própria diretriz do Google define): são a identidade de
/// outra empresa, e o glifo só é reconhecido nas cores dele. Moram aqui
/// porque este é o único arquivo do app onde cor literal pode existir — não
/// porque alguma tela deva usá-las para pintar qualquer outra coisa. Ver
/// [GoogleSignInButton](../components/shared/google_sign_in_button.dart).
class AppBrandColors {
  const AppBrandColors._();

  static const Color googleBlue = Color(0xFF4285F4);
  static const Color googleRed = Color(0xFFEA4335);
  static const Color googleYellow = Color(0xFFFBBC05);
  static const Color googleGreen = Color(0xFF34A853);

  // As cores do botão "Continuar com o Google", como a diretriz do Google as
  // define. **Não seguem a paleta do app**: o botão é reconhecido pela cor
  // neutra e pelo G, e pintá-lo de dourado/azul o transformaria em mais um
  // CTA do bolão — que é justamente o que ele não pode ser.
  static const Color googleLightFill = Color(0xFFFFFFFF);
  static const Color googleLightOutline = Color(0xFF747775);
  static const Color googleLightLabel = Color(0xFF1F1F1F);

  static const Color googleDarkFill = Color(0xFF131314);
  static const Color googleDarkOutline = Color(0xFF8E918F);
  static const Color googleDarkLabel = Color(0xFFE3E3E3);
}
