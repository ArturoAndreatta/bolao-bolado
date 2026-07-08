import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Cor exclusiva da conta admin. Serve apenas de base para gerar as
/// cores de avatar dos demais usuários — nunca é sorteada para eles.
const Color kCorBaseAdmin = Color(0xFF7400C7);
const String kEmailAdmin = 'arturoandreatta@gmail.com';

/// 16 cores derivadas de [kCorBaseAdmin] variando matiz/saturação/luminosidade
/// em torno da cor base, disponíveis para os usuários comuns escolherem ou
/// receberem aleatoriamente no cadastro.
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

class AvatarService {
  /// Sorteia uma cor aleatória dentre as 16 disponíveis (nunca a cor base do admin)
  /// e retorna seu valor ARGB como inteiro, para persistir no Firestore.
  static int sortearCorAleatoria() {
    final random = Random();
    final cor = kCoresAvatar[random.nextInt(kCoresAvatar.length)];
    return cor.toARGB32();
  }

  /// Salva a cor de avatar escolhida no Firestore
  static Future<void> salvarCor(int corValue) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance.collection('usuarios').doc(uid).set({
      'avatarColor': corValue,
    }, SetOptions(merge: true));
  }

  /// Busca a cor de avatar do usuário no Firestore.
  /// A cor salva em `avatarColor` sempre tem prioridade — a conta admin só
  /// recebe [kCorBaseAdmin] como valor padrão, enquanto nenhuma cor tiver
  /// sido gravada explicitamente. Usuários sem documento em `usuarios`
  /// (ex.: anônimos) recebem uma cor sorteada apenas em memória, sem
  /// tentar persistir.
  static Future<Color> buscarCor(String uid, {String? email}) async {
    final doc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(uid)
        .get();

    if (!doc.exists) {
      if (email == kEmailAdmin) return kCorBaseAdmin;
      return Color(sortearCorAleatoria());
    }

    final corValue = doc.data()?['avatarColor'] as int?;
    if (corValue != null) return Color(corValue);

    final dataEmail = email ?? doc.data()?['email'] as String?;
    if (dataEmail == kEmailAdmin) return kCorBaseAdmin;

    final novaCor = sortearCorAleatoria();
    await FirebaseFirestore.instance.collection('usuarios').doc(uid).set({
      'avatarColor': novaCor,
    }, SetOptions(merge: true));
    return Color(novaCor);
  }
}
