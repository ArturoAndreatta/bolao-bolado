import 'package:bolao_bolado/components/shared/header_paginas.dart';
import 'package:bolao_bolado/components/shell/default_layout.dart';
import 'package:bolao_bolado/components/shared/back_screen_button.dart';
import 'package:bolao_bolado/components/shared/custom_card.dart';
import 'package:bolao_bolado/components/shell/drawer.dart';
import 'package:bolao_bolado/core/responsive.dart';
import 'package:bolao_bolado/models/bet.dart';
import 'package:bolao_bolado/pages/cadastrar_sala/cadastrar_sala_router.dart';
import 'package:bolao_bolado/pages/pages.dart';
import 'package:bolao_bolado/services/authentication/auth_service.dart';
import 'package:bolao_bolado/widgets/chat_sala.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ╔══════════════════════════════════════════════════════════════════════╗
// ║ TODO REMOVER: bloco inteiro de apostadores fake para teste visual.     ║
// ║ Basta apagar esta lista (e a linha que a referencia em `_load()`)      ║
// ║ para voltar a exibir somente os dados reais do Firestore.              ║
// ╚══════════════════════════════════════════════════════════════════════╝
final List<Map<String, dynamic>> _apostadoresFake = List.generate(15, (i) {
  final nomes = [
    'Carlos Silva',
    'Fernanda Costa',
    'João Pereira',
    'Mariana Alves',
    'Rafael Souza',
    'Juliana Lima',
    'Bruno Rocha',
    'Camila Dias',
    'Eduardo Nunes',
    'Patrícia Gomes',
    'Lucas Martins',
    'Aline Ferreira',
    'Diego Barbosa',
    'Vanessa Ribeiro',
    'Thiago Cardoso',
  ];
  final cotas = (i % 5) + 1;
  final valor = cotas * 6.0;
  return {
    'nome': nomes[i % nomes.length],
    'valor': valor,
    'cotas': cotas,
    'premio': cotas * 1500,
    'data-hora': Timestamp.now(),
    'uid': 'fake-$i',
    'verificado': i % 3 == 0,
  };
});

class Participants extends StatefulWidget {
  const Participants({super.key});

  @override
  State<Participants> createState() => _ParticipantsState();
}

class _ParticipantsState extends State<Participants> {
  List<Map<String, dynamic>> _rowsData = [];
  bool _loading = true;
  String? _salaId;
  bool _isAdmin = false;
  String? _sorteio;
  DateTime? _dataSorteio;
  double _premioSala = 0;
  String _busca = '';
  final FocusNode _buscaFocusNode = FocusNode();

  // Ordenação padrão: valor decrescente
  int _colunaOrdenada = 1; // 0=nome, 1=valor, 2=cotas, 3=premio, 4=data
  bool _ascendente = false;

  // Aba ativa no mobile: 0 = Participantes, 1 = Chat
  int _abaAtiva = 0;

  @override
  void initState() {
    super.initState();
    _load();
    HardwareKeyboard.instance.addHandler(_onKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKeyEvent);
    _buscaFocusNode.dispose();
    super.dispose();
  }

  bool _onKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.keyF &&
        HardwareKeyboard.instance.isControlPressed) {
      _buscaFocusNode.requestFocus();
      return true;
    }
    return false;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final salaId = await buscarSalaPrincipalId();
    final dataBets = await getBets();
    final user = FirebaseAuth.instance.currentUser;
    final isAdmin = user != null && !user.isAnonymous
        ? await AuthService().isAdmin(user.uid)
        : false;
    final salaDoc = await FirebaseFirestore.instance
        .collection('Salas')
        .doc(salaId)
        .get();
    final sorteio = salaDoc.data()?['sorteio']?.toString();
    final dataSorteio = (salaDoc.data()?['dataHora'] as Timestamp?)?.toDate();
    final premioSala = (salaDoc.data()?['premio'] as num?)?.toDouble() ?? 0;
    setState(() {
      _salaId = salaId;
      _rowsData = [
        ...dataBets,
        ..._apostadoresFake, // TODO REMOVER: apostadores fake para teste visual
      ];
      _isAdmin = isAdmin;
      _sorteio = sorteio;
      _dataSorteio = dataSorteio;
      _premioSala = premioSala;
      _ordenar();
      _loading = false;
    });
  }

  void _ordenar() {
    _rowsData.sort((a, b) {
      dynamic va;
      dynamic vb;

      switch (_colunaOrdenada) {
        case 0:
          va = (a['nome'] ?? '').toString().toLowerCase();
          vb = (b['nome'] ?? '').toString().toLowerCase();
          break;
        case 1:
          va = (a['valor'] as num?)?.toDouble() ?? 0;
          vb = (b['valor'] as num?)?.toDouble() ?? 0;
          break;
        case 2:
          va = (a['cotas'] as num?)?.toInt() ?? 0;
          vb = (b['cotas'] as num?)?.toInt() ?? 0;
          break;
        case 3:
          va = (a['premio'] as num?)?.toDouble() ?? 0;
          vb = (b['premio'] as num?)?.toDouble() ?? 0;
          break;
        case 4:
          final ta = a['data-hora'];
          final tb = b['data-hora'];
          va = ta is Timestamp ? ta.millisecondsSinceEpoch : 0;
          vb = tb is Timestamp ? tb.millisecondsSinceEpoch : 0;
          break;
        default:
          return 0;
      }

      final cmp = va is String
          ? va.compareTo(vb)
          : (va as num).compareTo(vb as num);
      return _ascendente ? cmp : -cmp;
    });
  }

  void _onCabecalhoTap(int coluna) {
    setState(() {
      if (_colunaOrdenada == coluna) {
        _ascendente = !_ascendente;
      } else {
        _colunaOrdenada = coluna;
        _ascendente = false;
      }
      _ordenar();
    });
  }

  Widget _textoSelecionavel({
    required BuildContext context,
    required Widget child,
  }) {
    final habilitarSelecao = kIsWeb || Responsive.isDesktop(context);
    return habilitarSelecao ? SelectionArea(child: child) : child;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return DefaultLayout(
      drawer: AppDrawer(),
      child: isMobile ? _layoutMobile(currentUid) : _layoutDesktop(currentUid),
    );
  }

  // ── Layout Desktop: card de participantes + chat lateral ────────────────
  Widget _layoutDesktop(String? currentUid) {
    const double chatHeight = 640;

    return CustomCard(
      color: const Color(0xFFF3F1EF),
      maxWidth: 1112,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: BackScreenButton(
                floating: false,
                onTap: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    Navigator.of(context).pushReplacement(
                      PageRouteBuilder(
                        transitionDuration: Duration.zero,
                        reverseTransitionDuration: Duration.zero,
                        pageBuilder: (_, _, _) => Pages(),
                      ),
                    );
                  }
                },
              ),
            ),
            Expanded(
              child: HeaderPaginas(
                text: 'Participantes',
                subtitle: 'Visualize quem está participando',
                trailing: _isAdmin ? _botaoEditarSala() : null,
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
          child: SizedBox(
            height: chatHeight,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 7,
                    child: _cardParticipantes(
                      currentUid,
                      expandirConteudo: true,
                      mostrarCabecalho: false,
                    ),
                  ),
                  if (_salaId != null) const SizedBox(width: 16),
                  if (_salaId != null)
                    Expanded(flex: 3, child: ChatSala(salaId: _salaId!)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _layoutMobile(String? currentUid) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: _SeletorAbas(
            abaAtiva: _abaAtiva,
            onSelecionar: (i) => setState(() => _abaAtiva = i),
          ),
        ),
        if (_abaAtiva == 0)
          _cardParticipantesMobile(currentUid)
        else if (_salaId != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.62,
              child: ChatSala(salaId: _salaId!),
            ),
          ),
      ],
    );
  }

  Widget _cardParticipantesMobile(String? currentUid) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: CircularProgressIndicator(
          strokeWidth: 5,
          color: Color(0xFF7CC8B5),
        ),
      );
    }

    final termo = _busca.trim().toLowerCase();
    final linhasFiltradas = termo.isEmpty
        ? _rowsData
        : _rowsData
              .where(
                (item) => (item['nome'] ?? '')
                    .toString()
                    .toLowerCase()
                    .contains(termo),
              )
              .toList();

    return CustomCard(
      color: const Color(0xFFF3F1EF),
      children: [
        HeaderPaginas(
          text: 'Participantes',
          subtitle: 'Visualize quem está participando',
          trailing: _isAdmin ? _botaoEditarSala() : null,
        ),
        const SizedBox(height: 12),
        _PainelEstatisticas(
          rows: _rowsData,
          currentUid: currentUid,
          sorteio: _sorteio,
          dataSorteio: _dataSorteio,
          premioSala: _premioSala,
        ),
        const SizedBox(height: 14),
        _BarraBuscaOrdenacao(
          busca: _busca,
          onBuscaChanged: (v) => setState(() => _busca = v),
          colunaOrdenada: _colunaOrdenada,
          ascendente: _ascendente,
          onOrdenarPor: _onCabecalhoTap,
        ),
        const SizedBox(height: 12),
        linhasFiltradas.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.sentiment_dissatisfied_outlined,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _rowsData.isEmpty
                          ? 'Nenhuma aposta ainda.'
                          : 'Nenhum participante encontrado.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              )
            : _ListaParticipantes(
                rows: linhasFiltradas,
                currentUid: currentUid,
              ),
        const SizedBox(height: 14),
        _RodapeLista(total: linhasFiltradas.length),
      ],
    );
  }

  Widget _botaoEditarSala() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: IconButton(
        tooltip: 'Editar sala',
        icon: const Icon(Icons.edit_outlined, color: Color(0xFF487DE5)),
        onPressed: _salaId == null
            ? null
            : () {
                Navigator.of(context).push(
                  PageRouteBuilder(
                    transitionDuration: Duration.zero,
                    reverseTransitionDuration: Duration.zero,
                    pageBuilder: (_, _, _) => CadastrarSala(salaId: _salaId),
                  ),
                );
              },
      ),
    );
  }

  Widget _cardParticipantes(
    String? currentUid, {
    bool expandirConteudo = false,
    bool mostrarCabecalho = true,
  }) {
    final termo = _busca.trim().toLowerCase();
    final linhasFiltradas = termo.isEmpty
        ? _rowsData
        : _rowsData
              .where(
                (item) => (item['nome'] ?? '')
                    .toString()
                    .toLowerCase()
                    .contains(termo),
              )
              .toList();

    final conteudo = _loading
        ? const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: CircularProgressIndicator(
              strokeWidth: 5,
              color: Color(0xFF7CC8B5),
            ),
          )
        : _TabelaApostas(
            rows: linhasFiltradas,
            colunaOrdenada: _colunaOrdenada,
            ascendente: _ascendente,
            onCabecalhoTap: _onCabecalhoTap,
            currentUid: currentUid,
            alturaFixa: expandirConteudo,
            mensagemVazio: linhasFiltradas.isEmpty
                ? _textoSelecionavel(
                    context: context,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.sentiment_dissatisfied_outlined,
                          size: 48,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Nenhuma aposta ainda.',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : null,
          );

    final painelEstatisticas = _loading
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _PainelEstatisticas(
              rows: _rowsData,
              currentUid: currentUid,
              sorteio: _sorteio,
              premioSala: _premioSala,
            ),
          );

    if (!expandirConteudo) {
      return CustomCard(
        color: const Color(0xFFF3F1EF),
        children: [
          if (mostrarCabecalho)
            HeaderPaginas(
              text: 'Participantes',
              subtitle: 'Visualize quem está participando',
              trailing: _isAdmin ? _botaoEditarSala() : null,
            ),
          painelEstatisticas,
          SelectionArea(child: conteudo),
        ],
      );
    }

    return Material(
      color: const Color(0xFFFEFEFE),
      elevation: 20,
      shadowColor: Colors.black,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            painelEstatisticas,
            _CampoBusca(
              busca: _busca,
              onBuscaChanged: (v) => setState(() => _busca = v),
              focusNode: _buscaFocusNode,
            ),
            const SizedBox(height: 12),
            Expanded(child: SelectionArea(child: conteudo)),
          ],
        ),
      ),
    );
  }
}

class _SeletorAbas extends StatelessWidget {
  final int abaAtiva;
  final void Function(int) onSelecionar;

  const _SeletorAbas({required this.abaAtiva, required this.onSelecionar});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE9EAEC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _aba(context, 'Participantes', Icons.people_outline, 0),
          _aba(context, 'Chat', Icons.chat_bubble_outline, 1),
        ],
      ),
    );
  }

  Widget _aba(BuildContext context, String texto, IconData icon, int indice) {
    final ativa = abaAtiva == indice;
    return Expanded(
      child: GestureDetector(
        onTap: () => onSelecionar(indice),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: ativa ? const Color(0xFFFEFEFE) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: ativa
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: ativa ? const Color(0xFF487DE5) : Colors.grey.shade500,
              ),
              const SizedBox(width: 6),
              Text(
                texto,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: ativa ? const Color(0xFF487DE5) : Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Probabilidade de acertar as 6 dezenas da Mega-Sena com um único jogo (1 em 50.063.860).
const double _probabilidadeMega = 1 / 50063860;

/// Probabilidade de acertar as 15 dezenas da Lotofácil com um único jogo (1 em 3.268.760).
const double _probabilidadeLotofacil = 1 / 3268760;

class _PainelEstatisticas extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final String? currentUid;
  final String? sorteio;
  final DateTime? dataSorteio;
  final double premioSala;

  const _PainelEstatisticas({
    required this.rows,
    required this.currentUid,
    this.sorteio,
    this.dataSorteio,
    this.premioSala = 0,
  });

  @override
  Widget build(BuildContext context) {
    final formatoMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    final totalCotas = rows.fold<int>(
      0,
      (soma, item) => soma + ((item['cotas'] as num?)?.toInt() ?? 0),
    );
    Map<String, dynamic>? meuRegistro;
    for (final item in rows) {
      if (item['uid'] == currentUid) {
        meuRegistro = item;
        break;
      }
    }
    final minhasCotas = (meuRegistro?['cotas'] as num?)?.toInt() ?? 0;

    final probabilidadeJogo = sorteio == 'lotofacil'
        ? _probabilidadeLotofacil
        : _probabilidadeMega;

    // Cada cota representa um jogo apostado no bolão, então a chance
    // individual é o número de cotas do usuário vezes a probabilidade
    // de acerto de um único jogo no tipo de sorteio da sala.
    final chance = minhasCotas > 0 ? minhasCotas * probabilidadeJogo : 0.0;
    final chancePercentual = chance == 0
        ? '0'
        : chance.toStringAsFixed(chance < 0.001 ? 8 : 3);
    final chanceFracao = chance > 0
        ? '1 em ${NumberFormat.decimalPattern('pt_BR').format((1 / chance).round())}'
        : '0 em 0';

    final isMobile = Responsive.isMobile(context);

    if (isMobile) {
      final diasRestantes = dataSorteio?.difference(DateTime.now()).inDays;
      final dataFormatada = dataSorteio != null
          ? DateFormat('dd/MM/yyyy').format(dataSorteio!)
          : '—';

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BannerChance(percentual: chancePercentual, fracao: chanceFracao),
          const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _CardEstatisticaIcone(
                    icone: Icons.savings_outlined,
                    corIcone: const Color(0xFF2E7D32),
                    corFundoIcone: const Color(0xFFE3F3E9),
                    titulo: 'Prêmio Total',
                    valor: formatoMoeda.format(premioSala),
                    corValor: const Color(0xFF2E7D32),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CardEstatisticaIcone(
                    icone: Icons.local_activity_outlined,
                    corIcone: const Color(0xFFCB8A2C),
                    corFundoIcone: const Color(0xFFFBEED9),
                    titulo: 'Cotas',
                    valor: totalCotas.toString(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _CardEstatisticaIcone(
                    icone: Icons.people_alt_outlined,
                    corIcone: const Color(0xFF487DE5),
                    corFundoIcone: const Color(0xFFE1E9FB),
                    titulo: 'Jogadores',
                    valor: rows.length.toString(),
                    corValor: const Color(0xFF487DE5),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CardEstatisticaIcone(
                    icone: Icons.calendar_month_outlined,
                    corIcone: const Color(0xFF7C5CD9),
                    corFundoIcone: const Color(0xFFEAE3F8),
                    titulo: 'Data do Sorteio',
                    valor: dataFormatada,
                    rodape: diasRestantes != null && diasRestantes >= 0
                        ? 'Em $diasRestantes dias'
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final cardChance = _CardEstatistica(
      destaque: true,
      icone: Icons.emoji_events_outlined,
      titulo: 'Chance de ganhar',
      valor: '$chancePercentual%',
      fontSizeValor: 26,
      infoTooltip: 'Sua chance é calculada com base no total de cotas.',
      valorWidget: _ChanceFracaoReveal(
        percentual: chancePercentual,
        fracao: chanceFracao,
        percentualStyle: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1F2937),
        ),
        fracaoStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade600,
        ),
      ),
    );
    final cardCotas = _CardEstatistica(
      titulo: 'Cotas',
      fontSizeValor: 30,
      valor: totalCotas.toString(),
    );
    final cardPremio = _CardEstatistica(
      titulo: 'Prêmio Total',
      fontSizeValor: 19,
      valor: formatoMoeda.format(premioSala),
      corValor: const Color(0xFF2E7D32),
    );
    final cardJogadores = _CardEstatistica(
      titulo: 'Jogadores',
      valor: rows.length.toString(),
      fontSizeValor: 30,
      corValor: const Color(0xFF487DE5),
    );

    final cards = [cardChance, cardPremio, cardCotas, cardJogadores];
    const flexes = [2, 2, 1, 1];

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            Expanded(flex: flexes[i], child: cards[i]),
            if (i != cards.length - 1) const SizedBox(width: 12),
          ],
        ],
      ),
    );
  }
}

class _ChanceFracaoReveal extends StatefulWidget {
  final String percentual;
  final String fracao;
  final TextStyle percentualStyle;
  final TextStyle fracaoStyle;

  const _ChanceFracaoReveal({
    required this.percentual,
    required this.fracao,
    required this.percentualStyle,
    required this.fracaoStyle,
  });

  @override
  State<_ChanceFracaoReveal> createState() => _ChanceFracaoRevealState();
}

class _ChanceFracaoRevealState extends State<_ChanceFracaoReveal> {
  bool _revelado = false;

  void _toggle() => setState(() => _revelado = !_revelado);

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _revelado = true),
      onExit: (_) => setState(() => _revelado = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _toggle,
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('${widget.percentual}%', style: widget.percentualStyle),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: _revelado
                  ? Padding(
                      key: const ValueKey('fracao'),
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(widget.fracao, style: widget.fracaoStyle),
                    )
                  : const SizedBox.shrink(key: ValueKey('vazio')),
            ),
          ],
        ),
      ),
    );
  }
}

class _BannerChance extends StatelessWidget {
  final String percentual;
  final String fracao;

  const _BannerChance({required this.percentual, required this.fracao});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF4E3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF2D9A8), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFFBEED9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.emoji_events_outlined,
              size: 22,
              color: Color(0xFFCB8A2C),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Chance de ganhar',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF8A6116),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Tooltip(
                      message:
                          'Sua chance é calculada com base no total de cotas.',
                      child: Icon(
                        Icons.info_outline,
                        size: 13,
                        color: const Color(0xFF8A6116).withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _ChanceFracaoReveal(
                  percentual: percentual,
                  fracao: fracao,
                  percentualStyle: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2937),
                  ),
                  fracaoStyle: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
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

class _CardEstatisticaIcone extends StatelessWidget {
  final IconData icone;
  final Color corIcone;
  final Color corFundoIcone;
  final String titulo;
  final String valor;
  final Color? corValor;
  final String? rodape;

  const _CardEstatisticaIcone({
    required this.icone,
    required this.corIcone,
    required this.corFundoIcone,
    required this.titulo,
    required this.valor,
    this.corValor,
    this.rodape,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEFEFE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: corFundoIcone,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icone, size: 18, color: corIcone),
          ),
          const SizedBox(height: 10),
          Text(
            titulo,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            valor,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: corValor ?? const Color(0xFF1F2937),
            ),
          ),
          if (rodape != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFEAE3F8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                rodape!,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF7C5CD9),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CardEstatistica extends StatelessWidget {
  final String titulo;
  final String valor;
  final bool destaque;
  final IconData? icone;
  final Color? corValor;
  final String? infoTooltip;
  final double fontSizeValor;
  final Widget? valorWidget;

  const _CardEstatistica({
    required this.titulo,
    required this.valor,
    this.destaque = false,
    this.icone,
    this.corValor,
    this.infoTooltip,
    this.fontSizeValor = 24,
    this.valorWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: destaque ? const Color(0xFFFDF4E3) : const Color(0xFFFEFEFE),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: destaque ? const Color(0xFFF2D9A8) : const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icone != null) ...[
                Icon(icone, size: 18, color: const Color(0xFFCB8A2C)),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  titulo,
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: destaque
                        ? const Color(0xFF8A6116)
                        : Colors.grey.shade600,
                  ),
                ),
              ),
              if (infoTooltip != null) ...[
                const SizedBox(width: 4),
                Tooltip(
                  message: infoTooltip!,
                  child: Icon(
                    Icons.info_outline,
                    size: 15,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          valorWidget ??
              Text(
                valor,
                softWrap: true,
                style: TextStyle(
                  fontSize: fontSizeValor,
                  fontWeight: FontWeight.w700,
                  color: corValor ?? const Color(0xFF1F2937),
                ),
              ),
        ],
      ),
    );
  }
}

// Larguras fixas de cada coluna
const double _wNome = 205;
const double _wValor = 110;
const double _wCotas = 80;
const double _wPremio = 140;
const double _wData = 155;
const double _larguraTotal = _wNome + _wValor + _wCotas + _wPremio + _wData;

class _TabelaApostas extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final int colunaOrdenada;
  final bool ascendente;
  final void Function(int) onCabecalhoTap;
  final String? currentUid;
  final Widget? mensagemVazio;
  final bool alturaFixa;

  const _TabelaApostas({
    required this.rows,
    required this.colunaOrdenada,
    required this.ascendente,
    required this.onCabecalhoTap,
    required this.currentUid,
    this.mensagemVazio,
    this.alturaFixa = false,
  });

  static const _corLinhaA = Color(0xFFFEFEFE);
  static const _corLinhaB = Color(0xFFF3F4F6);
  static const _corLinhaVerificada = Color(0xFFDCFCE7);
  static const _corBorda = Color(0xFFE5E7EB);
  static const _corCabecalho = Color(0xFFE9EAEC);

  @override
  Widget build(BuildContext context) {
    final formatoMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        constraints: const BoxConstraints(minWidth: _larguraTotal),
        decoration: BoxDecoration(
          border: Border.all(color: _corBorda, width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: alturaFixa ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CabecalhoTabela(
              colunaOrdenada: colunaOrdenada,
              ascendente: ascendente,
              onCabecalhoTap: onCabecalhoTap,
            ),
            const Divider(height: 1, thickness: 1, color: _corBorda),
            if (alturaFixa)
              Expanded(
                child: Stack(
                  children: [
                    SingleChildScrollView(child: _corpoTabela(formatoMoeda)),
                    if (mensagemVazio != null)
                      Positioned.fill(child: Center(child: mensagemVazio!)),
                  ],
                ),
              )
            else
              Stack(
                children: [
                  _corpoTabela(formatoMoeda),
                  if (mensagemVazio != null)
                    Positioned.fill(child: Center(child: mensagemVazio!)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _corpoTabela(NumberFormat formatoMoeda) {
    return SelectionArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...rows.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isPar = index % 2 == 0;
            final isUsuarioLogado = item['uid'] == currentUid;
            final isVerificado = item['verificado'] == true;

            final nome = item['nome']?.toString() ?? '—';
            final valor = (item['valor'] as num?)?.toDouble() ?? 0;
            final cotas = (item['cotas'] as num?)?.toInt() ?? 0;
            final premio = (item['premio'] as num?)?.toDouble() ?? 0;
            final dataHora = item['data-hora'];

            String dataFormatada = '—';
            if (dataHora != null && dataHora is Timestamp) {
              dataFormatada = DateFormat(
                'dd/MM/yy HH:mm',
              ).format(dataHora.toDate());
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  color: isVerificado
                      ? _corLinhaVerificada
                      : (isPar ? _corLinhaA : _corLinhaB),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _CelulaLinha(
                        texto: nome,
                        width: _wNome,
                        alinhamento: TextAlign.left,
                        negrito: isUsuarioLogado,
                      ),
                      _CelulaLinha(
                        texto: formatoMoeda.format(valor),
                        width: _wValor,
                        alinhamento: TextAlign.right,
                      ),
                      _CelulaLinha(
                        texto: cotas.toString(),
                        width: _wCotas,
                        alinhamento: TextAlign.right,
                      ),
                      _CelulaLinha(
                        texto: formatoMoeda.format(premio),
                        width: _wPremio,
                        alinhamento: TextAlign.right,
                        destaque: true,
                      ),
                      _CelulaLinha(
                        texto: dataFormatada,
                        width: _wData,
                        alinhamento: TextAlign.right,
                        subTexto: true,
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                if (index < rows.length - 1)
                  const Divider(height: 1, thickness: 1, color: _corBorda),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _CabecalhoTabela extends StatelessWidget {
  final int colunaOrdenada;
  final bool ascendente;
  final void Function(int) onCabecalhoTap;

  const _CabecalhoTabela({
    required this.colunaOrdenada,
    required this.ascendente,
    required this.onCabecalhoTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _TabelaApostas._corCabecalho,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CelulaCabecalho(
            texto: 'Nome',
            width: _wNome,
            alinhamento: TextAlign.left,
            indice: 0,
            colunaOrdenada: colunaOrdenada,
            ascendente: ascendente,
            onTap: onCabecalhoTap,
          ),
          _CelulaCabecalho(
            texto: 'Valor',
            width: _wValor,
            alinhamento: TextAlign.right,
            indice: 1,
            colunaOrdenada: colunaOrdenada,
            ascendente: ascendente,
            onTap: onCabecalhoTap,
          ),
          _CelulaCabecalho(
            texto: 'Cotas',
            width: _wCotas,
            alinhamento: TextAlign.right,
            indice: 2,
            colunaOrdenada: colunaOrdenada,
            ascendente: ascendente,
            onTap: onCabecalhoTap,
          ),
          _CelulaCabecalho(
            texto: 'Prêmio',
            width: _wPremio,
            alinhamento: TextAlign.right,
            indice: 3,
            colunaOrdenada: colunaOrdenada,
            ascendente: ascendente,
            onTap: onCabecalhoTap,
          ),
          _CelulaCabecalho(
            texto: 'Última Alteração',
            width: _wData,
            alinhamento: TextAlign.right,
            indice: 4,
            colunaOrdenada: colunaOrdenada,
            ascendente: ascendente,
            onTap: onCabecalhoTap,
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _CelulaCabecalho extends StatelessWidget {
  final String texto;
  final double width;
  final TextAlign alinhamento;
  final int indice;
  final int colunaOrdenada;
  final bool ascendente;
  final void Function(int) onTap;
  final bool isLast;

  const _CelulaCabecalho({
    required this.texto,
    required this.width,
    required this.alinhamento,
    required this.indice,
    required this.colunaOrdenada,
    required this.ascendente,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final ativa = colunaOrdenada == indice;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onTap(indice),
        child: Container(
          width: width,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: isLast
              ? null
              : const BoxDecoration(
                  border: Border(
                    right: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                  ),
                ),
          child: Row(
            mainAxisAlignment: alinhamento == TextAlign.right
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              if (alinhamento == TextAlign.right && ativa) ...[
                Icon(
                  ascendente ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 12,
                  color: const Color(0xFF487DE5),
                ),
                const SizedBox(width: 4),
              ],
              Text(
                texto,
                textAlign: alinhamento,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: ativa
                      ? const Color(0xFF487DE5)
                      : const Color(0xFF1F2937),
                ),
              ),
              if (alinhamento == TextAlign.left && ativa) ...[
                const SizedBox(width: 4),
                Icon(
                  ascendente ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 12,
                  color: const Color(0xFF487DE5),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CelulaLinha extends StatelessWidget {
  final String texto;
  final double width;
  final TextAlign alinhamento;
  final bool destaque;
  final bool subTexto;
  final bool isLast;
  final bool negrito;

  const _CelulaLinha({
    required this.texto,
    required this.width,
    required this.alinhamento,
    this.destaque = false,
    this.subTexto = false,
    this.isLast = false,
    this.negrito = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: isLast
          ? null
          : const BoxDecoration(
              border: Border(
                right: BorderSide(color: Color(0xFFE5E7EB), width: 1),
              ),
            ),
      child: Text(
        texto,
        textAlign: alinhamento,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          fontWeight: destaque
              ? FontWeight.w600
              : negrito
              ? FontWeight.w700
              : FontWeight.w400,
          color: destaque
              ? const Color(0xFF2E7D32)
              : subTexto
              ? Colors.grey
              : const Color(0xFF1F2937),
        ),
      ),
    );
  }
}

class _CampoBusca extends StatefulWidget {
  final String busca;
  final void Function(String) onBuscaChanged;
  final FocusNode? focusNode;

  const _CampoBusca({
    required this.busca,
    required this.onBuscaChanged,
    this.focusNode,
  });

  @override
  State<_CampoBusca> createState() => _CampoBuscaState();
}

class _CampoBuscaState extends State<_CampoBusca> {
  FocusNode? _focusNode;
  bool _focado = false;

  FocusNode get _effectiveFocusNode => widget.focusNode ?? _focusNode!;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode == null) _focusNode = FocusNode();
    _effectiveFocusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant _CampoBusca oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode?.removeListener(_onFocusChange);
      _focusNode?.removeListener(_onFocusChange);
      if (widget.focusNode == null) _focusNode ??= FocusNode();
      _effectiveFocusNode.addListener(_onFocusChange);
    }
  }

  void _onFocusChange() {
    setState(() => _focado = _effectiveFocusNode.hasFocus);
  }

  @override
  void dispose() {
    _effectiveFocusNode.removeListener(_onFocusChange);
    _focusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEFEFE),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _focado ? const Color(0xFF487DE5) : const Color(0xFFE5E7EB),
          width: _focado ? 1.5 : 1,
        ),
        boxShadow: _focado
            ? [
                BoxShadow(
                  color: const Color(0xFF487DE5).withValues(alpha: 0.15),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Icon(
            Icons.search,
            size: 18,
            color: _focado ? const Color(0xFF487DE5) : Colors.grey.shade500,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Focus(
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.escape) {
                  _effectiveFocusNode.unfocus();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: TextField(
                focusNode: _effectiveFocusNode,
                onChanged: widget.onBuscaChanged,
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: 'Buscar participante...',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarraBuscaOrdenacao extends StatelessWidget {
  final String busca;
  final void Function(String) onBuscaChanged;
  final int colunaOrdenada;
  final bool ascendente;
  final void Function(int) onOrdenarPor;

  const _BarraBuscaOrdenacao({
    required this.busca,
    required this.onBuscaChanged,
    required this.colunaOrdenada,
    required this.ascendente,
    required this.onOrdenarPor,
  });

  static const Map<int, String> _opcoes = {
    1: 'Valor',
    0: 'Nome',
    2: 'Cotas',
    3: 'Prêmio',
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEFEFE),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
            ),
            child: Row(
              children: [
                Icon(Icons.search, size: 18, color: Colors.grey.shade500),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    onChanged: onBuscaChanged,
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: 'Buscar participante...',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<int>(
          onSelected: onOrdenarPor,
          offset: const Offset(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          itemBuilder: (context) => _opcoes.entries
              .map(
                (e) => PopupMenuItem<int>(value: e.key, child: Text(e.value)),
              )
              .toList(),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEFEFE),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  ascendente ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 15,
                  color: const Color(0xFF487DE5),
                ),
                const SizedBox(width: 6),
                Text(
                  _opcoes[colunaOrdenada] ?? 'Valor',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF487DE5),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFFEFEFE),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
          ),
          child: Icon(Icons.tune, size: 18, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

const List<Color> _coresAvatar = [
  Color(0xFF2E7D32),
  Color(0xFF487DE5),
  Color(0xFF7C5CD9),
  Color(0xFFCB8A2C),
  Color(0xFFD9534F),
  Color(0xFF17A398),
];

Color _corAvatarPara(String nome) {
  final soma = nome.codeUnits.fold<int>(0, (acc, c) => acc + c);
  return _coresAvatar[soma % _coresAvatar.length];
}

class _ListaParticipantes extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final String? currentUid;

  const _ListaParticipantes({required this.rows, required this.currentUid});

  @override
  Widget build(BuildContext context) {
    final formatoMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          _LinhaParticipante(
            posicao: i + 1,
            nome: rows[i]['nome']?.toString() ?? '—',
            valor: formatoMoeda.format(
              (rows[i]['valor'] as num?)?.toDouble() ?? 0,
            ),
            cotas: (rows[i]['cotas'] as num?)?.toInt() ?? 0,
            destacado: rows[i]['uid'] == currentUid,
          ),
          if (i < rows.length - 1)
            Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
        ],
      ],
    );
  }
}

class _LinhaParticipante extends StatelessWidget {
  final int posicao;
  final String nome;
  final String valor;
  final int cotas;
  final bool destacado;

  const _LinhaParticipante({
    required this.posicao,
    required this.nome,
    required this.valor,
    required this.cotas,
    required this.destacado,
  });

  @override
  Widget build(BuildContext context) {
    final inicial = nome.trim().isNotEmpty ? nome.trim()[0].toUpperCase() : '?';
    final cor = _corAvatarPara(nome);

    return Container(
      color: destacado ? const Color(0xFFDCFCE7) : Colors.transparent,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            child: Text(
              posicao.toString(),
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          ),
          const SizedBox(width: 6),
          CircleAvatar(
            radius: 16,
            backgroundColor: cor,
            child: Text(
              inicial,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              nome,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: destacado ? FontWeight.w700 : FontWeight.w600,
                color: const Color(0xFF1F2937),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                valor,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                cotas == 1 ? '1 cota' : '$cotas cotas',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RodapeLista extends StatelessWidget {
  final int total;

  const _RodapeLista({required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(Icons.people_outline, size: 15, color: Colors.grey.shade500),
            const SizedBox(width: 6),
            Text(
              'Mostrando $total participantes',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
        Row(
          children: [
            Text(
              'Atualizado agora',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
            const SizedBox(width: 6),
            Icon(Icons.refresh, size: 15, color: Colors.grey.shade500),
          ],
        ),
      ],
    );
  }
}
