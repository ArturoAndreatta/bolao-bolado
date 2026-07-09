import 'package:bolao_bolado/components/shared/custom_show_dialog.dart';
import 'package:bolao_bolado/components/shell/default_layout.dart';
import 'package:bolao_bolado/components/shared/buttons.dart';
import 'package:bolao_bolado/components/shared/custom_card.dart';
import 'package:bolao_bolado/components/shell/drawer.dart';
import 'package:bolao_bolado/components/shared/custom_fields.dart';
import 'package:bolao_bolado/components/shared/header_paginas.dart';
import 'package:bolao_bolado/components/shared/skeletons.dart';
import 'package:bolao_bolado/pages/cadastrar_sala/cadastrar_sala_controller.dart';
import 'package:bolao_bolado/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CadastrarSalaDesktop extends StatefulWidget {
  final String? salaId;

  const CadastrarSalaDesktop({super.key, this.salaId});

  @override
  State<CadastrarSalaDesktop> createState() => _CadastrarSalaDesktopState();
}

class _CadastrarSalaDesktopState extends State<CadastrarSalaDesktop> {
  late final _c = CadastrarSalaController(salaId: widget.salaId);
  final _formKey = GlobalKey<FormState>();

  // Metade da largura do campo, descontando o espaço do gap entre os dois
  // campos de uma mesma linha (usado em _row, ex: Data + Hora).
  static const double _fieldMaxWidth = 540;
  static const double _gap = 15.0;
  static const double _halfWidth = (_fieldMaxWidth - _gap) / 2;

  @override
  void initState() {
    super.initState();
    if (_c.editando) {
      _c.carregarSala().then((_) {
        if (mounted) setState(() {});
      });
    } else {
      _c.loadingSala = false;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (_c.saving) return;
    if (!_formKey.currentState!.validate()) {
      CustomShowDialog.show(context, "Preencha os campos obrigatórios!");
      return;
    }
    setState(() => _c.saving = true);
    try {
      await _c.salvar();
      if (mounted) {
        if (_c.editando) {
          context.pop();
        } else {
          context.go(AppRoutes.consultarSalas);
        }
      }
    } catch (e) {
      if (mounted) {
        CustomShowDialog.show(context, 'Não foi possível salvar a sala: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _c.saving = false);
      }
    }
  }

  Widget _row(Widget left, Widget right) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: _fieldMaxWidth),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: _halfWidth, child: left),
          SizedBox(width: _gap),
          SizedBox(width: _halfWidth, child: right),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_c.loadingSala) {
      return DefaultLayout(
        drawer: AppDrawer(),
        child: CustomCard(
          color: const Color(0xFFF3F1EF),
          children: const [
            HeaderPaginas(
              text: 'Editar Sala',
              subtitle: 'Atualize as configurações da sala',
            ),
            SizedBox(height: 20),
            SkeletonFormulario(
              linhas: [
                [_fieldMaxWidth],
                [_fieldMaxWidth],
                [_fieldMaxWidth],
                [_halfWidth, _halfWidth],
                [_halfWidth, _halfWidth],
                [_fieldMaxWidth],
                [_fieldMaxWidth],
              ],
              maxWidth: _fieldMaxWidth,
            ),
            SizedBox(height: 20),
          ],
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
                text: _c.editando ? 'Editar Sala' : 'Criar Sala',
                subtitle: _c.editando
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
                      controller: _c.nameController,
                      textInputAction: TextInputAction.next,
                      maxWidth: _fieldMaxWidth,
                      isRequired: true,
                      autofocus: true,
                    ),
                    SizedBox(height: _gap),
                    CustomField(
                      hint: 'Descrição',
                      icon: Icons.speaker_notes_outlined,
                      controller: _c.descricaoController,
                      textInputAction: TextInputAction.next,
                      maxWidth: _fieldMaxWidth,
                    ),
                    SizedBox(height: _gap),
                    CustomDropdownField(
                      hint: 'Sorteio',
                      icon: Icons.confirmation_number_outlined,
                      value: _c.sorteio,
                      maxWidth: _fieldMaxWidth,
                      onChanged: (v) {
                        setState(() => _c.sorteio = v);
                        FocusScope.of(context).nextFocus();
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Campo obrigatório';
                        }
                        return null;
                      },
                      items: opcoesSorteio,
                    ),
                    SizedBox(height: _gap),
                    _row(
                      CustomDateField(
                        hint: 'Data do Sorteio',
                        controller: _c.dataController,
                        textInputAction: TextInputAction.next,
                        maxWidth: _halfWidth,
                        isRequired: true,
                      ),
                      CustomTimeField(
                        hint: 'Hora do Sorteio',
                        controller: _c.horaController,
                        textInputAction: TextInputAction.next,
                        maxWidth: _halfWidth,
                        isRequired: true,
                        initialTime: _c.horaSelecionada,
                        onPicked: (picked) =>
                            setState(() => _c.horaSelecionada = picked),
                      ),
                    ),
                    SizedBox(height: _gap),
                    _row(
                      CustomField(
                        hint: 'Prêmio',
                        icon: Icons.attach_money,
                        controller: _c.premioController,
                        textInputAction: TextInputAction.next,
                        maxWidth: _halfWidth,
                        prefix: Text('R\$ '),
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        isNumeric: true,
                        isRequired: true,
                      ),
                      CustomField(
                        hint: 'Valor Máximo de Aposta',
                        icon: Icons.attach_money,
                        controller: _c.valorMaximoApostaController,
                        textInputAction: TextInputAction.next,
                        maxWidth: _halfWidth,
                        prefix: Text('R\$ '),
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        isNumeric: true,
                      ),
                    ),
                    SizedBox(height: _gap),
                    CustomField(
                      hint: 'Senha da sala',
                      icon: Icons.password,
                      controller: _c.senhaSalaController,
                      textInputAction: TextInputAction.next,
                      maxWidth: _fieldMaxWidth,
                    ),
                    SizedBox(height: _gap),
                    CustomField(
                      hint: 'Chave PIX',
                      icon: Icons.key,
                      controller: _c.chavePixController,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _salvar(),
                      maxWidth: _fieldMaxWidth,
                      isRequired: true,
                    ),
                    SizedBox(height: 20),
                    PrimaryButton(
                      text: _c.editando ? 'Salvar Alterações' : 'Confirmar',
                      onTap: _salvar,
                    ),
                    SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
