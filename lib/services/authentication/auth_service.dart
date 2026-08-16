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
    _perfilPorUid.clear();
    _perfilResolvido.clear();
    await _auth.signOut();
    // App sempre mantém alguma sessão ativa (mesmo anônima) pra permitir
    // leitura de dados públicos sem forçar login imediato.
    //
    // Sem await de propósito: o `signOut` é local e imediato, mas o login
    // anônimo é um round-trip de rede. Quem chama sai da tela privada assim
    // que o `signOut` volta, e esperar o anônimo deixava a tela antiga
    // visível se atualizando para o estado de deslogado (o card de aposta
    // sumindo) antes de o app enfim navegar.
    unawaited(_reentrarAnonimo());
  }

  /// Restabelece a sessão anônima em segundo plano depois do logout.
  ///
  /// Erro é engolido: o usuário já está deslogado de qualquer forma, e
  /// estourar aqui só derrubaria um future sem dono. As telas públicas
  /// voltam a ler na próxima sessão anônima (o `main.dart` garante uma na
  /// abertura do app).
  Future<void> _reentrarAnonimo() async {
    try {
      await _auth.signInAnonymously();
    } catch (_) {}
  }

  /// Documento `usuarios/{uid}` memoizado por sessão — o Future e, quando já
  /// resolvido, o próprio valor.
  ///
  /// O MESMO documento era lido de cinco lugares numa navegação normal: o
  /// drawer (avatar + isAdmin), a tela de Participantes, o card Minha Aposta
  /// (nome, e de novo ao confirmar) e o Painel ADM. Pior: o drawer relia a
  /// cada ABERTURA do menu, então era uma leitura cobrada por toque no
  /// hambúrguer.
  ///
  /// Congelar por sessão é seguro pelo mesmo motivo de `buscarSalaPrincipal()`:
  /// o que este documento guarda ou não muda com o app aberto (`isAdmin` só
  /// muda via console/admin SDK — as regras proíbem o próprio usuário de
  /// alterá-lo), ou muda pelo PRÓPRIO app, e nesses dois casos quem escreve
  /// atualiza o cache junto (ver [mesclarNoCache]).
  ///
  /// Guarda o *Future* para que chamadas concorrentes (as telas montam
  /// praticamente juntas) compartilhem uma leitura só, e o *valor resolvido*
  /// para que quem chegar depois possa ler SEM passar por um `await` — é o
  /// await, e não a rede, que fazia o menu abrir com metade dos itens e
  /// completar no frame seguinte.
  static final Map<String, Future<Map<String, dynamic>?>> _perfilPorUid = {};
  static final Map<String, Map<String, dynamic>?> _perfilResolvido = {};

  /// Dados do usuário já em memória, ou null se ainda não foram lidos.
  ///
  /// Devolve `null` tanto para "não carregado" quanto para "usuário sem
  /// documento". A diferença não importa a nenhum ponto de chamada: os dois
  /// casos caem no mesmo comportamento (mostrar o padrão e esperar a leitura),
  /// e distinguir exigiria um sentinela que só complicaria a leitura.
  static Map<String, dynamic>? perfilConhecido(String uid) =>
      _perfilResolvido[uid];

  /// Lê `usuarios/{uid}` uma vez por sessão.
  Future<Map<String, dynamic>?> perfil(String uid) {
    final memoizado = _perfilPorUid[uid];
    if (memoizado != null) return memoizado;

    final future = getDadosUsuario(uid);
    _perfilPorUid[uid] = future;

    // Falha de rede não pode ficar memoizada: sem isto um erro na primeira
    // tentativa deixaria o usuário sem acesso de admin até recarregar o app
    // inteiro. O `identical` evita que um erro atrasado descarte uma tentativa
    // mais nova já em andamento.
    unawaited(
      future.then(
        (dados) {
          if (identical(_perfilPorUid[uid], future)) {
            _perfilResolvido[uid] = dados;
          }
        },
        onError: (Object _) {
          if (identical(_perfilPorUid[uid], future)) {
            _perfilPorUid.remove(uid);
          }
        },
      ),
    );

    return future;
  }

  /// Atualiza o cache depois de uma escrita feita pelo próprio app (nome,
  /// cor/emoji do avatar).
  ///
  /// Sem isto o cache de sessão passaria a mentir: trocar de avatar mostraria
  /// o novo na hora e o antigo na próxima abertura do menu.
  static void mesclarNoCache(String uid, Map<String, dynamic> campos) {
    final atual = _perfilResolvido[uid];
    if (atual == null) return;
    final novo = {...atual, ...campos};
    _perfilResolvido[uid] = novo;
    _perfilPorUid[uid] = Future.value(novo);
  }

  Future<Map<String, dynamic>?> getDadosUsuario(String uid) async {
    final doc = await _firestore.collection('usuarios').doc(uid).get();
    return doc.exists ? doc.data() : null;
  }

  Future<bool> isAdmin(String uid) =>
      perfil(uid).then((dados) => dados?['isAdmin'] == true);

  /// `isAdmin` já conhecido, sem passar por `await`. Null = ainda não lido.
  static bool? isAdminConhecido(String uid) {
    final dados = perfilConhecido(uid);
    return dados == null ? null : dados['isAdmin'] == true;
  }

  Future<void> atualizarNome(String novoNome) async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return;

    await user.updateDisplayName(novoNome);
    await _firestore.collection('usuarios').doc(user.uid).update({
      'nome': novoNome,
    });
    mesclarNoCache(user.uid, {'nome': novoNome});
  }

  Future<void> recuperarSenha(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  bool get isLoggedIn {
    final user = _auth.currentUser;
    return user != null && !user.isAnonymous;
  }
}
