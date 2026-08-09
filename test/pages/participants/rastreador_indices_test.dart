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

      // Aqui a lista não cresceu — é reordenação pura, sem ninguém entrando.
      // Então o movimento de 'a' e 'b' é real e vale animar: elas cederam o
      // lugar para 'c'. O desconto do empurrão só entra quando a lista cresce
      // (ver o teste de inserção no topo).
      expect(d['a'], -1, reason: 'a desceu 1');
      expect(d['b'], -1, reason: 'b desceu 1');
    });

    test(
      'linha nova não desliza — quem cuida dela é a animação de entrada',
      () {
        final r = RastreadorDeIndices()..atualizar(['a', 'b']);

        final d = r.atualizar(['nova', 'a', 'b']);

        expect(d.containsKey('nova'), isFalse);

        // E ninguém mais desliza: 'a' e 'b' desceram juntas, empurradas pela
        // inserção. É o caso mais comum ao ordenar por "última alteração",
        // onde toda aposta nova entra no topo — animar o empurrão punha a
        // tela inteira em movimento junto com a entrada.
        expect(d, isEmpty, reason: 'empurrão coletivo não é reordenação');
      },
    );

    test('remoção faz as de baixo subirem', () {
      final r = RastreadorDeIndices()..atualizar(['a', 'b', 'c']);

      final d = r.atualizar(['b', 'c']);

      expect(d['b'], 1);
      expect(d['c'], 1);
    });

    test('rajada de entradas no topo não põe a lista toda em movimento', () {
      // O caso da tela ordenada por "última alteração": cada aposta nova
      // entra na primeira linha e empurra todas as outras. Animar esse
      // empurrão fazia 9 de 13 linhas visíveis deslizarem ao mesmo tempo que
      // a linha nova entrava, e a confusão encobria a animação de entrada.
      final r = RastreadorDeIndices()..atualizar(['a', 'b', 'c']);

      expect(
        r.atualizar(['n1', 'a', 'b', 'c']),
        isEmpty,
        reason: 'só empurrão: ninguém trocou de lugar',
      );
      expect(r.atualizar(['n2', 'n1', 'a', 'b', 'c']), isEmpty);

      // Mas uma troca REAL no meio da rajada continua deslizando: aqui a
      // lista não cresceu e 'c' passou na frente de 'a' e 'b'.
      final d = r.atualizar(['n2', 'n1', 'c', 'a', 'b']);
      expect(d['c'], 2, reason: 'c subiu do índice 4 para o 2');
    });

    test('entrada no MEIO ainda desliza quem ela ultrapassa', () {
      // Crescer não anula tudo: se a aposta nova entra no meio, quem está
      // acima dela não se mexe e quem está abaixo desce. Como o empurrão não
      // é da lista inteira, ele não é descontado.
      final r = RastreadorDeIndices()..atualizar(['a', 'b', 'c', 'd']);

      final d = r.atualizar(['a', 'b', 'nova', 'c', 'd']);

      expect(d.containsKey('a'), isFalse, reason: 'a ficou no lugar');
      expect(d.containsKey('b'), isFalse, reason: 'b ficou no lugar');
      expect(d['c'], -1, reason: 'c desceu para dar espaço');
      expect(d['d'], -1);
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
