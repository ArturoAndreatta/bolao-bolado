import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─── Altere aqui para adicionar ou remover avatares ───────────────────────────
const int kTotalAvatares = 8;
// ──────────────────────────────────────────────────────────────────────────────

class AvatarService {
  static const String _pastaAvatares = 'assets/avatars/';

  /// Retorna o caminho do asset de um avatar pelo índice (1-based)
  static String caminhoPorIndice(int indice) {
    return '${_pastaAvatares}avatar_$indice.png';
  }

  /// Retorna todos os caminhos disponíveis
  static List<String> get todosAvatares {
    return List.generate(kTotalAvatares, (i) => caminhoPorIndice(i + 1));
  }

  /// Sorteia um avatar aleatório e retorna o caminho
  static String sortearAleatorio() {
    final random = Random();
    final indice = random.nextInt(kTotalAvatares) + 1;
    return caminhoPorIndice(indice);
  }

  /// Salva o avatar escolhido no Firestore
  static Future<void> salvarAvatar(String caminhoAvatar) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance.collection('usuarios').doc(uid).update({
      'avatar': caminhoAvatar,
    });
  }

  /// Busca o avatar atual do usuário no Firestore
  static Future<String> buscarAvatar(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(uid)
        .get();

    final avatar = doc.data()?['avatar'] as String?;
    return avatar ?? sortearAleatorio();
  }
}
