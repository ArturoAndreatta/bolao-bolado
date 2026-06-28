import 'package:bolao_bolado/components/shared/branding/logo.dart';
import 'package:bolao_bolado/core/responsive.dart';
import 'package:flutter/material.dart';

class HeaderPaginas extends StatelessWidget {
  final String text;

  const HeaderPaginas({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 40,
        vertical: isMobile ? 8 : 4,
      ),
      child: Row(
        children: [
          const SizedBox(width: 20),
          SizedBox(
            width: 120,
            height: 80,
            child: Logo(isSmall: true, logo: 'images/logo4.png'),
          ),

          Container(width: 1, height: 60, color: Colors.grey.shade300),

          const SizedBox(width: 22),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: isMobile ? 24 : 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1F2937),
                    ),
                  ),

                  const SizedBox(height: 2),

                  Text(
                    "Entre para continuar",
                    style: TextStyle(
                      fontSize: isMobile ? 16 : 15,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
