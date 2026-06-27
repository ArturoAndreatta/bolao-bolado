import 'package:bolao_bolado/components/shell/default_layout.dart';
import 'package:bolao_bolado/components/shared/back_screen_button.dart';
import 'package:bolao_bolado/components/shared/custom_card.dart';
import 'package:bolao_bolado/components/shell/drawer.dart';
import 'package:bolao_bolado/components/shared/header_paginas.dart';
import 'package:bolao_bolado/models/bet.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class Participants extends StatefulWidget {
  const Participants({super.key});

  @override
  State<Participants> createState() => _ParticipantsState();
}

class _ParticipantsState extends State<Participants> {
  List<Map<String, dynamic>> _rowsData = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final dataBets = await getBets();
    setState(() {
      _rowsData = dataBets;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultLayout(
      drawer: AppDrawer(),
      child: Stack(
        children: [
          CustomCard(
            color: const Color(0xFFF3F1EF),
            children: [
              HeaderPaginas(text: 'Participantes'),
              CustomCard(
                isChild: true,
                children: [
                  const SizedBox(height: 20),
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
                    _TabelaApostas(rows: _rowsData),
                  const SizedBox(height: 20),
                ],
              ),
            ],
          ),
          BackScreenButton(),
        ],
      ),
    );
  }
}

class _TabelaApostas extends StatelessWidget {
  final List<Map<String, dynamic>> rows;

  const _TabelaApostas({required this.rows});

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
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabeçalho
              Container(
                color: _corCabecalho,
                child: Row(
                  children: const [
                    _CelulaCabecalho(
                      texto: 'Nome',
                      flex: 3,
                      alinhamento: TextAlign.left,
                    ),
                    _CelulaCabecalho(
                      texto: 'Valor',
                      flex: 2,
                      alinhamento: TextAlign.right,
                    ),
                    _CelulaCabecalho(
                      texto: 'Cotas',
                      flex: 1,
                      alinhamento: TextAlign.right,
                    ),
                    _CelulaCabecalho(
                      texto: 'Prêmio',
                      flex: 2,
                      alinhamento: TextAlign.right,
                    ),
                    _CelulaCabecalho(
                      texto: 'Última Alteração',
                      flex: 3,
                      alinhamento: TextAlign.right,
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
                        children: [
                          _CelulaLinha(
                            texto: nome,
                            flex: 3,
                            alinhamento: TextAlign.left,
                          ),
                          _CelulaLinha(
                            texto: formatoMoeda.format(valor),
                            flex: 2,
                            alinhamento: TextAlign.right,
                          ),
                          _CelulaLinha(
                            texto: cotas.toString(),
                            flex: 1,
                            alinhamento: TextAlign.right,
                          ),
                          _CelulaLinha(
                            texto: formatoMoeda.format(premio),
                            flex: 2,
                            alinhamento: TextAlign.right,
                            destaque: true,
                          ),
                          _CelulaLinha(
                            texto: dataFormatada,
                            flex: 3,
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
      ),
    );
  }
}

class _CelulaCabecalho extends StatelessWidget {
  final String texto;
  final int flex;
  final TextAlign alinhamento;
  final bool isLast;

  const _CelulaCabecalho({
    required this.texto,
    required this.flex,
    required this.alinhamento,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Flexible(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: isLast
            ? null
            : const BoxDecoration(
                border: Border(
                  right: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                ),
              ),
        width: _larguraPorFlex(flex),
        child: Text(
          texto,
          textAlign: alinhamento,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
      ),
    );
  }

  double _larguraPorFlex(int flex) {
    switch (flex) {
      case 1:
        return 60;
      case 2:
        return 110;
      case 3:
        return 150;
      default:
        return 100;
    }
  }
}

class _CelulaLinha extends StatelessWidget {
  final String texto;
  final int flex;
  final TextAlign alinhamento;
  final bool destaque;
  final bool subTexto;
  final bool isLast;

  const _CelulaLinha({
    required this.texto,
    required this.flex,
    required this.alinhamento,
    this.destaque = false,
    this.subTexto = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Flexible(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: isLast
            ? null
            : const BoxDecoration(
                border: Border(
                  right: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                ),
              ),
        width: _larguraPorFlex(flex),
        child: Text(
          texto,
          textAlign: alinhamento,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: destaque ? FontWeight.w600 : FontWeight.w400,
            color: destaque
                ? const Color(0xFF2E7D32)
                : subTexto
                ? Colors.grey
                : const Color(0xFF1F2937),
          ),
        ),
      ),
    );
  }

  double _larguraPorFlex(int flex) {
    switch (flex) {
      case 1:
        return 60;
      case 2:
        return 110;
      case 3:
        return 150;
      default:
        return 100;
    }
  }
}
