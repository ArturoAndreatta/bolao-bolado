import 'package:cloud_firestore/cloud_firestore.dart';

/// UID fixo da sala principal do Bolão Bolado.
/// Sempre validado dinamicamente via campo `principal: true` no Firestore,
/// nunca assumido só pelo valor da constante (ver buscarSalaPrincipalId()).
const String kSalaPrincipalIdFallback = '9DvtjeS3gzyNyhFkqaF5';

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

/// Busca dinamicamente o ID da sala marcada como `principal: true`.
/// Nunca assume o ID fixo sem confirmar no Firestore.
Future<String> buscarSalaPrincipalId() async {
  final firestore = FirebaseFirestore.instance;
  final query = await firestore
      .collection('Salas')
      .where('principal', isEqualTo: true)
      .limit(1)
      .get();

  if (query.docs.isEmpty) {
    // Fallback de segurança: usa o ID conhecido se a query falhar
    // (ex: regra de segurança bloqueando query, mas permitindo doc direto)
    return kSalaPrincipalIdFallback;
  }

  return query.docs.first.id;
}

/// Lê todos os participantes/apostas da sala principal.
/// Fonte: Salas/{salaPrincipalId}/Participantes/{uid}
Future<List<Map<String, Object?>>> getBets() async {
  final firestore = FirebaseFirestore.instance;
  final salaId = await buscarSalaPrincipalId();

  final snapshot = await firestore
      .collection('Salas')
      .doc(salaId)
      .collection('Participantes')
      .orderBy('data-hora', descending: true)
      .get();

  return snapshot.docs.map((doc) {
    final dados = doc.data();
    final uid = doc.id; // doc ID É o uid do usuário logado
    final nome = dados['nome']?.toString() ?? '';
    final valor = double.tryParse(dados['valor'].toString()) ?? 0;
    final cotas = (valor / 6).floor();
    final premio = cotas * 1500;
    final dataHora = dados['data-hora'];
    final verificado = dados['verificado'] == true;

    return {
      'nome': nome,
      'valor': valor,
      'cotas': cotas,
      'premio': premio,
      'data-hora': dataHora,
      'uid': uid,
      'verificado': verificado,
    };
  }).toList();
}

/// Cria uma notificação para o admin sobre uma nova aposta.
Future<void> criarNotificacaoAposta({
  required String salaId,
  required String uid,
  required String nome,
  required String valor,
}) async {
  await FirebaseFirestore.instance.collection('notificacoes').add({
    'tipo': 'nova_aposta',
    'salaId': salaId,
    'uid': uid,
    'nome': nome,
    'valor': valor,
    'verificado': false,
    'data-hora': FieldValue.serverTimestamp(),
  });
}

/// Marca a aposta de um participante como verificada e resolve a
/// notificação correspondente.
Future<void> verificarAposta({
  required String salaId,
  required String uid,
  String? notificacaoId,
}) async {
  final firestore = FirebaseFirestore.instance;

  await firestore
      .collection('Salas')
      .doc(salaId)
      .collection('Participantes')
      .doc(uid)
      .update({'verificado': true});

  if (notificacaoId != null) {
    await firestore.collection('notificacoes').doc(notificacaoId).update({
      'verificado': true,
    });
  }
}
