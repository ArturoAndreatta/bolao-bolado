import 'package:bolao_bolado/pages/participants/participants_reordenacao.dart';
import 'package:flutter_test/flutter_test.dart';

List<Map<String, dynamic>> _linhas(List<String> uids, {Object? valor = 30.0}) =>
    uids.map((uid) => <String, dynamic>{'uid': uid, 'valor': valor}).toList();

void main() {
  group('RastreadorDeLinhas', () {
    test('linha presente na PRIMEIRA carga não anima (não é aposta nova)', () {
      final r = RastreadorDeLinhas();

      r.registrarBuild(rowsCompletas: _linhas(['a']), chavesEmOrdem: ['a']);

      expect(
        r.isNovaOuAlterada('a', 30.0),
        isFalse,
        reason: 'a tela abrindo com apostas existentes não é "chegada"',
      );
      expect(r.deslocamentoDe('a'), 0);
    });

    test('linha que chega DEPOIS da primeira carga anima normalmente', () {
      final r = RastreadorDeLinhas();

      // Primeira carga: só 'a'.
      r.registrarBuild(rowsCompletas: _linhas(['a']), chavesEmOrdem: ['a']);
      r.isNovaOuAlterada('a', 30.0);

      // 'b' chega depois, numa emissão seguinte do Firestore.
      r.registrarBuild(
        rowsCompletas: _linhas(['a', 'b']),
        chavesEmOrdem: ['b', 'a'],
      );

      expect(
        r.isNovaOuAlterada('b', 20.0),
        isTrue,
        reason: 'b é uma aposta genuinamente nova',
      );
    });

    test('reordenação real produz deslocamento sem reanimar a entrada', () {
      final r = RastreadorDeLinhas();

      r.registrarBuild(
        rowsCompletas: _linhas(['a', 'b', 'c']),
        chavesEmOrdem: ['a', 'b', 'c'],
      );
      r.isNovaOuAlterada('a', 30.0);
      r.isNovaOuAlterada('b', 20.0);
      r.isNovaOuAlterada('c', 10.0);

      // 'c' passa na frente das outras duas, sem entrar nem sair ninguém.
      r.registrarBuild(
        rowsCompletas: _linhas(['c', 'a', 'b']),
        chavesEmOrdem: ['c', 'a', 'b'],
      );

      expect(r.deslocamentoDe('c'), 2, reason: 'c subiu 2 lugares');
      expect(
        r.isNovaOuAlterada('c', 10.0),
        isFalse,
        reason: 'reordenar não é o mesmo que entrar — c já era conhecida',
      );
    });

    test('participante removido e recriado com mesmo valor volta a animar', () {
      final r = RastreadorDeLinhas();

      r.registrarBuild(rowsCompletas: _linhas(['a']), chavesEmOrdem: ['a']);
      r.isNovaOuAlterada('a', 30.0);

      // Sai da lista.
      r.registrarBuild(rowsCompletas: _linhas([]), chavesEmOrdem: []);

      // Volta com o MESMO valor de antes.
      r.registrarBuild(rowsCompletas: _linhas(['a']), chavesEmOrdem: ['a']);
      expect(
        r.isNovaOuAlterada('a', 30.0),
        isTrue,
        reason: 'a poda em registrarBuild deve esquecer quem saiu',
      );
    });

    test('aposta já existente na primeira carga não anima ao ser vista pela '
        'primeira vez (reciclagem/scroll)', () {
      // Reproduz o bug: numa lista reciclada, uma linha fora da viewport
      // inicial só passa por isNovaOuAlterada quando o usuário rola até
      // ela — que pode ser muito depois de registrarBuild. Sem tratamento
      // especial, isso fazia o simples ato de rolar "criar" apostas novas.
      final r = RastreadorDeLinhas();

      // Carga inicial: 50 apostas, mas só as 3 primeiras estão na
      // viewport (isNovaOuAlterada só é chamado para elas).
      final todas = _linhas(List.generate(50, (i) => 'u$i'));
      r.registrarBuild(
        rowsCompletas: todas,
        chavesEmOrdem: todas.map((e) => e['uid'] as Object).toList(),
      );
      for (final uid in ['u0', 'u1', 'u2']) {
        r.isNovaOuAlterada(uid, 30.0);
      }

      // Um rebuild sem mudança nenhuma nos dados (ex.: stream reemitindo).
      r.registrarBuild(
        rowsCompletas: todas,
        chavesEmOrdem: todas.map((e) => e['uid'] as Object).toList(),
      );

      // Usuário rola até u40, que nunca tinha passado por
      // isNovaOuAlterada. Ela JÁ existia desde a carga inicial — não pode
      // animar como se fosse nova.
      expect(
        r.isNovaOuAlterada('u40', 30.0),
        isFalse,
        reason: 'rolar até uma linha antiga não pode disparar a entrada',
      );
    });

    test(
      'esquecerQuemSaiu poda sem tocar no índice (caminho não-reciclado)',
      () {
        final r = RastreadorDeLinhas();

        r.registrarBuild(
          rowsCompletas: _linhas(['a', 'b']),
          chavesEmOrdem: ['a', 'b'],
        );
        r.isNovaOuAlterada('a', 30.0);
        r.isNovaOuAlterada('b', 20.0);

        // 'b' saiu; só a poda, sem recalcular deslocamentos por índice.
        r.esquecerQuemSaiu(_linhas(['a']));

        expect(
          r.isNovaOuAlterada('b', 20.0),
          isTrue,
          reason: 'b foi esquecida e deve voltar a animar se reaparecer',
        );
        expect(
          r.isNovaOuAlterada('a', 30.0),
          isFalse,
          reason: 'a continuou na lista, não deve reanimar',
        );
      },
    );
  });
}
