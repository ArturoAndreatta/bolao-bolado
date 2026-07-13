import 'package:bolao_bolado/components/shared/skeletons.dart';
import 'package:flutter/material.dart';

// Tabela simples de participantes usada em sala_detalhes.dart. Não confundir
// com TabelaApostas (lib/pages/participants/participants_tabela.dart), que é
// a tabela completa (ordenação, animação de linha nova) da tela de Participantes.
class ParticipantsTable extends StatelessWidget {
  final bool loading;
  final double heightTable;
  final double widthNome;
  final double widthValor;
  final double widthCotas;
  final double widthPremio;
  final List<Map<String, dynamic>> rowsData;

  const ParticipantsTable({
    super.key,
    required this.loading,
    required this.heightTable,
    required this.widthNome,
    required this.widthValor,
    required this.widthCotas,
    required this.widthPremio,
    required this.rowsData,
  });

  List<DataRow> _getRows() {
    return rowsData.map((item) {
      return DataRow(
        cells: [
          DataCell(
            SizedBox(
              width: widthNome,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(item['nome'], maxLines: 2),
              ),
            ),
          ),
          DataCell(
            SizedBox(
              width: widthValor,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text('R\$ ${item['valor']}'),
              ),
            ),
          ),
          DataCell(
            SizedBox(
              width: widthCotas,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(item['cotas'].toString()),
              ),
            ),
          ),
          DataCell(
            SizedBox(
              width: widthPremio,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text('R\$ ${item['premio']}'),
              ),
            ),
          ),
        ],
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: heightTable,
      child: loading
          ? Shimmer(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    color: Colors.grey.shade200,
                    child: Row(
                      children: [
                        SkeletonBox(width: widthNome, height: 14),
                        const SizedBox(width: 12),
                        SkeletonBox(width: widthValor, height: 14),
                        const SizedBox(width: 12),
                        SkeletonBox(width: widthCotas, height: 14),
                        const SizedBox(width: 12),
                        SkeletonBox(width: widthPremio, height: 14),
                      ],
                    ),
                  ),
                  for (var i = 0; i < 5; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          SkeletonBox(width: widthNome * 0.7, height: 12),
                          const SizedBox(width: 12),
                          SkeletonBox(width: widthValor * 0.7, height: 12),
                          const SizedBox(width: 12),
                          SkeletonBox(width: widthCotas * 0.7, height: 12),
                          const SizedBox(width: 12),
                          SkeletonBox(width: widthPremio * 0.7, height: 12),
                        ],
                      ),
                    ),
                ],
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  dividerThickness: 0.5,
                  headingRowColor: WidgetStateProperty.all(
                    Colors.grey.shade200,
                  ),
                  border: TableBorder.symmetric(
                    inside: BorderSide(color: Colors.grey.shade300, width: 0.5),
                    outside: BorderSide(
                      color: Colors.grey.shade300,
                      width: 1.5,
                    ),
                  ),
                  headingTextStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                  columnSpacing: 5,
                  columns: [
                    DataColumn(
                      label: SizedBox(
                        width: widthNome,
                        child: const Text('Nome'),
                      ),
                    ),
                    DataColumn(
                      label: SizedBox(
                        width: widthValor,
                        child: const Text('Valor', textAlign: TextAlign.end),
                      ),
                    ),
                    DataColumn(
                      label: SizedBox(
                        width: widthCotas,
                        child: const Text('Cotas', textAlign: TextAlign.end),
                      ),
                    ),
                    DataColumn(
                      label: SizedBox(
                        width: widthPremio,
                        child: const Text('Prêmio', textAlign: TextAlign.end),
                      ),
                    ),
                  ],
                  rows: _getRows(),
                ),
              ),
            ),
    );
  }
}
