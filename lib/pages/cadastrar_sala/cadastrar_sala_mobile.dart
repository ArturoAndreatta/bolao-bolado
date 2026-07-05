import 'package:bolao_bolado/components/shared/custom_show_dialog.dart';
import 'package:bolao_bolado/components/shell/default_layout.dart';
import 'package:bolao_bolado/components/shared/back_screen_button.dart';
import 'package:bolao_bolado/components/shared/buttons.dart';
import 'package:bolao_bolado/components/shared/custom_card.dart';
import 'package:bolao_bolado/components/shell/drawer.dart';
import 'package:bolao_bolado/components/shared/custom_fields.dart';
import 'package:bolao_bolado/components/shared/header_paginas.dart';
import 'package:bolao_bolado/pages/cadastrar_sala/cadastrar_sala_router.dart';
import 'package:bolao_bolado/pages/consultar_salas.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CadastrarSalaMobile extends StatefulWidget {
  final String? salaId;

  const CadastrarSalaMobile({super.key, this.salaId});

  @override
  State<CadastrarSalaMobile> createState() => _CadastrarSalaMobileState();
}

class _CadastrarSalaMobileState extends State<CadastrarSalaMobile> {
  FirebaseFirestore firestore = .instance;
  TextEditingController nameController = .new();
  TextEditingController descricaoController = .new();
  TextEditingController valorController = .new();
  TextEditingController horaController = .new();
  TextEditingController dataController = .new();
  TextEditingController premioController = .new();
  TextEditingController valorMaximoApostaController = .new();
  TextEditingController senhaSalaController = .new();
  TextEditingController chavePixController = .new();
  TimeOfDay? horaSelecionada;
  String? sorteio;
  bool _saving = false;
  bool _loadingSala = true;
  final _formKey = GlobalKey<FormState>();

  bool get _editando => widget.salaId != null;

  @override
  void initState() {
    super.initState();
    if (_editando) {
      _carregarSala();
    } else {
      _loadingSala = false;
    }
  }

  Future<void> _carregarSala() async {
    final doc = await firestore.collection('Salas').doc(widget.salaId).get();
    final dados = doc.data();
    if (dados != null) {
      final formatoMoeda = NumberFormat.currency(
        locale: 'pt_BR',
        symbol: '',
        decimalDigits: 2,
      );
      nameController.text = dados['nome']?.toString() ?? '';
      descricaoController.text = dados['descricao']?.toString() ?? '';
      sorteio = dados['sorteio']?.toString();
      final dataHora = dados['dataHora'];
      if (dataHora is Timestamp) {
        final dt = dataHora.toDate();
        dataController.text =
            '${dt.day.toString().padLeft(2, '0')}/'
            '${dt.month.toString().padLeft(2, '0')}/'
            '${dt.year}';
        horaSelecionada = TimeOfDay(hour: dt.hour, minute: dt.minute);
        horaController.text =
            '${dt.hour.toString().padLeft(2, '0')}:'
            '${dt.minute.toString().padLeft(2, '0')}';
      }
      final premio = (dados['premio'] as num?)?.toDouble();
      if (premio != null) {
        premioController.text = formatoMoeda.format(premio).trim();
      }
      final valorMaximo = (dados['valorMaximo'] as num?)?.toDouble();
      if (valorMaximo != null) {
        valorMaximoApostaController.text = formatoMoeda
            .format(valorMaximo)
            .trim();
      }
      senhaSalaController.text = dados['senha']?.toString() ?? '';
      chavePixController.text = dados['chavePix']?.toString() ?? '';
    }
    if (mounted) {
      setState(() => _loadingSala = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingSala) {
      return DefaultLayout(
        drawer: AppDrawer(),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF7CC8B5)),
        ),
      );
    }

    return DefaultLayout(
      drawer: AppDrawer(),
      child: Stack(
        children: [
          CustomCard(
            color: Color(0xFFF3F1EF),
            children: [
              HeaderPaginas(
                text: _editando ? 'Editar Sala' : 'Criar Sala',
                subtitle: _editando
                    ? 'Atualize as configurações da sala'
                    : 'Configure sua nova sala de apostas',
              ),
              Form(
                key: _formKey,
                child: CustomCard(
                  isChild: true,
                  children: [
                    SizedBox(height: 20),
                    CustomField(
                      hint: 'Nome da Sala',
                      icon: Icons.groups_2_outlined,
                      controller: nameController,
                      textInputAction: TextInputAction.next,
                      maxWidth: 480,
                      isRequired: true,
                    ),
                    SizedBox(height: 15),
                    CustomField(
                      hint: 'Descrição',
                      icon: Icons.speaker_notes_outlined,
                      controller: descricaoController,
                      textInputAction: TextInputAction.next,
                      maxWidth: 480,
                    ),
                    SizedBox(height: 15),
                    CustomDropdownField(
                      hint: 'Sorteio',
                      icon: Icons.confirmation_number_outlined,
                      value: sorteio,
                      maxWidth: 480,
                      onChanged: (v) {
                        setState(() => sorteio = v);
                        FocusScope.of(context).nextFocus();
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Campo obrigatório';
                        }
                        return null;
                      },
                      items: const [
                        DropdownMenuItem(
                          value: 'mega',
                          child: Text('Mega-Sena'),
                        ),
                        DropdownMenuItem(
                          value: 'loto',
                          child: Text('Lotofácil'),
                        ),
                        DropdownMenuItem(
                          value: 'outros',
                          child: Text('Outros'),
                        ),
                      ],
                    ),
                    SizedBox(height: 15),
                    CustomField(
                      hint: 'Data do Sorteio',
                      controller: dataController,
                      textInputAction: TextInputAction.next,
                      maxWidth: 480,
                      readOnly: true,
                      isRequired: true,
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
                      textInputAction: TextInputAction.next,
                      maxWidth: 480,
                      readOnly: true,
                      isRequired: true,
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
                      textInputAction: TextInputAction.next,
                      maxWidth: 480,
                      prefix: Text('R\$ '),
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      isNumeric: true,
                      isRequired: true,
                    ),
                    SizedBox(height: 15),
                    CustomField(
                      hint: 'Valor Máximo de Aposta',
                      icon: Icons.attach_money,
                      controller: valorMaximoApostaController,
                      textInputAction: TextInputAction.next,
                      maxWidth: 480,
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
                      textInputAction: TextInputAction.next,
                      maxWidth: 480,
                    ),
                    SizedBox(height: 15),
                    CustomField(
                      hint: 'Chave PIX',
                      icon: Icons.key,
                      controller: chavePixController,
                      textInputAction: TextInputAction.done,
                      maxWidth: 480,
                      isRequired: true,
                    ),
                    SizedBox(height: 20),
                    PrimaryButton(
                      text: _editando ? 'Salvar Alterações' : 'Confirmar',
                      onTap: () async {
                        if (_saving) return;
                        final navigator = Navigator.of(context);
                        if (!_formKey.currentState!.validate()) {
                          CustomShowDialog.show(
                            context,
                            "Preencha os campos obrigatórios!",
                          );
                          return;
                        }
                        final dataHora = juntarDataHora(
                          dataController.text,
                          horaController.text,
                        );
                        setState(() => _saving = true);
                        try {
                          final dados = {
                            'nome': nameController.text,
                            'descricao': descricaoController.text,
                            'sorteio': sorteio,
                            'dataHora': Timestamp.fromDate(dataHora),
                            'premio': double.parse(
                              premioController.text
                                  .replaceAll('.', '')
                                  .replaceAll(',', '.'),
                            ),
                            'valorMaximo':
                                valorMaximoApostaController.text.isNotEmpty
                                ? double.parse(
                                    valorMaximoApostaController.text
                                        .replaceAll('.', '')
                                        .replaceAll(',', '.'),
                                  )
                                : null,
                            'senha': senhaSalaController.text,
                            'chavePix': chavePixController.text,
                          };
                          if (_editando) {
                            await firestore
                                .collection('Salas')
                                .doc(widget.salaId)
                                .update(dados);
                          } else {
                            await firestore.collection('Salas').add(dados);
                          }
                          if (_editando) {
                            navigator.pop();
                          } else {
                            navigator.push(
                              PageRouteBuilder(
                                transitionDuration: Duration.zero,
                                reverseTransitionDuration: Duration.zero,
                                pageBuilder: (_, _, _) => ConsultarSalas(),
                              ),
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _saving = false);
                          }
                        }
                      },
                    ),
                    SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
          BackScreenButton(),
        ],
      ),
    );
  }
}
