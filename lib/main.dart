import 'package:bolao_bolado/bolao_bolado.dart';
import 'package:bolao_bolado/pages/splash_screen.dart';
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
    // Firebase precisa estar inicializado antes de qualquer chamada de autenticação
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

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
    setState(() => _pronto = true);
  }

  @override
  Widget build(BuildContext context) {
    // Exibe a splash enquanto Firebase/login anônimo não terminam de inicializar
    if (!_pronto) {
      return const MaterialApp(
        title: 'Bolão Bolado',
        debugShowCheckedModeBanner: false,
        home: SplashScreen(),
      );
    }
    return const BolaoBolado();
  }
}
