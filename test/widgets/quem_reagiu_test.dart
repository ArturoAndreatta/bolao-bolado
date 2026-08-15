import 'package:bolao_bolado/widgets/chat/quem_reagiu.dart';
import 'package:flutter_test/flutter_test.dart';

String _nome(String uid) => switch (uid) {
  'u1' => 'Ana',
  'u2' => 'Bruno',
  'u3' => 'carlos',
  'u4' => 'Daniela',
  _ => 'Alguém',
};

void main() {
  group('ordenarReacoes', () {
    test('agrupa por emoji na ordem da barra rápida', () {
      final linhas = ordenarReacoes(
        // 🎉 vem DEPOIS de 👍 em kReacoesRapidas, e a ordem do mapa é outra
        // de propósito: quem manda é a lista, não a inserção.
        reacoes: const {'u1': '🎉', 'u2': '👍', 'u3': '🎉'},
        uidAtual: null,
        nomeDe: _nome,
      );

      expect(linhas.map((l) => l.emoji), ['👍', '🎉', '🎉']);
    });

    test('emoji de fora da barra rápida vai para o fim', () {
      final linhas = ordenarReacoes(
        reacoes: const {'u1': '🤡', 'u2': '👍'},
        uidAtual: null,
        nomeDe: _nome,
      );

      expect(linhas.map((l) => l.emoji), ['👍', '🤡']);
    });

    test('você aparece na frente do seu grupo', () {
      final linhas = ordenarReacoes(
        reacoes: const {'u1': '👍', 'u2': '👍', 'u3': '👍'},
        uidAtual: 'u3',
        nomeDe: _nome,
      );

      expect(linhas.first.souEu, isTrue);
      expect(linhas.first.uid, 'u3');
    });

    test('o resto sai em ordem alfabética, ignorando maiúscula', () {
      // Sem critério fixo a lista trocaria de ordem a cada abertura: o mapa do
      // Firestore não guarda quando cada reação entrou.
      final linhas = ordenarReacoes(
        reacoes: const {'u3': '👍', 'u1': '👍', 'u4': '👍', 'u2': '👍'},
        uidAtual: null,
        nomeDe: _nome,
      );

      expect(linhas.map((l) => l.nome), ['Ana', 'Bruno', 'carlos', 'Daniela']);
    });

    test('ninguém aparece duas vezes quando o emoji se repete', () {
      final linhas = ordenarReacoes(
        reacoes: const {'u1': '👍', 'u2': '👍', 'u3': '👍'},
        uidAtual: null,
        nomeDe: _nome,
      );

      expect(linhas.length, 3);
      expect(linhas.map((l) => l.uid).toSet().length, 3);
    });

    test('mapa vazio devolve lista vazia', () {
      expect(
        ordenarReacoes(reacoes: const {}, uidAtual: 'u1', nomeDe: _nome),
        isEmpty,
      );
    });
  });

  group('resumoQuemReagiu', () {
    test('um nome sai sozinho', () {
      expect(resumoQuemReagiu(['Ana']), 'Ana');
    });

    test('dois nomes ligados por "e"', () {
      expect(resumoQuemReagiu(['Ana', 'Bruno']), 'Ana e Bruno');
    });

    test('três nomes ainda cabem inteiros', () {
      expect(
        resumoQuemReagiu(['Ana', 'Bruno', 'Carlos']),
        'Ana, Bruno e Carlos',
      );
    });

    test('a partir de quatro, conta o resto', () {
      // O tooltip é uma linha só; a lista inteira sai na folha.
      expect(
        resumoQuemReagiu(['Ana', 'Bruno', 'Carlos', 'Daniela']),
        'Ana, Bruno e mais 2',
      );
    });

    test('lista vazia não vira texto', () {
      expect(resumoQuemReagiu([]), '');
    });
  });
}
