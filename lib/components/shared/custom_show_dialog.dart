import 'dart:async';
import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/core/app_radii.dart';
import 'package:flutter/material.dart';

class CustomShowDialog {
  static void show(BuildContext context, String mensagem) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        Timer? timer;
        return StatefulBuilder(
          builder: (context, setState) {
            final cores = AppCores.de(context);
            timer ??= Timer(const Duration(seconds: 2), () {
              timer?.cancel();
              if (Navigator.of(dialogContext).canPop()) {
                Navigator.of(dialogContext).pop();
              }
            });
            return PopScope(
              onPopInvokedWithResult: (didPop, result) {
                if (didPop) timer?.cancel();
              },
              child: AlertDialog(
                backgroundColor: cores.card,
                surfaceTintColor: Colors.transparent,
                elevation: 18,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadii.circularXxl,
                  side: BorderSide(color: cores.borda, width: 1),
                ),
                contentPadding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: cores.fundoAmarelo,
                            borderRadius: AppRadii.circularLg,
                            border: Border.all(color: cores.bordaAmarelo),
                          ),
                          child: const Center(
                            child: Text('⚠️', style: TextStyle(fontSize: 20)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Ops, um problema foi encontrado!',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: cores.texto,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      mensagem,
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        height: 1.3,
                        fontSize: 14,
                        color: cores.textoSuave,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
