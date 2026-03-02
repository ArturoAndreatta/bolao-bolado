import 'package:flutter/material.dart';

class Logo extends StatelessWidget {
  final bool? isSmall;
  final String? logo;

  const Logo({super.key, this.isSmall, this.logo = 'images/logo.png'});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 15),
      child: Image.asset(
        logo!,
        height: (isSmall == true) ? 150 : 250,
        width: (isSmall == true) ? 200 : 335,
      ),
    );
  }
}
