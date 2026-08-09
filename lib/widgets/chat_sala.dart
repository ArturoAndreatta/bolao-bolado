import 'package:bolao_bolado/components/formatters/formatters.dart';
import 'package:bolao_bolado/components/shared/avatar_emoji.dart';
import 'package:bolao_bolado/components/shared/skeletons.dart';
import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/core/app_radii.dart';
import 'package:bolao_bolado/core/debug_flags.dart';
import 'package:bolao_bolado/models/mensagem.dart';
import 'package:bolao_bolado/pages/participants/participants_skeletons.dart';
import 'package:bolao_bolado/services/chat/chat_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChatSala extends StatefulWidget {
  final String salaId;
  // No mobile o chat já está dentro da aba "Chat", então o cabeçalho
  // repetindo "Chat da Sala" é redundante.
  final bool mostrarCabecalho;

  // Quando definido, exibe um botão de fechar (no cabeçalho, ou flutuando
  // sobre o card quando mostrarCabecalho é false).
  final VoidCallback? onFechar;

  // Sobreposto à tabela de participantes no desktop: aumenta a elevação
  // para reforçar a hierarquia visual de "por cima" da tabela.
  final bool flutuante;

  // No mobile o chat vive dentro da folha do Fichario, que já desenha o
  // cartão branco com borda e sombra. Sem isto o usuário vê dois retângulos
  // encaixados (o da folha e o do próprio chat) e perde ~16px de largura útil
  // de cada lado — que na tela estreita é justamente o que falta às bolhas.
  final bool compacto;

  const ChatSala({
    super.key,
    required this.salaId,
    this.mostrarCabecalho = true,
    this.onFechar,
    this.flutuante = false,
    this.compacto = false,
  });

  @override
  State<ChatSala> createState() => _ChatSalaState();
}

class _ChatSalaState extends State<ChatSala> {
  final ChatService _chatService = ChatService();
  final TextEditingController _textoController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _campoFocusNode = FocusNode();

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
    _campoFocusNode.dispose();
    super.dispose();
  }

  Future<void> _verificarPermissao() async {
    final pode = await _chatService.usuarioPodeParticipar(widget.salaId);

    if (mounted) {
      setState(() {
        _podeEnviar = pode;
        _verificandoPermissao = false;
      });
      // O campo de texto só é montado depois que a permissão é conhecida;
      // o foco automático fica restrito ao chat sobreposto no desktop
      // (mobile abre via aba, sem necessidade de puxar o teclado sozinho).
      if (widget.flutuante && pode) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _campoFocusNode.requestFocus();
        });
      }
    }
  }

  // Duas mensagens caem no mesmo dia? Usado tanto para agrupar mensagens
  // seguidas do mesmo autor quanto para decidir onde entra o separador de
  // data. Mensagem ainda sem `criadoEm` (escrita otimista local, antes do
  // serverTimestamp voltar) conta como "mesmo dia" da vizinha para não piscar
  // um separador que some no frame seguinte.
  static bool _mesmoDia(DateTime? a, DateTime? b) {
    if (a == null || b == null) return true;
    return a.year == b.year && a.month == b.month && a.day == b.day;
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
      // onSubmitted do TextField tira o foco por padrão; sem isso o usuário
      // precisa clicar de novo no campo pra mandar a próxima mensagem.
      if (mounted) _campoFocusNode.requestFocus();
    } catch (_) {
      // Falha silenciosa é ruim, mas evita poluir com showDialog
      // em um componente lateral pequeno. Mantemos o texto no campo.
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    return SizedBox.expand(
      child: Material(
        color: cores.card,
        // No modo compacto o cartão ao redor é do Fichario: aqui só o fundo,
        // sem elevação nem borda própria (ver [ChatSala.compacto]).
        elevation: widget.compacto ? 0 : (widget.flutuante ? 10 : 3),
        shadowColor: cores.sombra,
        surfaceTintColor: Colors.transparent,
        shape: widget.compacto
            ? const RoundedRectangleBorder()
            : RoundedRectangleBorder(
                borderRadius: AppRadii.circularSmd,
                side: BorderSide(color: cores.borda, width: 1.5),
              ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            if (widget.mostrarCabecalho)
              _CabecalhoChat(onFechar: widget.onFechar),
            Expanded(
              child: ValueListenableBuilder<bool>(
                valueListenable: forcarSkeletonGlobal,
                builder: (context, forcarSkeleton, _) {
                  return StreamBuilder<List<Mensagem>>(
                    stream: _mensagensStream,
                    builder: (context, snapshot) {
                      if (forcarSkeleton ||
                          snapshot.connectionState == ConnectionState.waiting) {
                        return const _SkeletonMensagens();
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
                                  color: cores.textoFraco,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                      final uidAtual = FirebaseAuth.instance.currentUser?.uid;

                      final lista = ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: EdgeInsets.symmetric(
                          horizontal: widget.compacto ? 10 : 12,
                          vertical: 10,
                        ),
                        itemCount: mensagens.length,
                        itemBuilder: (context, index) {
                          final msg = mensagens[index];
                          // A lista é reverse:true e vem do mais recente para
                          // o mais antigo, então o vizinho ANTERIOR na tela é
                          // index+1 e o POSTERIOR é index-1.
                          final anterior = index + 1 < mensagens.length
                              ? mensagens[index + 1]
                              : null;
                          final posterior = index > 0
                              ? mensagens[index - 1]
                              : null;

                          // Agrupa mensagens seguidas do mesmo autor: só a
                          // primeira do bloco mostra nome e avatar, as demais
                          // ganham um recuo equivalente. Evita repetir
                          // "Orlindo Cruz" + avatar quatro vezes em sequência.
                          final iniciaBloco =
                              anterior == null ||
                              anterior.autorUid != msg.autorUid ||
                              !_mesmoDia(anterior.criadoEm, msg.criadoEm);
                          final encerraBloco =
                              posterior == null ||
                              posterior.autorUid != msg.autorUid ||
                              !_mesmoDia(posterior.criadoEm, msg.criadoEm);

                          final bolha = _BolhaMensagem(
                            mensagem: msg,
                            isMinha: msg.autorUid == uidAtual,
                            iniciaBloco: iniciaBloco,
                            encerraBloco: encerraBloco,
                            compacto: widget.compacto,
                          );

                          // Separador de data acima da primeira mensagem de
                          // cada dia. Como a lista é invertida, "primeira do
                          // dia" é aquela cujo vizinho mais antigo (index+1)
                          // caiu em outro dia.
                          if (!_mesmoDia(anterior?.criadoEm, msg.criadoEm)) {
                            return Column(
                              children: [
                                _SeparadorData(dataHora: msg.criadoEm),
                                bolha,
                              ],
                            );
                          }
                          return bolha;
                        },
                      );

                      return SelectionArea(child: lista);
                    },
                  );
                },
              ),
            ),
            _CampoEnvioChat(
              verificandoPermissao: _verificandoPermissao,
              podeEnviar: _podeEnviar,
              enviando: _enviando,
              controller: _textoController,
              focusNode: _campoFocusNode,
              onEnviar: _enviar,
              compacto: widget.compacto,
            ),
          ],
        ),
      ),
    );
  }
}

// Rodapé do chat: alterna entre skeleton (verificando permissão), aviso de
// bloqueado (usuário sem permissão de enviar) e o campo de texto + botão de
// enviar (que também alterna para um spinner enquanto envia).
class _CampoEnvioChat extends StatelessWidget {
  final bool verificandoPermissao;
  final bool podeEnviar;
  final bool enviando;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onEnviar;
  final bool compacto;

  const _CampoEnvioChat({
    required this.verificandoPermissao,
    required this.podeEnviar,
    required this.enviando,
    required this.controller,
    required this.focusNode,
    required this.onEnviar,
    this.compacto = false,
  });

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    if (verificandoPermissao) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: cores.borda, width: 1)),
        ),
        child: const Shimmer(
          child: Row(
            children: [
              Icon(Icons.lock_outline, size: 16, color: Colors.transparent),
              SizedBox(width: 8),
              Expanded(child: SkeletonBox(width: double.infinity, height: 12)),
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
          Expanded(
            child: TextField(
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
                hintText: 'Escreva algo...',
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
            ),
          ),
          const SizedBox(width: 8),
          // No mobile o botão precisa dos ~44px de alvo de toque
          // recomendados: 12 de padding + 20 do ícone chegam lá.
          enviando
              ? Padding(
                  padding: EdgeInsets.all(compacto ? 12 : 10),
                  child: SizedBox(
                    height: compacto ? 20 : 18,
                    width: compacto ? 20 : 18,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : Material(
                  color: cores.azul,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onEnviar,
                    child: Padding(
                      padding: EdgeInsets.all(compacto ? 12 : 10),
                      child: Icon(
                        Icons.send_rounded,
                        size: compacto ? 20 : 18,
                        color: cores.textoSobreCor,
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _SkeletonMensagens extends StatelessWidget {
  const _SkeletonMensagens();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            SkeletonBolhaMensagem(isMinha: false, largura: 140),
            SkeletonBolhaMensagem(isMinha: false, largura: 100),
            SkeletonBolhaMensagem(isMinha: true, largura: 120),
            SkeletonBolhaMensagem(isMinha: false, largura: 160),
            SkeletonBolhaMensagem(isMinha: true, largura: 90),
          ],
        ),
      ),
    );
  }
}

class _CabecalhoChat extends StatelessWidget {
  final VoidCallback? onFechar;

  const _CabecalhoChat({this.onFechar});

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cores.campo,
        border: Border(bottom: BorderSide(color: cores.borda, width: 1)),
      ),
      child: Row(
        children: [
          Icon(Icons.chat_bubble_outline, size: 16, color: cores.azul),
          const SizedBox(width: 8),
          Text(
            'Chat da Sala',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: cores.texto,
            ),
          ),
          if (onFechar != null) ...[
            const Spacer(),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: IconButton(
                tooltip: 'Fechar chat',
                icon: const Icon(Icons.close, size: 18),
                color: cores.textoSuave,
                onPressed: onFechar,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Faixa "Hoje" / "Ontem" / "12/07/2026" entre blocos de dias diferentes.
// Sem ela o chat vira um rolo contínuo em que só dá pra saber a data lendo o
// carimbo de cada mensagem — que agora é só a hora.
class _SeparadorData extends StatelessWidget {
  final DateTime? dataHora;

  const _SeparadorData({required this.dataHora});

  String _rotulo(DateTime data) {
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final dia = DateTime(data.year, data.month, data.day);
    final diferenca = hoje.difference(dia).inDays;

    if (diferenca == 0) return 'Hoje';
    if (diferenca == 1) return 'Ontem';
    return Formatters.data.format(data);
  }

  @override
  Widget build(BuildContext context) {
    if (dataHora == null) return const SizedBox.shrink();

    final cores = AppCores.de(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(child: Divider(color: cores.borda, height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              _rotulo(dataHora!),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: cores.textoFraco,
              ),
            ),
          ),
          Expanded(child: Divider(color: cores.borda, height: 1)),
        ],
      ),
    );
  }
}

class _BolhaMensagem extends StatelessWidget {
  final Mensagem mensagem;
  final bool isMinha;

  // Primeira/última mensagem de um bloco de mensagens seguidas do mesmo autor
  // no mesmo dia. Controlam quem mostra avatar e nome (só a primeira) e o
  // arredondamento do "rabinho" da bolha (só a última).
  final bool iniciaBloco;
  final bool encerraBloco;

  final bool compacto;

  const _BolhaMensagem({
    required this.mensagem,
    required this.isMinha,
    required this.iniciaBloco,
    required this.encerraBloco,
    required this.compacto,
  });

  @override
  Widget build(BuildContext context) {
    final horario = mensagem.criadoEm != null
        ? Formatters.horaCurta.format(mensagem.criadoEm!)
        : '';

    const larguraAvatar = 28.0;
    const espacoAvatar = 8.0;

    return Padding(
      // Dentro de um bloco as mensagens ficam bem mais próximas do que entre
      // blocos: é o espaçamento que faz a sequência ser lida como uma fala só.
      padding: EdgeInsets.only(top: iniciaBloco ? 8 : 2, bottom: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isMinha
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isMinha) ...[
            // Continuações do bloco reservam o mesmo espaço do avatar para
            // as bolhas ficarem alinhadas na vertical.
            iniciaBloco
                ? _avatar()
                : const SizedBox(width: larguraAvatar, height: 0),
            const SizedBox(width: espacoAvatar),
          ],
          Flexible(
            child: ConstrainedBox(
              // Bolha nunca encosta na margem oposta: mesmo no mobile sobra
              // um respiro que deixa claro de que lado a mensagem está.
              constraints: BoxConstraints(
                maxWidth:
                    MediaQuery.of(context).size.width *
                    (compacto ? 0.78 : 0.85),
              ),
              child: Column(
                crossAxisAlignment: isMinha
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (!isMinha && iniciaBloco)
                    Padding(
                      padding: const EdgeInsets.only(left: 10, bottom: 3),
                      child: Text(
                        mensagem.autorNome,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppCores.de(context).textoSuave,
                        ),
                      ),
                    ),
                  _corpoBolha(context, horario),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Texto e horário dividem a mesma bolha: o carimbo flutua no canto inferior
  // junto à última linha em vez de ocupar uma linha inteira abaixo — era isso
  // que fazia cada mensagem custar três alturas de texto no mobile.
  Widget _corpoBolha(BuildContext context, String horario) {
    final cores = AppCores.de(context);
    final corTexto = isMinha ? cores.textoSobreCor : cores.bolhaOutroTexto;
    final corHorario = isMinha
        ? cores.textoSobreCor.withValues(alpha: 0.75)
        : cores.textoFraco;

    const raio = Radius.circular(16);
    const raioRabo = Radius.circular(5);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 7, 10, 7),
      decoration: BoxDecoration(
        color: isMinha ? cores.azul : cores.bolhaOutro,
        borderRadius: BorderRadius.only(
          topLeft: raio,
          topRight: raio,
          // Só a última bolha do bloco ganha o canto "rabinho" apontando para
          // o avatar; as do meio ficam com os quatro cantos redondos.
          bottomLeft: !isMinha && encerraBloco ? raioRabo : raio,
          bottomRight: isMinha && encerraBloco ? raioRabo : raio,
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: 8,
        children: [
          Text(
            mensagem.texto,
            style: TextStyle(fontSize: 14, height: 1.3, color: corTexto),
          ),
          Text(
            horario,
            style: TextStyle(
              fontSize: 10,
              height: 1.3,
              color: corHorario,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  // 28px de diâmetro, exatamente o espaço que as continuações do bloco
  // reservam com o SizedBox em build() para manter o alinhamento.
  //
  // Um StreamBuilder só: cor e emoji saem do mesmo documento e agora têm uma
  // stream combinada, então o par de builders aninhados (que reconstruía a
  // bolha duas vezes por atualização de avatar) deixou de ser necessário.
  Widget _avatar() {
    return AvatarDoParticipante(uid: mensagem.autorUid, tamanho: 28);
  }
}
