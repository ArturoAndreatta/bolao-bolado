import 'package:bolao_bolado/components/Default/default_layout.dart';
import 'package:bolao_bolado/components/back_screen_button.dart';
import 'package:bolao_bolado/components/buttons.dart';
import 'package:bolao_bolado/components/custom_card.dart';
import 'package:bolao_bolado/components/default/drawer.dart';
import 'package:bolao_bolado/components/custom_fields.dart';
import 'package:bolao_bolado/components/header_paginas.dart';
import 'package:bolao_bolado/components/logo.dart';
import 'package:bolao_bolado/pages/participants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CadastrarSala extends StatefulWidget {
  const CadastrarSala({super.key});

  @override
  State<CadastrarSala> createState() => _CadastrarSalaState();
}

class _CadastrarSalaState extends State<CadastrarSala> {
  FirebaseFirestore firestore = .instance;
  TextEditingController nameController = .new();
  TextEditingController valueController = .new();
  String? sorteio;
  final TextEditingController dataController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return DefaultLayout(
      drawer: AppDrawer(),
      child: Stack(
        children: [
          CustomCard(
            color: Color(0xFFF3F1EF),
            children: [
              HeaderPaginas(text: 'Criar Sala'),
              CustomCard(
                isChild: true,
                children: [
                  SizedBox(height: 20),
                  CustomField(
                    hint: 'Nome da Sala',
                    // icon: Icons.groups,
                    controller: nameController,
                    maxWidth: 500,
                  ),
                  SizedBox(height: 20),
                  CustomField(
                    hint: 'Descrição',
                    controller: nameController,
                    maxWidth: 500,
                  ),
                  SizedBox(height: 20),
                  CustomDropdownField(
                    hint: 'Sorteio',
                    icon: Icons.confirmation_number_outlined,
                    value: sorteio,
                    maxWidth: 500,
                    onChanged: (v) => setState(() => sorteio = v),
                    items: const [
                      DropdownMenuItem(value: 'mega', child: Text('Mega-Sena')),
                      DropdownMenuItem(value: 'loto', child: Text('Lotofácil')),
                      DropdownMenuItem(value: 'outros', child: Text('Outros')),
                    ],
                  ),
                  SizedBox(height: 20),
                  CustomField(
                    hint: 'Data do Sorteio',
                    controller: dataController,
                    maxWidth: 500,
                    readOnly: true,
                    icon: Icons.calendar_today,
                    onTap: () async {
                      FocusScope.of(context).requestFocus(FocusNode());
                      final data = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (data == null) return;
                      dataController.text =
                          '${data.day.toString().padLeft(2, '0')}/'
                          '${data.month.toString().padLeft(2, '0')}/'
                          '${data.year}';
                    },
                  ),
                  SizedBox(height: 20),
                  PrimaryButton(
                    text: 'Confirmar',
                    onTap: () async {
                      final nome = nameController.text.trim();
                      final valor = valueController.text.trim();
                      if (nome.isEmpty ||
                          valor.isEmpty ||
                          (double.parse(valor) % 6 != 0)) {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) {
                            final navigator = Navigator.of(context);
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
                                          color: Color(0xFFFFF3C7),
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
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
                                    (valor.isNotEmpty &&
                                            double.parse(valor) % 6 != 0)
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
                        'valor': valor,
                      });
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
            ],
          ),
          BackScreenButton(),
        ],
      ),
    );
  }
}
