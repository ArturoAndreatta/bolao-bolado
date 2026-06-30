import 'package:cloud_firestore/cloud_firestore.dart';

class Mensagem {
  final String id;
  final String texto;
  final String autorUid;
  final String autorNome;
  final String? autorAvatar;
  final DateTime? criadoEm;

  Mensagem({
    required this.id,
    required this.texto,
    required this.autorUid,
    required this.autorNome,
    this.autorAvatar,
    this.criadoEm,
  });

  factory Mensagem.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Mensagem(
      id: doc.id,
      texto: data['texto'] ?? '',
      autorUid: data['autorUid'] ?? '',
      autorNome: data['autorNome'] ?? 'Anônimo',
      autorAvatar: data['autorAvatar'],
      criadoEm: (data['criadoEm'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'texto': texto,
      'autorUid': autorUid,
      'autorNome': autorNome,
      'autorAvatar': autorAvatar,
      'criadoEm': FieldValue.serverTimestamp(),
    };
  }
}
