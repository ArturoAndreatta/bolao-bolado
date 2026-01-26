import 'dart:math';
import 'package:bolao_bolado/components/Default/default_layout.dart';
import 'package:bolao_bolado/components/buttons.dart';
import 'package:bolao_bolado/components/default/drawer.dart';
import 'package:bolao_bolado/components/logo.dart';
import 'package:bolao_bolado/pages/informar_aposta.dart';
import 'package:bolao_bolado/pages/participants.dart';
import 'package:bolao_bolado/components/phrases.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late String frase;
  // FirebaseFirestore firestore = .instance;

  @override
  void initState() {
    super.initState();
    _sortearFrase();
  }

  void _sortearFrase() {
    final random = Random();
    frase = phrases[random.nextInt(phrases.length)];
  }

  @override
  Widget build(BuildContext context) {
    return DefaultLayout(
      drawer: AppDrawer(),
      child: Column(
        children: [
          SingleChildScrollView(
            child: Card(
              elevation: 20,
              color: Color(0xFFFEFEFE),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Logo(),
                  SizedBox(height: 20),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 420),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Bem-vindo',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(
                            text: ' ao Bolão Bolado!',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          TextSpan(
                            text: '\n$frase',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontStyle: FontStyle.italic,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 25),
                      softWrap: true,
                    ),
                  ),
                  SizedBox(height: 20),
                  PrimaryButton(
                    text: 'Participar',
                    onTap: () {
                      Navigator.of(context).push(
                        PageRouteBuilder(
                          transitionDuration: Duration.zero,
                          reverseTransitionDuration: Duration.zero,
                          pageBuilder: (_, _, _) => Login(),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 20),
                  SecondaryButton(
                    text: 'Visualizar',
                    onTap: () {
                      Navigator.of(context).push(
                        PageRouteBuilder(
                          transitionDuration: Duration.zero,
                          reverseTransitionDuration: Duration.zero,
                          pageBuilder: (_, _, _) => Participants(),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
