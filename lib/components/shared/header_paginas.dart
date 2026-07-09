import 'package:bolao_bolado/components/shared/back_screen_button.dart';
import 'package:bolao_bolado/core/responsive.dart';
import 'package:flutter/material.dart';

class HeaderPaginas extends StatelessWidget {
  final String text;
  final String subtitle;
  final Widget? trailing;
  final bool showBackButton;

  const HeaderPaginas({
    super.key,
    required this.text,
    required this.subtitle,
    this.trailing,
    this.showBackButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 0, 10, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showBackButton) const BackScreenButton(floating: false),
          const SizedBox(width: 14),
          Container(
            width: 1,
            height: isMobile ? 50 : 40,
            color: Colors.grey.shade300,
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
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
                      height: 1.0,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: isMobile ? 15 : 14,
                      color: Colors.grey.shade600,
                      height: 1.0,
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
