import 'package:bolao_bolado/pages/participants/participants_reordenacao.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RastreadorDeIndices', () {
    test('primeira chamada não acusa deslocamento (ninguém tinha lugar)', () {
      final r = RastreadorDeIndices();
      expect(r.atualizar(['a', 'b', 'c']), isEmpty);
    });

    test('lista estável não acusa deslocamento', () {
      final r = RastreadorDeIndices()..atualizar(['a', 'b', 'c']);
      expect(r.atualizar(['a', 'b', 'c']), isEmpty);
    });

    test('linha que sobe devolve quantos índices andou', () {
      final r = RastreadorDeIndices()..atualizar(['a', 'b', 'c']);

      // 'c' vai do índice 2 para o 0: subiu 2 posições.
      final d = r.atualizar(['c', 'a', 'b']);

      expect(d['c'], 2, reason: 'c subiu 2 lugares');
      expect(d['a'], -1, reason: 'a desceu 1');
      expect(d['b'], -1, reason: 'b desceu 1');
    });

    test(
      'linha nova não desliza — quem cuida dela é a animação de entrada',
      () {
        final r = RastreadorDeIndices()..atualizar(['a', 'b']);

        final d = r.atualizar(['nova', 'a', 'b']);

        expect(d.containsKey('nova'), isFalse);
        // As antigas desceram uma posição de verdade, então essas deslizam.
        expect(d['a'], -1);
        expect(d['b'], -1);
      },
    );

    test('remoção faz as de baixo subirem', () {
      final r = RastreadorDeIndices()..atualizar(['a', 'b', 'c']);

      final d = r.atualizar(['b', 'c']);

      expect(d['b'], 1);
      expect(d['c'], 1);
    });

    test('rajada de entradas: cada passo mede contra o passo anterior', () {
      // Este é o caso que quebrava a versão que MEDIA posições: apostas
      // chegando antes de a animação anterior terminar. Como o índice não é
      // uma grandeza transitória, cada reordenação é exata mesmo em rajada.
      final r = RastreadorDeIndices()..atualizar(['a', 'b', 'c']);

      final d1 = r.atualizar(['n1', 'a', 'b', 'c']);
      expect(d1['a'], -1);

      final d2 = r.atualizar(['n2', 'n1', 'a', 'b', 'c']);
      expect(d2['a'], -1, reason: 'a desceu mais uma, não duas');
      expect(d2['n1'], -1, reason: 'n1 agora tem lugar anterior e desceu 1');

      final d3 = r.atualizar(['n2', 'n1', 'c', 'a', 'b']);
      expect(d3['c'], 2, reason: 'c subiu do índice 4 para o 2');
    });

    test('esquece tudo ao limpar', () {
      final r = RastreadorDeIndices()..atualizar(['a', 'b']);
      expect(r.indiceDe('a'), 0);

      r.limpar();

      expect(r.indiceDe('a'), isNull);
      expect(r.atualizar(['b', 'a']), isEmpty, reason: 'sem histórico');
    });

    test('linha que sai deixa de ser lembrada', () {
      final r = RastreadorDeIndices()..atualizar(['a', 'b']);
      r.atualizar(['b']);

      expect(r.indiceDe('a'), isNull);
    });
  });
}
