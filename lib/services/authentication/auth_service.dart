import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream do estado do usuário (logado/deslogado)
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Usuário atual
  User? get currentUser => _auth.currentUser;

  // Cadastro com e-mail e senha
  Future<UserCredential> cadastrar({
    required String email,
    required String senha,
    required String nome,
  }) async {
    // Remove a sessão anônima antes de criar conta real
    if (_auth.currentUser != null && _auth.currentUser!.isAnonymous) {
      await _auth.currentUser!.delete();
    }

    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: senha,
    );

    // Atualiza displayName no Auth
    await credential.user!.updateDisplayName(nome);

    // Cria documento no Firestore
    await _firestore.collection('usuarios').doc(credential.user!.uid).set({
      'nome': nome,
      'email': email,
      'criadoEm': FieldValue.serverTimestamp(),
    });

    return credential;
  }

  // Login com e-mail e senha
  Future<UserCredential> logar({
    required String email,
    required String senha,
  }) async {
    // Remove sessão anônima antes de logar
    if (_auth.currentUser != null && _auth.currentUser!.isAnonymous) {
      await _auth.currentUser!.delete();
    }

    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: senha,
    );
  }

  // Logout
  Future<void> logout() async {
    await _auth.signOut();
    // Recria sessão anônima para manter acesso ao Firestore
    await _auth.signInAnonymously();
  }

  // Busca dados do usuário no Firestore
  Future<Map<String, dynamic>?> getDadosUsuario(String uid) async {
    final doc = await _firestore.collection('usuarios').doc(uid).get();
    return doc.exists ? doc.data() : null;
  }

  // Atualiza nome no Auth e no Firestore
  Future<void> atualizarNome(String novoNome) async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return;

    await user.updateDisplayName(novoNome);
    await _firestore.collection('usuarios').doc(user.uid).update({
      'nome': novoNome,
    });
  }

  // Recuperação de senha
  Future<void> recuperarSenha(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // Verifica se o usuário está autenticado de verdade (não anônimo)
  bool get isLoggedIn {
    final user = _auth.currentUser;
    return user != null && !user.isAnonymous;
  }
}
