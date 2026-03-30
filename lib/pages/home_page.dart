import 'dart:math';
import 'package:bolao_bolado/components/shell/default_layout.dart';
import 'package:bolao_bolado/components/shared/buttons.dart';
import 'package:bolao_bolado/components/shared/custom_card.dart';
import 'package:bolao_bolado/components/shell/drawer.dart';
import 'package:bolao_bolado/components/shared/branding/logo.dart';
import 'package:bolao_bolado/pages/auth/signup.dart';
import 'package:bolao_bolado/pages/informar_aposta.dart';
import 'package:bolao_bolado/pages/pages.dart';
import 'package:bolao_bolado/pages/participants.dart';
import 'package:bolao_bolado/components/shared/constants/phrases.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late String frase;

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
    final width = MediaQuery.of(context).size.width;
    final isDesktopWeb = kIsWeb && width >= 900;
    return DefaultLayout(
      drawer: AppDrawer(),
      child: Stack(
        children: [
          CustomCard(
            children: [
              Logo(),
              SizedBox(height: 20),
              Text.rich(
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
              SizedBox(height: 20),
              PrimaryButton(
                text: 'Acessar',
                onTap: () {
                  Navigator.of(context).push(
                    PageRouteBuilder(
                      transitionDuration: Duration.zero,
                      reverseTransitionDuration: Duration.zero,
                      pageBuilder: (_, _, _) => Signup(),
                    ),
                  );
                },
              ),
              SizedBox(height: 20),
              // SecondaryButton(
              //   text: 'Visualizar',
              //   onTap: () {
              //     Navigator.of(context).push(
              //       PageRouteBuilder(
              //         transitionDuration: Duration.zero,
              //         reverseTransitionDuration: Duration.zero,
              //         pageBuilder: (_, _, _) => Participants(),
              //       ),
              //     );
              //   },
              // ),
              // SizedBox(height: 30),
            ],
          ),
          Positioned(
            top: 10,
            left: isDesktopWeb ? 500 : 250,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () {
                  Navigator.of(context).push(
                    PageRouteBuilder(
                      transitionDuration: Duration.zero,
                      reverseTransitionDuration: Duration.zero,
                      pageBuilder: (_, _, _) => Pages(),
                    ),
                  );
                },
                child: Container(padding: EdgeInsets.all(20)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
