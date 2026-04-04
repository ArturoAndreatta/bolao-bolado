import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = .instance;

  void logar({required String email, required String senha}) {
    print("logou: $email, $senha");
  }

  void cadastrar({
    required String email,
    required String senha,
    required String nome,
  }) async {
    UserCredential userCredential = await _firebaseAuth
        .createUserWithEmailAndPassword(email: email, password: senha);
    userCredential.user!.updateDisplayName(nome);
  }
}
