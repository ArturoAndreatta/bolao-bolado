import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Rede de segurança: o caminho normal é o evento de foco (ver o construtor),
/// que chega no instante certo. A leitura periódica cobre o gerenciador que
/// preenche sem devolver o foco à página. O custo é ler o valor de dois
/// elementos, então 200ms não pesa.
const _intervalo = Duration(milliseconds: 200);

/// Vigia os inputs que o Flutter web cria para o autofill e avisa quando o
/// gerenciador de senhas escreve neles.
///
/// Ver o porquê da ponte em [autofill_navegador.dart].
class VigiaAutofill {
  VigiaAutofill._(this._aoPreencher) {
    _timer = Timer.periodic(_intervalo, (_) => _conferir());
    // O preenchimento acontece com a página SEM foco — a lista de credenciais
    // é outra janela. Quando o foco volta, o valor já está no campo: conferir
    // nesse exato momento faz a tela preencher junto com o retorno da janela,
    // em vez de esperar até 200ms pela próxima leitura.
    web.window.addEventListener('focus', _aoVoltarOFoco);
  }

  final void Function(String? email, String? senha) _aoPreencher;
  late final Timer _timer;
  late final JSFunction _aoVoltarOFoco = ((web.Event _) => _conferir()).toJS;

  // O que já foi visto no DOM, não o que está nos campos da tela: só mudança
  // de valor conta. Sem isso, apagar um campo na mão faria a leitura seguinte
  // reescrever o mesmo texto de volta.
  String? _ultimoEmail;
  String? _ultimaSenha;

  // A próxima leitura só registra o estado, sem avisar ninguém. Vale na
  // abertura da tela — o form pode ter sobra de uma tentativa anterior, e
  // preencher sozinho ao abrir seria estranho — e ao retomar de uma pausa.
  bool _apenasRegistrar = true;

  bool _pausado = false;

  /// Suspende a vigia. Necessário enquanto a tela escreve nos campos: o Flutter
  /// espelha o texto de volta nesses mesmos inputs do DOM, e sem a pausa esse
  /// eco seria lido como um preenchimento novo, num laço sem fim.
  void pausar() => _pausado = true;

  /// Volta a vigiar, adotando o que estiver no DOM como ponto de partida — é
  /// isso que absorve o eco do que a tela acabou de escrever.
  void retomar() {
    _pausado = false;
    _apenasRegistrar = true;
  }

  void parar() {
    _timer.cancel();
    web.window.removeEventListener('focus', _aoVoltarOFoco);
  }

  void _conferir() {
    if (_pausado) return;

    final host = web.document.querySelector('flt-text-editing-host');
    if (host == null) return;

    final email = _valorDe(host, 'input[autocomplete="username"]');
    // Pelo autocomplete, não por `type=password`: é o atributo que o
    // AutofillGroup da tela de login pediu, e não pega um campo de senha de
    // outra tela que por acaso esteja no mesmo host.
    final senha = _valorDe(host, 'input[autocomplete="current-password"]');

    if (_apenasRegistrar) {
      _apenasRegistrar = false;
      _ultimoEmail = email;
      _ultimaSenha = senha;
      return;
    }

    // Campo vazio é ignorado: o Flutter recria esses inputs a cada troca de
    // foco, e o estado recém-criado é sempre vazio — reagir a isso apagaria o
    // que o usuário já tinha digitado.
    final emailNovo =
        email != null && email.isNotEmpty && email != _ultimoEmail;
    final senhaNova =
        senha != null && senha.isNotEmpty && senha != _ultimaSenha;

    if (email != null) _ultimoEmail = email;
    if (senha != null) _ultimaSenha = senha;

    if (emailNovo || senhaNova) {
      _aoPreencher(emailNovo ? email : null, senhaNova ? senha : null);
    }
  }
}

VigiaAutofill observarAutofillDoNavegador(
  void Function(String? email, String? senha) aoPreencher,
) {
  return VigiaAutofill._(aoPreencher);
}

String? _valorDe(web.Element host, String seletor) {
  final el = host.querySelector(seletor);
  if (el == null || !el.isA<web.HTMLInputElement>()) return null;
  return (el as web.HTMLInputElement).value;
}
