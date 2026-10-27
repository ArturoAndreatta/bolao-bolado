import 'package:bolao_bolado/pages/participants/participants_reordenacao.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _aposta(
  String uid, {
  String? nome,
  Object? valor = 30.0,
}) => {'uid': uid, 'nome': nome ?? uid, 'valor': valor};

List<Map<String, dynamic>> _linhas(List<String> uids) =>
    uids.map(_aposta).toList();

/// Um build completo da tela: registra a emissão e, como o widget faz num
/// callback pós-frame, encerra os eventos do quadro ao final. O que [ler]
/// devolve é o que as linhas montadas NESTE quadro enxergam.
T _quadro<T>(
  RastreadorDeLinhas r,
  List<Map<String, dynamic>> rows,
  T Function() ler, {
  List<Object>? chaves,
}) {
  r.registrarBuild(
    rowsCompletas: rows,
    chavesEmOrdem: chaves ?? rows.map((e) => e['uid'] as Object).toList(),
  );
  final lido = ler();
  r.descartarEventosDoQuadro();
  return lido;
}

void main() {
  group('RastreadorDeLinhas', () {
    test('linha presente na PRIMEIRA carga não anima (não é aposta nova)', () {
      final r = RastreadorDeLinhas();

      final mudanca = _quadro(r, _linhas(['a']), () => r.mudancaDe('a'));

      expect(
        mudanca,
        isNull,
        reason: 'a tela abrindo com apostas existentes não é "chegada"',
      );
    });

    test('linha que chega DEPOIS da primeira carga anima a entrada', () {
      final r = RastreadorDeLinhas();
      _quadro(r, _linhas(['a']), () {});

      expect(_quadro(r, _linhas(['b', 'a']), () => r.isNova('b')), isTrue);
    });

    test('EDITAR o valor não é aposta nova: só a célula do valor troca', () {
      // O bug que motivou a separação: valor diferente contava como linha
      // nova, e editar a própria aposta reencenava a entrada inteira.
      final r = RastreadorDeLinhas();
      _quadro(r, [_aposta('a', valor: 30.0)], () {});

      final mudanca = _quadro(r, [
        _aposta('a', valor: 42.0),
      ], () => r.mudancaDe('a'));

      expect(mudanca, isNotNull);
      expect(mudanca!.nova, isFalse, reason: 'edição não é chegada');
      expect(mudanca.valorMudou, isTrue);
      expect(mudanca.valorAnterior, 30.0);
      expect(mudanca.nomeMudou, isFalse, reason: 'o nome não foi tocado');
    });

    test('EDITAR o nome marca só o nome', () {
      final r = RastreadorDeLinhas();
      _quadro(r, [_aposta('a', nome: 'Ana')], () {});

      final mudanca = _quadro(r, [
        _aposta('a', nome: 'Ana Paula'),
      ], () => r.mudancaDe('a'));

      expect(mudanca!.nova, isFalse);
      expect(mudanca.nomeMudou, isTrue);
      expect(mudanca.nomeAnterior, 'Ana');
      expect(mudanca.valorMudou, isFalse);
    });

    test('reemissão com os mesmos dados não gera evento', () {
      // Escrita local e confirmação do servidor chegam como duas emissões
      // iguais: só a primeira é acontecimento.
      final r = RastreadorDeLinhas();
      _quadro(r, _linhas(['a']), () {});
      _quadro(r, _linhas(['b', 'a']), () {});

      expect(_quadro(r, _linhas(['b', 'a']), () => r.mudancaDe('b')), isNull);
    });

    test('evento vale só no quadro em que os dados chegaram', () {
      // Linha montada depois (rolagem até ela) não pode tocar uma animação
      // de algo que aconteceu quadros atrás.
      final r = RastreadorDeLinhas();
      _quadro(r, _linhas(['a']), () {});
      _quadro(r, [_aposta('a', valor: 99.0)], () {});

      expect(r.mudancaDe('a'), isNull);
      expect(r.temEventos, isFalse);
    });

    test('aposta antiga fora da viewport não anima ao ser vista '
        '(reciclagem/scroll)', () {
      final r = RastreadorDeLinhas();
      final todas = _linhas(List.generate(50, (i) => 'u$i'));

      _quadro(r, todas, () {});
      _quadro(r, todas, () {});

      // Usuário rola até u40, montada pela primeira vez agora.
      expect(r.isNova('u40'), isFalse);
    });

    test('reordenação produz deslocamento sem animar a entrada', () {
      final r = RastreadorDeLinhas();
      _quadro(r, _linhas(['a', 'b', 'c']), () {});
      final geracaoAntes = r.geracao;

      final (andou, nova) = _quadro(
        r,
        _linhas(['c', 'a', 'b']),
        () => (r.deslocamentoDe('c'), r.isNova('c')),
      );

      expect(andou, 2, reason: 'c subiu 2 lugares');
      expect(nova, isFalse, reason: 'reordenar não é entrar');
      expect(
        r.geracao,
        greaterThan(geracaoAntes),
        reason: 'a geração sobe para o deslize reaproveitado perceber',
      );
    });

    test('participante removido e recriado com mesmo valor volta a animar', () {
      final r = RastreadorDeLinhas();
      _quadro(r, _linhas(['x', 'a']), () {});
      _quadro(r, _linhas(['x']), () {});

      expect(_quadro(r, _linhas(['x', 'a']), () => r.isNova('a')), isTrue);
    });

    test('filtro de busca não esquece quem ficou escondido', () {
      // A comparação usa a lista COMPLETA; só a ordem vem da filtrada.
      final r = RastreadorDeLinhas();
      final todas = _linhas(['ana', 'bruno', 'carla']);
      _quadro(r, todas, () {});

      _quadro(r, todas, () {}, chaves: ['ana']);
      final novas = _quadro(
        r,
        todas,
        () => [
          for (final u in ['ana', 'bruno', 'carla']) r.isNova(u),
        ],
      );

      expect(novas, everyElement(isFalse));
    });

    test('sem chavesEmOrdem (corpo não reciclado) detecta só mudanças', () {
      final r = RastreadorDeLinhas();
      r.registrarBuild(rowsCompletas: _linhas(['a']));
      r.registrarBuild(rowsCompletas: _linhas(['a', 'b']));

      expect(r.isNova('b'), isTrue);
      expect(r.deslocamentoDe('a'), 0);
    });
  });

  group('podarConhecidos', () {
    test('esquece uid que saiu e mantém quem continua', () {
      final conhecidos = <String, Object?>{'a': 1, 'b': 2};

      podarConhecidos(conhecidos, _linhas(['a', 'c']));

      expect(conhecidos.keys, ['a']);
    });
  });
}
