import 'package:bolao_bolado/models/mensagem.dart';
import 'package:bolao_bolado/services/chat/formatacao_mensagem.dart';
import 'package:flutter_test/flutter_test.dart';

/// Atalho de leitura: junta os trechos num texto só, para conferir que a
/// formatação nunca perde nem duplica caractere visível.
String visivel(List<TrechoMensagem> trechos) =>
    trechos.map((t) => t.texto).join();

void main() {
  group('formatarMensagem — marcação', () {
    test('texto sem marcação vira um trecho só', () {
      final trechos = formatarMensagem('bora fechar o bolão');
      expect(trechos, hasLength(1));
      expect(trechos.single.tipo, TipoTrecho.texto);
      expect(trechos.single.negrito, isFalse);
    });

    test('reconhece negrito, itálico, riscado e mono', () {
      for (final caso in [
        ('*forte*', 'negrito'),
        ('_torto_', 'italico'),
        ('~cortado~', 'riscado'),
        ('`codigo`', 'mono'),
      ]) {
        final trechos = formatarMensagem(caso.$1);
        expect(trechos, hasLength(1), reason: caso.$1);
        final trecho = trechos.single;
        expect(trecho.texto, caso.$1.substring(1, caso.$1.length - 1));
        expect(trecho.negrito, caso.$2 == 'negrito', reason: caso.$1);
        expect(trecho.italico, caso.$2 == 'italico', reason: caso.$1);
        expect(trecho.riscado, caso.$2 == 'riscado', reason: caso.$1);
        expect(trecho.mono, caso.$2 == 'mono', reason: caso.$1);
      }
    });

    test('marcador no meio de palavra continua sendo texto', () {
      // O caso que quebra parser ingênuo: nome de variável e multiplicação.
      for (final texto in ['nome_do_campo', '3*4*5', 'a~b~c']) {
        final trechos = formatarMensagem(texto);
        expect(visivel(trechos), texto, reason: texto);
        expect(
          trechos.every((t) => !t.negrito && !t.italico && !t.riscado),
          isTrue,
          reason: texto,
        );
      }
    });

    test('marcador sem fechamento fica literal', () {
      final trechos = formatarMensagem('vai *começar hoje');
      expect(visivel(trechos), 'vai *começar hoje');
    });

    test('marcação no meio da frase preserva o resto do texto', () {
      final trechos = formatarMensagem('olha o *prazo* aí');
      expect(visivel(trechos), 'olha o prazo aí');
      expect(trechos.where((t) => t.negrito).single.texto, 'prazo');
    });
  });

  group('formatarMensagem — links', () {
    test('reconhece http e www', () {
      final trechos = formatarMensagem('veja https://caixa.gov.br agora');
      final link = trechos.singleWhere((t) => t.tipo == TipoTrecho.link);
      expect(link.texto, 'https://caixa.gov.br');
      expect(link.alvo, 'https://caixa.gov.br');

      final semEsquema = formatarMensagem('www.caixa.gov.br');
      expect(semEsquema.single.alvo, 'https://www.caixa.gov.br');
    });

    test('pontuação final da frase não entra no endereço', () {
      final trechos = formatarMensagem('resultado em https://caixa.gov.br.');
      final link = trechos.firstWhere((t) => t.tipo == TipoTrecho.link);
      expect(link.texto, 'https://caixa.gov.br');
      expect(visivel(trechos), 'resultado em https://caixa.gov.br.');
    });

    test('underscore dentro da URL não vira itálico', () {
      const url = 'https://site.com/a_b_c';
      final trechos = formatarMensagem(url);
      expect(trechos.single.tipo, TipoTrecho.link);
      expect(trechos.single.texto, url);
    });
  });

  group('formatarMensagem — menções', () {
    test('marca o intervalo informado', () {
      const texto = 'boa @Ana, fecha aí';
      final trechos = formatarMensagem(
        texto,
        mencoes: const [Mencao(uid: 'u1', nome: 'Ana', inicio: 4, fim: 8)],
      );
      final mencao = trechos.singleWhere((t) => t.tipo == TipoTrecho.mencao);
      expect(mencao.texto, '@Ana');
      expect(mencao.alvo, 'u1');
      expect(visivel(trechos), texto);
    });

    test('menção com índice fora do texto é descartada sem estourar', () {
      const texto = 'oi';
      final trechos = formatarMensagem(
        texto,
        mencoes: const [Mencao(uid: 'u1', nome: 'Ana', inicio: 40, fim: 44)],
      );
      expect(visivel(trechos), texto);
      expect(trechos.any((t) => t.tipo == TipoTrecho.mencao), isFalse);
    });

    test('menções sobrepostas: fica só a primeira', () {
      const texto = '@Ana Paula';
      final trechos = formatarMensagem(
        texto,
        mencoes: const [
          Mencao(uid: 'u1', nome: 'Ana Paula', inicio: 0, fim: 10),
          Mencao(uid: 'u2', nome: 'Ana', inicio: 0, fim: 4),
        ],
      );
      expect(trechos.where((t) => t.tipo == TipoTrecho.mencao), hasLength(1));
      expect(visivel(trechos), texto);
    });
  });

  group('detectarMencao', () {
    test('abre no @ do começo e no meio da frase', () {
      final inicial = detectarMencao('@', 1);
      expect(inicial?.inicio, 0);
      expect(inicial?.consulta, '');

      final meio = detectarMencao('bora @an', 8);
      expect(meio?.inicio, 5);
      expect(meio?.consulta, 'an');
    });

    test('não abre no @ de um e-mail', () {
      expect(detectarMencao('manda pro fulano@site.com', 25), isNull);
    });

    test('considera só o que está ANTES do cursor', () {
      // Cursor entre o "n" e o "a" de "@ana".
      final emDigitacao = detectarMencao('@ana', 3);
      expect(emDigitacao?.consulta, 'an');
    });

    test('normaliza acento na consulta', () {
      expect(detectarMencao('@joã', 4)?.consulta, 'joa');
    });

    test('token longo demais deixa de ser menção', () {
      final texto = '@${'a' * 40}';
      expect(detectarMencao(texto, texto.length), isNull);
    });

    test('quebra de linha corta a busca pelo @', () {
      expect(detectarMencao('@ana\nnova linha', 15), isNull);
    });

    test('cursor fora do texto devolve null em vez de estourar', () {
      expect(detectarMencao('@ana', 99), isNull);
      expect(detectarMencao('@ana', -1), isNull);
    });
  });

  group('nomeCasaConsulta', () {
    test('casa por nome, por sobrenome e ignora acento', () {
      expect(nomeCasaConsulta('João Silva', 'joa'), isTrue);
      expect(nomeCasaConsulta('João Silva', 'silv'), isTrue);
      expect(nomeCasaConsulta('João Silva', ''), isTrue);
      expect(nomeCasaConsulta('João Silva', 'ana'), isFalse);
    });

    test('não casa por pedaço no meio da palavra', () {
      expect(nomeCasaConsulta('Orlindo', 'lindo'), isFalse);
    });
  });

  group('aplicarMencao', () {
    test('troca o token pelo nome inteiro e põe o cursor depois dele', () {
      final resultado = aplicarMencao(
        texto: 'bora @an',
        cursor: 8,
        inicio: 5,
        nome: 'Ana Paula',
      );
      expect(resultado.texto, 'bora @Ana Paula ');
      expect(resultado.cursor, 16);
    });

    test('no meio da frase não duplica o espaço que já existe', () {
      final resultado = aplicarMencao(
        texto: 'bora @an fechar',
        cursor: 8,
        inicio: 5,
        nome: 'Ana Paula',
      );
      expect(resultado.texto, 'bora @Ana Paula fechar');
      expect(resultado.cursor, 15);
    });

    test('índice inválido devolve o texto intacto', () {
      final resultado = aplicarMencao(
        texto: 'oi',
        cursor: 2,
        inicio: 7,
        nome: 'Ana',
      );
      expect(resultado.texto, 'oi');
    });

    test('o token que ele escreve é reconhecido no envio', () {
      // Ida e volta completa do fluxo: digitou, escolheu na lista, enviou.
      final aplicado = aplicarMencao(
        texto: 'e aí @an',
        cursor: 8,
        inicio: 5,
        nome: 'Ana',
      );
      final mencoes = resolverMencoes(aplicado.texto.trim(), [
        (uid: 'u1', nome: 'Ana'),
      ]);
      expect(mencoes, hasLength(1));
      expect(
        aplicado.texto.substring(mencoes.single.inicio, mencoes.single.fim),
        '@Ana',
      );
    });
  });

  group('resolverMencoes', () {
    test('acha a posição do token no texto final', () {
      final mencoes = resolverMencoes('e aí @Ana Paula, bora?', [
        (uid: 'u1', nome: 'Ana Paula'),
      ]);
      expect(mencoes, hasLength(1));
      expect(mencoes.single.inicio, 5);
      expect(mencoes.single.fim, 15);
      expect(mencoes.single.uid, 'u1');
    });

    test('nome apagado do texto deixa de ser menção', () {
      final mencoes = resolverMencoes('mudei de ideia', [
        (uid: 'u1', nome: 'Ana'),
      ]);
      expect(mencoes, isEmpty);
    });

    test('não casa token que é prefixo de outro nome', () {
      final mencoes = resolverMencoes('fala @Anabela', [
        (uid: 'u1', nome: 'Ana'),
      ]);
      expect(mencoes, isEmpty);
    });

    test('mesma pessoa citada duas vezes usa a primeira ocorrência livre', () {
      final mencoes = resolverMencoes('@Ana e @Ana de novo', [
        (uid: 'u1', nome: 'Ana'),
        (uid: 'u1', nome: 'Ana'),
      ]);
      expect(mencoes.map((m) => m.inicio), [0, 7]);
    });

    test('devolve em ordem de posição, não de escolha', () {
      final mencoes = resolverMencoes('@Bia falou com @Ana', [
        (uid: 'u2', nome: 'Ana'),
        (uid: 'u1', nome: 'Bia'),
      ]);
      expect(mencoes.map((m) => m.uid), ['u1', 'u2']);
    });
  });
}
