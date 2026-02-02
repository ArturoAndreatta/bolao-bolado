import 'package:bolao_bolado/components/logo.dart';
import 'package:flutter/material.dart';

class HeaderPaginas extends StatelessWidget {
  final String text;
  const HeaderPaginas({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Logo(isSmall: true, logo: 'images/logo4.png'),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: text,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 30),
                  ),
                ],
              ),
              maxLines: 4,
              overflow: TextOverflow.clip,
              textAlign: TextAlign.center,
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }
}
