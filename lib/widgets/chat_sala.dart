import 'package:bolao_bolado/models/mensagem.dart';
import 'package:bolao_bolado/services/chat/chat_service.dart';
import 'package:bolao_bolado/services/avatar/avatar_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ChatSala extends StatefulWidget {
  final String salaId;
  // No mobile o chat já está dentro da aba "Chat", então o cabeçalho
  // repetindo "Chat da Sala" é redundante.
  final bool mostrarCabecalho;

  const ChatSala({
    super.key,
    required this.salaId,
    this.mostrarCabecalho = true,
  });

  @override
  State<ChatSala> createState() => _ChatSalaState();
}

class _ChatSalaState extends State<ChatSala> {
  final ChatService _chatService = ChatService();
  final TextEditingController _textoController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _podeEnviar = false;
  bool _verificandoPermissao = true;
  bool _enviando = false;

  // Criada uma única vez em initState: se fosse aberta direto no build(),
  // cada rebuild do widget pai (ex: nova aposta atualizando a tela de
  // participantes) geraria uma nova instância de Stream, forçando o
  // StreamBuilder a descartar a subscription antiga e reiniciar o chat
  // (efeito de "recarregar" mesmo sem nenhuma mensagem nova).
  late final Stream<List<Mensagem>> _mensagensStream = _chatService
      .mensagensStream(widget.salaId);

  @override
  void initState() {
    super.initState();
    _verificarPermissao();
  }

  @override
  void dispose() {
    _textoController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _verificarPermissao() async {
    final pode = await _chatService.usuarioPodeParticipar(widget.salaId);

    if (mounted) {
      setState(() {
        _podeEnviar = pode;
        _verificandoPermissao = false;
      });
    }
  }

  // A lista usa reverse:true (mensagem mais recente no topo visual), então
  // "rolar para o final" na prática é rolar até o offset 0.
  void _scrollParaFinal() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _enviar() async {
    final texto = _textoController.text.trim();
    if (texto.isEmpty || _enviando) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _enviando = true);

    try {
      await _chatService.enviarMensagem(
        salaId: widget.salaId,
        texto: texto,
        autorNome: user.displayName ?? 'Participante',
      );
      _textoController.clear();
      _scrollParaFinal();
    } catch (_) {
      // Falha silenciosa é ruim, mas evita poluir com showDialog
      // em um componente lateral pequeno. Mantemos o texto no campo.
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Material(
        color: const Color(0xFFFEFEFE),
        elevation: 20,
        shadowColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            if (widget.mostrarCabecalho) _CabecalhoChat(),
            Expanded(
              child: StreamBuilder<List<Mensagem>>(
                stream: _mensagensStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 4,
                        color: Color(0xFF7CC8B5),
                      ),
                    );
                  }

                  final mensagens = snapshot.data ?? [];

                  if (mensagens.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: SelectionArea(
                          child: Text(
                            'Nenhuma mensagem ainda.\nSeja o primeiro a falar! 💬',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  final lista = ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    itemCount: mensagens.length,
                    itemBuilder: (context, index) {
                      final msg = mensagens[index];
                      final isMinha =
                          msg.autorUid ==
                          FirebaseAuth.instance.currentUser?.uid;
                      return _BolhaMensagem(mensagem: msg, isMinha: isMinha);
                    },
                  );

                  return SelectionArea(child: lista);
                },
              ),
            ),
            _campoEnvio(),
          ],
        ),
      ),
    );
  }

  Widget _campoEnvio() {
    if (_verificandoPermissao) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (!_podeEnviar) {
      final logado =
          FirebaseAuth.instance.currentUser != null &&
          !FirebaseAuth.instance.currentUser!.isAnonymous;

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
        ),
        child: Row(
          children: [
            Icon(Icons.lock_outline, size: 16, color: Colors.grey.shade500),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                logado
                    ? 'Faça sua aposta para participar do chat'
                    : 'Faça login para enviar mensagens',
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textoController,
              maxLength: kLimiteCaracteresMensagem,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _enviar(),
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Escreva algo...',
                hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                counterText: '',
                filled: true,
                fillColor: const Color(0xFFF3F4F6),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _enviando
              ? const Padding(
                  padding: EdgeInsets.all(10),
                  child: SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : Material(
                  color: const Color(0xFF487DE5),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _enviar,
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(
                        Icons.send_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _CabecalhoChat extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF3F4F6),
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.chat_bubble_outline,
            size: 16,
            color: Color(0xFF487DE5),
          ),
          const SizedBox(width: 8),
          const Text(
            'Chat da Sala',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }
}

class _BolhaMensagem extends StatelessWidget {
  final Mensagem mensagem;
  final bool isMinha;

  const _BolhaMensagem({required this.mensagem, required this.isMinha});

  String _formatarDataHora(DateTime dataHora) {
    final agora = DateTime.now();
    final mesmoDia = agora.year == dataHora.year &&
        agora.month == dataHora.month &&
        agora.day == dataHora.day;

    if (mesmoDia) {
      return DateFormat('HH:mm').format(dataHora);
    }
    return DateFormat('dd/MM/yyyy HH:mm').format(dataHora);
  }

  @override
  Widget build(BuildContext context) {
    final horario = mensagem.criadoEm != null
        ? _formatarDataHora(mensagem.criadoEm!)
        : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isMinha
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isMinha) ...[_avatar(), const SizedBox(width: 8)],
          Flexible(
            child: Column(
              crossAxisAlignment: isMinha
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!isMinha)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Text(
                      mensagem.autorNome,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isMinha
                        ? const Color(0xFF487DE5)
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(14),
                      topRight: const Radius.circular(14),
                      bottomLeft: Radius.circular(isMinha ? 14 : 4),
                      bottomRight: Radius.circular(isMinha ? 4 : 14),
                    ),
                  ),
                  child: Text(
                    mensagem.texto,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: isMinha ? Colors.white : const Color(0xFF1F2937),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
                  child: Text(
                    horario,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                  ),
                ),
              ],
            ),
          ),
          if (isMinha) const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _avatar() {
    final cache = AvatarColorCache.instance;
    return StreamBuilder<Color>(
      initialData: cache.corConhecida(mensagem.autorUid),
      stream: cache.corStream(mensagem.autorUid),
      builder: (context, snapshot) {
        return _avatarCirculo(snapshot.data ?? const Color(0xFFE5E7EB));
      },
    );
  }

  Widget _avatarCirculo(Color cor) {
    return CircleAvatar(
      radius: 14,
      backgroundColor: cor,
      child: Text(
        mensagem.autorNome.isNotEmpty
            ? mensagem.autorNome[0].toUpperCase()
            : '?',
        style: const TextStyle(
          fontSize: 11,
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
