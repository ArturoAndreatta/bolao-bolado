import 'package:flutter/material.dart';

// Comentário teste commit
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
                child: Text(item['id'].toString(), maxLines: 2),
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
          ? const Center(child: CircularProgressIndicator())
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
                    outside: BorderSide(color: Colors.grey.shade300, width: 1),
                  ),
                  headingTextStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                  columnSpacing: 24,
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
                        child: const Text('Valor'),
                      ),
                    ),
                    DataColumn(
                      label: SizedBox(
                        width: widthCotas,
                        child: const Text('Cotas'),
                      ),
                    ),
                    DataColumn(
                      label: SizedBox(
                        width: widthPremio,
                        child: const Text('Prêmio'),
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
