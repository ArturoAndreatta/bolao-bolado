import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/core/app_radii.dart';
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
    final cores = AppCores.de(context);
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        // No claro o campo é a superfície mais clara (branco sobre o card
        // off-white); no escuro isso se inverteria — `card` é o bloco mais
        // claro dali, e o campo viraria uma laje brilhante sobre a tabela.
        // No escuro ele usa o tom de campo, que recua em vez de saltar.
        color: cores.escuro ? cores.campo : cores.card,
        borderRadius: AppRadii.circularSmd,
        border: Border.all(
          color: _focado ? cores.azul : cores.borda,
          width: _focado ? 1.5 : 1,
        ),
        boxShadow: _focado
            ? [
                BoxShadow(
                  color: cores.azul.withValues(alpha: 0.15),
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
            color: _focado ? cores.azul : cores.textoFraco,
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
                  hintStyle: TextStyle(fontSize: 14, color: cores.textoFraco),
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
  static const Map<int, String> _opcoes = {0: 'Nome', 1: 'Valor', 4: 'Data'};

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: CampoBusca(busca: busca, onBuscaChanged: onBuscaChanged),
        ),
        const SizedBox(width: 8),
        _BotaoDirecaoOrdenacao(
          ascendente: ascendente,
          // Alterna a direção mantendo a mesma coluna já selecionada.
          onTap: () => onOrdenarPor(colunaOrdenada),
        ),
        const SizedBox(width: 8),
        _BotaoCampoOrdenacao(
          colunaOrdenada: colunaOrdenada,
          opcoes: _opcoes,
          onSelected: onOrdenarPor,
        ),
      ],
    );
  }
}

// Botão que só alterna a direção (asc/desc) da ordenação já selecionada.
class _BotaoDirecaoOrdenacao extends StatelessWidget {
  final bool ascendente;
  final VoidCallback onTap;

  const _BotaoDirecaoOrdenacao({required this.ascendente, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          width: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: cores.escuro ? cores.campo : cores.card,
            borderRadius: AppRadii.circularSmd,
            border: Border.all(color: cores.borda, width: 1),
          ),
          child: Icon(
            ascendente ? Icons.arrow_upward : Icons.arrow_downward,
            size: 18,
            color: cores.azul,
          ),
        ),
      ),
    );
  }
}

// Botão que escolhe qual campo será usado na ordenação (Valor, Nome, etc).
class _BotaoCampoOrdenacao extends StatelessWidget {
  final int colunaOrdenada;
  final Map<int, String> opcoes;
  final void Function(int) onSelected;

  const _BotaoCampoOrdenacao({
    required this.colunaOrdenada,
    required this.opcoes,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    return PopupMenuButton<int>(
      onSelected: onSelected,
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: AppRadii.circularSmd),
      itemBuilder: (context) => opcoes.entries
          .map((e) => PopupMenuItem<int>(value: e.key, child: Text(e.value)))
          .toList(),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: cores.escuro ? cores.campo : cores.card,
          borderRadius: AppRadii.circularSmd,
          border: Border.all(color: cores.borda, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              opcoes[colunaOrdenada] ?? 'Valor',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: cores.azul,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 18, color: cores.azul),
          ],
        ),
      ),
    );
  }
}
