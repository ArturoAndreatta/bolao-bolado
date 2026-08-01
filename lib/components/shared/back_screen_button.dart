import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/core/app_radii.dart';
import 'package:bolao_bolado/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BackScreenButton extends StatelessWidget {
  final bool floating;
  final VoidCallback? onTap;

  const BackScreenButton({super.key, this.floating = true, this.onTap});

  void _voltar(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    final isMobile = MediaQuery.of(context).size.width < 600;

    final button = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: cores.campo,
        elevation: 1.5,
        shadowColor: Colors.black12,
        borderRadius: AppRadii.circularCircle,
        child: InkWell(
          borderRadius: AppRadii.circularCircle,
          onTap: onTap ?? () => _voltar(context),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 14,
              vertical: isMobile ? 10 : 11,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back, size: 18, color: cores.texto),
                if (!isMobile) ...[
                  const SizedBox(width: 8),
                  Text(
                    'Voltar',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: cores.texto,
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
