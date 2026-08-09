import 'dart:math';

import 'package:bolao_bolado/services/bet/jogos_aposta.dart';
import 'package:bolao_bolado/services/bet/preco_cota.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('combinacoes', () {
    test('casos de borda', () {
      expect(combinacoes(6, 6), 1);
      expect(combinacoes(6, 0), 1);
      expect(combinacoes(5, 6), 0); // k > n
      expect(combinacoes(6, -1), 0);
    });

    test('não perde precisão no maior caso do app (C(20,6))', () {
      // Calculado por fatorial ingênuo, 20! já passa dos 53 bits de precisão
      // do int na web; este é o valor exato.
      expect(combinacoes(20, 6), 38760);
      expect(combinacoes(20, 15), 15504);
    });
  });

  group('cotasDoJogo (Mega-Sena)', () {
    test('jogo simples custa uma cota', () {
      expect(cotasDoJogo(6, 'mega'), 1);
    });

    test('jogo maior custa a quantidade de combinações simples que contém', () {
      expect(cotasDoJogo(7, 'mega'), 7);
      expect(cotasDoJogo(8, 'mega'), 28);
      expect(cotasDoJogo(9, 'mega'), 84);
      expect(cotasDoJogo(10, 'mega'), 210);
    });

    test('cota vezes preço reproduz a tabela oficial da Caixa', () {
      expect(cotasDoJogo(6, 'mega') * kPrecoCotaMega, 6.0);
      expect(cotasDoJogo(7, 'mega') * kPrecoCotaMega, 42.0);
      expect(cotasDoJogo(8, 'mega') * kPrecoCotaMega, 168.0);
      expect(cotasDoJogo(9, 'mega') * kPrecoCotaMega, 504.0);
      expect(cotasDoJogo(10, 'mega') * kPrecoCotaMega, 1260.0);
    });

    test('fora da faixa válida não é jogo', () {
      expect(cotasDoJogo(5, 'mega'), 0);
      expect(cotasDoJogo(kTamanhoMaximoJogo + 1, 'mega'), 0);
    });
  });

  group('cotasDoJogo (Lotofácil)', () {
    test('parte de 15 números, não de 6', () {
      expect(cotasDoJogo(15, 'lotofacil'), 1);
      expect(cotasDoJogo(14, 'lotofacil'), 0);
    });

    test('cota vezes preço reproduz a tabela oficial da Caixa', () {
      expect(cotasDoJogo(15, 'lotofacil') * kPrecoCotaLotofacil, 3.5);
      expect(cotasDoJogo(16, 'lotofacil') * kPrecoCotaLotofacil, 56.0);
      expect(cotasDoJogo(17, 'lotofacil') * kPrecoCotaLotofacil, 476.0);
      expect(cotasDoJogo(18, 'lotofacil') * kPrecoCotaLotofacil, 2856.0);
    });

    test('reconhece o value legado "loto"', () {
      expect(cotasDoJogo(15, 'loto'), 1);
      expect(cotasDoJogo(16, 'loto'), 16);
    });
  });

  group('cotasDosJogos', () {
    test('soma o custo de jogos de tamanhos diferentes', () {
      final jogos = [
        [1, 2, 3, 4, 5, 6], // 1 cota
        [1, 2, 3, 4, 5, 6, 7], // 7 cotas
        [10, 11, 12, 13, 14, 15], // 1 cota
      ];
      expect(cotasDosJogos(jogos, 'mega'), 9);
    });

    test('lista vazia não custa nada', () {
      expect(cotasDosJogos([], 'mega'), 0);
    });
  });

  group('jogosParaDados / jogosDeDados', () {
    test('ida e volta preserva os jogos', () {
      final jogos = [
        [1, 2, 3, 4, 5, 6],
        [7, 8, 9, 10, 11, 12],
      ];
      final dados = {'jogos': jogosParaDados(jogos)};
      expect(jogosDeDados(dados), jogos);
    });

    test('grava array de MAP (o Firestore não aceita array de array)', () {
      final dados = jogosParaDados([
        [1, 2, 3, 4, 5, 6],
      ]);
      expect(dados.single, isA<Map<String, Object?>>());
      expect(dados.single['numeros'], [1, 2, 3, 4, 5, 6]);
    });

    test('lê o campo legado `numeros` como um jogo único', () {
      final dados = <String, dynamic>{
        'numeros': [4, 8, 15, 16, 23, 42],
      };
      expect(jogosDeDados(dados), [
        [4, 8, 15, 16, 23, 42],
      ]);
    });

    test('`jogos` tem prioridade sobre o legado quando os dois existem', () {
      final dados = <String, dynamic>{
        'numeros': [1, 2, 3, 4, 5, 6],
        'jogos': [
          {
            'numeros': [10, 11, 12, 13, 14, 15],
          },
        ],
      };
      expect(jogosDeDados(dados), [
        [10, 11, 12, 13, 14, 15],
      ]);
    });

    test('aposta sem números escolhidos devolve lista vazia', () {
      expect(jogosDeDados(<String, dynamic>{'valor': '6'}), isEmpty);
      expect(jogosDeDados(<String, dynamic>{'jogos': []}), isEmpty);
    });

    test('ordena e converte num vindo do Firestore', () {
      // O Firestore devolve inteiros como num; a ordem é a de gravação.
      final dados = <String, dynamic>{
        'jogos': [
          {
            'numeros': <num>[42, 4, 23, 8, 16, 15],
          },
        ],
      };
      expect(jogosDeDados(dados), [
        [4, 8, 15, 16, 23, 42],
      ]);
    });

    test('descarta entrada malformada em vez de quebrar a leitura', () {
      final dados = <String, dynamic>{
        'jogos': [
          'lixo',
          {'numeros': 'lixo'},
          {
            'numeros': [1, 2, 3, 4, 5, 6],
          },
        ],
      };
      expect(jogosDeDados(dados), [
        [1, 2, 3, 4, 5, 6],
      ]);
    });
  });

  group('sortearNumeros', () {
    test('devolve a quantidade pedida, sem repetir, ordenada e na faixa', () {
      final numeros = sortearNumeros(
        tamanho: 6,
        numeroMaximo: 60,
        aleatorio: Random(7),
      );
      expect(numeros, hasLength(6));
      expect(numeros.toSet(), hasLength(6));
      expect(numeros, orderedEquals([...numeros]..sort()));
      expect(numeros.every((n) => n >= 1 && n <= 60), isTrue);
    });

    test('preserva os números já marcados na cartela', () {
      final numeros = sortearNumeros(
        tamanho: 6,
        numeroMaximo: 60,
        fixos: [7, 13],
        aleatorio: Random(3),
      );
      expect(numeros, hasLength(6));
      expect(numeros, containsAll([7, 13]));
    });

    test('ignora fixos fora da faixa do sorteio', () {
      final numeros = sortearNumeros(
        tamanho: 15,
        numeroMaximo: 25,
        fixos: [0, 30, 5],
        aleatorio: Random(1),
      );
      expect(numeros, hasLength(15));
      expect(numeros, contains(5));
      expect(numeros.every((n) => n >= 1 && n <= 25), isTrue);
    });
  });

  group('tamanhosParaCotas', () {
    test('estilo simples usa só o jogo mínimo', () {
      expect(
        tamanhosParaCotas(14, 'mega', EstiloSorteio.simples),
        List.filled(14, 6),
      );
    });

    test('estilo maiores pega o maior jogo que cabe, do maior ao menor', () {
      // 54 = 28 (um de 8) + 21 (três de 7) + 5 (cinco de 6) — o exemplo que
      // motivou o estilo.
      expect(tamanhosParaCotas(54, 'mega', EstiloSorteio.maiores), [
        8,
        7,
        7,
        7,
        6,
        6,
        6,
        6,
        6,
      ]);
    });

    test('estilo maiores repete o mesmo tamanho enquanto couber', () {
      expect(tamanhosParaCotas(14, 'mega', EstiloSorteio.maiores), [7, 7]);
      expect(tamanhosParaCotas(56, 'mega', EstiloSorteio.maiores), [8, 8]);
    });

    test('os dois estilos gastam exatamente as cotas disponíveis', () {
      for (var cotas = 1; cotas <= 120; cotas++) {
        for (final estilo in EstiloSorteio.values) {
          final tamanhos = tamanhosParaCotas(cotas, 'mega', estilo);
          final gasto = tamanhos.fold<int>(
            0,
            (soma, tamanho) => soma + cotasDoJogo(tamanho, 'mega'),
          );
          expect(gasto, cotas, reason: 'cotas: $cotas, estilo: ${estilo.name}');
        }
      }
    });

    test('funciona igual na Lotofácil, partindo de 15', () {
      expect(tamanhosParaCotas(17, 'lotofacil', EstiloSorteio.maiores), [
        16,
        15,
      ]);
      expect(tamanhosParaCotas(3, 'lotofacil', EstiloSorteio.maiores), [
        15,
        15,
        15,
      ]);
    });

    test('orçamento vazio ou negativo não gera jogo', () {
      expect(tamanhosParaCotas(0, 'mega', EstiloSorteio.maiores), isEmpty);
      expect(tamanhosParaCotas(-3, 'mega', EstiloSorteio.simples), isEmpty);
    });
  });

  group('resumoDeTamanhos', () {
    test('agrupa por tamanho, do maior para o menor', () {
      expect(resumoDeTamanhos([6, 7, 8, 7, 6, 7, 6, 6, 6]), '1×8 · 3×7 · 5×6');
    });

    test('lista vazia vira texto vazio', () {
      expect(resumoDeTamanhos([]), '');
    });
  });

  group('sortearJogosRestantes', () {
    test('completa o orçamento com jogos simples, preservando os atuais', () {
      final atuais = [
        [1, 2, 3, 4, 5, 6, 7], // 7 cotas
      ];
      final jogos = sortearJogosRestantes(
        jogosAtuais: atuais,
        cotasDisponiveis: 10,
        sorteio: 'mega',
        aleatorio: Random(11),
      );

      expect(jogos.first, atuais.first);
      expect(jogos, hasLength(4)); // o de 7 + 3 simples
      expect(cotasDosJogos(jogos, 'mega'), 10);
    });

    test('não gera nada quando o orçamento já está fechado', () {
      final atuais = [
        [1, 2, 3, 4, 5, 6],
      ];
      final jogos = sortearJogosRestantes(
        jogosAtuais: atuais,
        cotasDisponiveis: 1,
        sorteio: 'mega',
        aleatorio: Random(2),
      );
      expect(jogos, atuais);
    });

    test('usa jogos de 15 números numa sala de Lotofácil', () {
      final jogos = sortearJogosRestantes(
        jogosAtuais: const [],
        cotasDisponiveis: 3,
        sorteio: 'lotofacil',
        aleatorio: Random(5),
      );
      expect(jogos, hasLength(3));
      expect(jogos.every((jogo) => jogo.length == 15), isTrue);
      expect(jogos.every((jogo) => jogo.every((n) => n <= 25)), isTrue);
    });

    test('estilo maiores fecha o orçamento com menos jogos', () {
      final jogos = sortearJogosRestantes(
        jogosAtuais: const [],
        cotasDisponiveis: 14,
        sorteio: 'mega',
        estilo: EstiloSorteio.maiores,
        aleatorio: Random(4),
      );

      expect(jogos, hasLength(2));
      expect(jogos.every((jogo) => jogo.length == 7), isTrue);
      expect(cotasDosJogos(jogos, 'mega'), 14);
      // Cada jogo continua sem repetir número.
      expect(jogos.every((jogo) => jogo.toSet().length == jogo.length), isTrue);
    });

    test('para no teto de jogos por aposta em vez de travar a tela', () {
      final jogos = sortearJogosRestantes(
        jogosAtuais: const [],
        // R$60 mil numa sala de Mega: 10 mil cotas. Sem o teto isso viraria
        // 10 mil jogos, estourando o limite de 1 MiB do documento.
        cotasDisponiveis: 10000,
        sorteio: 'mega',
        aleatorio: Random(9),
      );
      expect(jogos, hasLength(kMaximoJogosPorAposta));
    });
  });
}
