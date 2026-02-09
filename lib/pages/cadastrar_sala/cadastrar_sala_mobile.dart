import 'package:bolao_bolado/components/Default/default_layout.dart';
import 'package:bolao_bolado/components/back_screen_button.dart';
import 'package:bolao_bolado/components/buttons.dart';
import 'package:bolao_bolado/components/custom_card.dart';
import 'package:bolao_bolado/components/default/drawer.dart';
import 'package:bolao_bolado/components/custom_fields.dart';
import 'package:bolao_bolado/components/header_paginas.dart';
import 'package:bolao_bolado/pages/participants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CadastrarSalaMobile extends StatefulWidget {
  const CadastrarSalaMobile({super.key});

  @override
  State<CadastrarSalaMobile> createState() => _CadastrarSalaMobileState();
}

class _CadastrarSalaMobileState extends State<CadastrarSalaMobile> {
  FirebaseFirestore firestore = .instance;
  TextEditingController nameController = .new();
  TextEditingController valueController = .new();
  TextEditingController descriptionController = .new();
  TextEditingController horaController = .new();
  TextEditingController dataController = .new();
  TextEditingController premioController = .new();
  TextEditingController numerosApostadosController = .new();
  TextEditingController valorMaximoApostaController = .new();
  TextEditingController senhaSalaController = .new();
  TextEditingController chavePixController = .new();
  TimeOfDay? horaSelecionada;
  String? sorteio;

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
                    icon: Icons.groups_2_outlined,
                    controller: nameController,
                    maxWidth: 500,
                  ),
                  SizedBox(height: 15),
                  CustomField(
                    hint: 'Descrição',
                    icon: Icons.speaker_notes_outlined,
                    controller: descriptionController,
                    maxWidth: 500,
                  ),
                  SizedBox(height: 15),
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
                  SizedBox(height: 15),
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
                  SizedBox(height: 15),
                  CustomField(
                    hint: 'Hora do Sorteio',
                    controller: horaController,
                    maxWidth: 500,
                    readOnly: true,
                    icon: Icons.schedule_outlined,
                    onTap: () async {
                      FocusScope.of(context).unfocus();
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: horaSelecionada ?? TimeOfDay.now(),
                      );
                      if (picked == null) return;
                      setState(() {
                        horaSelecionada = picked;
                        final hh = picked.hour.toString().padLeft(2, '0');
                        final mm = picked.minute.toString().padLeft(2, '0');
                        horaController.text = '$hh:$mm';
                      });
                    },
                  ),
                  SizedBox(height: 15),
                  CustomField(
                    hint: 'Prêmio',
                    icon: Icons.attach_money,
                    controller: premioController,
                    maxWidth: 500,
                    prefix: Text('R\$ '),
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    isNumeric: true,
                  ),
                  SizedBox(height: 15),
                  CustomField(
                    hint: 'Números Apostados',
                    icon: Icons.numbers,
                    controller: numerosApostadosController,
                    maxWidth: 500,
                  ),
                  SizedBox(height: 15),
                  CustomField(
                    hint: 'Valor Máximo de Aposta',
                    icon: Icons.attach_money,
                    controller: valorMaximoApostaController,
                    maxWidth: 500,
                    prefix: Text('R\$ '),
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    isNumeric: true,
                  ),
                  SizedBox(height: 15),
                  CustomField(
                    hint: 'Senha da sala',
                    icon: Icons.password,
                    controller: senhaSalaController,
                    maxWidth: 500,
                  ),
                  SizedBox(height: 15),
                  CustomField(
                    hint: 'Chave PIX',
                    icon: Icons.key,
                    controller: chavePixController,
                    maxWidth: 500,
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
                  SizedBox(height: 20),
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
