import 'package:bolao_bolado/components/shell/default_layout.dart';
import 'package:bolao_bolado/components/shared/back_screen_button.dart';
import 'package:bolao_bolado/components/shared/buttons.dart';
import 'package:bolao_bolado/components/shared/custom_card.dart';
import 'package:bolao_bolado/components/shell/drawer.dart';
import 'package:bolao_bolado/components/shared/custom_fields.dart';
import 'package:bolao_bolado/components/shared/branding/logo.dart';
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
      drawer: AppDrawer(),
      child: Stack(
        children: [
          CustomCard(
            children: [
              Logo(),
              SizedBox(height: 20),
              CustomField(
                hint: 'Nome',
                icon: Icons.person,
                controller: nameController,
              ),
              SizedBox(height: 20),
              CustomField(
                hint: 'Valor',
                icon: Icons.attach_money,
                isNumeric: true,
                controller: valueController,
              ),
              SizedBox(height: 20),
              PrimaryButton(
                text: 'Confirmar',
                onTap: () async {
                  final nome = nameController.text.trim();
                  final valor = valueController.text.trim();
                  final valorEditado = valor.replaceAll(',', '.');
                  final navigator = Navigator.of(context);
                  if (nome.isEmpty ||
                      valorEditado.isEmpty ||
                      (double.parse(valorEditado) % 6 != 0)) {
                    showDialog(
                      context: context,
                      barrierDismissible: true,
                      builder: (_) {
                        Future.delayed(Duration(seconds: 2), () {
                          if (navigator.canPop()) {
                            navigator.pop();
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
                          contentPadding: EdgeInsets.fromLTRB(18, 18, 18, 14),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: Color(0xFFFFF3C7),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
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
                                        style: TextStyle(fontSize: 20),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Ops, um problema foi encontrado!',
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
                              Text(
                                (valorEditado.isNotEmpty &&
                                        double.parse(valorEditado) % 6 != 0)
                                    ? "O número deve ser divisível por 6!"
                                    : 'Preencha o nome e o valor antes de confirmar.',
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
                  await firestore.collection('Apostas').doc(nome).set({
                    'valor': valorEditado,
                    'data-hora': FieldValue.serverTimestamp(),
                  });
                  navigator.push(
                    PageRouteBuilder(pageBuilder: (_, _, _) => Participants()),
                  );
                },
              ),
              SizedBox(height: 30),
            ],
          ),
          BackScreenButton(),
        ],
      ),
    );
  }
}
