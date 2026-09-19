import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final _diaDaSemana = DateFormat('EEEE', 'pt_BR');
final _diaEMes = DateFormat("d 'de' MMMM", 'pt_BR');
final _diaMesEAno = DateFormat("d 'de' MMMM 'de' y", 'pt_BR');

/// Rótulo do separador de dia no chat, no padrão dos apps de conversa:
/// relativo enquanto é recente ("Hoje", "Ontem", "Sexta-feira" dentro da
/// semana) e por extenso depois ("12 de setembro"), com o ano só quando não
/// é o atual.
///
/// A conta é em dias de CALENDÁRIO, não em blocos de 24h: mensagem de ontem
/// às 23h, vista hoje à 0h30, é "Ontem" e não "Hoje". [agora] é parâmetro
/// para os testes fixarem o relógio.
String rotuloDataChat(DateTime data, {DateTime? agora}) {
  final referencia = agora ?? DateTime.now();
  final diferenca = DateUtils.dateOnly(
    referencia,
  ).difference(DateUtils.dateOnly(data)).inDays;

  if (diferenca == 0) return 'Hoje';
  if (diferenca == 1) return 'Ontem';
  if (diferenca > 1 && diferenca < 7) {
    final nome = _diaDaSemana.format(data);
    return nome[0].toUpperCase() + nome.substring(1);
  }
  return data.year == referencia.year
      ? _diaEMes.format(data)
      : _diaMesEAno.format(data);
}
