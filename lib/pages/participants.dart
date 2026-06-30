import 'package:bolao_bolado/components/shell/default_layout.dart';
import 'package:bolao_bolado/components/shared/back_screen_button.dart';
import 'package:bolao_bolado/components/shared/custom_card.dart';
import 'package:bolao_bolado/components/shell/drawer.dart';
import 'package:bolao_bolado/components/shared/header_paginas.dart';
import 'package:bolao_bolado/core/responsive.dart';
import 'package:bolao_bolado/models/bet.dart';
import 'package:bolao_bolado/pages/pages.dart';
import 'package:bolao_bolado/widgets/chat_sala.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Participants extends StatefulWidget {
  const Participants({super.key});

  @override
  State<Participants> createState() => _ParticipantsState();
}

class _ParticipantsState extends State<Participants> {
  List<Map<String, dynamic>> _rowsData = [];
  bool _loading = true;
  String? _salaId;

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
    setState(() {
      _salaId = salaId;
      _rowsData = dataBets;
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

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktopWeb = kIsWeb && width >= 900;
    final isMobile = Responsive.isMobile(context);
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return DefaultLayout(
      drawer: AppDrawer(),
      child: Stack(
        children: [
          isMobile ? _layoutMobile(currentUid) : _layoutDesktop(currentUid),
          if (!isMobile)
            Positioned(
              top: 10,
              left: isDesktopWeb ? 500 : 250,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(30),
                  onTap: () {
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        transitionDuration: Duration.zero,
                        reverseTransitionDuration: Duration.zero,
                        pageBuilder: (_, _, _) => Pages(),
                      ),
                    );
                  },
                  child: Container(padding: const EdgeInsets.all(20)),
                ),
              ),
            ),
          BackScreenButton(),
        ],
      ),
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
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _cardParticipantes(currentUid)),
              const SizedBox(width: 16),
              if (_salaId != null)
                SizedBox(
                  width: chatWidth,
                  child: ChatSala(salaId: _salaId!, height: chatHeight),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Layout Mobile: abas Participantes / Chat ─────────────────────────────
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
          CustomCard(
            color: const Color(0xFFF3F1EF),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
                child: ChatSala(
                  salaId: _salaId!,
                  height: MediaQuery.of(context).size.height * 0.62,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _cardParticipantes(String? currentUid) {
    return CustomCard(
      color: const Color(0xFFF3F1EF),
      children: [
        HeaderPaginas(text: 'Participantes'),
        CustomCard(
          isChild: true,
          children: [
            const SizedBox(height: 10),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: CircularProgressIndicator(
                  strokeWidth: 5,
                  color: Color(0xFF7CC8B5),
                ),
              )
            else if (_rowsData.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
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
            else
              _TabelaApostas(
                rows: _rowsData,
                colunaOrdenada: _colunaOrdenada,
                ascendente: _ascendente,
                onCabecalhoTap: _onCabecalhoTap,
                currentUid: currentUid,
              ),
            const SizedBox(height: 10),
          ],
        ),
      ],
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

// Larguras fixas de cada coluna
const double _wNome = 210;
const double _wValor = 110;
const double _wCotas = 80;
const double _wPremio = 120;
const double _wData = 140;

class _TabelaApostas extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final int colunaOrdenada;
  final bool ascendente;
  final void Function(int) onCabecalhoTap;
  final String? currentUid;

  const _TabelaApostas({
    required this.rows,
    required this.colunaOrdenada,
    required this.ascendente,
    required this.onCabecalhoTap,
    required this.currentUid,
  });

  static const _corLinhaA = Color(0xFFFEFEFE);
  static const _corLinhaB = Color(0xFFF3F4F6);
  static const _corBorda = Color(0xFFE5E7EB);
  static const _corCabecalho = Color(0xFFE9EAEC);

  @override
  Widget build(BuildContext context) {
    final formatoMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: _corBorda, width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho
            Container(
              color: _corCabecalho,
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
            ),
            const Divider(height: 1, thickness: 1, color: _corBorda),
            // Linhas
            ...rows.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isPar = index % 2 == 0;
              final isUsuarioLogado = item['uid'] == currentUid;

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
                    color: isPar ? _corLinhaA : _corLinhaB,
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
