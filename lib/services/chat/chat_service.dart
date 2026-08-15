import 'package:bolao_bolado/models/mensagem.dart';
import 'package:bolao_bolado/services/chat/emoji_reacao.dart';
import 'package:bolao_bolado/services/chat/formatacao_mensagem.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const int kLimiteCaracteresMensagem = 200;

/// Limita o histórico carregado no chat às mensagens mais recentes: sem
/// isso, a stream re-sincroniza a coleção inteira a cada reconexão, o que
/// fica caro conforme o histórico da sala cresce.
const int kLimiteMensagensChat = 100;

/// Teto de menções numa mensagem só.
///
/// Existe para limitar o tamanho do documento e o custo de destacar o texto,
/// mas o motivo real é outro: sem teto, uma mensagem podia marcar a sala
/// inteira de uma vez. Dez é mais do que qualquer conversa de bolão precisa e
/// está repetido em `firestore.rules` (a regra não importa código).
const int kMaximoMencoes = 10;

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
    List<({String uid, String nome})> mencoesEscolhidas = const [],
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

    // As posições das menções foram calculadas sobre o texto do campo; o
    // `trim()` acima muda os índices se havia espaço à esquerda, então elas
    // são recalculadas contra o texto que de fato vai ser gravado.
    final mencoesFinais = resolverMencoes(
      textoLimpo,
      mencoesEscolhidas,
    ).take(kMaximoMencoes).toList();

    final mensagem = Mensagem(
      id: '', // ignorado no toMap, Firestore gera o ID
      texto: textoLimpo,
      autorUid: user.uid,
      autorNome: autorNome,
      mencoes: mencoesFinais,
    );

    await _firestore
        .collection('Salas')
        .doc(salaId)
        .collection('Mensagens')
        .add(mensagem.toMap());
  }

  /// Liga/desliga a reação do usuário atual numa mensagem.
  ///
  /// Uma reação por pessoa: tocar no emoji que já está marcado remove, tocar
  /// em outro TROCA. É como WhatsApp e Slack se comportam, e é o que a regra
  /// do Firestore consegue garantir (ela valida só a própria chave do mapa).
  ///
  /// Qualquer emoji vale — a checagem é de FORMATO, não de pertinência a uma
  /// lista (ver [ehEmojiReacao]). Ela existe para o erro aparecer aqui, e não
  /// como uma escrita recusada pelo Firestore que o chat engoliria em silêncio.
  ///
  /// Escreve com caminho de campo aninhado (`reacoes.<uid>`) em vez de mandar
  /// o mapa inteiro: assim duas pessoas reagindo ao mesmo tempo não sobrescrevem
  /// a reação uma da outra, e a escrita não precisa ler o documento antes.
  Future<void> alternarReacao({
    required String salaId,
    required String mensagemId,
    required String emoji,
    required String? reacaoAtual,
  }) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      throw Exception('Usuário não autenticado.');
    }
    if (!ehEmojiReacao(emoji)) {
      throw Exception('Emoji de reação inválido.');
    }

    final doc = _firestore
        .collection('Salas')
        .doc(salaId)
        .collection('Mensagens')
        .doc(mensagemId);

    return doc.update({
      'reacoes.${user.uid}': reacaoAtual == emoji ? FieldValue.delete() : emoji,
    });
  }

  /// Recado fixado no topo do chat da sala (null quando não há nenhum).
  ///
  /// Lê o doc da sala, que outras telas já observam. O SDK do Firestore
  /// compartilha o listener entre assinantes do MESMO documento, então isto
  /// não abre uma conexão a mais — só um `map` sobre o snapshot que já chega.
  Stream<MensagemFixada?> mensagemFixadaStream(String salaId) {
    return _firestore
        .collection('Salas')
        .doc(salaId)
        .snapshots()
        .map((doc) => MensagemFixada.fromMap(doc.data()?['mensagemFixada']));
  }

  /// Fixa uma mensagem no topo do chat. Só admin passa nas regras (a escrita
  /// é no doc da sala, que já é restrito a admin).
  ///
  /// Grava uma CÓPIA do texto, não uma referência: o aviso continua de pé se
  /// a mensagem original for apagada na moderação, e o banner não precisa de
  /// uma leitura extra para se montar.
  Future<void> fixarMensagem({
    required String salaId,
    required Mensagem mensagem,
  }) {
    return _firestore.collection('Salas').doc(salaId).update({
      'mensagemFixada': {
        'id': mensagem.id,
        'texto': mensagem.texto,
        'autorNome': mensagem.autorNome,
        'fixadaEm': FieldValue.serverTimestamp(),
      },
    });
  }

  Future<void> desafixarMensagem(String salaId) {
    return _firestore.collection('Salas').doc(salaId).update({
      'mensagemFixada': FieldValue.delete(),
    });
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
