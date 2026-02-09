import 'dart:math';
import 'package:bolao_bolado/components/Default/default_layout.dart';
import 'package:bolao_bolado/components/back_screen_button.dart';
import 'package:bolao_bolado/components/buttons.dart';
import 'package:bolao_bolado/components/custom_card.dart';
import 'package:bolao_bolado/components/default/drawer.dart';
import 'package:bolao_bolado/components/logo.dart';
import 'package:bolao_bolado/pages/auth/signup.dart';
import 'package:bolao_bolado/pages/cadastrar_sala/cadastrar_sala_mobile.dart';
import 'package:bolao_bolado/pages/cadastrar_sala/cadastrar_sala_router.dart';
import 'package:bolao_bolado/pages/home_page.dart';
import 'package:bolao_bolado/pages/informar_aposta.dart';
import 'package:bolao_bolado/pages/participants.dart';
import 'package:bolao_bolado/components/phrases.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class Pages extends StatefulWidget {
  const Pages({super.key});

  @override
  State<Pages> createState() => _PagesState();
}

class _PagesState extends State<Pages> {
  @override
  Widget build(BuildContext context) {
    return DefaultLayout(
      drawer: AppDrawer(),
      child: Stack(
        children: [
          CustomCard(
            children: [
              SizedBox(height: 20),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '👉 Telas 👈',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 40,
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
                text: 'Sign Up',
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
              PrimaryButton(
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
              SizedBox(height: 20),
              PrimaryButton(
                text: 'Cadastrar Sala',
                onTap: () {
                  Navigator.of(context).push(
                    PageRouteBuilder(
                      transitionDuration: Duration.zero,
                      reverseTransitionDuration: Duration.zero,
                      pageBuilder: (_, _, _) => CadastrarSala(),
                    ),
                  );
                },
              ),
              SizedBox(height: 20),
              PrimaryButton(
                text: 'Consultar Salas',
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
              PrimaryButton(
                text: 'Criar Perfil',
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
            ],
          ),
          BackScreenButton(),
        ],
      ),
    );
  }
}
