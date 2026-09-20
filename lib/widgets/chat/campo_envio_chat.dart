import 'package:bolao_bolado/components/shared/skeletons.dart';
import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/core/app_radii.dart';
import 'package:bolao_bolado/services/chat/chat_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Intenções do autocomplete. Existem para que as setas e o Esc sejam
// interceptados ANTES do TextField: teclas de edição de texto são resolvidas
// pelo `Shortcuts` mais próximo do campo, e o do Material está lá em cima, no
// WidgetsApp.
class _IntentSubir extends Intent {
  const _IntentSubir();
}

class _IntentDescer extends Intent {
  const _IntentDescer();
}

class _IntentFechar extends Intent {
  const _IntentFechar();
}

class _IntentAceitar extends Intent {
  const _IntentAceitar();
}

/// Rodapé do chat: alterna entre skeleton (verificando permissão), aviso de
/// bloqueado (usuário sem permissão de enviar) e o campo de texto + botão de
/// enviar (que também alterna para um spinner enquanto envia).
///
/// Vive em arquivo próprio, e não dentro de `chat_sala.dart`, para poder ser
/// montado num teste de widget sem subir o chat inteiro (que depende de
/// Firebase). O teste que existe hoje trava a regressão descrita em [_campo].
class CampoEnvioChat extends StatelessWidget {
  final bool verificandoPermissao;
  final bool podeEnviar;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onEnviar;
  final bool compacto;

  /// A lista de participantes do autocomplete está aberta agora. Muda só quais
  /// atalhos de teclado valem — nunca a ESTRUTURA da árvore (ver [_campo]).
  final bool sugestoesAbertas;
  final VoidCallback onSubir;
  final VoidCallback onDescer;
  final VoidCallback onFechar;

  const CampoEnvioChat({
    super.key,
    required this.verificandoPermissao,
    required this.podeEnviar,
    required this.controller,
    required this.focusNode,
    required this.onEnviar,
    required this.sugestoesAbertas,
    required this.onSubir,
    required this.onDescer,
    required this.onFechar,
    this.compacto = false,
  });

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    if (verificandoPermissao) {
      // Mesma moldura e a MESMA altura do estado liberado (campo redondo de
      // 38 mais o botão de enviar), e não a faixa baixa do aviso de bloqueio:
      // é o estado que a maioria vê a seguir, e a diferença de altura entre
      // os dois fazia o rodapé do chat pular quando a permissão chegava.
      return Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: cores.borda, width: 1)),
        ),
        child: Shimmer(
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: cores.campo,
                    borderRadius: AppRadii.circularPill,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: cores.campo,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!podeEnviar) {
      final logado =
          FirebaseAuth.instance.currentUser != null &&
          !FirebaseAuth.instance.currentUser!.isAnonymous;

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: cores.borda, width: 1)),
        ),
        child: Row(
          children: [
            Icon(Icons.lock_outline, size: 16, color: cores.textoFraco),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                logado
                    ? 'Faça sua aposta para participar do chat'
                    : 'Faça login para enviar mensagens',
                style: TextStyle(fontSize: 12.5, color: cores.textoSuave),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: cores.borda, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(child: _campo(cores)),
          const SizedBox(width: 8),
          // O botão NÃO tem estado de carregando. A escrita do Firestore cai
          // primeiro no cache local, então a bolha já aparece na conversa no
          // mesmo frame em que o campo é limpo — trocar o avião por um
          // spinner anunciava uma espera que, para quem olha, não existe
          // (e ainda fazia o ícone sumir e voltar a cada mensagem).
          //
          // No mobile o botão precisa dos ~44px de alvo de toque
          // recomendados: 12 de padding + 20 do ícone chegam lá.
          // Cor de ação do tema, como todo botão principal do app (e como o
          // balão das próprias mensagens).
          Material(
            color: cores.acaoPrimaria,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onEnviar,
              child: Padding(
                padding: EdgeInsets.all(compacto ? 12 : 10),
                child: Icon(
                  Icons.send_rounded,
                  size: compacto ? 20 : 18,
                  color: cores.textoSobreAcao,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _campo(AppCores cores) {
    final campo = TextField(
      controller: controller,
      focusNode: focusNode,
      maxLength: kLimiteCaracteresMensagem,
      minLines: 1,
      maxLines: 3,
      textInputAction: TextInputAction.send,
      onSubmitted: (_) => onEnviar(),
      // 16px no mobile não é escolha estética: abaixo disso o Safari
      // do iOS dá zoom na página ao focar o campo, e a tela toda sai
      // do lugar quando o teclado abre.
      style: TextStyle(fontSize: compacto ? 16 : 14),
      decoration: InputDecoration(
        // Sem reticências (elas sugerem que a frase continua) e com o @
        // dito como atalho, não como instrução de manual.
        hintText: 'Fala aí! Use @ para marcar alguém',
        hintStyle: TextStyle(
          fontSize: compacto ? 15 : 14,
          color: cores.textoFraco,
        ),
        counterText: '',
        filled: true,
        fillColor: cores.campo,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadii.circularPill,
          borderSide: BorderSide.none,
        ),
      ),
    );

    // O par Shortcuts/Actions fica SEMPRE na árvore, e o que muda é só o mapa
    // de atalhos. Montá-lo e desmontá-lo conforme a lista abria e fechava
    // trocava o PAI do TextField, então o Flutter descartava o elemento e
    // criava outro: o campo continuava com foco na tela, mas com a conexão de
    // teclado perdida — digitar e apagar paravam de funcionar no instante em
    // que a sugestão era aceita.
    //
    // Os atalhos em si continuam valendo só com a lista aberta: registrados
    // sempre, as setas parariam de mover o cursor dentro do texto.
    return Shortcuts(
      shortcuts: sugestoesAbertas
          ? const {
              SingleActivator(LogicalKeyboardKey.arrowUp): _IntentSubir(),
              SingleActivator(LogicalKeyboardKey.arrowDown): _IntentDescer(),
              SingleActivator(LogicalKeyboardKey.escape): _IntentFechar(),
              // Tab ACEITA a sugestão, como no Slack e no GitHub — quem chegou
              // aqui pelo teclado espera completar o nome, não pular de campo.
              SingleActivator(LogicalKeyboardKey.tab): _IntentAceitar(),
            }
          : const <ShortcutActivator, Intent>{},
      child: Actions(
        actions: {
          _IntentSubir: CallbackAction<_IntentSubir>(
            onInvoke: (_) {
              onSubir();
              return null;
            },
          ),
          _IntentDescer: CallbackAction<_IntentDescer>(
            onInvoke: (_) {
              onDescer();
              return null;
            },
          ),
          _IntentFechar: CallbackAction<_IntentFechar>(
            onInvoke: (_) {
              onFechar();
              return null;
            },
          ),
          _IntentAceitar: CallbackAction<_IntentAceitar>(
            onInvoke: (_) {
              onEnviar();
              return null;
            },
          ),
        },
        child: campo,
      ),
    );
  }
}
