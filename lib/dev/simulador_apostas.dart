import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Prefixo usado nos uids dos participantes fake gerados pela simulação,
/// permitindo identificá-los e removê-los sem afetar apostas reais.
const String kPrefixoUidSimulado = 'sim-';

final List<String> _nomesSimulados = [
  'Carlos Silva',
  'Fernanda Costa',
  'João Pereira',
  'Mariana Alves',
  'Rafael Souza',
  'Juliana Lima',
  'Bruno Rocha',
  'Camila Dias',
  'Eduardo Nunes',
  'Patrícia Gomes',
  'Lucas Martins',
  'Aline Ferreira',
  'Diego Barbosa',
  'Vanessa Ribeiro',
  'Thiago Cardoso',
  'Renata Almeida',
  'Felipe Araújo',
  'Bianca Teixeira',
  'Marcos Vinícius',
  'Larissa Moura',
];

/// Gera/edita/remove apostas fake (uids prefixados com [kPrefixoUidSimulado])
/// na sala principal, simulando o movimento de muitas pessoas apostando.
/// Uso exclusivo para visualização/teste de layout com muitos participantes;
/// nunca deve ser exposto a usuários não-admin.
class SimuladorApostas {
  final _random = Random();
  bool _rodando = false;
  Timer? _timer;

  bool get rodando => _rodando;

  void iniciar(String salaId) {
    if (_rodando) return;
    _rodando = true;
    _timer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      _executarPasso(salaId);
    });
  }

  void parar() {
    _rodando = false;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _executarPasso(String salaId) async {
    final firestore = FirebaseFirestore.instance;
    final participantesRef = firestore
        .collection('Salas')
        .doc(salaId)
        .collection('Participantes');

    final existentes = await participantesRef
        .where(
          FieldPath.documentId,
          isGreaterThanOrEqualTo: kPrefixoUidSimulado,
        )
        .where(
          FieldPath.documentId,
          isLessThan: '$kPrefixoUidSimulado${String.fromCharCode(0x10FFFF)}',
        )
        .get();

    final acao = _random.nextInt(3);

    if (existentes.docs.isEmpty || acao == 0) {
      // Adicionar novo apostador fake
      final nome = _nomesSimulados[_random.nextInt(_nomesSimulados.length)];
      final uid =
          '$kPrefixoUidSimulado${DateTime.now().microsecondsSinceEpoch}';
      final cotas = _random.nextInt(5) + 1;
      await participantesRef.doc(uid).set({
        'nome': nome,
        'valor': (cotas * 6).toString(),
        'data-hora': FieldValue.serverTimestamp(),
        'verificado': _random.nextBool(),
      });
    } else if (acao == 1) {
      // Editar um apostador fake existente (nova cota/valor)
      final doc = existentes.docs[_random.nextInt(existentes.docs.length)];
      final cotas = _random.nextInt(6) + 1;
      await doc.reference.update({
        'valor': (cotas * 6).toString(),
        'data-hora': FieldValue.serverTimestamp(),
      });
    } else {
      // Remover um apostador fake existente
      final doc = existentes.docs[_random.nextInt(existentes.docs.length)];
      await doc.reference.delete();
    }
  }

  /// Remove todos os participantes fake criados pela simulação.
  Future<void> limparSimulados(String salaId) async {
    final firestore = FirebaseFirestore.instance;
    final participantesRef = firestore
        .collection('Salas')
        .doc(salaId)
        .collection('Participantes');

    final existentes = await participantesRef
        .where(
          FieldPath.documentId,
          isGreaterThanOrEqualTo: kPrefixoUidSimulado,
        )
        .where(
          FieldPath.documentId,
          isLessThan: '$kPrefixoUidSimulado${String.fromCharCode(0x10FFFF)}',
        )
        .get();

    final batch = firestore.batch();
    for (final doc in existentes.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
