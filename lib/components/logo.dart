import 'package:flutter/material.dart';

class Logo extends StatelessWidget {
  const Logo({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsGeometry.fromLTRB(0, 15, 0, 0),
      child: Image.asset('images/logo.png', height: 250, width: 500),
    );
  }
}
