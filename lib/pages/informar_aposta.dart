import 'package:bolao_bolado/components/shared/dialogs/custom_show_dialog.dart';
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
                  if (nome.isEmpty || valorEditado.isEmpty) {
                    CustomShowDialog.show(
                      context,
                      "Preencha o nome e o valor antes de confirmar.",
                    );
                    return;
                  }
                  if (double.parse(valorEditado) % 6 != 0) {
                    CustomShowDialog.show(
                      context,
                      "O valor deve ser divisível por 6!",
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
