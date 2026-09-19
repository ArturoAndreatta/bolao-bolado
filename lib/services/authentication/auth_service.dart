import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:bolao_bolado/services/avatar/avatar_service.dart';

/// Maior nome aceito para perfil, aposta e autor de mensagem — o mesmo teto
/// que `firestore.rules` impõe. Sem ele, um nome de milhares de caracteres
/// quebrava a lista de participantes e o chat de todo mundo.
const int kTamanhoMaximoNome = 60;

/// Corta [nome] no teto aceito pelas regras. Usado onde o nome vem de fora
/// (conta Google) e o usuário não teve como digitar outro.
String limitarNome(String nome) {
  final limpo = nome.trim();
  if (limpo.isEmpty) return 'Usuário';
  return limpo.length <= kTamanhoMaximoNome
      ? limpo
      : limpo.substring(0, kTamanhoMaximoNome);
}

/// Regra mínima de senha do cadastro.
///
/// O Firebase aceita qualquer senha de 6 caracteres, e o bloqueio por
/// tentativas do servidor não segura senha como `123456`, que cai nas
/// primeiras tentativas de qualquer lista pronta. Devolve a mensagem de erro,
/// ou null se a senha serve. A mesma política deve estar ligada no console
/// (Authentication > Configurações > Política de senha), que é quem vale
/// para quem chama a API direto.
String? problemaDaSenha(String senha) {
  if (senha.length < 8) return 'A senha precisa ter pelo menos 8 caracteres.';
  if (!RegExp(r'[A-Za-z]').hasMatch(senha) || !RegExp(r'\d').hasMatch(senha)) {
    return 'A senha precisa ter letras e números.';
  }
  return null;
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Backend próprio (repo bolao-bolado-email-api, projeto Vercel separado)
  // que gera o link de redefinição via Admin SDK e manda o e-mail com o
  // template visual do app — usado no lugar do `sendPasswordResetEmail`
  // padrão do Firebase, cujo e-mail é genérico e cuja customização está
  // quebrada neste projeto Firebase (Console recusa salvar o modelo/URL
  // acionável).
  static const _urlRecuperarSenha =
      'https://bolao-bolado-email-api.vercel.app/api/redefinir-senha';

  // Barreira simples contra bot varrendo o endpoint — não é um segredo
  // forte de verdade: o app é web pública, então dá pra extrair esse valor
  // do bundle. Só afasta abuso genérico, não alguém decidido (mesmo aviso
  // no endpoint em si).
  static const _segredoRecuperarSenha =
      '7f3a9c1e5b8d4f26a0c9e7d3b5f8a1c4e6d9b2f7a5c8e1d4b6f9a2c5e8d1b4f7';

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

    // Sem `email`: `usuarios/{uid}` é legível por qualquer sessão (nome e
    // avatar aparecem antes do login), então o que entra aqui é público. O
    // e-mail já fica guardado no Firebase Auth, e as regras recusam o campo.
    await _firestore.collection('usuarios').doc(credential.user!.uid).set({
      'nome': nome,
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

  /// Login/cadastro com conta Google, num toque só.
  ///
  /// Não usa o pacote `google_sign_in`: `signInWithProvider`/`signInWithPopup`
  /// do próprio `firebase_auth` bastam para web e mobile, e evitam registrar a
  /// impressão SHA-1 de cada chave de assinatura no console do Firebase — o
  /// app hoje só é assinado com a chave de depuração, e essa dependência
  /// quebraria calado no dia em que a chave de verdade entrasse.
  ///
  /// Devolve `null` quando o usuário desistiu (fechou a janela do Google) —
  /// isso não é erro, é a pessoa mudando de ideia, e não deve acender um
  /// diálogo vermelho na tela de login.
  Future<UserCredential?> entrarComGoogle() async {
    if (_auth.currentUser != null && _auth.currentUser!.isAnonymous) {
      unawaited(_auth.currentUser!.delete().catchError((_) {}));
    }

    // Só e-mail e nome interessam — contatos, agenda e o resto do catálogo do
    // Google não têm o que fazer num app de bolão, e cada escopo a mais é uma
    // linha a mais na tela de permissão que a pessoa lê antes de confiar.
    final provider = GoogleAuthProvider()
      ..addScope('email')
      ..addScope('profile');

    UserCredential credential;
    try {
      // Dois caminhos porque o Firebase oferece dois. Na web, a janela
      // suspensa devolve a sessão sem sair da página — recarregar o app no
      // meio do login perderia o estado do formulário.
      credential = kIsWeb
          ? await _auth.signInWithPopup(provider)
          : await _auth.signInWithProvider(provider);
    } on FirebaseAuthException catch (e) {
      if (_desistiuDoLogin(e.code)) return null;
      rethrow;
    }

    // Primeira vez desta conta Google no app: sorteia avatar e cria o
    // documento em `usuarios/{uid}`, igual ao fluxo de `cadastrar`.
    if (credential.additionalUserInfo?.isNewUser ?? false) {
      final corAleatoria = AvatarService.sortearCorAleatoria();
      final emojiAleatorio = AvatarService.sortearEmojiAleatorio();

      await _firestore.collection('usuarios').doc(credential.user!.uid).set({
        'nome': limitarNome(credential.user!.displayName ?? 'Usuário'),
        'avatarColor': corAleatoria,
        'avatarEmoji': emojiAleatorio,
        'criadoEm': FieldValue.serverTimestamp(),
      });
    }

    return credential;
  }

  /// Códigos que significam "mudei de ideia", não "deu errado" — fechar a
  /// janela do Google é um gesto comum (abrir, ver a conta errada, fechar), e
  /// tratar isso como erro deixaria um aviso vermelho na tela por algo que a
  /// pessoa fez de propósito.
  bool _desistiuDoLogin(String codigo) {
    return codigo == 'popup-closed-by-user' ||
        codigo == 'cancelled-popup-request' ||
        codigo == 'user-cancelled' ||
        codigo == 'web-context-canceled';
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

    final future = getDadosUsuario(uid).then((dados) {
      _limparDadoPrivadoLegado(uid, dados);
      return dados;
    });
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

  /// Apaga o `email` que contas antigas ainda têm em `usuarios/{uid}`.
  ///
  /// O cadastro gravava o e-mail nesse documento, que qualquer visitante lê.
  /// O cadastro parou de gravar, mas quem já tinha conta continua exposto
  /// até alguém apagar o campo — e o único que pode fazer isso pelo app é o
  /// próprio dono, na primeira vez que abre depois da atualização. O script
  /// `email_api/scripts/limpar_dados_privados.js` cobre quem não voltar.
  ///
  /// Fica fora do caminho crítico (sem await) e engole erro: é limpeza, e
  /// falhar agora só adia para a próxima abertura.
  void _limparDadoPrivadoLegado(String uid, Map<String, dynamic>? dados) {
    if (dados == null || !dados.containsKey('email')) return;
    if (_auth.currentUser?.uid != uid) return;
    dados.remove('email');
    unawaited(
      _firestore
          .collection('usuarios')
          .doc(uid)
          .update({'email': FieldValue.delete()})
          .catchError((Object _) {}),
    );
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

  /// Envia o e-mail de redefinição de senha pelo backend próprio (ver
  /// [_urlRecuperarSenha]).
  ///
  /// O endpoint é anti-enumeração de propósito: responde sucesso (200) tanto
  /// pra e-mail cadastrado quanto pra e-mail inexistente, sem diferenciar —
  /// não dá pra usar essa chamada pra descobrir se alguém tem conta no app.
  /// Só erro de rede/infraestrutura chega aqui como falha de verdade.
  Future<void> recuperarSenha(String email) async {
    final resposta = await http.post(
      Uri.parse(_urlRecuperarSenha),
      headers: {
        'Content-Type': 'application/json',
        'x-app-secret': _segredoRecuperarSenha,
      },
      body: jsonEncode({'email': email}),
    );

    if (resposta.statusCode != 200) {
      throw Exception(
        'Erro ao enviar e-mail de redefinição de senha (${resposta.statusCode}).',
      );
    }
  }

  bool get isLoggedIn {
    final user = _auth.currentUser;
    return user != null && !user.isAnonymous;
  }
}
