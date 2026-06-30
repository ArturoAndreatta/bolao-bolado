import 'package:cloud_firestore/cloud_firestore.dart';

class SalaService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static String? _salaIdCache;

  /// Busca o ID da sala principal (campo principal: true)
  /// Faz cache para não ficar batendo no Firestore toda vez
  static Future<String?> getSalaIdPrincipal() async {
    if (_salaIdCache != null) return _salaIdCache;

    final snapshot = await _firestore
        .collection('Salas')
        .where('principal', isEqualTo: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    _salaIdCache = snapshot.docs.first.id;
    return _salaIdCache;
  }

  /// Referência para a subcoleção de Participantes da sala principal
  static Future<CollectionReference?> getParticipantes() async {
    final salaId = await getSalaIdPrincipal();
    if (salaId == null) return null;
    return _firestore
        .collection('Salas')
        .doc(salaId)
        .collection('Participantes');
  }

  /// Referência para a subcoleção de Mensagens da sala principal
  static Future<CollectionReference?> getMensagens() async {
    final salaId = await getSalaIdPrincipal();
    if (salaId == null) return null;
    return _firestore.collection('Salas').doc(salaId).collection('Mensagens');
  }

  /// Stream em tempo real das mensagens
  static Future<Stream<QuerySnapshot>?> getMensagensStream() async {
    final salaId = await getSalaIdPrincipal();
    if (salaId == null) return null;
    return _firestore
        .collection('Salas')
        .doc(salaId)
        .collection('Mensagens')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }
}
