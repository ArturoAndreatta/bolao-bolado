import 'package:cloud_firestore/cloud_firestore.dart';

class Bet {
  String nome;
  int valor;
  Bet({required this.nome, required this.valor});

  Map<String, dynamic> toMap() {
    return {'nome': nome, 'valor': valor};
  }

  Bet.fromMap(Map<String, dynamic> map)
    : nome = map['nome'],
      valor = map['valor'];
}

Future<List<Map<String, Object>>> getBets() async {
  FirebaseFirestore firestore = .instance;
  final snapshot = await firestore.collection('Apostas').get();

  return snapshot.docs.map((bet) {
    final dados = bet.data();
    final valor = double.tryParse(dados['valor'].toString()) ?? 0;
    final cotas = (valor / 6).floor();
    final premio = cotas * 1500;

    return {'id': bet.id, 'valor': valor, 'cotas': cotas, 'premio': premio};
  }).toList();
}
