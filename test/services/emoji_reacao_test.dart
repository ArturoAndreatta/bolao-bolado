import 'dart:convert';

import 'package:bolao_bolado/services/chat/emoji_reacao.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ehEmojiReacao aceita', () {
    test('emoji simples', () {
      expect(ehEmojiReacao('👍'), isTrue);
      expect(ehEmojiReacao('🤡'), isTrue);
      expect(ehEmojiReacao('🎉'), isTrue);
    });

    test('emoji com seletor de variação', () {
      // ❤️ é 2764 + FE0F: sem aceitar o seletor, o coração do catálogo cairia.
      expect(ehEmojiReacao('❤️'), isTrue);
    });

    test('emoji com tom de pele', () {
      expect(ehEmojiReacao('👍🏽'), isTrue);
    });

    test('bandeira (par de indicadores regionais)', () {
      expect(ehEmojiReacao('🇧🇷'), isTrue);
    });

    test('sequência ZWJ', () {
      expect(ehEmojiReacao('👨‍👩‍👧‍👦'), isTrue);
    });

    test('símbolo fora do bloco principal', () {
      expect(ehEmojiReacao('⭐'), isTrue);
      expect(ehEmojiReacao('✅'), isTrue);
      expect(ehEmojiReacao('⚡'), isTrue);
    });
  });

  group('ehEmojiReacao recusa', () {
    test('string vazia', () {
      expect(ehEmojiReacao(''), isFalse);
    });

    test('texto', () {
      expect(ehEmojiReacao('oi'), isFalse);
      expect(ehEmojiReacao('a'), isFalse);
    });

    test(
      'emoji com texto grudado — o abuso que a checagem existe pra barrar',
      () {
        expect(ehEmojiReacao('👍 me paga'), isFalse);
      },
    );

    test('espaço em branco', () {
      expect(ehEmojiReacao(' '), isFalse);
      expect(ehEmojiReacao('\n'), isFalse);
    });

    test('só juntores, sem emoji nenhum', () {
      // Passaria pelo "todo rune é aceitável" e desenharia um chip invisível.
      expect(ehEmojiReacao('‍‍'), isFalse);
      expect(ehEmojiReacao('️'), isFalse);
    });

    test('sequência longa demais', () {
      expect(ehEmojiReacao('👍' * 9), isFalse);
    });

    test('letra de alfabeto não latino', () {
      // Não é ASCII, então a REGRA do Firestore deixaria passar. Quem barra
      // aqui é a faixa de runes — é esta camada que segura o caso.
      expect(ehEmojiReacao('дом'), isFalse);
      expect(ehEmojiReacao('日本'), isFalse);
    });

    test('emoji de teclinha (tem ASCII dentro)', () {
      // Recusado de propósito: a regra do Firestore barra ASCII, e aceitar
      // aqui produziria uma reação que some sozinha depois de escolhida.
      expect(ehEmojiReacao('1️⃣'), isFalse);
      expect(ehEmojiReacao('#️⃣'), isFalse);
    });
  });

  group('catálogo', () {
    test('todo emoji oferecido passa na própria validação', () {
      for (final categoria in kCatalogoEmoji) {
        for (final emoji in categoria.emojis) {
          expect(
            ehEmojiReacao(emoji),
            isTrue,
            reason: 'categoria ${categoria.rotulo}: "$emoji" seria recusado',
          );
        }
      }
    });

    test('todo emoji oferecido também passa na REGRA do Firestore', () {
      // Espelho de ehReacaoValida() em firestore.rules: sem ASCII e no
      // máximo 32 de tamanho. Um emoji que passe aqui e falhe lá vira uma
      // reação que o app aceita, some no próximo snapshot e não explica por
      // quê — este teste é o que impede o catálogo de crescer nessa direção.
      for (final categoria in kCatalogoEmoji) {
        for (final emoji in categoria.emojis) {
          expect(
            emoji.runes.every((r) => r > 0x7F),
            isTrue,
            reason: 'categoria ${categoria.rotulo}: "$emoji" tem ASCII',
          );
          expect(
            utf8.encode(emoji).length,
            lessThanOrEqualTo(32),
            reason: 'categoria ${categoria.rotulo}: "$emoji" é longo demais',
          );
        }
      }
    });

    test('as reações rápidas estão entre as aceitas', () {
      for (final emoji in kReacoesRapidas) {
        expect(ehEmojiReacao(emoji), isTrue, reason: emoji);
      }
    });

    test('nenhum emoji repetido dentro da mesma categoria', () {
      for (final categoria in kCatalogoEmoji) {
        expect(
          categoria.emojis.toSet().length,
          categoria.emojis.length,
          reason: 'categoria ${categoria.rotulo} tem emoji repetido',
        );
      }
    });

    test('o split não deixou entrada vazia', () {
      // Espaço duplo na string do catálogo viraria um item vazio, que desenha
      // uma célula em branco na grade.
      for (final categoria in kCatalogoEmoji) {
        expect(
          categoria.emojis.any((e) => e.isEmpty),
          isFalse,
          reason: 'categoria ${categoria.rotulo} tem entrada vazia',
        );
      }
    });
  });
}
