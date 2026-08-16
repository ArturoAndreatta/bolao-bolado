/// Implementação fora da web: não há DOM para vigiar, e o autofill do sistema
/// (Android/iOS) já entrega o texto pelo caminho normal do Flutter.
///
/// Ver o porquê da ponte em [autofill_navegador.dart].
class VigiaAutofill {
  const VigiaAutofill();

  void pausar() {}
  void retomar() {}
  void parar() {}
}

VigiaAutofill observarAutofillDoNavegador(
  void Function(String? email, String? senha) aoPreencher,
) {
  return const VigiaAutofill();
}
