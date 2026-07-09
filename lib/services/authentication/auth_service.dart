import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bolao_bolado/services/avatar/avatar_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> cadastrar({
    required String email,
    required String senha,
    required String nome,
  }) async {
    // Usuário anônimo é descartável: some app pode logar anonimamente antes
    // de cadastrar, então a conta anônima é apagada pra não sobrar lixo no Auth.
    if (_auth.currentUser != null && _auth.currentUser!.isAnonymous) {
      await _auth.currentUser!.delete();
    }

    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: senha,
    );

    await credential.user!.updateDisplayName(nome);

    // Sorteia uma cor aleatória da paleta para o avatar (exceto a cor do admin)
    final corAleatoria = AvatarService.sortearCorAleatoria();

    await _firestore.collection('usuarios').doc(credential.user!.uid).set({
      'nome': nome,
      'email': email,
      'avatarColor': corAleatoria,
      'criadoEm': FieldValue.serverTimestamp(),
    });

    return credential;
  }

  Future<UserCredential> logar({
    required String email,
    required String senha,
  }) async {
    if (_auth.currentUser != null && _auth.currentUser!.isAnonymous) {
      await _auth.currentUser!.delete();
    }

    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: senha,
    );
  }

  Future<void> logout() async {
    await _auth.signOut();
    // App sempre mantém alguma sessão ativa (mesmo anônima) pra permitir
    // leitura de dados públicos sem forçar login imediato.
    await _auth.signInAnonymously();
  }

  Future<Map<String, dynamic>?> getDadosUsuario(String uid) async {
    final doc = await _firestore.collection('usuarios').doc(uid).get();
    return doc.exists ? doc.data() : null;
  }

  Future<bool> isAdmin(String uid) async {
    final dados = await getDadosUsuario(uid);
    return dados?['isAdmin'] == true;
  }

  Future<void> atualizarNome(String novoNome) async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return;

    await user.updateDisplayName(novoNome);
    await _firestore.collection('usuarios').doc(user.uid).update({
      'nome': novoNome,
    });
  }

  Future<void> recuperarSenha(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  bool get isLoggedIn {
    final user = _auth.currentUser;
    return user != null && !user.isAnonymous;
  }
}
