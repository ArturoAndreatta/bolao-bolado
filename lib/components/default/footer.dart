import 'package:flutter/material.dart';

class Footer extends StatelessWidget {
  const Footer({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: EdgeInsets.only(bottom: 12, top: 8),
          child: Text(
            'Feito com ❤️ por Arturo Andreatta',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF1F2937),
              fontWeight: .w500,
              shadows: [
                Shadow(
                  blurRadius: 6,
                  offset: Offset(0, 1),
                  color: Color(0x33000000), // preto com alpha
                ),
              ],
            ),
            textAlign: .center,
          ),
        ),
      ),
    );
  }
}
