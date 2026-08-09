import 'package:bolao_bolado/core/debug_flags.dart';
import 'package:bolao_bolado/pages/participants/participants_estilo_entrada.dart';
import 'package:bolao_bolado/services/configuracoes/configuracoes_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('intervaloDeConfiguracoes', () {
    test('sala sem o campo devolve null', () {
      expect(intervaloDeConfiguracoes(null), isNull);
      expect(intervaloDeConfiguracoes({}), isNull);
      expect(intervaloDeConfiguracoes({'configuracoes': {}}), isNull);
    });

    test('valor dentro dos limites passa direto', () {
      expect(
        intervaloDeConfiguracoes({
          'configuracoes': {'intervaloSimulacaoMs': 900},
        }),
        900,
      );
    });

    test('valor acima do teto é limitado', () {
      expect(
        intervaloDeConfiguracoes({
          'configuracoes': {
            'intervaloSimulacaoMs': kIntervaloSimulacaoMaxMs + 5000,
          },
        }),
        kIntervaloSimulacaoMaxMs,
        reason: 'um documento editado à mão no console não pode travar a UI',
      );
    });

    test('valor abaixo do piso é limitado', () {
      expect(
        intervaloDeConfiguracoes({
          'configuracoes': {'intervaloSimulacaoMs': 0},
        }),
        kIntervaloSimulacaoMinMs,
      );
    });
  });

  group('estiloDeConfiguracoes', () {
    test('sala sem o campo devolve null', () {
      expect(estiloDeConfiguracoes(null), isNull);
      expect(estiloDeConfiguracoes({}), isNull);
      expect(estiloDeConfiguracoes({'configuracoes': {}}), isNull);
    });

    test('nome válido resolve para o estilo certo', () {
      expect(
        estiloDeConfiguracoes({
          'configuracoes': {'estiloEntrada': EstiloEntrada.glitch.name},
        }),
        EstiloEntrada.glitch,
      );
    });

    test('nome desconhecido (estilo removido do enum) devolve null', () {
      // Não é o mesmo que "sem configuração": alguém já escolheu algo, só
      // que esse algo não existe mais. Quem chama deve manter o valor atual
      // em vez de aplicar o padrão às cegas.
      expect(
        estiloDeConfiguracoes({
          'configuracoes': {'estiloEntrada': 'estiloQueNaoExisteMais'},
        }),
        isNull,
      );
    });

    test('cobre todo o enum, ida e volta pelo nome', () {
      for (final estilo in EstiloEntrada.values) {
        expect(
          estiloDeConfiguracoes({
            'configuracoes': {'estiloEntrada': estilo.name},
          }),
          estilo,
          reason: '${estilo.name} deveria resolver de volta para $estilo',
        );
      }
    });
  });

  group('quantidadeRajadaDeConfiguracoes', () {
    test('sala sem o campo devolve null', () {
      expect(quantidadeRajadaDeConfiguracoes(null), isNull);
      expect(quantidadeRajadaDeConfiguracoes({}), isNull);
      expect(quantidadeRajadaDeConfiguracoes({'configuracoes': {}}), isNull);
    });

    test('valor dentro dos limites passa direto', () {
      expect(
        quantidadeRajadaDeConfiguracoes({
          'configuracoes': {'quantidadeRajada': 3},
        }),
        3,
      );
    });

    test('valor acima do teto é limitado', () {
      expect(
        quantidadeRajadaDeConfiguracoes({
          'configuracoes': {
            'quantidadeRajada': kQuantidadeRajadaSimulacaoMax + 5,
          },
        }),
        kQuantidadeRajadaSimulacaoMax,
      );
    });

    test('valor abaixo de 1 é limitado a 1', () {
      expect(
        quantidadeRajadaDeConfiguracoes({
          'configuracoes': {'quantidadeRajada': 0},
        }),
        1,
      );
    });
  });

  group('atrasoRajadaDeConfiguracoes', () {
    test('sala sem o campo devolve null', () {
      expect(atrasoRajadaDeConfiguracoes(null), isNull);
      expect(atrasoRajadaDeConfiguracoes({}), isNull);
      expect(atrasoRajadaDeConfiguracoes({'configuracoes': {}}), isNull);
    });

    test('valor dentro dos limites passa direto', () {
      expect(
        atrasoRajadaDeConfiguracoes({
          'configuracoes': {'atrasoRajadaMs': 500},
        }),
        500,
      );
    });

    test('valor acima do teto é limitado', () {
      expect(
        atrasoRajadaDeConfiguracoes({
          'configuracoes': {
            'atrasoRajadaMs': kAtrasoRajadaSimulacaoMaxMs + 1000,
          },
        }),
        kAtrasoRajadaSimulacaoMaxMs,
      );
    });

    test('valor abaixo de 0 é limitado a 0', () {
      expect(
        atrasoRajadaDeConfiguracoes({
          'configuracoes': {'atrasoRajadaMs': -100},
        }),
        0,
      );
    });
  });
}
