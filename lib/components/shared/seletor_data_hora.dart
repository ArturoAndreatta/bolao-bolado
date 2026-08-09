import 'package:board_datetime_picker/board_datetime_picker.dart';
import 'package:bolao_bolado/core/app_cores.dart';
import 'package:flutter/material.dart';

/// Seletores de data e hora do app, sobre o pacote `board_datetime_picker`.
///
/// Por que um pacote, e não o `showDatePicker`/`showTimePicker` do Material:
/// os nativos são corretos e acessíveis, mas o desenho é o padrão cru do
/// Material — e o mostrador redondo do relógio serve para descobrir um ângulo,
/// não para digitar um horário que já se sabe (20:00). Este traz calendário e
/// roleta na MESMA peça: em tela larga os dois lado a lado, em tela estreita
/// alternando, com atalhos de hoje/amanhã e entrada por teclado.
///
/// Por que não escrever um: já se tentou nesta base, e o resultado perdeu modo
/// de digitação, navegação por teclado, leitor de tela e escala de fonte — que
/// aqui vêm mantidos por quem publica o pacote.
///
/// Tudo que é cor sai de [AppCores], então os dois seletores acompanham os 7
/// temas. Não pinte nada no ponto de chamada: mexa em [_opcoes].
BoardDateTimeOptions _opcoes(
  BuildContext context,
  String titulo, {
  required bool comCalendario,
}) {
  final cores = AppCores.de(context);
  return BoardDateTimeOptions(
    backgroundColor: cores.card,
    // Superfície das roletas e do calendário, um degrau à frente do card —
    // é ela que separa a área de escolha do fundo do diálogo.
    foregroundColor: cores.campo,
    textColor: cores.texto,
    // Mesma regra do CTA do app: cor de ação do tema (azul no claro, dourado
    // no escuro, magenta no Cyber) com o par de contraste que ela carrega.
    activeColor: cores.acaoPrimaria,
    activeTextColor: cores.textoSobreAcao,
    // Fundo levemente tingido com os dois tons do gradiente da marca. É sutil
    // de propósito (6%): o suficiente para o diálogo não ser mais um retângulo
    // cinza, longe do que atrapalharia a leitura dos números por cima.
    backgroundDecoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.alphaBlend(cores.dourado.withValues(alpha: 0.06), cores.card),
          Color.alphaBlend(cores.verdeAgua.withValues(alpha: 0.06), cores.card),
        ],
      ),
    ),
    // O pacote formata mês e dia da semana com `DateFormat(locale)`. O locale
    // precisa ser 'pt_BR' cheio: é esse o nome que o GlobalMaterialLocalizations
    // registra no intl, e pedir só 'pt' levanta LocaleDataException.
    languages: const BoardPickerLanguages(
      locale: 'pt_BR',
      today: 'Hoje',
      tomorrow: 'Amanhã',
      yesterday: 'Ontem',
      now: 'Agora',
    ),
    boardTitle: titulo,
    boardTitleTextStyle: TextStyle(
      color: cores.texto,
      fontSize: 15,
      fontWeight: FontWeight.w700,
    ),
    // Ordem brasileira (dia/mês/ano) e mês por extenso — o default do pacote é
    // ano/mês/dia com mês em número.
    pickerFormat: PickerFormat.dmy,
    pickerMonthFormat: PickerMonthFormat.long,
    weekend: BoardPickerWeekendOptions(
      saturdayColor: cores.azul,
      sundayColor: cores.vermelho,
    ),
    // Atalhos: ontem não serve para data de sorteio, que é sempre futura.
    actionButtonTypes: const [BoardDateButtonType.today],
    // Data abre no calendário, com a roleta a um toque — o default do pacote é
    // o contrário, e escolher um DIA em três roletas é justamente o que o
    // calendário resolve melhor. Hora vai em `pickerOnly`: sem essa distinção
    // o relógio abria mostrando um calendário de mês inteiro, que não tem nada
    // a ver com escolher 20:30.
    viewMode: comCalendario
        ? BoardDateTimeViewMode.calendarToPicker
        : BoardDateTimeViewMode.pickerOnly,
    // 24h. O AM/PM abriria espaço para erro de 12 horas num campo que grava
    // HH:mm — e no Brasil horário de sorteio se escreve 20:00.
    useAmpm: false,
    pickerSubTitles: const BoardDateTimeItemTitles(
      year: 'Ano',
      month: 'Mês',
      day: 'Dia',
      hour: 'Hora',
      minute: 'Minuto',
    ),
  );
}

/// Calendário. Devolve `null` se a pessoa fechar sem escolher.
Future<DateTime?> abrirSeletorData(
  BuildContext context, {
  DateTime? inicial,
  DateTime? minima,
  DateTime? maxima,
}) {
  return showBoardDateTimePickerForDate(
    context: context,
    initialDate: inicial,
    minimumDate: minima,
    maximumDate: maxima,
    radius: 20,
    options: _opcoes(context, 'Data do sorteio', comCalendario: true),
  );
}

/// Relógio (roleta de hora e minuto). Devolve `null` se fechar sem escolher.
Future<DateTime?> abrirSeletorHora(BuildContext context, {TimeOfDay? inicial}) {
  final agora = DateTime.now();
  final base = inicial ?? TimeOfDay.fromDateTime(agora);
  return showBoardDateTimePickerForTime(
    context: context,
    // O pacote trabalha em DateTime; o dia não importa aqui, só a hora é lida
    // de volta pelo campo.
    initialDate: DateTime(
      agora.year,
      agora.month,
      agora.day,
      base.hour,
      base.minute,
    ),
    radius: 20,
    options: _opcoes(context, 'Horário do sorteio', comCalendario: false),
  );
}
