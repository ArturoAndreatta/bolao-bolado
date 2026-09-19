import 'package:bolao_bolado/components/shared/buttons.dart';
import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/core/app_radii.dart';
import 'package:bolao_bolado/router/app_router.dart';
import 'package:bolao_bolado/services/authentication/auth_service.dart';
import 'package:bolao_bolado/widgets/chat_sala.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// O chat da sala para quem tem conta; para o visitante, um convite a entrar.
///
/// O chat é conversa entre quem está no bolão, e o visitante (sessão anônima)
/// não é ninguém ali: ele vê a lista de participantes, mas não as mensagens.
/// Quem garante isso é `firestore.rules` (leitura de `Mensagens` exige conta);
/// este widget só evita montar um [ChatSala] que ia receber permissão negada.
///
/// Hoje o visitante nem vê as entradas do chat (aba, botão e item do menu
/// somem para ele — ver `_logado` em participants_page.dart). O convite fica
/// como rede de segurança: se a sessão cair para anônima com o chat aberto,
/// aparece ele em vez de um chat quebrado por permissão negada.
class ChatOuConvite extends StatelessWidget {
  final String salaId;
  final bool mostrarCabecalho;
  final bool flutuante;

  const ChatOuConvite({
    super.key,
    required this.salaId,
    this.mostrarCabecalho = true,
    this.flutuante = false,
  });

  @override
  Widget build(BuildContext context) {
    if (AuthService().isLoggedIn) {
      return ChatSala(
        salaId: salaId,
        mostrarCabecalho: mostrarCabecalho,
        flutuante: flutuante,
      );
    }
    return _ConviteChat(flutuante: flutuante);
  }
}

class _ConviteChat extends StatelessWidget {
  final bool flutuante;

  const _ConviteChat({required this.flutuante});

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);

    // Mesma moldura do ChatSala (cor, borda, elevação): o convite ocupa o
    // lugar dele e não pode parecer um corpo estranho no painel.
    return SizedBox.expand(
      child: Material(
        color: cores.card,
        elevation: flutuante ? 10 : 3,
        shadowColor: cores.sombra,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.circularSmd,
          side: BorderSide(color: cores.borda, width: 1.5),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: cores.fundoAzul,
                      shape: BoxShape.circle,
                      border: Border.all(color: cores.bordaAzul),
                    ),
                    child: Icon(
                      Icons.lock_outline,
                      size: 28,
                      color: cores.textoAzul,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'O chat é da galera do bolão',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: cores.texto,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Entre na sua conta para ler as mensagens e conversar '
                    'com quem está participando.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: cores.textoSuave,
                    ),
                  ),
                  const SizedBox(height: 20),
                  PrimaryButton(
                    text: 'Entrar',
                    width: 200,
                    compact: true,
                    onTap: () => context.go(AppRoutes.signup),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
