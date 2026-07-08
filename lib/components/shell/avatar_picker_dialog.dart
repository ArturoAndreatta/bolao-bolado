import 'package:bolao_bolado/services/avatar/avatar_service.dart';
import 'package:flutter/material.dart';

Future<void> mostrarEscolhaAvatar(
  BuildContext context, {
  required Color corAtual,
  required void Function(Color novaCor) onSelecionado,
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
        onSelecionado: onSelecionado,
        isAdmin: isAdmin,
      ),
    );
  } else {
    await showDialog(
      context: context,
      builder: (_) => _AvatarDialog(
        corAtual: corAtual,
        onSelecionado: onSelecionado,
        isAdmin: isAdmin,
      ),
    );
  }
}

// ─── Dialog (desktop) ────────────────────────────────────────────────────────

class _AvatarDialog extends StatefulWidget {
  final Color corAtual;
  final void Function(Color) onSelecionado;
  final bool isAdmin;

  const _AvatarDialog({
    required this.corAtual,
    required this.onSelecionado,
    this.isAdmin = false,
  });

  @override
  State<_AvatarDialog> createState() => _AvatarDialogState();
}

class _AvatarDialogState extends State<_AvatarDialog> {
  late Color _selecionada;

  @override
  void initState() {
    super.initState();
    _selecionada = widget.corAtual;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFFFEFEFE),
      surfaceTintColor: Colors.transparent,
      elevation: 18,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      title: const Text(
        'Escolha a cor do seu avatar',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1F2937),
        ),
      ),
      content: SizedBox(
        width: 320,
        child: _GridCores(
          selecionada: _selecionada,
          onTap: (cor) => setState(() => _selecionada = cor),
          isAdmin: widget.isAdmin,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () async {
            await AvatarService.salvarCor(_selecionada.toARGB32());
            widget.onSelecionado(_selecionada);
            if (context.mounted) Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF487DE5),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
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
  final void Function(Color) onSelecionado;
  final bool isAdmin;

  const _AvatarBottomSheet({
    required this.corAtual,
    required this.onSelecionado,
    this.isAdmin = false,
  });

  @override
  State<_AvatarBottomSheet> createState() => _AvatarBottomSheetState();
}

class _AvatarBottomSheetState extends State<_AvatarBottomSheet> {
  late Color _selecionada;

  @override
  void initState() {
    super.initState();
    _selecionada = widget.corAtual;
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
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            'Escolha a cor do seu avatar',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 20),
          _GridCores(
            selecionada: _selecionada,
            onTap: (cor) => setState(() => _selecionada = cor),
            isAdmin: widget.isAdmin,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                await AvatarService.salvarCor(_selecionada.toARGB32());
                widget.onSelecionado(_selecionada);
                if (context.mounted) Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF487DE5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
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

// ─── Grid de cores compartilhado ─────────────────────────────────────────────

class _GridCores extends StatelessWidget {
  final Color selecionada;
  final void Function(Color) onTap;
  final bool isAdmin;

  const _GridCores({
    required this.selecionada,
    required this.onTap,
    this.isAdmin = false,
  });

  @override
  Widget build(BuildContext context) {
    final cores = isAdmin ? [...kCoresAvatar, kCorBaseAdmin] : kCoresAvatar;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: cores.length,
      itemBuilder: (context, index) {
        final cor = cores[index];
        final isSelected = cor.toARGB32() == selecionada.toARGB32();

        return GestureDetector(
          onTap: () => onTap(cor),
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
            child: CircleAvatar(backgroundColor: cor),
          ),
        );
      },
    );
  }
}
