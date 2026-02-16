import 'package:bolao_bolado/components/logo.dart';
import 'package:bolao_bolado/core/responsive.dart';
import 'package:flutter/material.dart';

class HeaderPaginas extends StatelessWidget {
  final String text;
  const HeaderPaginas({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    final logo = Logo(isSmall: true, logo: 'images/logo4.png');
    final tituloDesktop = _titulo(fontSize: 30);
    final tituloMobile = _titulo(fontSize: 25);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: isMobile
          ? Column(children: [logo, tituloMobile, const SizedBox(height: 10)])
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                logo,
                Expanded(child: tituloDesktop),
              ],
            ),
    );
  }

  Widget _titulo({required double fontSize}) {
    return Text(
      text,
      maxLines: 4,
      overflow: TextOverflow.clip,
      textAlign: TextAlign.center,
      softWrap: true,
      style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize),
    );
  }
}
