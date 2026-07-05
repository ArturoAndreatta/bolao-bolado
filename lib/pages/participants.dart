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

  // Ordenação padrão: valor decrescente
  int _colunaOrdenada = 1; // 0=nome, 1=valor, 2=cotas, 3=premio, 4=data
  bool _ascendente = false;

  // Aba ativa no mobile: 0 = Participantes, 1 = Chat
  int _abaAtiva = 0;

  @override
  void initState() {
    super.initState();
    _load();
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
    setState(() {
      _salaId = salaId;
      _rowsData = [
        ...dataBets,
        ..._apostadoresFake, // TODO REMOVER: apostadores fake para teste visual
      ];
      _isAdmin = isAdmin;
      _sorteio = sorteio;
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
    const double chatWidth = 320;
    const double chatHeight = 520;

    return CustomCard(
      color: const Color(0xFFF3F1EF),
      maxWidth: 1080,
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
                    child: _cardParticipantes(
                      currentUid,
                      expandirConteudo: true,
                      mostrarCabecalho: false,
                    ),
                  ),
                  if (_salaId != null) const SizedBox(width: 16),
                  if (_salaId != null)
                    SizedBox(
                      width: chatWidth,
                      child: ChatSala(salaId: _salaId!),
                    ),
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
        CustomCard(
          color: const Color(0xFFF3F1EF),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
              child: _SeletorAbas(
                abaAtiva: _abaAtiva,
                onSelecionar: (i) => setState(() => _abaAtiva = i),
              ),
            ),
          ],
        ),
        if (_abaAtiva == 0)
          _cardParticipantes(currentUid)
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
    final conteudo = _loading
        ? const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: CircularProgressIndicator(
              strokeWidth: 5,
              color: Color(0xFF7CC8B5),
            ),
          )
        : _TabelaApostas(
            rows: _rowsData,
            colunaOrdenada: _colunaOrdenada,
            ascendente: _ascendente,
            onCabecalhoTap: _onCabecalhoTap,
            currentUid: currentUid,
            alturaFixa: expandirConteudo,
            mensagemVazio: _rowsData.isEmpty
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

  const _PainelEstatisticas({
    required this.rows,
    required this.currentUid,
    this.sorteio,
  });

  @override
  Widget build(BuildContext context) {
    final formatoMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    final totalCotas = rows.fold<int>(
      0,
      (soma, item) => soma + ((item['cotas'] as num?)?.toInt() ?? 0),
    );
    final totalPremio = rows.fold<double>(
      0,
      (soma, item) => soma + ((item['premio'] as num?)?.toDouble() ?? 0),
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

    final cardChance = _CardEstatistica(
      destaque: true,
      icone: Icons.emoji_events_outlined,
      titulo: 'Chance de ganhar',
      valor: '$chancePercentual%\n$chanceFracao',
      valorPequeno: true,
      infoTooltip: 'Sua chance é calculada com base no total de cotas.',
    );
    final cardCotas = _CardEstatistica(
      titulo: 'Cotas',
      valor: totalCotas.toString(),
    );
    final cardPremio = _CardEstatistica(
      titulo: 'Total do Prêmio',
      valor: formatoMoeda.format(totalPremio),
      corValor: const Color(0xFF2E7D32),
    );
    final cardJogadores = _CardEstatistica(
      titulo: 'Jogadores',
      valor: rows.length.toString(),
      corValor: const Color(0xFF487DE5),
    );

    final cards = [cardChance, cardPremio, cardCotas, cardJogadores];
    const flexes = [2, 2, 1, 1];

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final card in cards) ...[
            card,
            if (card != cards.last) const SizedBox(height: 10),
          ],
        ],
      );
    }

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

class _CardEstatistica extends StatelessWidget {
  final String titulo;
  final String valor;
  final bool destaque;
  final bool valorPequeno;
  final IconData? icone;
  final Color? corValor;
  final String? infoTooltip;

  const _CardEstatistica({
    required this.titulo,
    required this.valor,
    this.destaque = false,
    this.valorPequeno = false,
    this.icone,
    this.corValor,
    this.infoTooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                Icon(icone, size: 16, color: const Color(0xFFCB8A2C)),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  titulo,
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 12,
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
                    size: 13,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            valor,
            softWrap: true,
            style: TextStyle(
              fontSize: valorPequeno ? 13 : 20,
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
const double _wPremio = 125;
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
