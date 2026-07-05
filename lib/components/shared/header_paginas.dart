import 'package:bolao_bolado/components/shared/branding/logo.dart';
import 'package:bolao_bolado/core/responsive.dart';
import 'package:flutter/material.dart';

class HeaderPaginas extends StatelessWidget {
  final String text;
  final String subtitle;
  final Widget? trailing;

  const HeaderPaginas({
    super.key,
    required this.text,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Padding(
      padding: EdgeInsets.symmetric(
        // horizontal: isMobile ? 16 : 24,
        // vertical: isMobile ? 4 : 2,
      ),
      child: Row(
        children: [
          // SizedBox(
          // width: isMobile ? 72 : 80,
          // height: isMobile ? 44 : 48,
          // child: Logo(isSmall: true, logo: 'images/logo4.png'),
          // ),
          const SizedBox(width: 14),
          Container(
            width: 1,
            height: isMobile ? 32 : 36,
            color: Colors.grey.shade300,
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 4, 0, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isMobile ? 24 : 21,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1F2937),
                    ),
                  ),

                  const SizedBox(height: 0),

                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: isMobile ? 15 : 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
