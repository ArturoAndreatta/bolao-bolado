import 'package:cloud_firestore/cloud_firestore.dart';

class Sala {
  final String id;
  final String nome;
  final String descricao;
  final String? sorteio;
  final DateTime? dataHora;
  final double premio;
  final double? valorMaximo; // limite de valor por aposta na sala, se houver
  final String? senha; // null/vazio = sala pública, sem senha de acesso
  final String chavePix;

  Sala({
    required this.id,
    required this.nome,
    required this.descricao,
    this.sorteio,
    this.dataHora,
    required this.premio,
    this.valorMaximo,
    this.senha,
    required this.chavePix,
  });

  factory Sala.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Sala(
      id: doc.id,
      nome: data['nome'] ?? '',
      descricao: data['descricao'] ?? '',
      sorteio: data['sorteio'],
      dataHora: (data['dataHora'] as Timestamp?)?.toDate(),
      premio: (data['premio'] as num?)?.toDouble() ?? 0,
      valorMaximo: (data['valorMaximo'] as num?)?.toDouble(),
      senha: data['senha'],
      chavePix: data['chavePix'] ?? '',
    );
  }
}
