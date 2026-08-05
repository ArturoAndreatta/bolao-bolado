import 'package:bolao_bolado/pages/participants/participants_tabela.dart';
import 'package:flutter_test/flutter_test.dart';

List<Map<String, dynamic>> _linhas(List<String> uids) =>
    uids.map((uid) => <String, dynamic>{'uid': uid}).toList();

void main() {
  group('detectarLinhaNova', () {
    test('uid inédito é novo; repetido com mesmo valor não é', () {
      final conhecidos = <String, Object?>{};

      expect(detectarLinhaNova(conhecidos, 'a', 30.0), isTrue);
      expect(detectarLinhaNova(conhecidos, 'a', 30.0), isFalse);
    });

    test('mesmo uid com valor diferente conta como aposta alterada', () {
      final conhecidos = <String, Object?>{};

      detectarLinhaNova(conhecidos, 'a', 30.0);
      expect(detectarLinhaNova(conhecidos, 'a', 42.0), isTrue);
      expect(detectarLinhaNova(conhecidos, 'a', 42.0), isFalse);
    });

    test('uid nulo nunca anima', () {
      expect(detectarLinhaNova(<String, Object?>{}, null, 30.0), isFalse);
    });
  });

  group('podarConhecidos', () {
    test('esquece uid que saiu da lista, e ele volta a animar', () {
      final conhecidos = <String, Object?>{};
      detectarLinhaNova(conhecidos, 'a', 30.0);
      detectarLinhaNova(conhecidos, 'b', 12.0);

      // 'b' foi removido da sala (o simulador faz isso o tempo todo).
      podarConhecidos(conhecidos, _linhas(['a']));
      expect(conhecidos.containsKey('b'), isFalse);

      // Recriado com o MESMO valor de antes: precisa animar de novo, senão a
      // reinserção passa despercebida.
      expect(detectarLinhaNova(conhecidos, 'b', 12.0), isTrue);
    });

    test('mantém quem continua na lista', () {
      final conhecidos = <String, Object?>{};
      detectarLinhaNova(conhecidos, 'a', 30.0);

      podarConhecidos(conhecidos, _linhas(['a', 'b']));

      expect(
        detectarLinhaNova(conhecidos, 'a', 30.0),
        isFalse,
        reason: 'quem seguiu na lista não pode reanimar',
      );
    });

    test('podar contra a lista COMPLETA não reanima ao limpar a busca', () {
      final conhecidos = <String, Object?>{};
      final todas = _linhas(['ana', 'bruno', 'carla']);
      for (final row in todas) {
        detectarLinhaNova(conhecidos, row['uid'] as String, 10.0);
      }

      // Busca por "ana": a tabela só renderiza 1 linha, mas a poda usa a
      // lista completa — é isso que impede o filtro de esquecer os outros.
      podarConhecidos(conhecidos, todas);

      // Busca limpa: ninguém pode animar, nada de novo aconteceu.
      for (final row in todas) {
        expect(
          detectarLinhaNova(conhecidos, row['uid'] as String, 10.0),
          isFalse,
          reason: 'filtrar e limpar a busca não é chegada de aposta',
        );
      }
    });
  });
}
