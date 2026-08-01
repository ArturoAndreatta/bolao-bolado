import 'package:bolao_bolado/components/shared/avatar_emoji.dart';
import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/core/app_radii.dart';
import 'package:bolao_bolado/services/avatar/avatar_service.dart';
import 'package:flutter/material.dart';

/// Abre o seletor de avatar (emoji + cor).
///
/// [onSelecionado] recebe emoji e cor já persistidos no Firestore.
Future<void> mostrarEscolhaAvatar(
  BuildContext context, {
  required Color corAtual,
  required String emojiAtual,
  required void Function(String novoEmoji, Color novaCor) onSelecionado,
  bool isAdmin = false,
}) async {
  final isMobile = MediaQuery.of(context).size.width < 600;

  if (isMobile) {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SeletorAvatar(
        corAtual: corAtual,
        emojiAtual: emojiAtual,
        onSelecionado: onSelecionado,
        isAdmin: isAdmin,
        emBottomSheet: true,
      ),
    );
  } else {
    await showDialog(
      context: context,
      builder: (_) => _SeletorAvatar(
        corAtual: corAtual,
        emojiAtual: emojiAtual,
        onSelecionado: onSelecionado,
        isAdmin: isAdmin,
        emBottomSheet: false,
      ),
    );
  }
}

/// Corpo único do seletor, embrulhado num `AlertDialog` no desktop e numa
/// folha arrastável no mobile.
///
/// Antes eram duas classes com estado próprio e o mesmo conteúdo duplicado —
/// qualquer mudança na seleção precisava ser feita em dois lugares e elas já
/// tinham divergido (só o dialog tinha botão de cancelar).
class _SeletorAvatar extends StatefulWidget {
  final Color corAtual;
  final String emojiAtual;
  final void Function(String, Color) onSelecionado;
  final bool isAdmin;
  final bool emBottomSheet;

  const _SeletorAvatar({
    required this.corAtual,
    required this.emojiAtual,
    required this.onSelecionado,
    required this.isAdmin,
    required this.emBottomSheet,
  });

  @override
  State<_SeletorAvatar> createState() => _SeletorAvatarState();
}

class _SeletorAvatarState extends State<_SeletorAvatar> {
  late String _emoji;
  late Color _cor;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _emoji = widget.emojiAtual;
    _cor = widget.corAtual;
  }

  bool get _mudou => _emoji != widget.emojiAtual || _cor != widget.corAtual;

  Future<void> _confirmar() async {
    if (_salvando) return;
    setState(() => _salvando = true);

    final navigator = Navigator.of(context);
    // Emoji e cor são dois campos do mesmo doc mas duas escritas
    // independentes: em série o usuário esperava dois round-trips para
    // fechar o diálogo.
    await (
      AvatarService.salvarEmoji(_emoji),
      AvatarService.salvarCor(_cor.toARGB32()),
    ).wait;

    widget.onSelecionado(_emoji, _cor);
    if (mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return widget.emBottomSheet ? _comoBottomSheet() : _comoDialog();
  }

  // ─── Invólucros ────────────────────────────────────────────────────────────

  Widget _comoDialog() {
    final cores = AppCores.de(context);
    return AlertDialog(
      backgroundColor: cores.card,
      surfaceTintColor: Colors.transparent,
      elevation: 18,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.circularXxl,
        side: BorderSide(color: cores.borda, width: 1),
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      content: SizedBox(
        width: 380,
        // O conteúdo é mais alto que a área útil de telas baixas (notebook
        // com a janela reduzida), então rola dentro do diálogo em vez de
        // estourar.
        child: SingleChildScrollView(child: _conteudo()),
      ),
      actions: [
        TextButton(
          onPressed: _salvando ? null : () => Navigator.of(context).pop(),
          child: Text('Cancelar', style: TextStyle(color: cores.textoSuave)),
        ),
        ElevatedButton(
          onPressed: _mudou && !_salvando ? _confirmar : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: cores.azul,
            foregroundColor: cores.textoSobreCor,
            disabledBackgroundColor: cores.superficieAlta,
            shape: RoundedRectangleBorder(borderRadius: AppRadii.circularSmd),
          ),
          child: _salvando ? const _Progresso() : const Text('Confirmar'),
        ),
      ],
    );
  }

  Widget _comoBottomSheet() {
    final cores = AppCores.de(context);
    // Altura limitada + rolagem interna: com as quatro categorias abertas a
    // grade não cabe na tela de um celular, e uma Column solta simplesmente
    // estouraria por baixo.
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: cores.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: cores.borda,
                borderRadius: AppRadii.circularXs,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: _conteudo(),
              ),
            ),
            // Fora da área rolável: o botão de confirmar fica sempre à mão,
            // sem obrigar a rolar até o fim da lista de emojis.
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: cores.borda)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _mudou && !_salvando ? _confirmar : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cores.azul,
                    foregroundColor: cores.textoSobreCor,
                    disabledBackgroundColor: cores.superficieAlta,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadii.circularMd,
                    ),
                  ),
                  child: _salvando
                      ? const _Progresso()
                      : const Text(
                          'Confirmar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Conteúdo compartilhado ────────────────────────────────────────────────

  Widget _conteudo() {
    final cores = AppCores.de(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Prévia grande: o avatar só aparecia em 32px dentro da grade, então
        // não dava pra julgar a combinação de cor e emoji antes de confirmar.
        Center(
          child: Column(
            children: [
              AvatarEmoji(tamanho: 76, cor: _cor, emoji: _emoji),
              const SizedBox(height: 10),
              Text(
                'Seu avatar',
                style: TextStyle(
                  fontSize: 13,
                  color: cores.textoSuave,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        const _TituloSecao('Cor'),
        const SizedBox(height: 10),
        _GradeCores(
          selecionada: _cor,
          isAdmin: widget.isAdmin,
          onTap: (cor) => setState(() => _cor = cor),
        ),
        const SizedBox(height: 20),

        const _TituloSecao('Emoji'),
        for (final categoria in kCategoriasEmojiAvatar) ...[
          const SizedBox(height: 12),
          Text(
            categoria.nome,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cores.textoFraco,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          _GradeEmojis(
            emojis: categoria.emojis,
            corFundo: _cor,
            selecionado: _emoji,
            onTap: (emoji) => setState(() => _emoji = emoji),
          ),
        ],
      ],
    );
  }
}

class _TituloSecao extends StatelessWidget {
  final String texto;

  const _TituloSecao(this.texto);

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppCores.de(context).texto,
      ),
    );
  }
}

class _Progresso extends StatelessWidget {
  const _Progresso();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
    );
  }
}

// ─── Grade de cores ──────────────────────────────────────────────────────────

class _GradeCores extends StatelessWidget {
  final Color selecionada;
  final bool isAdmin;
  final void Function(Color) onTap;

  const _GradeCores({
    required this.selecionada,
    required this.isAdmin,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // A cor base do admin não faz parte da paleta sorteada, mas o admin pode
    // querer voltar pra ela depois de experimentar outra.
    final cores = [if (isAdmin) kCorBaseAdmin, ...kCoresAvatar];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final cor in cores)
          _BolhaCor(
            cor: cor,
            selecionada: cor.toARGB32() == selecionada.toARGB32(),
            onTap: () => onTap(cor),
          ),
      ],
    );
  }
}

class _BolhaCor extends StatelessWidget {
  final Color cor;
  final bool selecionada;
  final VoidCallback onTap;

  const _BolhaCor({
    required this.cor,
    required this.selecionada,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: cor,
            shape: BoxShape.circle,
            // Anel branco entre a cor e a borda azul: sem ele, cores próximas
            // do azul de seleção encostavam na borda e a marca de selecionado
            // sumia.
            // Anel na cor do card (não branco fixo): no escuro um anel
            // branco entre a bolha e a borda azul brilharia mais que a
            // própria cor sendo escolhida.
            border: Border.all(
              color: selecionada ? cores.card : Colors.transparent,
              width: 2,
            ),
            boxShadow: selecionada
                ? [BoxShadow(color: cores.azul, spreadRadius: 2)]
                : null,
          ),
          child: selecionada
              ? const Icon(Icons.check, size: 16, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}

// ─── Grade de emojis ─────────────────────────────────────────────────────────

class _GradeEmojis extends StatelessWidget {
  final List<String> emojis;
  final Color corFundo;
  final String selecionado;
  final void Function(String) onTap;

  const _GradeEmojis({
    required this.emojis,
    required this.corFundo,
    required this.selecionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Wrap em vez de GridView: as categorias têm tamanhos diferentes (8 e 12
    // emojis) e um GridView de contagem fixa deixaria buracos no fim de cada
    // seção.
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final emoji in emojis)
          _BolhaEmoji(
            emoji: emoji,
            corFundo: corFundo,
            selecionado: emoji == selecionado,
            onTap: () => onTap(emoji),
          ),
      ],
    );
  }
}

class _BolhaEmoji extends StatelessWidget {
  final String emoji;
  final Color corFundo;
  final bool selecionado;
  final VoidCallback onTap;

  const _BolhaEmoji({
    required this.emoji,
    required this.corFundo,
    required this.selecionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selecionado
                  ? AppCores.de(context).azul
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: AvatarEmoji(tamanho: 40, cor: corFundo, emoji: emoji),
        ),
      ),
    );
  }
}
