import 'package:bolao_bolado/components/formatters/formatters.dart';
import 'package:bolao_bolado/components/shared/avatar_emoji.dart';
import 'package:bolao_bolado/components/shared/custom_confirm_dialog.dart';
import 'package:bolao_bolado/components/shared/snackbar_deslizante.dart';
import 'package:bolao_bolado/core/app_radii.dart';
import 'package:bolao_bolado/core/responsive.dart';
import 'package:bolao_bolado/models/mensagem.dart';
import 'package:bolao_bolado/pages/admin/widgets/admin_widgets.dart';
import 'package:bolao_bolado/services/avatar/avatar_service.dart';
import 'package:bolao_bolado/services/chat/chat_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Diálogo de moderação do chat: lista as mensagens da sala com um botão de
/// apagar em cada linha.
///
/// Deliberadamente NÃO reaproveita [ChatSala]: aquele widget é a experiência
/// de conversa (bolhas, agrupamento por autor, campo de envio, rolagem
/// invertida) e enfiar um botão de lixeira em cada bolha bagunçaria os dois
/// usos. Aqui o que importa é varrer o histórico e remover, então a lista é
/// densa, em ordem cronológica inversa (mais recente primeiro) e sem campo
/// de envio — o admin vem aqui para apagar, não para conversar.
Future<void> abrirDialogModerarChat(BuildContext context, String salaId) {
  return showDialog<void>(
    context: context,
    builder: (_) => _DialogModerarChat(salaId: salaId),
  );
}

class _DialogModerarChat extends StatefulWidget {
  final String salaId;

  const _DialogModerarChat({required this.salaId});

  @override
  State<_DialogModerarChat> createState() => _DialogModerarChatState();
}

class _DialogModerarChatState extends State<_DialogModerarChat> {
  final ChatService _chatService = ChatService();

  // Criada uma vez só: recriar a stream a cada rebuild (o setState de
  // _apagando roda a cada clique na lixeira) faria o StreamBuilder descartar
  // a subscription e a lista piscar inteira a cada exclusão.
  late final Stream<List<Mensagem>> _mensagens = _chatService.mensagensStream(
    widget.salaId,
  );

  // IDs em processo de exclusão: a linha some por conta da stream, mas entre
  // o clique e a confirmação do servidor o botão precisa parar de aceitar
  // toque (senão dois cliques rápidos disparam dois deletes).
  final Set<String> _apagando = {};

  Future<void> _apagar(Mensagem msg) async {
    if (_apagando.contains(msg.id)) return;

    // Apagar mensagem de terceiro não tem desfazer e some da tela de todo
    // mundo na hora, então não pode ficar a um toque acidental de distância.
    final confirmar = await CustomConfirmDialog.show(
      context,
      titulo: 'Apagar mensagem?',
      mensagem:
          'A mensagem de ${msg.autorNome} será apagada permanentemente para '
          'todos os participantes.',
      textoConfirmar: 'Apagar',
      destrutivo: true,
    );
    if (!confirmar || !mounted) return;

    setState(() => _apagando.add(msg.id));
    try {
      await _chatService.apagarMensagem(
        salaId: widget.salaId,
        mensagemId: msg.id,
      );
      if (!mounted) return;
      // Sem desfazer: o histórico do chat é imutável, mensagem apagada não
      // tem como ser recriada com o mesmo id/timestamp.
      mostrarSnackBarDeslizante(
        context,
        corFundo: AdminCores.de(context).verde,
        conteudo: Text('Mensagem de ${msg.autorNome} apagada'),
      );
    } catch (e) {
      debugPrint('Erro ao apagar mensagem: $e');
      if (!mounted) return;
      setState(() => _apagando.remove(msg.id));
      mostrarSnackBarDeslizante(
        context,
        corFundo: AdminCores.de(context).vermelho,
        conteudo: const Text('Erro ao apagar a mensagem. Tente novamente.'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cores = AdminCores.de(context);
    final tela = MediaQuery.sizeOf(context);
    final largura = Responsive.isMobile(context) ? tela.width - 64 : 460.0;
    // Altura fixa com scroll interno: sem isso o diálogo cresce com o
    // histórico até estourar a tela em salas com chat movimentado.
    final altura = (tela.height * 0.6).clamp(280.0, 520.0);

    return AlertDialog(
      backgroundColor: cores.fundoCard,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.circularXxl),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      title: Row(
        children: [
          const Expanded(
            child: Text(
              'Moderar chat',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
          ),
          IconButton(
            tooltip: 'Fechar',
            icon: const Icon(Icons.close, size: 20),
            color: cores.textoSuave,
            onPressed: () => context.pop(),
          ),
        ],
      ),
      content: SizedBox(
        width: largura,
        height: altura,
        child: StreamBuilder<List<Mensagem>>(
          stream: _mensagens,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return AdminEstadoVazio(
                icon: Icons.error_outline,
                cor: cores.vermelho,
                mensagem: 'Erro ao carregar as mensagens:\n${snapshot.error}',
              );
            }

            final mensagens = snapshot.data ?? [];
            if (mensagens.isEmpty) {
              return AdminEstadoVazio(
                icon: Icons.forum_outlined,
                cor: cores.textoSuave,
                mensagem: 'Nenhuma mensagem no chat.',
              );
            }

            // A stream já vem da mais recente para a mais antiga
            // (orderBy 'criadoEm' descending), que é a ordem útil aqui:
            // o que se modera normalmente é o que acabou de ser dito.
            return ListView.separated(
              itemCount: mensagens.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, color: cores.borda),
              itemBuilder: (context, index) {
                final msg = mensagens[index];
                return _LinhaMensagem(
                  mensagem: msg,
                  apagando: _apagando.contains(msg.id),
                  onApagar: () => _apagar(msg),
                );
              },
            );
          },
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      actions: [
        Text(
          'Apagar é permanente e vale para todos os participantes.',
          style: TextStyle(fontSize: 12, color: cores.textoSuave),
        ),
      ],
    );
  }
}

class _LinhaMensagem extends StatelessWidget {
  final Mensagem mensagem;
  final bool apagando;
  final VoidCallback onApagar;

  const _LinhaMensagem({
    required this.mensagem,
    required this.apagando,
    required this.onApagar,
  });

  @override
  Widget build(BuildContext context) {
    final cores = AdminCores.de(context);
    final criadoEm = mensagem.criadoEm;
    // Data + hora (não só a hora como nas bolhas do chat): aqui a lista mistura
    // dias sem separador, então o carimbo precisa se bastar sozinho.
    final carimbo = criadoEm == null
        ? '—'
        : Formatters.dataHora.format(criadoEm);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(uid: mensagem.autorUid),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        mensagem.autorNome,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: cores.texto,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      carimbo,
                      style: TextStyle(fontSize: 11, color: cores.textoSuave),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  mensagem.texto,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.3,
                    color: cores.texto,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          // Espaço reservado igual para o botão e para o spinner: sem isso a
          // linha encolhe no instante da troca e a lista dá um solavanco.
          SizedBox(
            width: 40,
            height: 40,
            child: apagando
                ? const Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    tooltip: 'Apagar mensagem',
                    onPressed: onApagar,
                    icon: Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: cores.vermelho,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// Mesma fonte de cor/emoji das bolhas do chat (AvatarColorCache), para o admin
// reconhecer aqui o mesmo avatar que vê na conversa.
class _Avatar extends StatelessWidget {
  final String uid;

  const _Avatar({required this.uid});

  @override
  Widget build(BuildContext context) {
    final cache = AvatarColorCache.instance;
    return StreamBuilder<Color>(
      initialData: cache.corConhecida(uid),
      stream: cache.corStream(uid),
      builder: (context, corSnapshot) {
        return StreamBuilder<String>(
          initialData: cache.emojiConhecido(uid),
          stream: cache.emojiStream(uid),
          builder: (context, emojiSnapshot) {
            return AvatarEmoji(
              tamanho: 30,
              cor: corSnapshot.data ?? AdminCores.de(context).borda,
              emoji: emojiSnapshot.data ?? kEmojiAvatarPadrao,
            );
          },
        );
      },
    );
  }
}
