import 'dart:math';
import 'package:bolao_bolado/components/buttons.dart';
import 'package:bolao_bolado/components/footer.dart';
import 'package:bolao_bolado/components/gradient_decoration.dart';
import 'package:bolao_bolado/components/logo.dart';
import 'package:bolao_bolado/pages/login.dart';
import 'package:bolao_bolado/pages/participants.dart';
import 'package:bolao_bolado/phrases.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
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
      home: HomePage(),
      theme: ThemeData(useMaterial3: true),
      debugShowCheckedModeBanner: false,
    );
  }
}

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
    return Container(
      decoration: GradientDecoration.backgroundGradient(),
      child: Scaffold(
        bottomNavigationBar: Footer(),
        backgroundColor: Colors.transparent,
        body: Center(
          child: Padding(
            padding: EdgeInsets.fromLTRB(0, 20, 0, 0),
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
                            // DateTime now = DateTime.now();
                            // firestore
                            //     .collection('Coleção')
                            //     .doc('Documento $now')
                            //     .set({'Funcionou': true});
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
          ),
        ),
      ),
    );
  }
}
