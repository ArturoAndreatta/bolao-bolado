import 'package:flutter/material.dart';

class BackScreenButton extends StatelessWidget {
  final bool floating;
  final VoidCallback? onTap;

  const BackScreenButton({super.key, this.floating = true, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    final button = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: const Color(0xFFF9FAFB),
        elevation: 1.5,
        shadowColor: Colors.black12,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onTap ??
                (Navigator.of(context).canPop()
                    ? () => Navigator.pop(context)
                    : null),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 14,
              vertical: isMobile ? 10 : 11,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.arrow_back,
                  size: 18,
                  color: Color(0xFF1F2937),
                ),
                if (!isMobile) ...[
                  const SizedBox(width: 8),
                  const Text(
                    'Voltar',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    if (floating) {
      return Positioned(
        top: isMobile ? 14 : 18,
        left: isMobile ? 14 : 22,
        child: button,
      );
    }

    return button;
  }
}
