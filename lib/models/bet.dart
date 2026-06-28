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

Future<List<Map<String, Object?>>> getBets() async {
  FirebaseFirestore firestore = FirebaseFirestore.instance;
  final snapshot = await firestore
      .collection('Apostas')
      .orderBy('data-hora', descending: true)
      .get();

  return snapshot.docs.map((bet) {
    final dados = bet.data();
    final uid = dados['uid'];
    final nome = dados['nome'].toString();
    final valor = double.tryParse(dados['valor'].toString()) ?? 0;
    final cotas = (valor / 6).floor();
    final premio = cotas * 1500;
    final dataHora = dados['data-hora']; // Timestamp ou null

    return {
      'nome': nome,
      'valor': valor,
      'cotas': cotas,
      'premio': premio,
      'data-hora': dataHora,
      'uid': uid,
    };
  }).toList();
}
