import 'package:bolao_bolado/core/app_radii.dart';
import 'package:bolao_bolado/services/avatar/avatar_service.dart';
import 'package:flutter/material.dart';

Future<void> mostrarEscolhaAvatar(
  BuildContext context, {
  required Color corAtual,
  required String emojiAtual,
  required void Function(String novoEmoji) onSelecionado,
  bool isAdmin = false,
}) async {
  final isMobile = MediaQuery.of(context).size.width < 600;

  if (isMobile) {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AvatarBottomSheet(
        corAtual: corAtual,
        emojiAtual: emojiAtual,
        onSelecionado: onSelecionado,
      ),
    );
  } else {
    await showDialog(
      context: context,
      builder: (_) => _AvatarDialog(
        corAtual: corAtual,
        emojiAtual: emojiAtual,
        onSelecionado: onSelecionado,
      ),
    );
  }
}

// ─── Dialog (desktop) ────────────────────────────────────────────────────────

class _AvatarDialog extends StatefulWidget {
  final Color corAtual;
  final String emojiAtual;
  final void Function(String) onSelecionado;

  const _AvatarDialog({
    required this.corAtual,
    required this.emojiAtual,
    required this.onSelecionado,
  });

  @override
  State<_AvatarDialog> createState() => _AvatarDialogState();
}

class _AvatarDialogState extends State<_AvatarDialog> {
  late String _selecionado;

  @override
  void initState() {
    super.initState();
    _selecionado = widget.emojiAtual;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFFFEFEFE),
      surfaceTintColor: Colors.transparent,
      elevation: 18,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.circularXxl,
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      title: const Text(
        'Escolha o emoji do seu avatar',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1F2937),
        ),
      ),
      content: SizedBox(
        width: 320,
        child: _GridEmojis(
          corFundo: widget.corAtual,
          selecionado: _selecionado,
          onTap: (emoji) => setState(() => _selecionado = emoji),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () async {
            await AvatarService.salvarEmoji(_selecionado);
            widget.onSelecionado(_selecionado);
            if (context.mounted) Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF487DE5),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: AppRadii.circularSmd),
          ),
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}

// ─── Bottom Sheet (mobile) ───────────────────────────────────────────────────

class _AvatarBottomSheet extends StatefulWidget {
  final Color corAtual;
  final String emojiAtual;
  final void Function(String) onSelecionado;

  const _AvatarBottomSheet({
    required this.corAtual,
    required this.emojiAtual,
    required this.onSelecionado,
  });

  @override
  State<_AvatarBottomSheet> createState() => _AvatarBottomSheetState();
}

class _AvatarBottomSheetState extends State<_AvatarBottomSheet> {
  late String _selecionado;

  @override
  void initState() {
    super.initState();
    _selecionado = widget.emojiAtual;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFEFEFE),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: AppRadii.circularXs,
            ),
          ),
          const Text(
            'Escolha o emoji do seu avatar',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 20),
          _GridEmojis(
            corFundo: widget.corAtual,
            selecionado: _selecionado,
            onTap: (emoji) => setState(() => _selecionado = emoji),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                await AvatarService.salvarEmoji(_selecionado);
                widget.onSelecionado(_selecionado);
                if (context.mounted) Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF487DE5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadii.circularMd,
                ),
              ),
              child: const Text(
                'Confirmar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Grid de emojis compartilhado ────────────────────────────────────────────

class _GridEmojis extends StatelessWidget {
  final Color corFundo;
  final String selecionado;
  final void Function(String) onTap;

  const _GridEmojis({
    required this.corFundo,
    required this.selecionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: kEmojisAvatar.length,
      itemBuilder: (context, index) {
        final emoji = kEmojisAvatar[index];
        final isSelected = emoji == selecionado;

        return GestureDetector(
          onTap: () => onTap(emoji),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF487DE5)
                    : Colors.transparent,
                width: 3,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF487DE5).withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: CircleAvatar(
              backgroundColor: corFundo,
              child: Text(emoji, style: const TextStyle(fontSize: 18)),
            ),
          ),
        );
      },
    );
  }
}
