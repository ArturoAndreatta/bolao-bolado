import 'package:bolao_bolado/services/bet/bet_service.dart';
import 'package:bolao_bolado/services/bet/preco_cota.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('calcularCotasEPremios (Mega-Sena, padrão)', () {
    test('calcula 1 cota a cada R\$6 apostados, arredondando para baixo', () {
      final resultado = calcularCotasEPremios([
        {'uid': 'a', 'valor': '18'},
        {'uid': 'b', 'valor': '20'},
      ], 0);

      expect(resultado[0]['cotas'], 3);
      expect(resultado[1]['cotas'], 3); // 20/6 = 3.33 -> arredonda para baixo
    });

    test('divide o prêmio proporcionalmente ao número de cotas', () {
      final resultado = calcularCotasEPremios([
        {'uid': 'a', 'valor': '6'}, // 1 cota
        {'uid': 'b', 'valor': '12'}, // 2 cotas
      ], 3000);

      expect(resultado[0]['premio'], closeTo(1000, 0.001));
      expect(resultado[1]['premio'], closeTo(2000, 0.001));
    });

    test('prêmio é zero para todos quando não há nenhuma cota', () {
      final resultado = calcularCotasEPremios([
        {'uid': 'a', 'valor': '0'},
        {'uid': 'b', 'valor': '5'}, // menos de 6, não fecha 1 cota
      ], 1000);

      expect(resultado[0]['premio'], 0.0);
      expect(resultado[1]['premio'], 0.0);
    });

    test('lista vazia retorna lista vazia', () {
      expect(calcularCotasEPremios([], 1000), isEmpty);
    });

    test('valor inválido ou nulo é tratado como zero', () {
      final resultado = calcularCotasEPremios([
        {'uid': 'a', 'valor': 'abc'},
        {'uid': 'b', 'valor': null},
      ], 1000);

      expect(resultado[0]['cotas'], 0);
      expect(resultado[1]['cotas'], 0);
    });

    test('preserva os demais campos do participante', () {
      final resultado = calcularCotasEPremios([
        {'uid': 'a', 'valor': '6', 'nome': 'Fulano', 'verificado': true},
      ], 500);

      expect(resultado[0]['uid'], 'a');
      expect(resultado[0]['nome'], 'Fulano');
      expect(resultado[0]['verificado'], true);
    });
  });

  group('calcularCotasEPremios (Lotofácil, preço de cota diferente)', () {
    test('calcula 1 cota a cada R\$3,50 apostados', () {
      final resultado = calcularCotasEPremios(
        [
          {'uid': 'a', 'valor': '7'}, // 2 cotas exatas
          {'uid': 'b', 'valor': '10'}, // 10/3.5 = 2.85 -> 2 cotas
        ],
        0,
        kPrecoCotaLotofacil,
      );

      expect(resultado[0]['cotas'], 2);
      expect(resultado[1]['cotas'], 2);
    });

    test(
      'divide o prêmio proporcionalmente com preço de cota da Lotofácil',
      () {
        final resultado = calcularCotasEPremios(
          [
            {'uid': 'a', 'valor': '3.5'}, // 1 cota
            {'uid': 'b', 'valor': '7'}, // 2 cotas
          ],
          3000,
          kPrecoCotaLotofacil,
        );

        expect(resultado[0]['premio'], closeTo(1000, 0.001));
        expect(resultado[1]['premio'], closeTo(2000, 0.001));
      },
    );
  });

  group('precoCotaPara', () {
    test('retorna o preço da Lotofácil quando sorteio é "lotofacil"', () {
      expect(precoCotaPara('lotofacil'), kPrecoCotaLotofacil);
    });

    test(
      'retorna o preço da Mega-Sena para "mega" ou valores desconhecidos/nulos',
      () {
        expect(precoCotaPara('mega'), kPrecoCotaMega);
        expect(precoCotaPara(null), kPrecoCotaMega);
        expect(precoCotaPara('outro-valor-qualquer'), kPrecoCotaMega);
      },
    );
  });
}
