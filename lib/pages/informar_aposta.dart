import 'package:bolao_bolado/components/Default/default_layout.dart';
import 'package:bolao_bolado/components/back_screen_button.dart';
import 'package:bolao_bolado/components/buttons.dart';
import 'package:bolao_bolado/components/fields.dart';
import 'package:bolao_bolado/components/logo.dart';
import 'package:bolao_bolado/pages/participants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  FirebaseFirestore firestore = .instance;
  TextEditingController nameController = .new();
  TextEditingController valueController = .new();

  @override
  Widget build(BuildContext context) {
    return DefaultLayout(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Stack(
              children: [
                Card(
                  elevation: 20,
                  color: Color(0xFFFEFEFE),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    child: Column(
                      children: [
                        Logo(),
                        SizedBox(height: 20),
                        CustomField(
                          hint: 'Nome',
                          icon: Icons.person,
                          isNumeric: false,
                          keyboardType: null,
                          controller: nameController,
                        ),
                        SizedBox(height: 20),
                        CustomField(
                          hint: 'Valor',
                          icon: Icons.attach_money,
                          isNumeric: true,
                          keyboardType: null,
                          controller: valueController,
                        ),
                        SizedBox(height: 20),
                        PrimaryButton(
                          text: 'Confirmar',
                          onTap: () async {
                            final nome = nameController.text.trim();
                            final valor = valueController.text.trim();
                            if (nome.isEmpty || valor.isEmpty) {
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (_) {
                                  Future.delayed(Duration(seconds: 2), () {
                                    if (Navigator.of(context).canPop()) {
                                      Navigator.of(context).pop();
                                    }
                                  });
                                  return AlertDialog(
                                    backgroundColor: Color(0xFFFEFEFE),
                                    surfaceTintColor: Colors.transparent,
                                    elevation: 18,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      side: BorderSide(
                                        color: Colors.grey.shade200,
                                        width: 1,
                                      ),
                                    ),
                                    contentPadding: EdgeInsets.fromLTRB(
                                      18,
                                      18,
                                      18,
                                      14,
                                    ),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Topo com ícone + título
                                        Row(
                                          children: [
                                            Container(
                                              width: 44,
                                              height: 44,
                                              decoration: BoxDecoration(
                                                color: Color(
                                                  0xFFFFF3C7,
                                                ), // amarelinho "alerta"
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withValues(
                                                          alpha: 0.08,
                                                        ),
                                                    blurRadius: 12,
                                                    offset: Offset(0, 6),
                                                  ),
                                                ],
                                                border: Border.all(
                                                  color: Color(0xFFFDE68A),
                                                ),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  '⚠️',
                                                  style: TextStyle(
                                                    fontSize: 20,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                'Ops! Faltou preencher',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF111827),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),

                                        SizedBox(height: 12),

                                        // Mensagem
                                        Text(
                                          'Preencha o nome e o valor antes de confirmar.',
                                          textAlign: TextAlign.left,
                                          style: TextStyle(
                                            height: 1.3,
                                            fontSize: 14,
                                            color: Colors.grey.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),

                                        SizedBox(height: 14),
                                      ],
                                    ),
                                  );
                                },
                              );
                              return;
                            }
                            await firestore.collection('Apostas').doc(nome).set(
                              {'valor': valor},
                            );
                            Navigator.of(context).push(
                              PageRouteBuilder(
                                transitionDuration: Duration.zero,
                                reverseTransitionDuration: Duration.zero,
                                pageBuilder: (_, __, ___) => Participants(),
                              ),
                            );
                          },
                        ),
                        SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
                BackScreenButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
