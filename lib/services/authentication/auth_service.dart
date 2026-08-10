import 'dart:async';

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
    // Falha ao apagar não deve impedir o cadastro em si.
    if (_auth.currentUser != null && _auth.currentUser!.isAnonymous) {
      try {
        await _auth.currentUser!.delete();
      } catch (_) {}
    }

    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: senha,
    );

    await credential.user!.updateDisplayName(nome);

    // Sorteia uma cor e um emoji aleatórios para o avatar (cor exceto a do admin)
    final corAleatoria = AvatarService.sortearCorAleatoria();
    final emojiAleatorio = AvatarService.sortearEmojiAleatorio();

    await _firestore.collection('usuarios').doc(credential.user!.uid).set({
      'nome': nome,
      'email': email,
      'avatarColor': corAleatoria,
      'avatarEmoji': emojiAleatorio,
      'criadoEm': FieldValue.serverTimestamp(),
    });

    return credential;
  }

  Future<UserCredential> logar({
    required String email,
    required String senha,
  }) async {
    if (_auth.currentUser != null && _auth.currentUser!.isAnonymous) {
      // Não usa await: é só limpeza, não deve bloquear o login de verdade
      // esperando uma chamada de rede que pode demorar ou nunca responder.
      unawaited(_auth.currentUser!.delete().catchError((_) {}));
    }

    return _auth.signInWithEmailAndPassword(email: email, password: senha);
  }

  Future<void> logout() async {
    // O memo é por uid, então outro usuário logando já teria chave própria —
    // limpar aqui é higiene: evita carregar a resposta de uma conta que saiu
    // por uma sessão que pode durar horas.
    _isAdminPorUid.clear();
    await _auth.signOut();
    // App sempre mantém alguma sessão ativa (mesmo anônima) pra permitir
    // leitura de dados públicos sem forçar login imediato.
    await _auth.signInAnonymously();
  }

  Future<Map<String, dynamic>?> getDadosUsuario(String uid) async {
    final doc = await _firestore.collection('usuarios').doc(uid).get();
    return doc.exists ? doc.data() : null;
  }

  /// Resposta de [isAdmin] memoizada por uid, pela sessão do app.
  ///
  /// `isAdmin` era consultado de quatro lugares numa navegação normal — o
  /// drawer, a tela de Participantes, o card Minha Aposta (ao confirmar) e o
  /// Painel ADM — e cada um pagava sua própria leitura do MESMO documento
  /// `usuarios/{uid}`.
  ///
  /// Congelar por sessão é seguro pelo mesmo motivo de `buscarSalaPrincipal()`:
  /// o campo só muda via console/admin SDK, porque as regras do Firestore
  /// proíbem o próprio usuário de alterar o seu `isAdmin`. O app nunca escreve
  /// nesse campo, então não existe caminho em que ele mude com o app aberto.
  ///
  /// Guarda o *Future*, não o valor: as telas montam praticamente juntas, então
  /// chamadas concorrentes compartilham a mesma leitura em vez de disparar
  /// várias em paralelo.
  static final Map<String, Future<bool>> _isAdminPorUid = {};

  Future<bool> isAdmin(String uid) {
    final memoizado = _isAdminPorUid[uid];
    if (memoizado != null) return memoizado;

    final future = getDadosUsuario(uid).then((d) => d?['isAdmin'] == true);
    _isAdminPorUid[uid] = future;

    // Falha de rede não pode ficar memoizada: sem isto um erro na primeira
    // tentativa deixaria o usuário sem acesso de admin até recarregar o app
    // inteiro. O `identical` evita que um erro atrasado descarte uma tentativa
    // mais nova já em andamento.
    unawaited(
      future.then(
        (_) {},
        onError: (Object _) {
          if (identical(_isAdminPorUid[uid], future)) {
            _isAdminPorUid.remove(uid);
          }
        },
      ),
    );

    return future;
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
