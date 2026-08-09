import 'package:bolao_bolado/models/mensagem.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const int kLimiteCaracteresMensagem = 200;

/// Limita o histórico carregado no chat às mensagens mais recentes: sem
/// isso, a stream re-sincroniza a coleção inteira a cada reconexão, o que
/// fica caro conforme o histórico da sala cresce.
const int kLimiteMensagensChat = 100;

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream de mensagens da sala principal, ordenadas da mais antiga
  /// pra mais nova (ordem natural de leitura num chat).
  Stream<List<Mensagem>> mensagensStream(String salaId) {
    return _firestore
        .collection('Salas')
        .doc(salaId)
        .collection('Mensagens')
        .orderBy('criadoEm', descending: true)
        .limit(kLimiteMensagensChat)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Mensagem.fromDoc(doc)).toList();
        });
  }

  /// Verifica se o usuário atual está logado E tem participação
  /// registrada na sala (ou seja, fez uma aposta).
  Future<bool> usuarioPodeParticipar(String salaId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return false;

    final doc = await _firestore
        .collection('Salas')
        .doc(salaId)
        .collection('Participantes')
        .doc(user.uid)
        .get();

    return doc.exists;
  }

  /// Envia uma mensagem na sala. Lança exceção se o texto for
  /// inválido (vazio ou acima do limite) — a regra de permissão
  /// de quem pode escrever fica garantida no Firestore Rules.
  Future<void> enviarMensagem({
    required String salaId,
    required String texto,
    required String autorNome,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      throw Exception('Usuário não autenticado.');
    }

    final textoLimpo = texto.trim();
    if (textoLimpo.isEmpty) {
      throw Exception('Mensagem vazia.');
    }
    if (textoLimpo.length > kLimiteCaracteresMensagem) {
      throw Exception('Mensagem excede o limite de caracteres.');
    }

    final mensagem = Mensagem(
      id: '', // ignorado no toMap, Firestore gera o ID
      texto: textoLimpo,
      autorUid: user.uid,
      autorNome: autorNome,
    );

    await _firestore
        .collection('Salas')
        .doc(salaId)
        .collection('Mensagens')
        .add(mensagem.toMap());
  }

  /// Apaga uma mensagem. Só admin passa nas regras do Firestore — aqui não
  /// há checagem de permissão de propósito: quem manda é `firestore.rules`,
  /// duplicar a regra no cliente só criaria duas fontes de verdade.
  Future<void> apagarMensagem({
    required String salaId,
    required String mensagemId,
  }) {
    return _firestore
        .collection('Salas')
        .doc(salaId)
        .collection('Mensagens')
        .doc(mensagemId)
        .delete();
  }

  /// Apaga TODAS as mensagens da sala e devolve quantas foram apagadas.
  ///
  /// Vai em páginas de [_loteExclusao] docs porque um WriteBatch do Firestore
  /// aceita no máximo 500 operações — um chat com histórico maior que isso
  /// estouraria o batch único. Os IDs vêm de `.get()` (não da stream do chat,
  /// que é limitada a [kLimiteMensagensChat]), senão as mensagens antigas
  /// ficariam para trás.
  Future<int> apagarTodasMensagens(String salaId) async {
    final colecao = _firestore
        .collection('Salas')
        .doc(salaId)
        .collection('Mensagens');

    var apagadas = 0;
    while (true) {
      // Só os IDs interessam aqui; o Firestore não tem "keys only", mas
      // limitar a página já mantém a leitura barata.
      final pagina = await colecao.limit(_loteExclusao).get();
      if (pagina.docs.isEmpty) break;

      final lote = _firestore.batch();
      for (final doc in pagina.docs) {
        lote.delete(doc.reference);
      }
      await lote.commit();
      apagadas += pagina.docs.length;

      // Página incompleta = era a última.
      if (pagina.docs.length < _loteExclusao) break;
    }
    return apagadas;
  }

  /// Teto de operações por WriteBatch do Firestore é 500.
  static const int _loteExclusao = 400;
}
