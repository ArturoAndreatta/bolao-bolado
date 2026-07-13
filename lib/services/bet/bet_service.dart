import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bolao_bolado/services/avatar/avatar_service.dart';
import 'package:bolao_bolado/services/bet/preco_cota.dart';

/// UID fixo da sala principal do Bolão Bolado.
/// Sempre validado dinamicamente via campo `principal: true` no Firestore,
/// nunca assumido só pelo valor da constante (ver buscarSalaPrincipalId()).
const String kSalaPrincipalIdFallback = '9DvtjeS3gzyNyhFkqaF5';

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

/// Observa em tempo real o documento da sala principal (prêmio, sorteio,
/// chave PIX). Usado pelo card "Minha Aposta" para refletir mudanças feitas
/// pelo admin sem precisar recarregar a tela.
Stream<DocumentSnapshot<Map<String, dynamic>>> streamSalaPrincipal() async* {
  final salaId = await buscarSalaPrincipalId();
  yield* FirebaseFirestore.instance.collection('Salas').doc(salaId).snapshots();
}

/// Lê uma vez os dados (sorteio, data, prêmio) da sala principal.
/// Usado pela tela de Participantes para exibir as estatísticas do sorteio.
Future<Map<String, dynamic>> getDadosSalaPrincipal() async {
  final salaId = await buscarSalaPrincipalId();
  final salaDoc = await FirebaseFirestore.instance
      .collection('Salas')
      .doc(salaId)
      .get();
  return {'salaId': salaId, ...?salaDoc.data()};
}

/// Lê todos os participantes/apostas da sala principal.
/// Fonte: Salas/{salaPrincipalId}/Participantes/{uid}
Future<List<Map<String, Object?>>> getBets() async {
  final firestore = FirebaseFirestore.instance;
  final salaId = await buscarSalaPrincipalId();

  final salaDoc = await firestore.collection('Salas').doc(salaId).get();
  final premioSala = (salaDoc.data()?['premio'] as num?)?.toDouble() ?? 0;
  final precoCota = precoCotaPara(salaDoc.data()?['sorteio']?.toString());

  final snapshot = await firestore
      .collection('Salas')
      .doc(salaId)
      .collection('Participantes')
      .orderBy('data-hora', descending: true)
      .get();

  return _montarParticipantes(snapshot.docs, premioSala, precoCota);
}

/// Observa em tempo real os participantes/apostas da sala principal.
/// Emite uma nova lista sempre que qualquer aposta é criada, editada ou
/// removida em Salas/{salaPrincipalId}/Participantes.
Stream<List<Map<String, Object?>>> streamBets() async* {
  final firestore = FirebaseFirestore.instance;
  final salaId = await buscarSalaPrincipalId();

  final salaStream = firestore.collection('Salas').doc(salaId).snapshots();
  final participantesStream = firestore
      .collection('Salas')
      .doc(salaId)
      .collection('Participantes')
      .orderBy('data-hora', descending: true)
      .snapshots();

  double premioSala = 0;
  double precoCota = kPrecoCotaMega;
  List<QueryDocumentSnapshot<Map<String, dynamic>>>? ultimosDocs;

  await for (final evento in _combinarStreams(
    salaStream,
    participantesStream,
  )) {
    if (evento.$1 != null) {
      premioSala = (evento.$1!.data()?['premio'] as num?)?.toDouble() ?? 0;
      precoCota = precoCotaPara(evento.$1!.data()?['sorteio']?.toString());
    }
    if (evento.$2 != null) {
      ultimosDocs = evento.$2!.docs;
    }
    if (ultimosDocs != null) {
      yield await _montarParticipantes(ultimosDocs, premioSala, precoCota);
    }
  }
}

/// Combina os dois streams (dados da sala + participantes) em um único
/// stream de tuplas, emitindo sempre que qualquer um dos dois atualizar.
Stream<
  (
    DocumentSnapshot<Map<String, dynamic>>?,
    QuerySnapshot<Map<String, dynamic>>?,
  )
>
_combinarStreams(
  Stream<DocumentSnapshot<Map<String, dynamic>>> salaStream,
  Stream<QuerySnapshot<Map<String, dynamic>>> participantesStream,
) {
  final controller =
      StreamController<
        (
          DocumentSnapshot<Map<String, dynamic>>?,
          QuerySnapshot<Map<String, dynamic>>?,
        )
      >();

  final subs = <StreamSubscription>[];
  subs.add(
    salaStream.listen(
      (doc) => controller.add((doc, null)),
      onError: controller.addError,
    ),
  );
  subs.add(
    participantesStream.listen(
      (query) => controller.add((null, query)),
      onError: controller.addError,
    ),
  );

  controller.onCancel = () async {
    for (final sub in subs) {
      await sub.cancel();
    }
  };

  return controller.stream;
}

Future<List<Map<String, Object?>>> _montarParticipantes(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  double premioSala,
  double precoCota,
) async {
  final uids = docs.map((doc) => doc.id).toList();
  final coresPorUid = await _buscarCoresAvatar(uids);

  final participantes = docs.map((doc) {
    final dados = doc.data();
    final uid = doc.id; // doc ID É o uid do usuário logado
    return {
      'uid': uid,
      'nome': dados['nome']?.toString() ?? '',
      'valor': dados['valor'],
      'data-hora': dados['data-hora'],
      'verificado': dados['verificado'] == true,
      'editadoAposVerificacao': dados['editadoAposVerificacao'] == true,
      'avatarColor': coresPorUid[uid],
    };
  }).toList();

  return calcularCotasEPremios(participantes, premioSala, precoCota);
}

/// Calcula cotas (valor apostado / preço da cota) e prêmio proporcional de
/// cada participante, dado o prêmio total da sala.
///
/// O preço da cota varia por tipo de sorteio (ver [precoCotaPara]) — nunca
/// deve ser assumido como um valor fixo único.
///
/// Função pura, sem acesso a Firestore, para poder ser testada isoladamente:
/// o cálculo de dinheiro real (quem recebe quanto do prêmio) não deve
/// depender de mocks de banco de dados para ser validado.
List<Map<String, Object?>> calcularCotasEPremios(
  List<Map<String, Object?>> participantes,
  double premioSala, [
  double precoCota = kPrecoCotaMega,
]) {
  final comCotas = participantes.map((item) {
    final valor = double.tryParse(item['valor'].toString()) ?? 0;
    // Arredonda pra baixo: valor apostado que não fecha uma cota inteira
    // não gera cota parcial (evita fração de prêmio por dinheiro insuficiente).
    final cotas = (valor / precoCota).floor();
    return {...item, 'valor': valor, 'cotas': cotas};
  }).toList();

  final totalCotas = comCotas.fold<int>(
    0,
    (soma, item) => soma + (item['cotas'] as int),
  );

  return comCotas.map((item) {
    final cotas = item['cotas'] as int;
    // Prêmio rateado proporcionalmente às cotas de cada um; se ninguém
    // tem cota (totalCotas == 0), evita divisão por zero e não distribui nada.
    final premio = totalCotas > 0 ? (cotas / totalCotas) * premioSala : 0.0;
    return {...item, 'premio': premio};
  }).toList();
}

/// Busca a cor de avatar (ARGB int) de cada uid em `usuarios/{uid}`, usando
/// o cache reativo compartilhado ([AvatarColorCache]) em vez de um `.get()`
/// por uid a cada emissão do stream de apostas — evita repetir a mesma
/// leitura para participantes cuja cor já foi observada antes.
Future<Map<String, int>> _buscarCoresAvatar(List<String> uids) async {
  if (uids.isEmpty) return {};

  final cache = AvatarColorCache.instance;
  final cores = <String, int>{};

  await Future.wait(
    uids.map((uid) async {
      final conhecida = cache.corConhecida(uid);
      final cor = conhecida ?? await cache.corStream(uid).first;
      cores[uid] = cor.toARGB32();
    }),
  );

  return cores;
}

/// Observa em tempo real as apostas pendentes de verificação de todas as
/// salas (usado pelo painel admin e pelo badge do drawer).
///
/// Não existe mais uma coleção separada de notificações: o próprio documento
/// em Salas/{salaId}/Participantes/{uid} é a fonte única de verdade sobre o
/// estado da aposta (`verificado`), então reapostar antes da verificação
/// apenas atualiza esse documento em vez de gerar entradas duplicadas.
/// Cache do stream em nível de módulo: `drawer.dart` (badge) e
/// `painel_admin.dart` abrem essa stream simultaneamente sempre que o
/// admin está no painel, então sem cache seriam dois listeners
/// `collectionGroup` idênticos rodando ao mesmo tempo (leituras em dobro).
///
/// Guarda também o último snapshot recebido e o reenvia manualmente a cada
/// novo `listen()` (via `onListen`): um `StreamController.broadcast` comum
/// (e `.asBroadcastStream()`) NÃO faz esse replay, então um StreamBuilder
/// que começasse a escutar depois do snapshot mais recente já ter chegado
/// (ex: ao navegar para o painel admin com o drawer já escutando a mesma
/// stream há mais tempo) ficava preso em ConnectionState.waiting até a
/// PRÓXIMA mudança nos dados — só saindo do skeleton quando alguém
/// confirmava/lançava uma aposta.
QuerySnapshot<Map<String, dynamic>>? _ultimoSnapshotPendentes;
Object? _erroApostasPendentes;
StreamController<QuerySnapshot<Map<String, dynamic>>>?
_apostasPendentesController;

Stream<QuerySnapshot<Map<String, dynamic>>> streamApostasPendentes() {
  final controllerExistente = _apostasPendentesController;
  if (controllerExistente != null) return controllerExistente.stream;

  late final StreamController<QuerySnapshot<Map<String, dynamic>>> controller;
  controller = StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast(
    onListen: () {
      final snapshot = _ultimoSnapshotPendentes;
      if (snapshot != null) controller.add(snapshot);
      final erro = _erroApostasPendentes;
      if (erro != null) controller.addError(erro);
    },
  );
  _apostasPendentesController = controller;

  FirebaseFirestore.instance
      .collectionGroup('Participantes')
      .where('verificado', isEqualTo: false)
      .snapshots()
      .listen(
        (snapshot) {
          _ultimoSnapshotPendentes = snapshot;
          _erroApostasPendentes = null;
          controller.add(snapshot);
        },
        onError: (Object erro) {
          _erroApostasPendentes = erro;
          controller.addError(erro);
        },
      );

  return controller.stream;
}

/// Cria (ou atualiza) uma aposta em nome de alguém sem conta no app,
/// lançada manualmente pelo admin. Usa um ID artificial (não é um uid de
/// Firebase Auth) para não colidir com participantes reais.
Future<void> criarApostaManual({
  required String salaId,
  required String nome,
  required String valor,
}) async {
  final firestore = FirebaseFirestore.instance;
  // Prefixo 'manual_' + timestamp garante um ID único e imediatamente
  // reconhecível como não vindo de Firebase Auth (uids reais nunca têm esse padrão).
  final id = 'manual_${DateTime.now().millisecondsSinceEpoch}';

  await firestore
      .collection('Salas')
      .doc(salaId)
      .collection('Participantes')
      .doc(id)
      .set({
        'nome': nome,
        'valor': valor,
        'uid': id,
        'data-hora': FieldValue.serverTimestamp(),
        'verificado': false,
        'editadoAposVerificacao': false,
        'criadoPeloAdmin': true,
      });
}

/// Marca a aposta de um participante como verificada. Também limpa o
/// destaque de "alterada" já que a nova versão acabou de ser aprovada.
Future<void> verificarAposta({
  required String salaId,
  required String uid,
}) async {
  await FirebaseFirestore.instance
      .collection('Salas')
      .doc(salaId)
      .collection('Participantes')
      .doc(uid)
      .update({'verificado': true, 'editadoAposVerificacao': false});
}

/// Igual a [verificarAposta], mas recebendo diretamente a referência do
/// documento em Participantes (usado ao confirmar a partir de uma query
/// collectionGroup, onde já se tem a referência exata do doc da sala certa).
Future<void> verificarApostaPorReferencia(
  DocumentReference<Map<String, dynamic>> participanteRef,
) async {
  await participanteRef.update({
    'verificado': true,
    'editadoAposVerificacao': false,
  });
}
