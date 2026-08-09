import 'package:bolao_bolado/core/debug_flags.dart';
import 'package:bolao_bolado/dev/simulador_apostas.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('nomes simulados', () {
    test('tem exatamente $kMaximoParticipantesSimulados nomes', () {
      // O tamanho da lista é o teto de participantes que a simulação alcança:
      // acabando os nomes, o ciclo para com MotivoParada.semNomesDisponiveis.
      expect(
        nomesSimuladosDisponiveis,
        hasLength(kMaximoParticipantesSimulados),
      );
    });

    test('não repete nome', () {
      // Nome repetido faria dois participantes fake indistinguíveis na tela e
      // quebraria a conta de nomes livres (que sai do que já está em uso).
      expect(
        nomesSimuladosDisponiveis.toSet(),
        hasLength(nomesSimuladosDisponiveis.length),
      );
    });

    test('não agrupa xarás no começo da lista', () {
      // Uma simulação curta usa só o começo da lista. Com o produto cartesiano
      // ingênuo os 50 primeiros nomes seriam todos do mesmo primeiro nome.
      final primeirosNomes = nomesSimuladosDisponiveis
          .take(50)
          .map((nome) => nome.split(' ').first)
          .toSet();
      expect(primeirosNomes, hasLength(50));
    });

    test('todo nome tem primeiro nome e sobrenome', () {
      for (final nome in nomesSimuladosDisponiveis) {
        expect(nome.split(' '), hasLength(2), reason: nome);
      }
    });
  });

  group('intervalo configurável', () {
    tearDown(() {
      intervaloSimulacaoMsGlobal.value = kIntervaloSimulacaoPadraoMs;
    });

    test('padrão é o intervalo que era fixo antes', () {
      expect(intervaloSimulacaoMsGlobal.value, kIntervaloSimulacaoPadraoMs);
      expect(
        kIntervaloSimulacaoPadraoMs,
        inInclusiveRange(kIntervaloSimulacaoMinMs, kIntervaloSimulacaoMaxMs),
      );
    });

    test('o mínimo é folgado o bastante para um passo caber nele', () {
      // Abaixo do mínimo os passos se sobrepõem e o simulador passa a pular
      // ticks — o ritmo real deixaria de acompanhar o slider.
      expect(kIntervaloSimulacaoMinMs, greaterThanOrEqualTo(100));
      expect(kIntervaloSimulacaoMinMs, lessThan(kIntervaloSimulacaoMaxMs));
    });

    test('a faixa é divisível em passos de 100ms', () {
      // O slider do painel usa divisions = faixa / 100; se a faixa não for
      // múltipla de 100, o valor máximo do slider não bate com o teto.
      expect(
        (kIntervaloSimulacaoMaxMs - kIntervaloSimulacaoMinMs) % 100,
        isZero,
      );
    });
  });
}
