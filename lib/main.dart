import 'dart:async';

import 'package:bolao_bolado/bolao_bolado.dart';
import 'package:bolao_bolado/core/app_check.dart';
import 'package:bolao_bolado/core/app_tema.dart';
import 'package:bolao_bolado/core/pre_carga_emoji.dart';
import 'package:bolao_bolado/core/splash_web.dart';
import 'package:bolao_bolado/core/tema_controller.dart';
import 'package:bolao_bolado/core/ultima_rota_admin.dart';
import 'package:bolao_bolado/pages/splash_screen.dart';
import 'package:bolao_bolado/services/authentication/auth_service.dart';
import 'package:bolao_bolado/services/bet/bet_service.dart';
import 'package:bolao_bolado/services/configuracoes/configuracoes_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Login automático de desenvolvimento: evita ter que logar manualmente toda
// vez ao rodar o app localmente. As credenciais NUNCA ficam no código — elas
// só existem se passadas via --dart-define-from-file na hora do run/debug
// (veja dev.env.json.example e a config "Flutter (auto-login dev)" no
// .vscode/launch.json). Em builds de release essas const ficam vazias e o
// bloco de auto-login em _inicializar() nunca é executado, então isso não
// vaza credencial nenhuma pro APK/bundle publicado.
const String _devEmail = String.fromEnvironment('DEV_LOGIN_EMAIL');
const String _devSenha = String.fromEnvironment('DEV_LOGIN_SENHA');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _AppInit());
}

/// Liga o cache local persistente do Firestore. Precisa rodar logo depois do
/// initializeApp e antes de qualquer leitura — mudar `settings` depois que a
/// instância já foi usada é ignorado pelo SDK.
///
/// Na web o padrão do plugin é `memoryLocalCache` (ver cloud_firestore_web:
/// `persistenceEnabled == null` cai em cache só de memória), então cada vez
/// que o app é reaberto — e no iPhone, cada vez que o atalho do Safari é
/// tocado é um carregamento novo da página — todas as leituras começam do
/// zero e a tela fica no skeleton esperando a rede. Com persistência, os
/// `snapshots()` emitem o último estado gravado no IndexedDB na hora e só
/// depois são corrigidos pelo servidor, então a tela aparece preenchida
/// mesmo antes da rede responder. Em Android/iOS nativo isso já era o
/// padrão; explicitar aqui só uniformiza o comportamento.
///
/// Ressalva conhecida: o plugin não expõe o `tabManager` do SDK web, então a
/// persistência usa o modo de aba única. Com duas abas do app abertas ao
/// mesmo tempo, a segunda não consegue o lock do IndexedDB e cai sozinha
/// para cache de memória (só um aviso no console — o app continua normal).
void _configurarFirestore() {
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );
}

class _AppInit extends StatefulWidget {
  const _AppInit();

  @override
  State<_AppInit> createState() => _AppInitState();
}

class _AppInitState extends State<_AppInit> {
  bool _pronto = false;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    // Firebase e as duas preferências locais não dependem um do outro: em
    // série, cada leitura somaria um passo antes do primeiro frame só para
    // descobrir um valor local. A do tema precisa acontecer ANTES do app
    // pintar, senão a tela aparece clara e pisca para o escuro no frame
    // seguinte; a de última rota precisa estar pronta antes da primeira
    // decisão do redirect do router (ver app_router.dart), senão a primeira
    // navegação de quem loga cairia sempre no destino padrão.
    await (
      Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
      carregarTemaSalvo(),
      carregarUltimaRotaAdmin(),
    ).wait;

    // Antes de qualquer pedido ao Firestore/Auth (ver app_check.dart). Sem
    // chave configurada volta na hora, sem custo.
    await ativarAppCheck();

    _configurarFirestore();

    // Aguarda o primeiro evento real de authStateChanges (em vez de só
    // checar currentUser) para garantir que uma sessão persistida do
    // navegador já foi restaurada antes de decidir se precisa logar
    // anonimamente. currentUser pode retornar null momentaneamente logo
    // após initializeApp, mesmo com uma sessão válida salva no storage.
    var user = await FirebaseAuth.instance.authStateChanges().first;

    // Login automático de dev (ver comentário no topo do arquivo): só roda em
    // build de debug e só se as credenciais foram fornecidas via dart-define.
    if (user == null &&
        kDebugMode &&
        _devEmail.isNotEmpty &&
        _devSenha.isNotEmpty) {
      try {
        final credential = await FirebaseAuth.instance
            .signInWithEmailAndPassword(email: _devEmail, password: _devSenha);
        user = credential.user;
      } catch (_) {}
    }

    // Garante que sempre exista um usuário (mesmo que anônimo) para permitir
    // acesso a dados/regras do Firestore antes do login real
    if (user == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }

    // Dispara a descoberta da sala principal já aqui, sem esperar: praticamente
    // toda tela do app precisa desse ID, e ele só pode ser lido depois que
    // existe um usuário autenticado. Adiantando agora, a consulta acontece
    // enquanto a primeira tela é montada, em vez de ser o primeiro round-trip
    // (e o primeiro segundo de skeleton) de quem abrir Participantes.
    // buscarSalaPrincipal() memoiza o Future, então quem chamar depois
    // reaproveita esta mesma consulta. Erro aqui é ignorado de propósito: a
    // função já descarta o cache em caso de falha, e quem realmente precisa
    // do valor trata o erro na própria tela.
    unawaited(buscarSalaPrincipal().then((_) {}, onError: (Object _) {}));

    // Mesma ideia para o documento `usuarios/{uid}`: ele decide o avatar do
    // drawer, o `isAdmin` (que acrescenta Cadastrar Sala, Consultar Salas e
    // Painel ADM ao menu) e o nome que o card Minha Aposta preenche. Lido
    // agora, chega pronto — sem isso a primeira abertura do menu mostrava os
    // itens de participante e completava os de admin um instante depois.
    //
    // Só para usuário de verdade: anônimo não tem documento, e pedir por ele
    // seria uma leitura garantidamente vazia em toda visita pública.
    final logado = FirebaseAuth.instance.currentUser;
    if (logado != null && !logado.isAnonymous) {
      unawaited(
        AuthService().perfil(logado.uid).then((_) {}, onError: (Object _) {}),
      );
    }

    // Mesmo padrão: assina sem esperar, os notifiers já nascem com o padrão
    // local (definido em debug_flags.dart) e passam a refletir o Firestore
    // assim que a primeira emissão chegar. A assinatura fica aberta pela
    // vida inteira do app — não há tela "dona" desse listener para cancelar
    // ao sair, já que a configuração precisa valer em qualquer parte do app
    // a qualquer momento (é global, não de uma tela). A busca da sala
    // principal por trás reaproveita o Future memoizado já disparado acima.
    unawaited(ouvirConfiguracoesGlobais());

    setState(() => _pronto = true);

    // Só depois do primeiro quadro do app de verdade: é a partir dele que a
    // `SplashScreen` deixou de estar por baixo do splash HTML. Avisar antes
    // faria o HTML esmaecer revelando a cópia Flutter do mesmo splash, e a
    // troca entre os dois apareceria como uma piscada.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      dispensarSplashWeb();
      // Logo depois do primeiro quadro, e não antes: o download dos pedaços da
      // fonte de emoji não pode disputar a conexão com o login e com o próprio
      // motor subindo. Ver pre_carga_emoji.dart.
      preCarregarEmojisIniciais();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Exibe a splash enquanto Firebase/login anônimo não terminam de
    // inicializar. Ela também precisa respeitar o tema salvo: sem isso, quem
    // usa o app no escuro leva um flash branco a cada abertura — justamente
    // o que o dark mode existe para evitar.
    if (!_pronto) {
      return ValueListenableBuilder<TemaApp>(
        valueListenable: temaGlobal,
        builder: (context, tema, _) => MaterialApp(
          title: 'Bolão Bolado',
          // O tema vai resolvido em `theme`, não via `themeMode`: os temas
          // únicos não são "o claro" nem "o escuro" do MaterialApp, então
          // deixar o par theme/darkTheme decidir jogaria a splash de volta
          // para uma das duas paletas padrão.
          theme: AppTema.de(
            paletaDe(tema, MediaQuery.platformBrightnessOf(context)),
          ),
          debugShowCheckedModeBanner: false,
          home: const SplashScreen(),
        ),
      );
    }
    return const BolaoBolado();
  }
}
