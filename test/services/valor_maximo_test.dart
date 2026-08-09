import 'package:bolao_bolado/services/bet/valor_maximo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('valorMaximoDe', () {
    test('converte o num do Firestore em double', () {
      expect(valorMaximoDe(120), 120.0);
      expect(valorMaximoDe(52.5), 52.5);
    });

    test('sala sem o campo não tem limite', () {
      expect(valorMaximoDe(null), isNull);
    });

    test('teto não-positivo é tratado como ausência de limite', () {
      // Um teto de 0 (ou negativo) só poderia recusar toda e qualquer
      // aposta, travando a sala — não é o que "sem valor máximo" significa.
      expect(valorMaximoDe(0), isNull);
      expect(valorMaximoDe(-10), isNull);
    });
  });

  group('valorRespeitaMaximo', () {
    test('sala sem limite aceita qualquer valor', () {
      expect(valorRespeitaMaximo(6, null), isTrue);
      expect(valorRespeitaMaximo(999999, null), isTrue);
    });

    test('aceita valores abaixo do teto', () {
      expect(valorRespeitaMaximo(60, 120), isTrue);
    });

    test('o teto é inclusivo: apostar exatamente o máximo vale', () {
      // O número aparece na tela como "Valor máx. aposta"; recusar o próprio
      // valor exibido seria incoerente com o que o usuário lê.
      expect(valorRespeitaMaximo(120, 120), isTrue);
    });

    test('rejeita valores acima do teto', () {
      expect(valorRespeitaMaximo(126, 120), isFalse);
    });

    test('teto fracionado compara sem erro de ponto flutuante', () {
      // Sala de Lotofácil: valores com centavos precisam bater exatamente no
      // teto, sem resíduo de double fazendo a aposta ser recusada.
      expect(valorRespeitaMaximo(52.5, 52.5), isTrue);
      expect(valorRespeitaMaximo(56, 52.5), isFalse);
    });
  });
}
