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

/// 16 cores derivadas de [kCorBaseAdmin] variando matiz/saturação/luminosidade
/// em torno da cor base, usadas como fundo do círculo do avatar.
final List<Color> kCoresAvatar = _gerarPaletaAvatares();

List<Color> _gerarPaletaAvatares() {
  final base = HSLColor.fromColor(kCorBaseAdmin);
  final cores = <Color>[];

  // 8 variações de matiz ao redor da base, em duas luminosidades,
  // preservando saturação semelhante para manter a identidade visual.
  const deslocamentosHue = [30, 60, 90, 120, 150, 200, 260, 320];
  const luminosidades = [0.42, 0.58];

  for (final l in luminosidades) {
    for (final deslocamento in deslocamentosHue) {
      final hue = (base.hue + deslocamento) % 360;
      final cor = HSLColor.fromAHSL(1.0, hue, base.saturation, l).toColor();
      cores.add(cor);
    }
  }

  return cores;
}

/// Emojis disponíveis para avatar, escolhidos por combinarem com o tema do
/// app (bolão, jogos de azar, sorte, comemoração).
const List<String> kEmojisAvatar = [
  '🍀',
  '🎲',
  '🎰',
  '🏆',
  '💰',
  '🎉',
  '🔥',
  '⭐',
  '🚀',
  '🦁',
  '🐯',
  '🐸',
  '🐵',
  '🦊',
  '🐼',
  '🐨',
  '🦄',
  '🐙',
  '🐬',
  '🦉',
  '🐝',
  '🦋',
  '🌟',
  '⚡',
  '🎯',
  '🎈',
  '🍕',
  '⚽',
  '🏀',
  '😎',
];

const String kEmojiAvatarPadrao = '🍀';

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

  /// Busca a cor de avatar do usuário no Firestore.
  /// A cor salva em `avatarColor` sempre tem prioridade — a conta admin só
  /// recebe [kCorBaseAdmin] como valor padrão, enquanto nenhuma cor tiver
  /// sido gravada explicitamente. Usuários sem documento em `usuarios`
  /// (ex.: anônimos) recebem uma cor sorteada apenas em memória, sem
  /// tentar persistir.
  static Future<Color> buscarCor(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(uid)
        .get();

    // Sem documento em `usuarios` (ex.: anônimo) nunca é admin — admin sempre
    // tem doc com isAdmin: true. Só sorteia uma cor em memória.
    if (!doc.exists) {
      return Color(sortearCorAleatoria());
    }

    final corValue = doc.data()?['avatarColor'] as int?;
    if (corValue != null) return Color(corValue);

    if (doc.data()?['isAdmin'] == true) return kCorBaseAdmin;

    final novaCor = sortearCorAleatoria();
    await FirebaseFirestore.instance.collection('usuarios').doc(uid).set({
      'avatarColor': novaCor,
    }, SetOptions(merge: true));
    return Color(novaCor);
  }

  /// Busca o emoji de avatar do usuário no Firestore, sorteando e
  /// persistindo um novo caso ainda não exista (ex.: contas criadas antes
  /// da migração para emojis). Usuários sem documento (ex.: anônimos)
  /// recebem um emoji sorteado apenas em memória.
  static Future<String> buscarEmoji(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(uid)
        .get();

    if (!doc.exists) {
      return sortearEmojiAleatorio();
    }

    final emoji = doc.data()?['avatarEmoji'] as String?;
    if (emoji != null && emoji.isNotEmpty) return emoji;

    final novoEmoji = sortearEmojiAleatorio();
    await FirebaseFirestore.instance.collection('usuarios').doc(uid).set({
      'avatarEmoji': novoEmoji,
    }, SetOptions(merge: true));
    return novoEmoji;
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
    return _docs.putIfAbsent(uid, () {
      final stream = FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .snapshots()
          .asBroadcastStream();

      // Registrado antes de qualquer outro assinante, então os "últimos
      // valores conhecidos" já estão preenchidos quando alguém consulta
      // corConhecida/emojiConhecido depois do primeiro evento.
      stream.listen((doc) {
        final dados = doc.data();
        final cor = _corDe(dados);
        final emoji = _emojiDe(dados);
        final mudou = _ultimoValor[uid] != cor || _ultimoEmoji[uid] != emoji;
        _ultimoValor[uid] = cor;
        _ultimoEmoji[uid] = emoji;
        if (mudou) _notificarMudanca();
      });
      return stream;
    });
  }

  static Color _corDe(Map<String, dynamic>? dados) {
    final corValue = dados?['avatarColor'] as int?;
    if (corValue != null) return Color(corValue);

    if (dados?['isAdmin'] == true) return kCorBaseAdmin;

    return const Color(0xFFE5E7EB);
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

  /// Cor e emoji já em memória, sem nenhuma espera. `null` enquanto o uid
  /// ainda não foi observado — quem chama desenha o avatar neutro e recompõe
  /// quando [mudancas] avisar.
  ({Color cor, String emoji})? avatarConhecido(String uid) {
    final cor = _ultimoValor[uid];
    final emoji = _ultimoEmoji[uid];
    if (cor == null || emoji == null) return null;
    return (cor: cor, emoji: emoji);
  }

  /// Começa a observar os [uids] que ainda não estão em memória, sem esperar
  /// o resultado.
  ///
  /// A lista de apostas chamava isso de forma bloqueante: montar a lista
  /// esperava uma leitura de `usuarios/{uid}` por participante terminar
  /// ANTES de qualquer linha aparecer. Medido numa sala de 11 apostas, essa
  /// espera era ~960ms dos ~1500ms até a tela pintar — dois terços do tempo
  /// gastos em algo puramente cosmético. Agora a lista aparece na hora e os
  /// avatares entram depois.
  void aquecer(Iterable<String> uids) {
    for (final uid in uids) {
      if (_docs.containsKey(uid)) continue;
      _docStream(uid);
    }
  }
}
