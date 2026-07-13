import 'package:bolao_bolado/components/shared/custom_show_dialog.dart';
import 'package:bolao_bolado/components/shell/default_layout.dart';
import 'package:bolao_bolado/components/shared/buttons.dart';
import 'package:bolao_bolado/components/shared/custom_card.dart';
import 'package:bolao_bolado/components/shell/drawer.dart';
import 'package:bolao_bolado/components/shared/custom_fields.dart';
import 'package:bolao_bolado/components/shared/header_paginas.dart';
import 'package:bolao_bolado/components/shared/skeletons.dart';
import 'package:bolao_bolado/core/responsive.dart';
import 'package:bolao_bolado/pages/cadastrar_sala/cadastrar_sala_controller.dart';
import 'package:bolao_bolado/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Formulário único de criação/edição de sala. Desktop exibe campos
// relacionados lado a lado (Data+Hora, Prêmio+Valor Máximo); mobile empilha
// tudo em uma coluna. Toda a lógica (controller, validação, salvar) é
// compartilhada — só o layout muda conforme Responsive.isMobile.
class CadastrarSalaForm extends StatefulWidget {
  final String? salaId;

  const CadastrarSalaForm({super.key, this.salaId});

  @override
  State<CadastrarSalaForm> createState() => _CadastrarSalaFormState();
}

class _CadastrarSalaFormState extends State<CadastrarSalaForm> {
  late final _c = CadastrarSalaController(salaId: widget.salaId);
  final _formKey = GlobalKey<FormState>();

  // Metade da largura do campo, descontando o espaço do gap entre os dois
  // campos de uma mesma linha no layout desktop (ex: Data + Hora).
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
    final isMobile = Responsive.isMobile(context);
    final maxWidth = isMobile ? 480.0 : _fieldMaxWidth;
    final gap = isMobile ? 15.0 : _gap;

    if (_c.loadingSala) {
      return DefaultLayout(
        drawer: AppDrawer(),
        child: CustomCard(
          color: const Color(0xFFF3F1EF),
          children: [
            const HeaderPaginas(
              text: 'Editar Sala',
              subtitle: 'Atualize as configurações da sala',
            ),
            const SizedBox(height: 20),
            SkeletonFormulario(
              linhas: isMobile
                  ? const [
                      [480],
                      [480],
                      [480],
                      [480],
                      [480],
                      [480],
                      [480],
                      [480],
                    ]
                  : [
                      [_fieldMaxWidth],
                      [_fieldMaxWidth],
                      [_fieldMaxWidth],
                      [_halfWidth, _halfWidth],
                      [_halfWidth, _halfWidth],
                      [_fieldMaxWidth],
                      [_fieldMaxWidth],
                    ],
              maxWidth: maxWidth,
            ),
            const SizedBox(height: 20),
          ],
        ),
      );
    }

    final campoData = FocusTraversalOrder(
      order: const NumericFocusOrder(4),
      child: CustomDateField(
        hint: 'Data do Sorteio',
        controller: _c.dataController,
        textInputAction: TextInputAction.next,
        maxWidth: isMobile ? maxWidth : _halfWidth,
        isRequired: true,
      ),
    );
    final campoHora = FocusTraversalOrder(
      order: const NumericFocusOrder(5),
      child: CustomTimeField(
        hint: 'Hora do Sorteio',
        controller: _c.horaController,
        textInputAction: TextInputAction.next,
        maxWidth: isMobile ? maxWidth : _halfWidth,
        isRequired: true,
        initialTime: _c.horaSelecionada,
        onPicked: (picked) => setState(() => _c.horaSelecionada = picked),
      ),
    );
    final campoPremio = FocusTraversalOrder(
      order: const NumericFocusOrder(6),
      child: CustomField(
        hint: 'Prêmio',
        icon: Icons.attach_money,
        controller: _c.premioController,
        textInputAction: TextInputAction.next,
        maxWidth: isMobile ? maxWidth : _halfWidth,
        prefix: const Text('R\$ '),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        isNumeric: true,
        isRequired: true,
      ),
    );
    final campoValorMaximo = FocusTraversalOrder(
      order: const NumericFocusOrder(7),
      child: CustomField(
        hint: 'Valor Máximo de Aposta',
        icon: Icons.attach_money,
        semCentavos: true,
        controller: _c.valorMaximoApostaController,
        textInputAction: TextInputAction.next,
        maxWidth: isMobile ? maxWidth : _halfWidth,
        prefix: const Text('R\$ '),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        isNumeric: true,
      ),
    );

    return DefaultLayout(
      drawer: AppDrawer(),
      child: Stack(
        children: [
          CustomCard(
            color: const Color(0xFFF3F1EF),
            children: [
              HeaderPaginas(
                text: _c.editando ? 'Editar Sala' : 'Criar Sala',
                subtitle: _c.editando
                    ? 'Atualize as configurações da sala'
                    : 'Configure sua nova sala de apostas',
              ),
              Form(
                key: _formKey,
                child: FocusTraversalGroup(
                  policy: OrderedTraversalPolicy(),
                  child: CustomCard(
                    isChild: true,
                    children: [
                      SizedBox(height: 20),
                      FocusTraversalOrder(
                        order: const NumericFocusOrder(1),
                        child: CustomField(
                          hint: 'Nome da Sala',
                          icon: Icons.groups_2_outlined,
                          controller: _c.nameController,
                          textInputAction: TextInputAction.next,
                          maxWidth: maxWidth,
                          isRequired: true,
                          autofocus: true,
                        ),
                      ),
                      SizedBox(height: gap),
                      FocusTraversalOrder(
                        order: const NumericFocusOrder(2),
                        child: CustomField(
                          hint: 'Descrição',
                          icon: Icons.speaker_notes_outlined,
                          controller: _c.descricaoController,
                          textInputAction: TextInputAction.next,
                          maxWidth: maxWidth,
                        ),
                      ),
                      SizedBox(height: gap),
                      FocusTraversalOrder(
                        order: const NumericFocusOrder(3),
                        child: CustomDropdownField(
                          hint: 'Sorteio',
                          icon: Icons.confirmation_number_outlined,
                          value: _c.sorteio,
                          maxWidth: maxWidth,
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
                      ),
                      SizedBox(height: gap),
                      if (isMobile) ...[
                        campoData,
                        SizedBox(height: gap),
                        campoHora,
                      ] else
                        _row(campoData, campoHora),
                      SizedBox(height: gap),
                      if (isMobile) ...[
                        campoPremio,
                        SizedBox(height: gap),
                        campoValorMaximo,
                      ] else
                        _row(campoPremio, campoValorMaximo),
                      SizedBox(height: gap),
                      FocusTraversalOrder(
                        order: const NumericFocusOrder(8),
                        child: CustomField(
                          hint: 'Senha da sala',
                          icon: Icons.password,
                          controller: _c.senhaSalaController,
                          textInputAction: TextInputAction.next,
                          maxWidth: maxWidth,
                        ),
                      ),
                      SizedBox(height: gap),
                      FocusTraversalOrder(
                        order: const NumericFocusOrder(9),
                        child: CustomField(
                          hint: 'Chave PIX',
                          icon: Icons.key,
                          controller: _c.chavePixController,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _salvar(),
                          maxWidth: maxWidth,
                          isRequired: true,
                        ),
                      ),
                      const SizedBox(height: 20),
                      FocusTraversalOrder(
                        order: const NumericFocusOrder(10),
                        child: PrimaryButton(
                          text: _c.editando ? 'Salvar Alterações' : 'Confirmar',
                          onTap: _salvar,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
