import 'package:flutter/material.dart';

List<DataRow> fakeRows = [
  _row('Amanda Costa', 'R\$ 300', '60', 'R\$ 85.200.000'),
  _row('Ricardo Ferreira', 'R\$ 25', '5', 'R\$ 7.100.000'),
  _row('Júlia Silva', 'R\$ 100', '20', 'R\$ 28.400.000'),
  _row('Felipe Oliveira', 'R\$ 75', '15', 'R\$ 21.300.000'),
  _row('Paula Martins', 'R\$ 15', '3', 'R\$ 4.260.000'),
  _row('Gustavo Alves', 'R\$ 250', '50', 'R\$ 71.000.000'),
  _row('Camila Dias', 'R\$ 350', '70', 'R\$ 99.400.000'),
  _row('Marcos Rocha', 'R\$ 5', '1', 'R\$ 1.420.000'),
  _row('Renata Lima', 'R\$ 180', '36', 'R\$ 51.120.000'),
  _row('Bruno Pacheco', 'R\$ 60', '12', 'R\$ 17.040.000'),
  _row('Daniela Torres', 'R\$ 220', '44', 'R\$ 62.480.000'),
  _row('Lucas Nogueira', 'R\$ 90', '18', 'R\$ 25.560.000'),
  _row('Patrícia Azevedo', 'R\$ 140', '28', 'R\$ 39.760.000'),
  _row('Thiago Ribeiro', 'R\$ 200', '40', 'R\$ 56.800.000'),
  _row('Fernanda Lopes', 'R\$ 55', '11', 'R\$ 15.620.000'),
  _row('Rafael Cunha', 'R\$ 125', '25', 'R\$ 35.500.000'),
  _row('Bianca Moreira', 'R\$ 165', '33', 'R\$ 46.860.000'),
  _row('Eduardo Farias', 'R\$ 80', '16', 'R\$ 22.720.000'),
  _row('Natalia Guedes', 'R\$ 95', '19', 'R\$ 26.980.000'),
  _row('Vinícius Barros', 'R\$ 40', '8', 'R\$ 11.360.000'),
  _row('Carolina Pinto', 'R\$ 270', '54', 'R\$ 76.680.000'),
  _row('Pedro Henrique', 'R\$ 110', '22', 'R\$ 31.240.000'),
  _row('Juliano Mendes', 'R\$ 30', '6', 'R\$ 8.520.000'),
  _row('Aline Batista', 'R\$ 155', '31', 'R\$ 44.020.000'),
  _row('Leandro Costa', 'R\$ 210', '42', 'R\$ 59.640.000'),
];

DataRow _row(String nome, String valor, String cotas, String premio) {
  return DataRow(
    cells: [
      DataCell(Align(alignment: Alignment.centerLeft, child: Text(nome))),
      DataCell(Align(alignment: Alignment.centerRight, child: Text(valor))),
      DataCell(Align(alignment: Alignment.centerRight, child: Text(cotas))),
      DataCell(Align(alignment: Alignment.centerRight, child: Text(premio))),
    ],
  );
}
