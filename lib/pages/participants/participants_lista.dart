import 'package:bolao_bolado/components/formatters/formatters.dart';
import 'package:bolao_bolado/pages/participants/participants_tabela.dart'
    show LinhaEntrandoAnimada, detectarLinhaNova;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

const List<Color> coresAvatar = [
  Color(0xFF2E7D32),
  Color(0xFF487DE5),
  Color(0xFF7C5CD9),
  Color(0xFFCB8A2C),
  Color(0xFFD9534F),
  Color(0xFF17A398),
];

// Deriva cor determinística a partir do nome (mesmo participante = mesma cor sempre)
Color corAvatarPara(String nome) {
  final soma = nome.codeUnits.fold<int>(0, (acc, c) => acc + c);
  return coresAvatar[soma % coresAvatar.length];
}

class ListaParticipantes extends StatefulWidget {
  final List<Map<String, dynamic>> rows;
  final String? currentUid;

  const ListaParticipantes({
    super.key,
    required this.rows,
    required this.currentUid,
  });

  @override
  State<ListaParticipantes> createState() => _ListaParticipantesState();
}

class _ListaParticipantesState extends State<ListaParticipantes> {
  // Mesmo mecanismo usado em TabelaApostas: guarda o último timestamp por uid
  // para detectar linhas novas/recriadas e disparar a animação de entrada.
  final Map<String, int?> _timestampsConhecidos = {};

  @override
  Widget build(BuildContext context) {
    final rows = widget.rows;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          Builder(
            builder: (context) {
              final uid = rows[i]['uid']?.toString();
              final dataHora = rows[i]['data-hora'];
              final tsAtual = dataHora is Timestamp
                  ? dataHora.millisecondsSinceEpoch
                  : null;
              final isNova = detectarLinhaNova(
                _timestampsConhecidos,
                uid,
                tsAtual,
              );

              return LinhaEntrandoAnimada(
                key: ValueKey(
                  '${uid ?? '$i-${rows[i]['nome']}'}-${tsAtual ?? i}',
                ),
                animar: isNova,
                corBase: Colors.transparent,
                child: LinhaParticipante(
                  nome: rows[i]['nome']?.toString() ?? '—',
                  valor: Formatters.moeda.format(
                    (rows[i]['valor'] as num?)?.toDouble() ?? 0,
                  ),
                  cotas: (rows[i]['cotas'] as num?)?.toInt() ?? 0,
                  premio: Formatters.moeda.format(
                    (rows[i]['premio'] as num?)?.toDouble() ?? 0,
                  ),
                  corAvatar: (rows[i]['avatarColor'] as int?) != null
                      ? Color(rows[i]['avatarColor'] as int)
                      : null,
                  destacado: rows[i]['uid'] == widget.currentUid,
                  verificado: rows[i]['verificado'] == true,
                  alterada: rows[i]['editadoAposVerificacao'] == true,
                ),
              );
            },
          ),
          if (i < rows.length - 1)
            Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
        ],
      ],
    );
  }
}

class LinhaParticipante extends StatelessWidget {
  final String nome;
  final String valor;
  final int cotas;
  final String premio;
  final Color? corAvatar;
  final bool destacado;
  final bool verificado;
  final bool alterada;

  const LinhaParticipante({
    super.key,
    required this.nome,
    required this.valor,
    required this.cotas,
    required this.premio,
    this.corAvatar,
    required this.destacado,
    this.verificado = false,
    this.alterada = false,
  });

  @override
  Widget build(BuildContext context) {
    final inicial = nome.trim().isNotEmpty ? nome.trim()[0].toUpperCase() : '?';
    final cor = corAvatar ?? corAvatarPara(nome);
    // Prioridade visual: edição pós-verificação > verificado/destacado > normal
    final corFundo = alterada
        ? const Color(0xFFFEF3C7)
        : verificado
        ? const Color(0xFFDCFCE7)
        : (destacado ? const Color(0xFFDCFCE7) : Colors.transparent);

    return Container(
      color: corFundo,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: destacado ? FontWeight.w700 : FontWeight.w400,
                    color: const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.emoji_events_outlined,
                      size: 12,
                      color: Colors.amber.shade700,
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        premio,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.amber.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
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

class RodapeLista extends StatelessWidget {
  final int total;
  final double valorTotal;
  final int cotasTotal;

  const RodapeLista({
    super.key,
    required this.total,
    required this.valorTotal,
    required this.cotasTotal,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '${Formatters.moeda.format(valorTotal)} | $cotasTotal Cotas',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
        const SizedBox(width: 12),
        Icon(Icons.people_outline, size: 15, color: Colors.grey.shade500),
        const SizedBox(width: 6),
        Text(
          '$total ${total == 1 ? 'participante' : 'participantes'}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
      ],
    );
  }
}
