import 'package:bolao_bolado/pages/participants/participants_tabela.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const List<Color> coresAvatar = [
  Color(0xFF2E7D32),
  Color(0xFF487DE5),
  Color(0xFF7C5CD9),
  Color(0xFFCB8A2C),
  Color(0xFFD9534F),
  Color(0xFF17A398),
];

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
  final Map<String, int?> _timestampsConhecidos = {};

  @override
  Widget build(BuildContext context) {
    final rows = widget.rows;
    final formatoMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

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
              final tsConhecido = uid == null
                  ? null
                  : _timestampsConhecidos[uid];
              final isNova =
                  uid != null &&
                  (!_timestampsConhecidos.containsKey(uid) ||
                      tsConhecido != tsAtual);
              if (uid != null) _timestampsConhecidos[uid] = tsAtual;

              return LinhaEntrandoAnimada(
                key: ValueKey(
                  '${uid ?? '$i-${rows[i]['nome']}'}-${tsAtual ?? i}',
                ),
                animar: isNova,
                corBase: Colors.transparent,
                child: LinhaParticipante(
                  posicao: i + 1,
                  nome: rows[i]['nome']?.toString() ?? '—',
                  valor: formatoMoeda.format(
                    (rows[i]['valor'] as num?)?.toDouble() ?? 0,
                  ),
                  cotas: (rows[i]['cotas'] as num?)?.toInt() ?? 0,
                  premio: formatoMoeda.format(
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
  final int posicao;
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
    required this.posicao,
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
    final corFundo = alterada
        ? const Color(0xFFFEF3C7)
        : verificado
        ? const Color(0xFFDCFCE7)
        : (destacado ? const Color(0xFFDCFCE7) : Colors.transparent);

    return Container(
      color: corFundo,
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

  const RodapeLista({super.key, required this.total});

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
