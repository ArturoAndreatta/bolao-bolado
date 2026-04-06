import 'dart:async';
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
                backgroundColor: const Color(0xFFFEFEFE),
                surfaceTintColor: Colors.transparent,
                elevation: 18,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: Colors.grey.shade200, width: 1),
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
                            color: const Color(0xFFFFF3C7),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: const Center(
                            child: Text('⚠️', style: TextStyle(fontSize: 20)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Ops, um problema foi encontrado!',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      mensagem,
                      textAlign: TextAlign.left,
                      style: const TextStyle(
                        height: 1.3,
                        fontSize: 14,
                        color: Colors.grey,
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
