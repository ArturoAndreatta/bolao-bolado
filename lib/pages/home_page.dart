import 'dart:async';
import 'dart:math';

import 'package:bolao_bolado/components/formatters/formatters.dart';
import 'package:bolao_bolado/components/shared/branding/logo.dart';
import 'package:bolao_bolado/components/shared/buttons.dart';
import 'package:bolao_bolado/components/shared/constants/phrases.dart';
import 'package:bolao_bolado/components/shared/custom_card.dart';
import 'package:bolao_bolado/components/shared/numero_rolante.dart';
import 'package:bolao_bolado/components/shared/skeletons.dart';
import 'package:bolao_bolado/components/shell/default_layout.dart';
import 'package:bolao_bolado/components/shell/drawer.dart';
import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/core/app_radii.dart';
import 'package:bolao_bolado/router/app_router.dart';
import 'package:bolao_bolado/services/authentication/auth_service.dart';
import 'package:bolao_bolado/services/bet/bet_service.dart';
import 'package:bolao_bolado/services/bet/preco_cota.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Largura do conteúdo a partir da qual a tela vira duas colunas (apresentação
/// à esquerda, bolão da vez e botões à direita). Abaixo disso tudo empilha.
const double _kLarguraDuasColunas = 760;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with RouteAware {
  static const _fraseInterval = Duration(seconds: 5);

  late String frase;
  Timer? _fraseTimer;
  final AuthService _authService = AuthService();

  // Assinadas no estado, e não com StreamBuilder: as duas streams aceitam um
  // ouvinte só, e qualquer coisa que recriasse o StreamBuilder — o bloco do
  // bolão trocando de lugar quando a largura cruza a das duas colunas, o
  // layout do celular remontando o conteúdo — fazia ele assinar de novo e
  // estourar "Stream has already been listened to", pintando um bloco cinza
  // no lugar do bolão.
  //
  // `streamBets()` é a MESMA stream compartilhada da tela de Participantes:
  // assinar aqui não abre listener a mais, e de quebra adianta a leitura para
  // quem toca em Só dar uma olhada logo em seguida.
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subSala;
  StreamSubscription<List<Map<String, Object?>>>? _subApostas;
  Map<String, dynamic>? _dadosSala;
  List<Map<String, Object?>>? _apostas;
  bool _erroSala = false;

  @override
  void initState() {
    super.initState();
    _sortearFrase();
    _subSala = streamSalaPrincipal().listen(
      (doc) {
        if (mounted) setState(() => _dadosSala = doc.data());
      },
      onError: (Object _) {
        if (mounted) setState(() => _erroSala = true);
      },
    );
    _subApostas = streamBets().listen(
      (linhas) {
        if (mounted) setState(() => _apostas = linhas);
      },
      // Sem as apostas o bloco continua de pé, só sem a contagem.
      onError: (Object _) {},
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _stopTimer();
    unawaited(_subSala?.cancel());
    unawaited(_subApostas?.cancel());
    super.dispose();
  }

  @override
  void didPush() => _startTimer();

  @override
  void didPopNext() => _startTimer();

  @override
  void didPushNext() => _stopTimer();

  @override
  void didPop() => _stopTimer();

  // Timer só roda enquanto a HomePage está visível (ver RouteAware abaixo),
  // evitando setState em segundo plano quando outra tela está no topo da pilha.
  void _startTimer() {
    _stopTimer();
    _fraseTimer = Timer.periodic(_fraseInterval, (_) => _sortearFrase());
  }

  void _stopTimer() {
    _fraseTimer?.cancel();
    _fraseTimer = null;
  }

  void _sortearFrase() {
    final random = Random();
    final novaFrase = phrases[random.nextInt(phrases.length)];
    if (!mounted) return;
    setState(() => frase = novaFrase);
  }

  @override
  Widget build(BuildContext context) {
    final logado = _authService.isLoggedIn;

    return DefaultLayout(
      drawer: AppDrawer(),
      showLogo: false,
      child: _conteudo(
        logado: logado,
        bolao: _BolaoDaVez(
          dadosSala: _dadosSala,
          erroSala: _erroSala,
          apostas: _apostas,
        ),
      ),
    );
  }

  Widget _conteudo({required bool logado, required Widget bolao}) {
    final apresentacao = _Apresentacao(frase: frase);
    final botoes = _Botoes(logado: logado);

    return CustomCard(
      maxWidth: 960,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final largo = constraints.maxWidth >= _kLarguraDuasColunas;
            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: largo ? 18 : 6,
                vertical: largo ? 14 : 6,
              ),
              child: Column(
                children: [
                  if (largo)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(flex: 5, child: apresentacao),
                        const SizedBox(width: 28),
                        Expanded(
                          flex: 6,
                          child: Column(
                            children: [
                              bolao,
                              const SizedBox(height: 18),
                              botoes,
                            ],
                          ),
                        ),
                      ],
                    )
                  else ...[
                    apresentacao,
                    const SizedBox(height: 16),
                    bolao,
                    const SizedBox(height: 18),
                    botoes,
                  ],
                  SizedBox(height: largo ? 26 : 22),
                  _ComoFunciona(horizontal: largo),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Logo, boas-vindas e a frase que troca a cada 5s.
class _Apresentacao extends StatelessWidget {
  final String frase;

  const _Apresentacao({required this.frase});

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    final compacto = MediaQuery.sizeOf(context).width < 600;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Logo(isSmall: compacto),
        const SizedBox(height: 12),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(
                text: 'Bem-vindo',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              TextSpan(
                text: ' ao Bolão Bolado!',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: cores.textoSuave,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: compacto ? 21 : 24, color: cores.texto),
        ),
        const SizedBox(height: 6),
        // Altura reservada para duas linhas: as frases têm tamanhos bem
        // diferentes, e sem isto cada troca empurrava o bolão e os botões
        // para cima e para baixo a cada 5 segundos.
        SizedBox(
          height: compacto ? 48 : 56,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Text(
                frase,
                key: ValueKey(frase),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compacto ? 16 : 18,
                  height: 1.3,
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                  color: cores.textoSuave,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Resumo ao vivo da sala principal: prêmio, sorteio e participantes.
///
/// É o que faz a tela inicial dizer alguma coisa sobre o bolão antes de a
/// pessoa decidir entrar — antes ela era só logo, frase e dois botões.
class _BolaoDaVez extends StatelessWidget {
  /// Null enquanto a sala não chegou.
  final Map<String, dynamic>? dadosSala;
  final bool erroSala;

  /// Null enquanto as apostas não chegaram.
  final List<Map<String, Object?>>? apostas;

  const _BolaoDaVez({
    required this.dadosSala,
    required this.erroSala,
    required this.apostas,
  });

  @override
  Widget build(BuildContext context) {
    // Erro na leitura (sem rede, regra recusando): a tela inicial não pode
    // travar num skeleton eterno por causa de um resumo. Some com o bloco
    // inteiro; os botões continuam levando ao bolão.
    if (erroSala) return const SizedBox.shrink();

    final cores = AppCores.de(context);
    final dados = dadosSala;
    final linhas = apostas;
    final totalCotas = linhas?.fold<int>(
      0,
      (soma, item) => soma + ((item['cotas'] as num?)?.toInt() ?? 0),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: cores.campo,
        borderRadius: AppRadii.circularLg,
        border: Border.all(color: cores.borda),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _CabecalhoBolao(
            nomeSorteio: dados == null
                ? null
                : _nomeSorteio(dados['sorteio']?.toString()),
          ),
          const SizedBox(height: 10),
          if (dados == null)
            const _SkeletonBolao()
          else
            _IndicadoresBolao(
              premio: (dados['premio'] as num?)?.toDouble() ?? 0,
              dataSorteio: (dados['dataHora'] as Timestamp?)?.toDate(),
              participantes: linhas?.length,
              cotas: totalCotas,
            ),
        ],
      ),
    );
  }

  static String _nomeSorteio(String? sorteio) {
    if (isLotofacil(sorteio)) return 'Lotofácil';
    if (sorteio == 'mega') return 'Mega-Sena';
    return 'Sorteio';
  }
}

class _CabecalhoBolao extends StatelessWidget {
  final String? nomeSorteio;

  const _CabecalhoBolao({required this.nomeSorteio});

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);

    return Row(
      children: [
        Icon(Icons.local_activity_outlined, size: 18, color: cores.dourado),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Bolão da vez',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: cores.texto,
            ),
          ),
        ),
        if (nomeSorteio != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: cores.fundoRoxo,
              borderRadius: AppRadii.circularPill,
              border: Border.all(color: cores.bordaRoxo),
            ),
            child: Text(
              nomeSorteio!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: cores.textoRoxo,
              ),
            ),
          ),
      ],
    );
  }
}

/// Os três números do bolão, nos mesmos pares de cor de estado dos cards de
/// estatística de Participantes (verde = prêmio, azul = sorteio, amarelo =
/// participação), para a tela inicial falar a mesma língua visual.
class _IndicadoresBolao extends StatelessWidget {
  final double premio;
  final DateTime? dataSorteio;

  /// Null enquanto as apostas ainda não chegaram.
  final int? participantes;
  final int? cotas;

  const _IndicadoresBolao({
    required this.premio,
    required this.dataSorteio,
    required this.participantes,
    required this.cotas,
  });

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);

    final tilePremio = _Tile(
      cor: _CorTile.verde,
      rotulo: 'Prêmio',
      icone: Icons.emoji_events_outlined,
      valor: NumeroRolante(
        texto: Formatters.moeda.format(premio),
        valor: premio,
        estilo: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: cores.texto,
        ),
      ),
    );

    final tileSorteio = _Tile(
      cor: _CorTile.azul,
      rotulo: 'Sorteio',
      icone: Icons.event_outlined,
      valor: _ValorTexto(
        dataSorteio == null ? 'A definir' : _dataCurta(dataSorteio!),
      ),
      detalhe: dataSorteio == null ? null : _quantoFalta(dataSorteio!),
    );

    final tileParticipantes = _Tile(
      cor: _CorTile.amarelo,
      rotulo: 'Participantes',
      icone: Icons.groups_outlined,
      valor: participantes == null
          ? const SkeletonBox(width: 40, height: 20)
          : _ValorTexto('$participantes'),
      detalhe: cotas == null ? null : '$cotas ${cotas == 1 ? 'cota' : 'cotas'}',
    );

    // Prêmio ocupa a linha de cima inteira: é o número que as pessoas abrem
    // o app para ver, e o único que precisa de largura (R$ com milhões).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        tilePremio,
        const SizedBox(height: 8),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: tileSorteio),
              const SizedBox(width: 8),
              Expanded(child: tileParticipantes),
            ],
          ),
        ),
      ],
    );
  }

  static const _diasSemana = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];

  static String _dataCurta(DateTime data) =>
      '${_diasSemana[data.weekday - 1]}, ${Formatters.data.format(data).substring(0, 5)}'
      ' às ${Formatters.horaCurta.format(data)}';

  /// Contagem regressiva em linguagem de gente. Recalculada a cada rebuild,
  /// e a troca de frase já reconstrói a tela a cada 5s — não precisa de timer
  /// próprio para ficar em dia.
  static String _quantoFalta(DateTime data) {
    final falta = data.difference(DateTime.now());
    if (falta.isNegative) return 'Sorteio realizado';
    if (falta.inDays >= 2) return 'Faltam ${falta.inDays} dias';
    if (falta.inDays == 1) return 'Falta 1 dia';
    if (falta.inHours >= 1) {
      return 'Faltam ${falta.inHours}h${(falta.inMinutes % 60).toString().padLeft(2, '0')}';
    }
    return 'Faltam ${max(falta.inMinutes, 1)} min';
  }
}

enum _CorTile { verde, azul, amarelo }

class _Tile extends StatelessWidget {
  final _CorTile cor;
  final String rotulo;
  final IconData icone;
  final Widget valor;
  final String? detalhe;

  /// Substitui o texto de [detalhe] por um widget — é o que o skeleton usa
  /// para reservar a linha de detalhe com um bloco em vez de texto. Sem ela,
  /// o tile nasceria mais baixo e cresceria quando o dado chegasse.
  final Widget? detalheWidget;

  const _Tile({
    required this.cor,
    required this.rotulo,
    required this.icone,
    required this.valor,
    this.detalhe,
    this.detalheWidget,
  });

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    final (fundo, borda, texto) = switch (cor) {
      _CorTile.verde => (cores.fundoVerde, cores.bordaVerde, cores.textoVerde),
      _CorTile.azul => (cores.fundoAzul, cores.bordaAzul, cores.textoAzul),
      _CorTile.amarelo => (
        cores.fundoAmarelo,
        cores.bordaAmarelo,
        cores.textoAmarelo,
      ),
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: AppRadii.circularSmd,
        border: Border.all(color: borda),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icone, size: 15, color: texto),
              const SizedBox(width: 5),
              Text(
                rotulo,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: texto,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: valor,
          ),
          if (detalheWidget != null) ...[
            const SizedBox(height: 2),
            detalheWidget!,
          ] else if (detalhe != null) ...[
            const SizedBox(height: 2),
            Text(
              detalhe!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: cores.textoSuave,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ValorTexto extends StatelessWidget {
  final String texto;

  const _ValorTexto(this.texto);

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      maxLines: 1,
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: AppCores.de(context).texto,
      ),
    );
  }
}

/// Placeholder dos indicadores do bolão na tela inicial.
///
/// São os TILES REAIS (mesma cor, ícone e rótulo de [_IndicadoresBolao]) com
/// um bloco no lugar do número: o rótulo "Prêmio" não depende de dado nenhum,
/// e o que está carregando é só a quantia. Com blocos cinza maciços no lugar
/// dos três, a tela trocava de cor e de altura ao mesmo tempo.
class _SkeletonBolao extends StatelessWidget {
  const _SkeletonBolao();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Tile(
            cor: _CorTile.verde,
            rotulo: 'Prêmio',
            icone: Icons.emoji_events_outlined,
            valor: SkeletonBox(width: 186, height: 24),
          ),
          const SizedBox(height: 8),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: const [
                Expanded(
                  child: _Tile(
                    cor: _CorTile.azul,
                    rotulo: 'Sorteio',
                    icone: Icons.event_outlined,
                    valor: SkeletonBox(width: 124, height: 17),
                    detalheWidget: SkeletonBox(width: 78, height: 12),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _Tile(
                    cor: _CorTile.amarelo,
                    rotulo: 'Participantes',
                    icone: Icons.groups_outlined,
                    valor: SkeletonBox(width: 40, height: 17),
                    detalheWidget: SkeletonBox(width: 60, height: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Botoes extends StatelessWidget {
  final bool logado;

  const _Botoes({required this.logado});

  @override
  Widget build(BuildContext context) {
    // Logado, os dois botões levavam à mesma tela (Minha Aposta e Visualizar
    // abriam Participantes): sobra um só, e ele diz o que a pessoa vai achar.
    if (logado) {
      return PrimaryButton(
        text: 'Minha aposta',
        width: double.infinity,
        onTap: () => context.go(AppRoutes.participants),
      );
    }

    final entrar = PrimaryButton(
      text: 'Entrar e apostar',
      width: double.infinity,
      onTap: () => context.go(AppRoutes.signup),
    );
    final ver = SecondaryButton(
      text: 'Só dar uma olhada',
      width: double.infinity,
      onTap: () => context.go(AppRoutes.participants),
    );

    return Column(children: [entrar, const SizedBox(height: 12), ver]);
  }
}

/// Os três passos do bolão, para quem chegou por um link e não sabe como
/// isso funciona.
class _ComoFunciona extends StatelessWidget {
  final bool horizontal;

  const _ComoFunciona({required this.horizontal});

  static const _passos = [
    (
      Icons.person_add_alt_1_outlined,
      'Crie sua conta',
      'Com e-mail ou com a conta Google, em poucos segundos.',
    ),
    (
      Icons.pix,
      'Aposte e pague no PIX',
      'Escolha quantas cotas quer e, se quiser, os seus números.',
    ),
    (
      Icons.forum_outlined,
      'Acompanhe com a galera',
      'Veja o rateio do prêmio ao vivo e converse no chat da sala.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    final itens = [
      for (var i = 0; i < _passos.length; i++)
        _Passo(
          numero: i + 1,
          icone: _passos[i].$1,
          titulo: _passos[i].$2,
          descricao: _passos[i].$3,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: cores.borda)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Como funciona',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: cores.textoFraco,
                ),
              ),
            ),
            Expanded(child: Divider(color: cores.borda)),
          ],
        ),
        const SizedBox(height: 14),
        if (horizontal)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < itens.length; i++) ...[
                  Expanded(child: itens[i]),
                  if (i != itens.length - 1) const SizedBox(width: 12),
                ],
              ],
            ),
          )
        else
          for (var i = 0; i < itens.length; i++) ...[
            itens[i],
            if (i != itens.length - 1) const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _Passo extends StatelessWidget {
  final int numero;
  final IconData icone;
  final String titulo;
  final String descricao;

  const _Passo({
    required this.numero,
    required this.icone,
    required this.titulo,
    required this.descricao,
  });

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cores.campo,
        borderRadius: AppRadii.circularMd,
        border: Border.all(color: cores.borda),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Disco na cor de ação do tema com o par de contraste dela — o
          // mesmo acerto de cor do botão principal, então vale nos 7 temas.
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: cores.acaoPrimaria,
              shape: BoxShape.circle,
            ),
            child: Icon(icone, size: 19, color: cores.textoSobreAcao),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$numero. $titulo',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: cores.texto,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  descricao,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: cores.textoSuave,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
