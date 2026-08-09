import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bolao_bolado/services/avatar/avatar_service.dart';
import 'package:bolao_bolado/services/bet/preco_cota.dart';

/// UID fixo da sala principal do Bolão Bolado.
/// Sempre validado dinamicamente via campo `principal: true` no Firestore,
/// nunca assumido só pelo valor da constante (ver buscarSalaPrincipalId()).
const String kSalaPrincipalIdFallback = '9DvtjeS3gzyNyhFkqaF5';

/// Descoberta da sala principal memoizada por sessão do app.
///
/// `buscarSalaPrincipalId()` era chamada de cinco pontos diferentes numa
/// única carga da tela de Participantes (getDadosSalaPrincipal, streamBets
/// pela página, streamBets e streamSalaPrincipal pelo MinhaApostaCard,
/// _carregarDados do MinhaApostaCard) e cada chamada era uma query de rede
/// própria — cinco round-trips seriais só para redescobrir o mesmo ID. Em
/// rede lenta isso sozinho já custava vários segundos de skeleton.
///
/// Guarda o *Future* e não o valor: chamadas concorrentes (o caso normal
/// aqui, já que a página e o card montam juntos) compartilham a mesma query
/// em vez de dispararem várias em paralelo.
///
/// Qual sala é a principal só muda via console/admin SDK — o app nunca
/// grava `principal` (as regras proíbem criar sala com `principal: true`),
/// então congelar essa identidade por sessão é seguro. Os dados da sala em
/// si (prêmio, sorteio, chave PIX) continuam ao vivo via [streamSalaPrincipal].
Future<DocumentSnapshot<Map<String, dynamic>>>? _salaPrincipalFuture;

Future<DocumentSnapshot<Map<String, dynamic>>> _carregarSalaPrincipal() async {
  final firestore = FirebaseFirestore.instance;
  final query = await firestore
      .collection('Salas')
      .where('principal', isEqualTo: true)
      .limit(1)
      .get();

  if (query.docs.isNotEmpty) return query.docs.first;

  // Fallback de segurança: usa o ID conhecido se a query falhar
  // (ex: regra de segurança bloqueando query, mas permitindo doc direto)
  return firestore.collection('Salas').doc(kSalaPrincipalIdFallback).get();
}

/// Snapshot da sala marcada como `principal: true`, resolvido uma vez por
/// sessão (ver [_salaPrincipalFuture]). A query já devolve o documento
/// inteiro, então quem precisa dos dados da sala não paga um `.get()` extra.
Future<DocumentSnapshot<Map<String, dynamic>>> buscarSalaPrincipal() {
  final emAndamento = _salaPrincipalFuture;
  if (emAndamento != null) return emAndamento;

  final future = _carregarSalaPrincipal();
  _salaPrincipalFuture = future;

  // Falha de rede não pode ficar memoizada: sem isso, um erro na primeira
  // tentativa (ex: wifi caindo no meio do carregamento) deixaria o app sem
  // sala principal até recarregar a página inteira. O `identical` evita que
  // um erro atrasado descarte uma tentativa mais nova já em andamento.
  unawaited(
    future.then(
      (_) {},
      onError: (Object _) {
        if (identical(_salaPrincipalFuture, future)) {
          _salaPrincipalFuture = null;
        }
      },
    ),
  );

  return future;
}

/// Busca dinamicamente o ID da sala marcada como `principal: true`.
/// Nunca assume o ID fixo sem confirmar no Firestore.
Future<String> buscarSalaPrincipalId() async {
  return (await buscarSalaPrincipal()).id;
}

/// Observa em tempo real o documento da sala principal (prêmio, sorteio,
/// chave PIX). Usado pelo card "Minha Aposta" para refletir mudanças feitas
/// pelo admin sem precisar recarregar a tela.
Stream<DocumentSnapshot<Map<String, dynamic>>> streamSalaPrincipal() async* {
  final sala = await buscarSalaPrincipal();
  // Só o ID vem do snapshot memoizado; os dados saem sempre do `snapshots()`
  // ao vivo. Reemitir o snapshot memoizado aqui adiantaria um frame, mas
  // faria o card piscar um prêmio/chave PIX velho se a sessão estivesse
  // aberta há bastante tempo — inaceitável numa tela que mostra dinheiro.
  yield* sala.reference.snapshots();
}

/// Lê uma vez os dados (sorteio, data, prêmio) da sala principal.
/// Usado pelo painel admin, que trabalha com uma leitura pontual em vez de
/// stream. Relê o documento em vez de devolver o snapshot memoizado: o ID
/// da sala não muda durante a sessão, mas prêmio e data do sorteio mudam, e
/// devolver um valor velho aqui mostraria dinheiro errado na tela.
Future<Map<String, dynamic>> getDadosSalaPrincipal() async {
  final sala = await buscarSalaPrincipal();
  final atual = await sala.reference.get();
  return {'salaId': sala.id, ...?atual.data()};
}

/// Lê todos os participantes/apostas da sala principal.
/// Fonte: Salas/{salaPrincipalId}/Participantes/{uid}
Future<List<Map<String, Object?>>> getBets() async {
  final sala = await buscarSalaPrincipal();
  // Prêmio e preço de cota saem de uma releitura (mesmo motivo de
  // getDadosSalaPrincipal: o rateio não pode ser calculado com prêmio
  // velho), mas a query de descoberta da sala já foi paga uma vez só.
  final atual = await sala.reference.get();
  final premioSala = (atual.data()?['premio'] as num?)?.toDouble() ?? 0;
  final precoCota = precoCotaPara(atual.data()?['sorteio']?.toString());

  final snapshot = await sala.reference
      .collection('Participantes')
      .orderBy('data-hora', descending: true)
      .get();

  return _montarParticipantes(snapshot.docs, premioSala, precoCota);
}

/// Observa em tempo real os participantes/apostas da sala principal.
/// Emite uma nova lista sempre que qualquer aposta é criada, editada ou
/// removida em Salas/{salaPrincipalId}/Participantes.
///
/// Cache do stream em nível de módulo: a tela de Participantes e o card
/// "Minha Aposta" ficam montados ao mesmo tempo e os dois escutam esta
/// stream. Sem o cache, cada um abria seu PRÓPRIO par de listeners (doc da
/// sala + query de Participantes) e rodava `_montarParticipantes` — ou
/// seja, o dobro de listeners e o dobro de resolução de avatares por
/// evento, tudo competindo pela mesma conexão.
///
/// Reemite a última lista conhecida para cada novo assinante. O replay é
/// feito aqui, e não pelo `onListen` do broadcast, porque `onListen` só
/// dispara quando o número de ouvintes vai de 0 para 1 — com a página e o
/// card assinando em momentos diferentes, quem chegasse por último ficaria
/// preso em `ConnectionState.waiting` até a próxima aposta mudar.
List<Map<String, Object?>>? _ultimasApostas;
StreamController<List<Map<String, Object?>>>? _apostasController;

Stream<List<Map<String, Object?>>> streamBets() async* {
  final apostas = _garantirStreamApostas().stream;

  final ultimas = _ultimasApostas;
  if (ultimas != null) yield ultimas;

  yield* apostas;
}

StreamController<List<Map<String, Object?>>> _garantirStreamApostas() {
  final existente = _apostasController;
  if (existente != null) return existente;

  // Mantido aberto de propósito enquanto estiver saudável (compartilhado
  // entre a página de Participantes e o card Minha Aposta). Fechá-lo a cada
  // desmontagem destruiria o cache dos listeners e faria voltar à tela
  // custar uma carga inteira de novo, então close_sinks não se aplica aqui.
  // ignore: close_sinks
  final controller = StreamController<List<Map<String, Object?>>>.broadcast();
  _apostasController = controller;

  _apostasDaSalaPrincipal().listen(
    (apostas) {
      _ultimasApostas = apostas;
      controller.add(apostas);
    },
    onError: (Object erro) {
      // Solta o cache antes de propagar: sem isso uma falha de rede na
      // primeira carga congelaria a stream compartilhada e nenhuma tela
      // voltaria a receber apostas sem recarregar a página inteira. Assim,
      // a próxima chamada de streamBets() reabre os listeners do zero.
      _apostasController = null;
      controller.addError(erro);
      controller.close();
    },
  );

  return controller;
}

Stream<List<Map<String, Object?>>> _apostasDaSalaPrincipal() async* {
  final sala = await buscarSalaPrincipal();

  final salaStream = sala.reference.snapshots();
  final participantesStream = sala.reference
      .collection('Participantes')
      .orderBy('data-hora', descending: true)
      .snapshots();

  double premioSala = 0;
  double precoCota = kPrecoCotaMega;
  List<QueryDocumentSnapshot<Map<String, dynamic>>>? ultimosDocs;

  await for (final evento in _combinarStreams(
    salaStream,
    participantesStream,
    // Avatares entram como uma terceira fonte de eventos: a lista é montada
    // na hora com os avatares já conhecidos e remontada quando os que
    // faltavam chegam (ver AvatarColorCache.mudancas). Quem observa cada uid
    // é o AvatarDoParticipante da linha visível.
    AvatarColorCache.instance.mudancas,
  )) {
    if (evento.$1 != null) {
      premioSala = (evento.$1!.data()?['premio'] as num?)?.toDouble() ?? 0;
      precoCota = precoCotaPara(evento.$1!.data()?['sorteio']?.toString());
    }
    if (evento.$2 != null) {
      ultimosDocs = evento.$2!.docs;
    }
    if (ultimosDocs != null) {
      yield _montarParticipantes(ultimosDocs, premioSala, precoCota);
    }
  }
}

/// Combina os três streams (dados da sala + participantes + avisos de
/// avatar) em um único stream de tuplas, emitindo sempre que qualquer um
/// deles atualizar. O aviso de avatar não carrega dado nenhum: só serve para
/// a lista ser remontada com os avatares que acabaram de chegar.
Stream<
  (
    DocumentSnapshot<Map<String, dynamic>>?,
    QuerySnapshot<Map<String, dynamic>>?,
  )
>
_combinarStreams(
  Stream<DocumentSnapshot<Map<String, dynamic>>> salaStream,
  Stream<QuerySnapshot<Map<String, dynamic>>> participantesStream,
  Stream<void> avataresStream,
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
  subs.add(
    // Sem onError: uma falha ao ler o avatar de alguém não pode derrubar a
    // lista de apostas inteira — no pior caso o avatar fica no padrão.
    avataresStream.listen((_) => controller.add((null, null))),
  );

  controller.onCancel = () async {
    for (final sub in subs) {
      await sub.cancel();
    }
    // Fecha o próprio controller ao cancelar: sem isso o StreamController
    // fica alocado mesmo depois que ninguém mais escuta o stream combinado.
    await controller.close();
  };

  return controller.stream;
}

/// Monta a lista de apostas **sem esperar rede**.
///
/// Os avatares entram só se já estiverem em memória. Nenhuma leitura é
/// disparada aqui: quem observa um uid é o `AvatarDoParticipante` da linha
/// visível, e o que ele descobre chega numa emissão seguinte desta mesma
/// stream (o aviso vem por `AvatarColorCache.mudancas`, combinado em
/// [_apostasDaSalaPrincipal]).
///
/// Antes esta função era `async` e esperava uma leitura de `usuarios/{uid}`
/// por participante antes de devolver qualquer linha: numa sala de 11
/// apostas isso segurava a tela inteira por ~960ms dos ~1500ms de
/// carregamento, para uma informação puramente decorativa.
List<Map<String, Object?>> _montarParticipantes(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  double premioSala,
  double precoCota,
) {
  final cache = AvatarColorCache.instance;

  final participantes = docs.map((doc) {
    final dados = doc.data();
    final uid = doc.id; // doc ID É o uid do usuário logado
    // Só o que já está em memória: nenhuma leitura é disparada aqui.
    //
    // Antes esta função chamava `cache.aquecer` com TODOS os uids, e como o
    // cache abre um `snapshots()` por uid, uma sala de 300 apostas abria 300
    // listeners do Firestore de uma vez no F5 — todos concorrendo com o chat
    // e o card "Minha Aposta" pela mesma conexão, que por isso demoravam a
    // carregar. Quem observa um uid agora é o `AvatarDoParticipante` da linha
    // que está VISÍVEL, então o custo acompanha a tela e não o tamanho da
    // sala. Estes campos seguem preenchidos para quem já é conhecido, o que
    // evita o avatar piscar no estado neutro ao rolar de volta.
    final avatar = cache.avatarConhecido(uid);
    return {
      'uid': uid,
      'nome': dados['nome']?.toString() ?? '',
      'valor': dados['valor'],
      'data-hora': dados['data-hora'],
      // Uma escrita com `FieldValue.serverTimestamp()` aparece no cache local
      // ANTES de o servidor responder, e nesse intervalo `data-hora` vem
      // `null`. Ordenar por data tratava esse null como época zero, então a
      // aposta recém-criada nascia na ÚLTIMA linha e só depois pulava para o
      // topo — o salto que se via ao simular apostas.
      //
      // `hasPendingWrites` é exatamente o sinal de "ainda não confirmado pelo
      // servidor": quem o tem e está sem data é uma escrita de agora, não uma
      // aposta antiga sem timestamp. Ver `dataHoraOrdenacao`.
      'pendente': doc.metadata.hasPendingWrites,
      'verificado': dados['verificado'] == true,
      'editadoAposVerificacao': dados['editadoAposVerificacao'] == true,
      // Também aceita o prefixo do ID como sinal: apostas lançadas antes de
      // `criadoPeloAdmin` existir só têm o `manual_` do ID artificial gerado
      // por criarApostaManual().
      'criadoPeloAdmin':
          dados['criadoPeloAdmin'] == true || uid.startsWith('manual_'),
      'avatarColor': avatar?.cor.toARGB32(),
      'avatarEmoji': avatar?.emoji,
    };
  }).toList();

  return calcularCotasEPremios(participantes, premioSala, precoCota);
}

/// Posição de ordenação já atribuída a apostas que apareceram pendentes.
///
/// Chaveado pelo uid. Uma vez que a linha entrou na tela num lugar, ela
/// continua valendo aquele número mesmo depois de o servidor confirmar — é o
/// que impede a segunda mudança de posição. Ver [dataHoraOrdenacao].
final Map<String, int> _ordemDeChegada = {};

/// Esquece as posições memorizadas de apostas que não estão mais na lista.
///
/// Sem isso o mapa cresceria para sempre numa sessão longa, e uma aposta
/// removida e recriada herdaria a posição antiga em vez da nova.
void esquecerOrdemDeChegada(Iterable<String> uidsPresentes) {
  if (_ordemDeChegada.isEmpty) return;
  final presentes = uidsPresentes.toSet();
  _ordemDeChegada.removeWhere((uid, _) => !presentes.contains(uid));
}

/// Valor em milissegundos usado para ORDENAR uma linha por "Última
/// Alteração".
///
/// Resolve o caso da aposta recém-escrita: entre o clique e a confirmação do
/// servidor, o doc já existe no cache local mas `data-hora`
/// (`FieldValue.serverTimestamp()`) ainda é `null`. Tratar esse null como 0
/// jogava a linha para o fim da tabela, e ela pulava para o topo quando o
/// servidor respondia.
///
/// **O valor precisa ser ESTÁVEL, não só plausível.** Devolver
/// `DateTime.now()` só enquanto pendente resolvia a posição inicial mas
/// criava um SEGUNDO salto: o "agora" do cliente não é o mesmo instante que
/// o servidor grava, então na confirmação a linha mudava de lugar de novo —
/// ela animava a entrada e logo era mandada para outra posição, que é
/// exatamente o defeito visível ao simular várias apostas seguidas.
///
/// Por isso, uma vez que uma aposta apareceu pendente e recebeu um lugar,
/// ela MANTÉM esse lugar enquanto estiver na lista, mesmo depois de
/// confirmada. A diferença para o timestamp real é de milissegundos e não
/// muda a ordem percebida; o que importa é a linha não se mexer duas vezes.
///
/// Um `null` SEM escrita pendente continua valendo 0: aí é mesmo uma aposta
/// antiga sem timestamp, e o lugar dela é o fim da lista.
int dataHoraOrdenacao(Object? dataHora, {required bool pendente, String? uid}) {
  // Aposta que já entrou na tela pendente mantém o lugar que recebeu.
  if (uid != null) {
    final memorizado = _ordemDeChegada[uid];
    if (memorizado != null) return memorizado;
  }

  if (dataHora is Timestamp) return dataHora.millisecondsSinceEpoch;
  if (!pendente) return 0;

  final agora = DateTime.now().millisecondsSinceEpoch;
  if (uid != null) _ordemDeChegada[uid] = agora;
  return agora;
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

  // Cache singleton em nível de módulo: este controller é intencionalmente
  // mantido aberto por toda a vida do app (compartilhado entre o badge do
  // drawer e o painel admin). Fechá-lo destruiria o cache do listener
  // collectionGroup, então o lint close_sinks não se aplica aqui.
  // ignore: close_sinks
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

/// Atualiza campos editáveis da sala principal direto do painel admin
/// (prêmio, data/hora do sorteio, chave PIX, valor máximo de aposta), sem
/// passar pela tela de cadastro. Só grava as chaves presentes em [dados],
/// então dá pra editar um campo sem sobrescrever os outros.
Future<void> atualizarDadosSala({
  required String salaId,
  required Map<String, Object?> dados,
}) async {
  if (dados.isEmpty) return;
  await FirebaseFirestore.instance
      .collection('Salas')
      .doc(salaId)
      .update(dados);
}

/// Edita o valor apostado de um participante já existente. Ao mudar o valor
/// de uma aposta já verificada, marca `editadoAposVerificacao: true` para o
/// admin revisar de novo (a aposta volta a aparecer como pendente de
/// re-verificação), espelhando o fluxo de quando o próprio usuário reaposta.
Future<void> editarValorAposta({
  required String salaId,
  required String uid,
  required String valor,
  required bool estavaVerificado,
}) async {
  await FirebaseFirestore.instance
      .collection('Salas')
      .doc(salaId)
      .collection('Participantes')
      .doc(uid)
      .update({
        'valor': valor,
        if (estavaVerificado) 'editadoAposVerificacao': true,
      });
}

/// Remove por completo a aposta de um participante da sala. Ação
/// destrutiva: o documento em Participantes deixa de existir e o
/// participante some do rateio de cotas/prêmios.
Future<void> removerAposta({
  required String salaId,
  required String uid,
}) async {
  await FirebaseFirestore.instance
      .collection('Salas')
      .doc(salaId)
      .collection('Participantes')
      .doc(uid)
      .delete();
}

/// Teto de operações por WriteBatch do Firestore é 500; 400 deixa folga.
const int _loteExclusaoApostas = 400;

/// Remove TODAS as apostas da sala e devolve quantas foram apagadas.
///
/// Ação destrutiva e sem desfazer: a sala volta a zero participante, e o
/// rateio de cotas/prêmios é recalculado do zero. Só o painel admin chama.
///
/// Apaga em páginas de [_loteExclusaoApostas] em vez de num `get()` único:
/// o batch do Firestore tem teto de 500 operações, então uma sala grande
/// estouraria o commit. O loop pára quando a página vem incompleta — sinal
/// de que era a última.
Future<int> removerTodasApostas({required String salaId}) async {
  final colecao = FirebaseFirestore.instance
      .collection('Salas')
      .doc(salaId)
      .collection('Participantes');

  var apagadas = 0;
  while (true) {
    final pagina = await colecao.limit(_loteExclusaoApostas).get();
    if (pagina.docs.isEmpty) break;

    final lote = FirebaseFirestore.instance.batch();
    for (final doc in pagina.docs) {
      lote.delete(doc.reference);
    }
    await lote.commit();
    apagadas += pagina.docs.length;

    if (pagina.docs.length < _loteExclusaoApostas) break;
  }
  return apagadas;
}

/// Alterna o estado de verificação de uma aposta (verificado ⇄ pendente).
/// Ao reverter para pendente, também limpa `editadoAposVerificacao` para o
/// card não acumular os dois destaques ao mesmo tempo.
Future<void> alternarVerificacao({
  required String salaId,
  required String uid,
  required bool verificar,
}) async {
  await FirebaseFirestore.instance
      .collection('Salas')
      .doc(salaId)
      .collection('Participantes')
      .doc(uid)
      .update({'verificado': verificar, 'editadoAposVerificacao': false});
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
