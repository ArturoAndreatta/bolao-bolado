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

    test('aceita o value antigo "loto" como Lotofácil (compatibilidade)', () {
      // Salas criadas antes da correção do dropdown têm sorteio == 'loto'.
      // Sem esse fallback, elas voltariam a calcular cotas com o preço da
      // Mega-Sena (R\$6) em vez do da Lotofácil (R\$3,50).
      expect(precoCotaPara('loto'), kPrecoCotaLotofacil);
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

  group('valorFechaCotasInteiras', () {
    test('aceita múltiplos exatos da cota da Mega-Sena', () {
      expect(valorFechaCotasInteiras(6, kPrecoCotaMega), isTrue);
      expect(valorFechaCotasInteiras(18, kPrecoCotaMega), isTrue);
      expect(valorFechaCotasInteiras(600, kPrecoCotaMega), isTrue);
    });

    test('rejeita valores que não fecham cota inteira na Mega-Sena', () {
      expect(valorFechaCotasInteiras(5, kPrecoCotaMega), isFalse);
      expect(valorFechaCotasInteiras(20, kPrecoCotaMega), isFalse);
    });

    test('aceita múltiplos da cota fracionada da Lotofácil', () {
      // O caso que o `% 6` fixo do painel admin rejeitava: R$3,50 e R$7,00
      // são apostas válidas de Lotofácil (1 e 2 cotas).
      expect(valorFechaCotasInteiras(3.5, kPrecoCotaLotofacil), isTrue);
      expect(valorFechaCotasInteiras(7, kPrecoCotaLotofacil), isTrue);
      expect(valorFechaCotasInteiras(52.5, kPrecoCotaLotofacil), isTrue);
    });

    test('rejeita valores que não fecham cota inteira na Lotofácil', () {
      // R$6 é múltiplo de 6, mas não fecha cota de R$3,50 — era aceito pela
      // validação antiga do painel admin.
      expect(valorFechaCotasInteiras(6, kPrecoCotaLotofacil), isFalse);
      expect(valorFechaCotasInteiras(10, kPrecoCotaLotofacil), isFalse);
    });

    test('rejeita zero e valores negativos em qualquer sorteio', () {
      expect(valorFechaCotasInteiras(0, kPrecoCotaMega), isFalse);
      expect(valorFechaCotasInteiras(0, kPrecoCotaLotofacil), isFalse);
      expect(valorFechaCotasInteiras(-6, kPrecoCotaMega), isFalse);
    });
  });

  group('ajustarValorEmCotas', () {
    double ajustar(
      double valor,
      int delta, {
      double preco = kPrecoCotaMega,
      double? maximo,
    }) => ajustarValorEmCotas(
      valor: valor,
      deltaCotas: delta,
      precoCota: preco,
      valorMaximo: maximo,
    );

    test('sobe e desce uma cota da Mega-Sena', () {
      expect(ajustar(12, 1), 18);
      expect(ajustar(12, -1), 6);
    });

    test('sobe e desce uma cota da Lotofácil sem erro de ponto flutuante', () {
      // O bug do passo fixo: aqui o stepper andava de 6 em 6, produzindo
      // valores que não fecham cota de R$3,50.
      expect(ajustar(3.5, 1, preco: kPrecoCotaLotofacil), 7);
      expect(ajustar(7, 1, preco: kPrecoCotaLotofacil), 10.5);
      expect(ajustar(10.5, -1, preco: kPrecoCotaLotofacil), 7);
    });

    test('resultado sempre fecha cota inteira, mesmo somando muitas vezes', () {
      var valor = kPrecoCotaLotofacil;
      for (var i = 0; i < 40; i++) {
        valor = ajustar(valor, 1, preco: kPrecoCotaLotofacil);
      }
      expect(valorFechaCotasInteiras(valor, kPrecoCotaLotofacil), isTrue);
      expect(valor, 143.5); // 41 cotas × 3,50
    });

    test('alinha valor quebrado ao múltiplo de cota', () {
      // Digitado na mão: 20 não fecha cota de 6. Subindo vai para 24 (múltiplo
      // acima), descendo para 18 (múltiplo abaixo).
      expect(ajustar(20, 1), 24);
      expect(ajustar(20, -1), 18);
    });

    test('nunca desce abaixo de uma cota', () {
      expect(ajustar(6, -1), 6);
      expect(ajustar(0, -1), 6);
      expect(ajustar(3.5, -1, preco: kPrecoCotaLotofacil), kPrecoCotaLotofacil);
    });

    test('respeita o teto da sala, parando no último múltiplo que cabe', () {
      // Teto 20 com cota 6: o maior múltiplo que cabe é 18.
      expect(ajustar(18, 1, maximo: 20), 18);
      expect(ajustar(12, 1, maximo: 20), 18);
    });

    test('teto exato permite chegar no valor máximo', () {
      expect(ajustar(12, 1, maximo: 18), 18);
    });

    test('teto menor que uma cota não trava abaixo do mínimo apostável', () {
      // Sala mal configurada (teto R$3 com cota R$6): o piso de uma cota
      // prevalece em vez de o clamp inverter.
      expect(ajustar(6, 1, maximo: 3), 6);
    });

    test('sem teto, sobe livremente', () {
      expect(ajustar(600, 1), 606);
    });
  });

  group('precoCotaFormatado', () {
    test('cota inteira sai sem casas decimais', () {
      expect(precoCotaFormatado(kPrecoCotaMega), '6');
    });

    test('cota fracionada sai com vírgula (pt-BR)', () {
      expect(precoCotaFormatado(kPrecoCotaLotofacil), '3,50');
    });
  });

  group('isLotofacil', () {
    test('reconhece "lotofacil" e o value antigo "loto"', () {
      expect(isLotofacil('lotofacil'), isTrue);
      expect(isLotofacil('loto'), isTrue);
    });

    test('não reconhece Mega-Sena nem valores nulos/desconhecidos', () {
      expect(isLotofacil('mega'), isFalse);
      expect(isLotofacil(null), isFalse);
      expect(isLotofacil('outros'), isFalse);
    });
  });
}
