import 'package:bolao_bolado/components/formatters/formatters.dart';
import 'package:bolao_bolado/components/formatters/money_input_format.dart';
import 'package:bolao_bolado/components/shared/custom_field_decoration.dart';
import 'package:bolao_bolado/components/shared/seletor_data_hora.dart';
import 'package:bolao_bolado/core/app_cores.dart';
import 'package:flutter/material.dart';

class CustomField extends StatelessWidget {
  final String hint;
  final IconData? icon;
  final bool? isNumeric;
  final TextInputType? keyboardType;
  final TextEditingController controller;
  final TextInputAction? textInputAction;
  final double? maxWidth;
  final Widget? suffix;
  final bool? obscure;
  final bool? readOnly;
  final Widget? prefix;
  final void Function()? onTap;
  final void Function(String)? onFieldSubmitted;
  final bool? isRequired;
  // Validação adicional, aplicada depois da checagem de obrigatório/numérico.
  // Retorne null para indicar que o valor passou nessa checagem extra.
  final String? Function(String?)? validator;
  final bool autofocus;
  // Quando isNumeric, controla se os dígitos digitados vão direto para a
  // parte inteira (sem centavos) — usado em valores sempre inteiros, como
  // o valor de aposta da Mega-Sena (múltiplo de R$6).
  final bool semCentavos;
  final FocusNode? focusNode;
  // Dicas de preenchimento automático (gerenciador de senhas do navegador,
  // Chaveiro do iCloud, Google Password Manager). Na web o engine do Flutter só
  // cria o <input autocomplete="..."> de verdade no DOM quando o campo declara
  // isso — sem a dica o gerenciador até mostra a lista, mas não tem onde
  // escrever, e o clique na senha salva não faz nada. Precisa vir junto de um
  // AutofillGroup em volta do formulário.
  final Iterable<String>? autofillHints;

  const CustomField({
    super.key,
    required this.hint,
    required this.controller,
    this.icon,
    this.isNumeric = false,
    this.obscure = false,
    this.textInputAction,
    this.keyboardType,
    this.maxWidth = 300,
    this.suffix,
    this.readOnly = false,
    this.onTap,
    this.onFieldSubmitted,
    this.prefix,
    this.isRequired = false,
    this.validator,
    this.autofocus = false,
    this.semCentavos = false,
    this.focusNode,
    this.autofillHints,
  });

  String? _validate(String? value) {
    if (isRequired!) {
      if (value == null || value.isEmpty) {
        // String vazia (não null): ativa a borda de erro sem reservar
        // altura pra texto, evitando que o card cresça/role. O aviso
        // completo aparece no dialog ao tentar confirmar.
        return '';
      }
      if (isNumeric!) {
        final number = MoneyInputFormat.parse(value);
        if (number == null || number == 0) {
          return '';
        }
      }
    }
    return validator?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth!),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        readOnly: readOnly!,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        autofillHints: autofillHints,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        style: TextStyle(color: cores.texto, fontSize: 18),
        obscureText: obscure!,
        enableInteractiveSelection: true,
        onTap: onTap,
        onFieldSubmitted: onFieldSubmitted,
        inputFormatters: isNumeric!
            ? [MoneyInputFormat(semCentavos: semCentavos)]
            : null,
        validator: (isRequired! || validator != null) ? _validate : null,
        decoration: CustomFieldDecoration.build(
          context,
          hint: hint,
          icon: icon,
          prefix: prefix,
          suffix: suffix,
        ),
      ),
    );
  }
}

// Campo de data: encapsula o calendário de [abrirSeletorData] + formatação
// (dd/MM/yyyy via intl), evitando repetir o seletor e o padLeft em cada tela.
class CustomDateField extends StatelessWidget {
  final String hint;
  final IconData? icon;
  final TextEditingController controller;
  final double? maxWidth;
  final bool isRequired;
  final DateTime? initialDate;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final void Function(DateTime picked)? onPicked;
  final TextInputAction? textInputAction;

  const CustomDateField({
    super.key,
    required this.hint,
    required this.controller,
    this.icon = Icons.calendar_today,
    this.maxWidth = 300,
    this.isRequired = false,
    this.initialDate,
    this.firstDate,
    this.lastDate,
    this.onPicked,
    this.textInputAction,
  });

  Future<void> _abrirSeletor(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final escolhida = await abrirSeletorData(
      context,
      inicial: initialDate,
      minima: firstDate ?? DateTime(2020),
      maxima: lastDate ?? DateTime(2030),
    );
    if (escolhida == null) return;
    controller.text = Formatters.data.format(escolhida);
    onPicked?.call(escolhida);
  }

  @override
  Widget build(BuildContext context) {
    return CustomField(
      hint: hint,
      icon: icon,
      controller: controller,
      readOnly: true,
      isRequired: isRequired,
      maxWidth: maxWidth,
      textInputAction: textInputAction,
      onTap: () => _abrirSeletor(context),
    );
  }
}

// Campo de hora: encapsula o relógio de [abrirSeletorHora] + formatação
// (HH:mm), evitando repetir o seletor e o padLeft em cada tela.
class CustomTimeField extends StatelessWidget {
  final String hint;
  final IconData? icon;
  final TextEditingController controller;
  final double? maxWidth;
  final bool isRequired;
  final TimeOfDay? initialTime;
  final void Function(TimeOfDay picked)? onPicked;
  final TextInputAction? textInputAction;

  const CustomTimeField({
    super.key,
    required this.hint,
    required this.controller,
    this.icon = Icons.schedule_outlined,
    this.maxWidth = 300,
    this.isRequired = false,
    this.initialTime,
    this.onPicked,
    this.textInputAction,
  });

  static String format(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  Future<void> _abrirSeletor(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final escolhida = await abrirSeletorHora(context, inicial: initialTime);
    if (escolhida == null) return;
    final hora = TimeOfDay.fromDateTime(escolhida);
    controller.text = format(hora);
    onPicked?.call(hora);
  }

  @override
  Widget build(BuildContext context) {
    return CustomField(
      hint: hint,
      icon: icon,
      controller: controller,
      readOnly: true,
      isRequired: isRequired,
      maxWidth: maxWidth,
      textInputAction: textInputAction,
      onTap: () => _abrirSeletor(context),
    );
  }
}
