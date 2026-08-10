import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Cor exclusiva da conta admin. Serve apenas de base para gerar as
/// cores de avatar dos demais usuários — nunca é sorteada para eles.
///
/// Quem é admin é decidido pelo campo `isAdmin` em `usuarios/{uid}` (mesma
/// fonte de verdade usada pelas Firestore rules e pelo painel admin), não
/// mais por um e-mail fixo no código — assim a identidade do admin pode
/// mudar sem precisar editar o app.
const Color kCorBaseAdmin = Color(0xFF7400C7);

/// 16 cores derivadas de [kCorBaseAdmin] variando matiz/luminosidade em torno
/// da cor base, usadas como fundo do círculo do avatar.
final List<Color> kCoresAvatar = _gerarPaletaAvatares();

List<Color> _gerarPaletaAvatares() {
  final base = HSLColor.fromColor(kCorBaseAdmin);
  final cores = <Color>[];

  // 8 variações de matiz ao redor da base, em duas luminosidades.
  const deslocamentosHue = [30, 60, 90, 120, 150, 200, 260, 320];

  // Saturação abaixo da base (que é 1.0) e luminosidades mais próximas entre
  // si do que antes (0.42/0.58). O fundo do avatar é palco, não protagonista:
  // com saturação máxima o círculo vibrava contra o emoji desenhado por cima
  // e as duas faixas de luminosidade brigavam entre si na mesma lista. Amarelo
  // e ciano puros ainda por cima chegavam quase brancos, apagando emojis
  // claros. Aqui todas as 16 ficam num contraste parecido, escuras o bastante
  // para qualquer emoji se destacar.
  const luminosidades = [0.40, 0.50];
  const saturacao = 0.62;

  for (final l in luminosidades) {
    for (final deslocamento in deslocamentosHue) {
      final hue = (base.hue + deslocamento) % 360;
      final cor = HSLColor.fromAHSL(1.0, hue, saturacao, l).toColor();
      cores.add(cor);
    }
  }

  return cores;
}

/// Uma categoria de emojis do seletor de avatar.
///
/// O agrupamento não é só cosmético: com uma lista única de 30 emojis o
/// usuário varria tudo pra achar "aquele do macaco". Em grupos rotulados ele
/// vai direto na seção certa.
class CategoriaEmojiAvatar {
  final String nome;
  final List<String> emojis;

  const CategoriaEmojiAvatar(this.nome, this.emojis);
}

/// Emojis disponíveis para avatar, agrupados por tema.
///
/// Todos foram escolhidos para continuarem legíveis a ~14px sobre um círculo
/// colorido — que é o tamanho real em que aparecem na lista de participantes
/// e no chat. Isso descarta duas famílias que estavam aqui antes:
///
/// - **Silhuetas finas / muito detalhadas** (🦋, 🐙, 🎰, 🍕): viram uma mancha
///   indistinta nesse tamanho.
/// - **Pares quase idênticos em miniatura** (⭐ vs 🌟, 🔥 vs ⚡, 🎲 vs 🎯):
///   dois usuários com avatares diferentes pareciam ter o mesmo.
///
/// A preferência é por formas compactas e de alto contraste — rostos de
/// animais em vez de corpo inteiro, objetos com silhueta fechada.
const List<CategoriaEmojiAvatar> kCategoriasEmojiAvatar = [
  CategoriaEmojiAvatar('Sorte', [
    '🍀',
    '🎲',
    '🏆',
    '💰',
    '💎',
    '🔮',
    '🎯',
    '🧿',
  ]),
  CategoriaEmojiAvatar('Bichos', [
    '🦁',
    '🐯',
    '🐵',
    '🦊',
    '🐼',
    '🐨',
    '🐷',
    '🐶',
    '🐱',
    '🐮',
    '🐸',
    '🦉',
  ]),
  CategoriaEmojiAvatar('Caras', [
    '😎',
    '🤠',
    '🤑',
    '🥳',
    '🤖',
    '👽',
    '👻',
    '🤡',
  ]),
  CategoriaEmojiAvatar('Coisas', [
    '🔥',
    '⚡',
    '🚀',
    '⚽',
    '🏀',
    '🍕',
    '🍔',
    '🎸',
  ]),
];

/// Lista plana de todos os emojis, na ordem das categorias.
///
/// Mantida para quem só precisa sortear ou indexar (ex.: emoji determinístico
/// por nome na lista de participantes) sem se importar com o agrupamento.
final List<String> kEmojisAvatar = [
  for (final categoria in kCategoriasEmojiAvatar) ...categoria.emojis,
];

const String kEmojiAvatarPadrao = '🍀';

/// Cinza do avatar de quem ainda não escolheu cor — e do estado de espera,
/// enquanto o documento do usuário não chegou do Firestore.
const Color kCorAvatarNeutra = Color(0xFFE5E7EB);

class AvatarService {
  /// Sorteia uma cor aleatória dentre as 16 disponíveis (nunca a cor base do admin)
  /// e retorna seu valor ARGB como inteiro, para persistir no Firestore.
  static int sortearCorAleatoria() {
    final random = Random();
    final cor = kCoresAvatar[random.nextInt(kCoresAvatar.length)];
    return cor.toARGB32();
  }

  /// Sorteia um emoji aleatório dentre os disponíveis.
  static String sortearEmojiAleatorio() {
    final random = Random();
    return kEmojisAvatar[random.nextInt(kEmojisAvatar.length)];
  }

  /// Salva a cor de avatar escolhida no Firestore
  static Future<void> salvarCor(int corValue) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance.collection('usuarios').doc(uid).set({
      'avatarColor': corValue,
    }, SetOptions(merge: true));
  }

  /// Salva o emoji de avatar escolhido no Firestore
  static Future<void> salvarEmoji(String emoji) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance.collection('usuarios').doc(uid).set({
      'avatarEmoji': emoji,
    }, SetOptions(merge: true));
  }

  /// Cor e emoji do avatar derivados de um documento `usuarios/{uid}` **já
  /// lido**, sorteando em memória o que estiver faltando.
  ///
  /// Função pura, sem Firestore: quem chama decide se relê o documento
  /// ([buscarAvatar]) ou se aproveita um que já tem em mãos. Era isso que
  /// faltava — `buscarCor` e `buscarEmoji` liam o MESMO documento cada uma por
  /// sua conta, e quem também precisava do `isAdmin` (o drawer) lia uma
  /// terceira vez. Três leituras cobradas para o mesmo `usuarios/{uid}` só
  /// para abrir o menu.
  ///
  /// Regras preservadas: `avatarColor`/`avatarEmoji` gravados sempre têm
  /// prioridade; a conta admin cai em [kCorBaseAdmin] enquanto não tiver cor
  /// própria; e [faltava] avisa que algo foi sorteado agora e merece ser
  /// persistido — decisão de quem chama, porque usuário sem documento
  /// (anônimo) recebe valores só em memória.
  static ({Color cor, String emoji, bool faltava}) avatarDeDados(
    Map<String, dynamic>? dados,
  ) {
    final corValue = dados?['avatarColor'] as int?;
    final emojiSalvo = dados?['avatarEmoji'] as String?;
    final temEmoji = emojiSalvo != null && emojiSalvo.isNotEmpty;

    // Sem documento em `usuarios` (ex.: anônimo) nunca é admin — admin sempre
    // tem doc com isAdmin: true.
    final cor = corValue != null
        ? Color(corValue)
        : (dados?['isAdmin'] == true
              ? kCorBaseAdmin
              : Color(sortearCorAleatoria()));

    return (
      cor: cor,
      emoji: temEmoji ? emojiSalvo : sortearEmojiAleatorio(),
      // A cor do admin é um padrão calculado, não um sorteio a persistir.
      faltava: (corValue == null && dados?['isAdmin'] != true) || !temEmoji,
    );
  }

  /// Grava cor e/ou emoji sorteados por [avatarDeDados], num `set` só.
  ///
  /// Só grava o que realmente faltava no documento — passar os dois campos
  /// sempre sobrescreveria uma escolha que o usuário já tinha feito.
  static Future<void> persistirAvatar(
    String uid, {
    required Map<String, dynamic>? dados,
    required Color cor,
    required String emoji,
  }) async {
    final campos = <String, Object?>{
      if (dados?['avatarColor'] == null && dados?['isAdmin'] != true)
        'avatarColor': cor.toARGB32(),
      if ((dados?['avatarEmoji'] as String?)?.isNotEmpty != true)
        'avatarEmoji': emoji,
    };
    if (campos.isEmpty) return;

    await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(uid)
        .set(campos, SetOptions(merge: true));
  }

  /// Cor e emoji do avatar do usuário, resolvidos numa leitura só.
  ///
  /// Substitui o par `buscarCor`/`buscarEmoji`, que lia o mesmo documento duas
  /// vezes e podia disparar dois `set` separados para preencher o que faltava.
  /// Quem já tem o documento em mãos deve usar [avatarDeDados] direto, sem
  /// nenhuma leitura.
  static Future<({Color cor, String emoji})> buscarAvatar(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(uid)
        .get();

    final dados = doc.exists ? doc.data() : null;
    final avatar = avatarDeDados(dados);

    // Sem documento não há o que persistir: usuário anônimo recebe os valores
    // sorteados apenas em memória, como antes.
    if (avatar.faltava && doc.exists) {
      await persistirAvatar(
        uid,
        dados: dados,
        cor: avatar.cor,
        emoji: avatar.emoji,
      );
    }

    return (cor: avatar.cor, emoji: avatar.emoji);
  }
}

/// Cache reativo de cores e emojis de avatar por uid, compartilhado entre
/// chat e lista de participantes/apostas.
///
/// Sem isso, cada bolha de mensagem no chat (`FutureBuilder` por item) e
/// cada emissão de `streamBets()` disparavam um `.get()` no Firestore por
/// uid — N leituras a cada mensagem nova ou aposta alterada. Aqui, cada uid
/// é observado por uma única `snapshots()` compartilhada entre todos os
/// consumidores: a cor/emoji são buscados uma vez e depois atualizados
/// automaticamente caso o usuário os troque, sem exigir novas buscas manuais.
class AvatarColorCache {
  AvatarColorCache._();
  static final AvatarColorCache instance = AvatarColorCache._();

  final Map<String, Stream<DocumentSnapshot<Map<String, dynamic>>>> _docs = {};
  final Map<String, Stream<Color>> _streams = {};
  final Map<String, Color> _ultimoValor = {};

  final Map<String, Stream<String>> _emojiStreams = {};
  final Map<String, String> _ultimoEmoji = {};

  final Map<String, Stream<({Color cor, String emoji})>> _avatarStreams = {};

  /// Assinatura interna de cada uid observado, guardada só para poder ser
  /// cancelada em [_soltar]. Sem isto o listener do `snapshots()` ficava
  /// inalcançável depois de criado — o cache só crescia.
  final Map<String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>
  _assinaturas = {};

  /// Ordem de último uso de cada uid (contador crescente, não relógio: só a
  /// ordem relativa importa e assim não há dependência de horário do sistema).
  final Map<String, int> _ultimoUso = {};
  int _relogioDeUso = 0;

  void _tocar(String uid) => _ultimoUso[uid] = _relogioDeUso++;

  /// Avisa que este uid está sendo DESENHADO agora, renovando a posição dele na
  /// fila de descarte ([_podarObservados]).
  ///
  /// Existe porque um avatar já resolvido é desenhado direto do último valor
  /// conhecido, sem assinar stream nenhuma (ver `AvatarDoParticipante`) — então
  /// sem este aviso a linha na tela há mais tempo pareceria a mais ociosa de
  /// todas, e seria a primeira a perder o listener.
  ///
  /// Não confundir com [avatarConhecido] e companhia, que são leituras PURAS:
  /// elas também são chamadas em massa para montar a lista inteira (inclusive o
  /// que está fora da tela), e renovar a fila ali diria que tudo está em uso.
  void tocarSeObservado(String uid) {
    if (_docs.containsKey(uid)) _tocar(uid);
  }

  // Compartilhado por toda a vida do app junto com o próprio cache
  // (singleton), por isso não é fechado.
  // ignore: close_sinks
  final StreamController<void> _mudancas = StreamController<void>.broadcast();
  Timer? _debounceMudancas;

  /// Avisa que algum avatar conhecido mudou (ou acabou de ser descoberto).
  ///
  /// Serve para a lista de apostas poder ser montada na hora, só com o que
  /// já está em memória, e se recompor depois quando os avatares chegarem —
  /// em vez de segurar a tela inteira esperando uma leitura por participante.
  Stream<void> get mudancas => _mudancas.stream;

  // Agrupa a enxurrada de avisos: os N documentos de uma lista chegam
  // praticamente juntos, e emitir um evento por documento faria a lista ser
  // remontada N vezes seguidas.
  void _notificarMudanca() {
    _debounceMudancas?.cancel();
    _debounceMudancas = Timer(const Duration(milliseconds: 80), () {
      if (!_mudancas.isClosed) _mudancas.add(null);
    });
  }

  /// Um único listener por uid, compartilhado entre cor e emoji.
  ///
  /// Cor e emoji saem do MESMO documento `usuarios/{uid}`, mas antes cada um
  /// abria seu próprio `snapshots()` — dois listeners por participante da
  /// lista (e por autor de mensagem no chat) trazendo exatamente os mesmos
  /// bytes. Numa sala com 20 apostas isso eram 40 listeners abertos em vez
  /// de 20, todos concorrendo pela mesma conexão na primeira carga.
  Stream<DocumentSnapshot<Map<String, dynamic>>> _docStream(String uid) {
    _tocar(uid);
    final existente = _docs[uid];
    if (existente != null) return existente;

    final stream = FirebaseFirestore.instance
        .collection('usuarios')
        .doc(uid)
        .snapshots()
        .asBroadcastStream();
    _docs[uid] = stream;

    // Registrado antes de qualquer outro assinante, então os "últimos
    // valores conhecidos" já estão preenchidos quando alguém consulta
    // corConhecida/emojiConhecido depois do primeiro evento.
    _assinaturas[uid] = stream.listen((doc) {
      final dados = doc.data();
      final cor = _corDe(dados);
      final emoji = _emojiDe(dados);
      final mudou = _ultimoValor[uid] != cor || _ultimoEmoji[uid] != emoji;
      _ultimoValor[uid] = cor;
      _ultimoEmoji[uid] = emoji;
      if (mudou) _notificarMudanca();
    });

    _podarObservados();
    return stream;
  }

  static Color _corDe(Map<String, dynamic>? dados) {
    final corValue = dados?['avatarColor'] as int?;
    if (corValue != null) return Color(corValue);

    if (dados?['isAdmin'] == true) return kCorBaseAdmin;

    return kCorAvatarNeutra;
  }

  static String _emojiDe(Map<String, dynamic>? dados) {
    final emoji = dados?['avatarEmoji'] as String?;
    return (emoji != null && emoji.isNotEmpty) ? emoji : kEmojiAvatarPadrao;
  }

  /// Stream com a cor atual do avatar do [uid], atualizada em tempo real.
  ///
  /// A view derivada também é memoizada: `_BolhaMensagem` monta o
  /// StreamBuilder dentro do build(), e devolver um objeto de stream novo a
  /// cada rebuild faria o StreamBuilder cancelar e reassinar, voltando o
  /// avatar pro estado de carregamento a cada mensagem nova.
  Stream<Color> corStream(String uid) {
    return _streams.putIfAbsent(
      uid,
      () => _docStream(uid).map((doc) => _corDe(doc.data())),
    );
  }

  /// Último valor conhecido em memória (sem novas leituras), usado para
  /// não esperar o primeiro evento do stream ao montar listas grandes.
  Color? corConhecida(String uid) => _ultimoValor[uid];

  /// Stream com o emoji atual do avatar do [uid], atualizada em tempo real.
  Stream<String> emojiStream(String uid) {
    return _emojiStreams.putIfAbsent(
      uid,
      () => _docStream(uid).map((doc) => _emojiDe(doc.data())),
    );
  }

  /// Último emoji conhecido em memória (sem novas leituras).
  String? emojiConhecido(String uid) => _ultimoEmoji[uid];

  /// Cor e emoji juntos, em tempo real — o que um avatar precisa para ser
  /// desenhado.
  ///
  /// É esta a porta usada por `AvatarDoParticipante`, que resolve o avatar de
  /// UMA linha no momento em que ela aparece. Assinar esta stream começa a
  /// observar o uid: quem não está na tela não custa listener nenhum. Antes
  /// existia um `aquecer(uids)` que abria todos de uma vez, e numa sala de
  /// 300 apostas isso eram 300 listeners disputando a conexão no primeiro
  /// carregamento.
  ///
  /// Memoizada como as demais views: o StreamBuilder de cada linha é montado
  /// dentro do build(), e devolver um objeto novo a cada rebuild faria ele
  /// cancelar e reassinar, piscando o avatar de volta ao estado neutro.
  Stream<({Color cor, String emoji})> avatarStream(String uid) {
    return _avatarStreams.putIfAbsent(
      uid,
      () => _docStream(uid).map((doc) {
        final dados = doc.data();
        return (cor: _corDe(dados), emoji: _emojiDe(dados));
      }),
    );
  }

  /// Cor e emoji já em memória, sem nenhuma espera. `null` enquanto o uid
  /// ainda não foi observado — quem chama desenha o avatar neutro e recompõe
  /// quando [mudancas] avisar.
  ({Color cor, String emoji})? avatarConhecido(String uid) {
    final cor = _ultimoValor[uid];
    final emoji = _ultimoEmoji[uid];
    if (cor == null || emoji == null) return null;
    return (cor: cor, emoji: emoji);
  }

  /// Registra localmente a cor/emoji de um uid ANTES do Firestore confirmar
  /// a escrita — para quem acabou de sortear e gravar esses valores em
  /// `usuarios/{uid}` não precisar esperar o round-trip do `snapshots()`
  /// para a linha nova deixar de mostrar o avatar neutro.
  ///
  /// Não abre listener nenhum: se `_docStream(uid)` ainda não existe, o
  /// primeiro `snapshots()` (aberto quando a linha entra na tela) vai chegar
  /// depois e simplesmente confirmar o mesmo valor — como `mudou` dá `false`
  /// nesse caso, não gera segunda notificação nem segunda piscada.
  void anteciparAvatar(
    String uid, {
    required Color cor,
    required String emoji,
  }) {
    final mudou = _ultimoValor[uid] != cor || _ultimoEmoji[uid] != emoji;
    _ultimoValor[uid] = cor;
    _ultimoEmoji[uid] = emoji;
    if (mudou) _notificarMudanca();
  }

  /// Quantos uids podem ficar sendo observados ao mesmo tempo.
  ///
  /// O cache não soltava nada: cada uid observado (participante da lista, autor
  /// de mensagem do chat) deixava um `snapshots()` aberto até o app recarregar.
  /// Numa sessão longa, rolando salas grandes e um chat movimentado, isso é um
  /// listener acumulado por pessoa que passou pela tela — todos recebendo push
  /// do servidor para sempre.
  ///
  /// O teto é deliberadamente MUITO maior que uma tela (um viewport mostra ~15
  /// linhas de aposta e o chat carrega no máximo 100 mensagens). Isso importa
  /// porque o listener é o que mantém o avatar AO VIVO: se alguém troca o seu,
  /// é por ele que a mudança chega às telas abertas dos outros. Com folga
  /// grande, o uso normal nunca chega perto do limite e esse comportamento fica
  /// intacto; o teto existe só para a sessão que rolou por horas, onde os uids
  /// descartados são justamente os que ninguém está olhando há muito tempo.
  ///
  /// Mesmo descartado, o avatar continua sendo desenhado: o último valor
  /// conhecido é preservado (ver [_soltar]). O que se perde é só a atualização
  /// automática daquele uid — que volta assim que ele reaparecer e alguém
  /// pedir a stream de novo.
  static const int kMaxUidsObservados = 150;

  /// Fecha os listeners dos uids parados há mais tempo, até voltar ao teto.
  void _podarObservados() {
    if (_docs.length <= kMaxUidsObservados) return;

    // Ordena por último uso: os mais antigos saem primeiro. O uid que acabou de
    // ser criado é sempre o mais recente, então nunca é o escolhido — nenhum
    // StreamBuilder que ainda está esperando o primeiro evento é cortado.
    final porIdade = _docs.keys.toList()
      ..sort((a, b) => (_ultimoUso[a] ?? 0).compareTo(_ultimoUso[b] ?? 0));

    for (final uid in porIdade.take(_docs.length - kMaxUidsObservados)) {
      _soltar(uid);
    }
  }

  /// Para de observar um uid, fechando o listener do Firestore.
  ///
  /// Os últimos valores conhecidos (cor/emoji) são MANTIDOS de propósito: são
  /// baratos (dois campos por uid) e permitem redesenhar um avatar já visto sem
  /// piscar no estado neutro caso ele volte à tela. O que se solta aqui é a
  /// conexão viva, não a memória.
  ///
  /// As streams derivadas saem dos mapas junto: assim, se o uid voltar a ser
  /// pedido, [_docStream] abre uma assinatura nova em vez de devolver uma que
  /// já foi cancelada.
  void _soltar(String uid) {
    unawaited(_assinaturas.remove(uid)?.cancel());
    _docs.remove(uid);
    _streams.remove(uid);
    _emojiStreams.remove(uid);
    _avatarStreams.remove(uid);
    _ultimoUso.remove(uid);
  }
}
