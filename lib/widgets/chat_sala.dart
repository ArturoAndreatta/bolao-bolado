import 'package:bolao_bolado/models/mensagem.dart';
import 'package:bolao_bolado/services/chat/chat_service.dart';
import 'package:bolao_bolado/services/avatar/avatar_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ChatSala extends StatefulWidget {
  final String salaId;
  final double height;

  const ChatSala({super.key, required this.salaId, required this.height});

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
  String? _avatarAtual;

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
    final uid = FirebaseAuth.instance.currentUser?.uid;

    String? avatar;
    if (uid != null) {
      avatar = await AvatarService.buscarAvatar(uid);
    }

    if (mounted) {
      setState(() {
        _podeEnviar = pode;
        _avatarAtual = avatar;
        _verificandoPermissao = false;
      });
    }
  }

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
        autorAvatar: _avatarAtual,
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
    return SizedBox(
      height: widget.height,
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
            _CabecalhoChat(),
            Expanded(
              child: StreamBuilder<List<Mensagem>>(
                stream: _chatService.mensagensStream(widget.salaId),
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

  @override
  Widget build(BuildContext context) {
    final horario = mensagem.criadoEm != null
        ? DateFormat('HH:mm').format(mensagem.criadoEm!)
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
    return CircleAvatar(
      radius: 14,
      backgroundColor: const Color(0xFFE5E7EB),
      backgroundImage: mensagem.autorAvatar != null
          ? AssetImage(mensagem.autorAvatar!)
          : null,
      child: mensagem.autorAvatar == null
          ? Text(
              mensagem.autorNome.isNotEmpty
                  ? mensagem.autorNome[0].toUpperCase()
                  : '?',
              style: const TextStyle(fontSize: 11, color: Color(0xFF1F2937)),
            )
          : null,
    );
  }
}
