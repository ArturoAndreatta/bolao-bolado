import 'package:bolao_bolado/services/chat/rotulo_data_chat.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  // Sábado, 19/09/2026, 0h30: perto da meia-noite de propósito.
  final agora = DateTime(2026, 9, 19, 0, 30);

  test('mesmo dia é Hoje', () {
    expect(rotuloDataChat(DateTime(2026, 9, 19, 0, 5), agora: agora), 'Hoje');
  });

  test('ontem à noite é Ontem, mesmo com menos de 24h de diferença', () {
    expect(
      rotuloDataChat(DateTime(2026, 9, 18, 23, 50), agora: agora),
      'Ontem',
    );
  });

  test('dentro da semana mostra o dia da semana com maiúscula', () {
    expect(
      rotuloDataChat(DateTime(2026, 9, 15, 10), agora: agora),
      'Terça-feira',
    );
  });

  test('uma semana ou mais mostra dia e mês', () {
    expect(
      rotuloDataChat(DateTime(2026, 9, 12, 10), agora: agora),
      '12 de setembro',
    );
  });

  test('ano anterior inclui o ano', () {
    expect(
      rotuloDataChat(DateTime(2025, 12, 31, 22), agora: agora),
      '31 de dezembro de 2025',
    );
  });
}
