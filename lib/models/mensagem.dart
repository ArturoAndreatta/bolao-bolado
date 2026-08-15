import 'package:cloud_firestore/cloud_firestore.dart';

/// Um `@Nome` dentro do texto de uma [Mensagem].
///
/// Guarda o UID **e** as posições do token no texto cru. As posições existem
/// para o destaque não depender de casar o nome por texto: dois participantes
/// chamados "Ana" ficariam ambos marcados, e quem trocasse de nome depois
/// veria menções antigas deixarem de acender. Com o intervalo gravado, a
/// mensagem continua significando exatamente o que significava quando foi
/// enviada.
///
/// [nome] é o nome no momento do envio — é ele que aparece na tela, pelo mesmo
/// motivo: mensagem publicada não muda de texto depois.
class Mencao {
  final String uid;
  final String nome;

  /// Índice do `@` no texto (inclusivo) e do caractere seguinte ao token
  /// (exclusivo), no mesmo sistema de `String.substring`.
  final int inicio;
  final int fim;

  const Mencao({
    required this.uid,
    required this.nome,
    required this.inicio,
    required this.fim,
  });

  /// Descarta menção malformada em vez de lançar: um doc escrito por uma
  /// versão antiga (ou por fora do app) não pode derrubar o chat inteiro.
  static Mencao? fromMap(Object? valor) {
    if (valor is! Map) return null;
    final uid = valor['uid'];
    final nome = valor['nome'];
    final inicio = valor['inicio'];
    final fim = valor['fim'];
    if (uid is! String || uid.isEmpty) return null;
    if (nome is! String) return null;
    if (inicio is! num || fim is! num) return null;
    if (inicio < 0 || fim <= inicio) return null;
    return Mencao(
      uid: uid,
      nome: nome,
      inicio: inicio.toInt(),
      fim: fim.toInt(),
    );
  }

  Map<String, Object?> toMap() => {
    'uid': uid,
    'nome': nome,
    'inicio': inicio,
    'fim': fim,
  };
}

/// Recado que o admin prendeu no topo do chat da sala.
///
/// Vive num campo do doc da SALA (`mensagemFixada`), não numa flag na própria
/// mensagem: assim o chat descobre o que está fixado sem varrer o histórico
/// atrás de uma flag — e o recado sobrevive à mensagem original ser apagada,
/// que é justamente o caso do aviso importante ("PIX até sexta") ainda
/// precisar ficar de pé.
class MensagemFixada {
  /// ID da mensagem original. Pode não existir mais no histórico.
  final String id;
  final String texto;
  final String autorNome;
  final DateTime? fixadaEm;

  const MensagemFixada({
    required this.id,
    required this.texto,
    required this.autorNome,
    this.fixadaEm,
  });

  static MensagemFixada? fromMap(Object? valor) {
    if (valor is! Map) return null;
    final texto = valor['texto'];
    if (texto is! String || texto.isEmpty) return null;
    return MensagemFixada(
      id: valor['id'] as String? ?? '',
      texto: texto,
      autorNome: valor['autorNome'] as String? ?? 'Anônimo',
      fixadaEm: (valor['fixadaEm'] as Timestamp?)?.toDate(),
    );
  }
}

class Mensagem {
  final String id;
  final String texto;
  final String autorUid;
  final String autorNome;
  final DateTime? criadoEm;

  /// Menções feitas nesta mensagem, na ordem em que aparecem no texto.
  final List<Mencao> mencoes;

  /// Reações, no formato `{uid: emoji}` — **um emoji por pessoa**.
  ///
  /// Fica num campo MAP do próprio documento, e não numa subcoleção: a bolha
  /// já recebe a mensagem pela stream compartilhada do chat, então a reação
  /// chega junto sem custar um listener por mensagem (100 mensagens na tela
  /// seriam 100 listeners novos). O preço é que reagir é um `update` no doc da
  /// mensagem — as regras liberam só a própria chave dentro deste mapa, o
  /// texto continua imutável.
  final Map<String, String> reacoes;

  Mensagem({
    required this.id,
    required this.texto,
    required this.autorUid,
    required this.autorNome,
    this.criadoEm,
    this.mencoes = const [],
    this.reacoes = const {},
  });

  /// Monta uma [Mensagem] a partir de um documento do Firestore.
  ///
  /// Mesma proteção de [Sala.fromDoc]: doc sem dados vira mensagem vazia em
  /// vez de lançar e derrubar o chat inteiro.
  factory Mensagem.fromDoc(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? const {};
    final mencoesCruas = data['mencoes'];
    final reacoesCruas = data['reacoes'];
    return Mensagem(
      id: doc.id,
      texto: data['texto'] ?? '',
      autorUid: data['autorUid'] ?? '',
      autorNome: data['autorNome'] ?? 'Anônimo',
      criadoEm: (data['criadoEm'] as Timestamp?)?.toDate(),
      mencoes: mencoesCruas is List
          ? [
              for (final item in mencoesCruas)
                if (Mencao.fromMap(item) case final mencao?) mencao,
            ]
          : const [],
      reacoes: reacoesCruas is Map
          ? {
              for (final entrada in reacoesCruas.entries)
                if (entrada.key is String && entrada.value is String)
                  entrada.key as String: entrada.value as String,
            }
          : const {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'texto': texto,
      'autorUid': autorUid,
      'autorNome': autorNome,
      'criadoEm': FieldValue.serverTimestamp(),
      // Só grava o campo quando há menção: mensagem simples continua com o
      // mesmo formato de doc de antes desta feature.
      if (mencoes.isNotEmpty)
        'mencoes': [for (final mencao in mencoes) mencao.toMap()],
    };
  }
}
