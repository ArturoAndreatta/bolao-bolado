import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Campo de busca usado no desktop (sem seletor de ordenação, que fica no
// cabeçalho clicável da tabela) e reaproveitado dentro de BarraBuscaOrdenacao
// (mobile), que só adiciona o seletor de ordenação ao lado.
class CampoBusca extends StatefulWidget {
  final String busca;
  final void Function(String) onBuscaChanged;
  final FocusNode? focusNode;

  const CampoBusca({
    super.key,
    required this.busca,
    required this.onBuscaChanged,
    this.focusNode,
  });

  @override
  State<CampoBusca> createState() => _CampoBuscaState();
}

class _CampoBuscaState extends State<CampoBusca> {
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
  void didUpdateWidget(covariant CampoBusca oldWidget) {
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
                // Esc tira o foco do campo sem limpar o texto digitado
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

// Busca + seletor de ordenação combinados: usado no mobile, onde não há
// cabeçalho de tabela clicável para ordenar (a lista usa cards, não colunas).
class BarraBuscaOrdenacao extends StatelessWidget {
  final String busca;
  final void Function(String) onBuscaChanged;
  final int colunaOrdenada;
  final bool ascendente;
  final void Function(int) onOrdenarPor;

  const BarraBuscaOrdenacao({
    super.key,
    required this.busca,
    required this.onBuscaChanged,
    required this.colunaOrdenada,
    required this.ascendente,
    required this.onOrdenarPor,
  });

  // Índices correspondem às colunas de TabelaApostas (mesma convenção de
  // ordenação); ordem do mapa é a ordem de exibição no menu, não os índices.
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
          child: CampoBusca(busca: busca, onBuscaChanged: onBuscaChanged),
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
      ],
    );
  }
}
