import 'package:bolao_bolado/pages/auth/signup.dart';
import 'package:flutter/material.dart';

class BolaoBolado extends StatefulWidget {
  const BolaoBolado({super.key});

  @override
  State<BolaoBolado> createState() => _BolaoBoladoState();
}

class _BolaoBoladoState extends State<BolaoBolado> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bolão Bolado',
      home: Signup(),
      theme: ThemeData(useMaterial3: true),
      debugShowCheckedModeBanner: false,
    );
  }
}
