import 'package:bolao_bolado/components/shared/custom_card.dart';
import 'package:bolao_bolado/components/shared/header_paginas.dart';
import 'package:bolao_bolado/core/responsive.dart';
import 'package:bolao_bolado/pages/participants/participants_busca.dart';
import 'package:bolao_bolado/pages/participants/participants_estatisticas.dart';
import 'package:bolao_bolado/pages/participants/participants_lista.dart';
import 'package:bolao_bolado/pages/participants/participants_skeletons.dart';
import 'package:bolao_bolado/pages/participants/participants_tabela.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Painel de participantes (estatísticas + busca + tabela/lista).
///
/// Mantém o estado de busca/ordenação isolado do restante da página,
/// para que digitar no filtro não force o rebuild do chat lateral.
class PainelParticipantes extends StatefulWidget {
  final String? currentUid;
  final bool loading;
  final List<Map<String, dynamic>> rowsData;
  final bool isAdmin;
  final String? sorteio;
  final DateTime? dataSorteio;
  final double premioSala;
  final Widget Function() onEditarSala;
  final VoidCallback? onSimularApostas;
  final bool mobile;
  final bool expandirConteudo;
  final bool mostrarCabecalho;

  const PainelParticipantes({
    super.key,
    required this.currentUid,
    required this.loading,
    required this.rowsData,
    required this.isAdmin,
    required this.sorteio,
    required this.dataSorteio,
    required this.premioSala,
    required this.onEditarSala,
    this.onSimularApostas,
    required this.mobile,
    this.expandirConteudo = false,
    this.mostrarCabecalho = true,
  });

  @override
  State<PainelParticipantes> createState() => _PainelParticipantesState();
}

class _PainelParticipantesState extends State<PainelParticipantes> {
  String _busca = '';
  final FocusNode _buscaFocusNode = FocusNode();

  // Ordenação padrão: valor decrescente
  int _colunaOrdenada = 1; // 0=nome, 1=valor, 2=cotas, 3=premio, 4=data
  bool _ascendente = false;

  @override
  void initState() {
    super.initState();
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

  void _ordenar(List<Map<String, dynamic>> rows) {
    rows.sort((a, b) {
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
    });
  }

  Widget _textoSelecionavel({
    required BuildContext context,
    required Widget child,
  }) {
    final habilitarSelecao = kIsWeb || Responsive.isDesktop(context);
    return habilitarSelecao ? SelectionArea(child: child) : child;
  }

  List<Map<String, dynamic>> _linhasFiltradas() {
    final termo = _busca.trim().toLowerCase();
    final rows = termo.isEmpty
        ? List<Map<String, dynamic>>.from(widget.rowsData)
        : widget.rowsData
              .where(
                (item) => (item['nome'] ?? '')
                    .toString()
                    .toLowerCase()
                    .contains(termo),
              )
              .toList();
    _ordenar(rows);
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return widget.mobile ? _buildMobile(context) : _buildDesktop(context);
  }

  Widget _buildMobile(BuildContext context) {
    if (widget.loading) {
      return CustomCard(
        color: const Color(0xFFF3F1EF),
        children: const [SkeletonParticipantes(mobile: true)],
      );
    }

    final linhasFiltradas = _linhasFiltradas();

    return CustomCard(
      color: const Color(0xFFF3F1EF),
      children: [
        HeaderPaginas(
          text: 'Participantes',
          subtitle: 'Visualize quem está participando',
          showBackButton: false,
          trailing: widget.isAdmin
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.onSimularApostas != null)
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: IconButton(
                          tooltip: 'Simular apostas',
                          icon: const Icon(
                            Icons.groups_2_outlined,
                            color: Color(0xFF7C5CD9),
                          ),
                          onPressed: widget.onSimularApostas,
                        ),
                      ),
                    widget.onEditarSala(),
                  ],
                )
              : null,
        ),
        const SizedBox(height: 12),
        PainelEstatisticas(
          rows: widget.rowsData,
          currentUid: widget.currentUid,
          sorteio: widget.sorteio,
          dataSorteio: widget.dataSorteio,
          premioSala: widget.premioSala,
        ),
        const SizedBox(height: 14),
        BarraBuscaOrdenacao(
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
                      widget.rowsData.isEmpty
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
            : ListaParticipantes(
                rows: linhasFiltradas,
                currentUid: widget.currentUid,
              ),
        const SizedBox(height: 14),
        RodapeLista(total: linhasFiltradas.length),
      ],
    );
  }

  Widget _buildDesktop(BuildContext context) {
    final linhasFiltradas = _linhasFiltradas();

    final conteudo = widget.loading
        ? const SkeletonTabela()
        : TabelaApostas(
            rows: linhasFiltradas,
            colunaOrdenada: _colunaOrdenada,
            ascendente: _ascendente,
            onCabecalhoTap: _onCabecalhoTap,
            currentUid: widget.currentUid,
            alturaFixa: widget.expandirConteudo,
            mensagemVazio: linhasFiltradas.isEmpty
                ? _textoSelecionavel(
                    context: context,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.sentiment_dissatisfied_outlined,
                          size: 48,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.rowsData.isEmpty
                              ? 'Nenhuma aposta ainda.'
                              : 'Nenhum participante encontrado.',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : null,
          );

    final painelEstatisticas = widget.loading
        ? const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: SkeletonEstatisticasDesktop(),
          )
        : Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PainelEstatisticas(
              rows: widget.rowsData,
              currentUid: widget.currentUid,
              sorteio: widget.sorteio,
              premioSala: widget.premioSala,
            ),
          );

    if (!widget.expandirConteudo) {
      return CustomCard(
        color: const Color(0xFFF3F1EF),
        children: [
          if (widget.mostrarCabecalho)
            HeaderPaginas(
              text: 'Participantes',
              subtitle: 'Visualize quem está participando',
              showBackButton: false,
              trailing: widget.isAdmin ? widget.onEditarSala() : null,
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
            CampoBusca(
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

class SeletorAbas extends StatelessWidget {
  final int abaAtiva;
  final void Function(int) onSelecionar;

  const SeletorAbas({
    super.key,
    required this.abaAtiva,
    required this.onSelecionar,
  });

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
