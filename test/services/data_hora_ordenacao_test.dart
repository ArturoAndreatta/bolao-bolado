import 'package:bolao_bolado/services/bet/bet_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('dataHoraOrdenacao', () {
    test('Timestamp confirmado vale o próprio instante', () {
      final agora = DateTime(2026, 3, 14, 10, 30);
      expect(
        dataHoraOrdenacao(Timestamp.fromDate(agora), pendente: false),
        agora.millisecondsSinceEpoch,
      );
    });

    test('escrita pendente sem timestamp vale ~agora, não época zero', () {
      final antes = DateTime.now().millisecondsSinceEpoch;
      final valor = dataHoraOrdenacao(null, pendente: true);
      final depois = DateTime.now().millisecondsSinceEpoch;

      expect(valor, greaterThanOrEqualTo(antes));
      expect(valor, lessThanOrEqualTo(depois));
    });

    test('null SEM escrita pendente continua valendo 0', () {
      expect(dataHoraOrdenacao(null, pendente: false), 0);
    });

    test('aposta recém-criada fica à frente das antigas na ordem desc', () {
      final antiga = dataHoraOrdenacao(
        Timestamp.fromDate(DateTime(2026, 1, 1)),
        pendente: false,
      );
      final recemCriada = dataHoraOrdenacao(null, pendente: true);

      // É esta comparação que decide a posição na tabela ordenada por
      // "Última Alteração" decrescente. Antes da correção a recém-criada
      // valia 0 e caía para a ÚLTIMA linha, subindo depois que o servidor
      // confirmava o timestamp.
      expect(
        recemCriada,
        greaterThan(antiga),
        reason: 'a aposta de agora precisa nascer no topo, sem pular depois',
      );
    });

    test('a posição NÃO muda quando o servidor confirma o timestamp', () {
      esquecerOrdemDeChegada(const []);

      // Fase 1: cache local, ainda sem timestamp.
      final pendente = dataHoraOrdenacao(null, pendente: true, uid: 'sim-123');

      // Fase 2: servidor confirma, com um instante DIFERENTE do "agora" que
      // o cliente tinha estimado (a escrita saiu antes de ser gravada).
      final confirmado = dataHoraOrdenacao(
        Timestamp.fromDate(DateTime.now().subtract(const Duration(seconds: 3))),
        pendente: false,
        uid: 'sim-123',
      );

      // Este é o defeito que o usuário via: a linha animava a entrada num
      // lugar e, ao confirmar, era mandada para outro. Mantendo o valor, ela
      // se move uma vez só.
      expect(
        confirmado,
        pendente,
        reason: 'a linha não pode mudar de lugar ao confirmar',
      );
    });

    test('aposta que saiu da lista deixa de ser lembrada', () {
      esquecerOrdemDeChegada(const []);

      final primeiro = dataHoraOrdenacao(null, pendente: true, uid: 'sim-a');
      // Continua na lista: mantém o lugar.
      esquecerOrdemDeChegada(const ['sim-a']);
      expect(dataHoraOrdenacao(null, pendente: true, uid: 'sim-a'), primeiro);

      // Saiu da lista: o registro é descartado, e uma futura aposta com o
      // mesmo uid recebe um lugar novo em vez de herdar o antigo.
      esquecerOrdemDeChegada(const []);
      expect(
        dataHoraOrdenacao(
          Timestamp.fromDate(DateTime(2026, 1, 1)),
          pendente: false,
          uid: 'sim-a',
        ),
        DateTime(2026, 1, 1).millisecondsSinceEpoch,
        reason: 'sem registro, vale o timestamp real',
      );
    });
  });
}
