import 'package:flutter_test/flutter_test.dart';

/// Réplica da regra de desempate de `_ordenar` em participants_painel.dart.
///
/// A ordenação real vive num State privado, mas a parte que importa aqui é a
/// regra: empate no critério visível é desempatado pelo uid, sempre
/// crescente. Testar a regra isolada guarda o comportamento sem precisar
/// montar a página inteira.
int comparar(
  Map<String, Object?> a,
  Map<String, Object?> b, {
  required bool ascendente,
}) {
  final va = (a['valor'] as num?)?.toDouble() ?? 0;
  final vb = (b['valor'] as num?)?.toDouble() ?? 0;
  final cmp = va.compareTo(vb);
  if (cmp != 0) return ascendente ? cmp : -cmp;
  return (a['uid']?.toString() ?? '').compareTo(b['uid']?.toString() ?? '');
}

List<String> ordenar(
  List<Map<String, Object?>> linhas, {
  bool ascendente = false,
}) {
  final copia = [...linhas]
    ..sort((a, b) => comparar(a, b, ascendente: ascendente));
  return copia.map((e) => e['uid'].toString()).toList();
}

void main() {
  group('ordenação estável', () {
    test('apostas de mesmo valor ficam sempre na mesma ordem', () {
      // O simulador gera muitas apostas de valor igual; sem desempate, a
      // ordem entre elas dependia da ordem de entrada, que muda sozinha
      // quando o Firestore reposiciona um doc recém-confirmado.
      final linhas = [
        {'uid': 'sim-c', 'valor': 30.0},
        {'uid': 'sim-a', 'valor': 30.0},
        {'uid': 'sim-b', 'valor': 30.0},
      ];

      final ordemA = ordenar(linhas);
      // Mesma lista, embaralhada na entrada.
      final ordemB = ordenar(linhas.reversed.toList());

      expect(ordemA, ordemB, reason: 'a ordem não pode depender da entrada');
      expect(ordemA, ['sim-a', 'sim-b', 'sim-c']);
    });

    test('uma aposta nova entrando não embaralha as de mesmo valor', () {
      final antes = [
        {'uid': 'sim-a', 'valor': 30.0},
        {'uid': 'sim-b', 'valor': 30.0},
        {'uid': 'sim-c', 'valor': 30.0},
      ];
      // A nova entra no COMEÇO da lista de origem — é o que o Firestore faz
      // com uma escrita pendente ordenada por data-hora descendente.
      final depois = [
        {'uid': 'sim-nova', 'valor': 30.0},
        ...antes,
      ];

      final ordemAntes = ordenar(antes);
      final ordemDepois = ordenar(depois);

      // As três antigas mantêm a posição relativa entre si: só a nova é
      // inserida. Sem o desempate, elas trocavam de lugar e cada troca virava
      // uma reordenação animada.
      expect(
        ordemDepois.where((uid) => uid != 'sim-nova').toList(),
        ordemAntes,
        reason: 'as apostas antigas não podem se mexer',
      );
    });

    test('o desempate não inverte junto com a direção da ordenação', () {
      // O desempate é só um critério de estabilidade, não de exibição: ele é
      // sempre crescente para a ordem ser previsível nos dois sentidos.
      final linhas = [
        {'uid': 'sim-b', 'valor': 30.0},
        {'uid': 'sim-a', 'valor': 30.0},
      ];

      expect(ordenar(linhas, ascendente: false), ['sim-a', 'sim-b']);
      expect(ordenar(linhas, ascendente: true), ['sim-a', 'sim-b']);
    });

    test('valores diferentes continuam mandando na ordem', () {
      final linhas = [
        {'uid': 'sim-z', 'valor': 10.0},
        {'uid': 'sim-a', 'valor': 90.0},
      ];

      // Decrescente: o maior valor vem primeiro, mesmo com uid "maior".
      expect(ordenar(linhas), ['sim-a', 'sim-z']);
      expect(ordenar(linhas, ascendente: true), ['sim-z', 'sim-a']);
    });
  });
}
