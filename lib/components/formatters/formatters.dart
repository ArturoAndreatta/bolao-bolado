import 'package:intl/intl.dart';

// Formatadores de moeda/data reaproveitados pelo app, centralizados para
// evitar reconstruir NumberFormat/DateFormat (e divergir o locale/padrão)
// em cada tela que precisa exibir um valor em R$ ou uma data.
class Formatters {
  static final NumberFormat moeda = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
  );

  // Mesmo padrão de moeda, sem o símbolo — usado ao reaplicar a formatação
  // pt-BR (ex: "1.234,56") em campos que já têm o próprio prefixo "R$ ".
  static final NumberFormat moedaSemSimbolo = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: '',
    decimalDigits: 2,
  );

  static final DateFormat data = DateFormat('dd/MM/yyyy');
  static final DateFormat dataHora = DateFormat('dd/MM/yyyy HH:mm');
  static final DateFormat dataHoraAno2 = DateFormat('dd/MM/yy HH:mm');
  static final DateFormat horaCurta = DateFormat('HH:mm');
}
