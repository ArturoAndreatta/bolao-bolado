import 'package:bolao_bolado/components/shared/avatar_emoji.dart';
import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/pages/participants/participants_lista.dart';
import 'package:bolao_bolado/services/avatar/avatar_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// O avatar de cada participante é resolvido pela LINHA que o desenha, e não
/// mais por um aquecimento de todos os uids da sala.
///
/// Isso existe porque o cache abre um `snapshots()` do Firestore por uid:
/// aquecer 300 participantes no F5 abria 300 listeners de uma vez, todos
/// concorrendo com o chat e o card "Minha Aposta" pela mesma conexão.
void main() {
  testWidgets('sem uid, cai no fallback sem tentar ler o Firestore', (
    tester,
  ) async {
    // Aposta manual lançada pelo admin não tem usuário por trás.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AvatarDoParticipante(
            uid: null,
            tamanho: 32,
            corFallback: Color(0xFF123456),
            emojiFallback: '🎲',
          ),
        ),
      ),
    );

    expect(find.text('🎲'), findsOneWidget);
    // Nenhum StreamBuilder montado: sem uid não há o que observar.
    expect(
      find.byType(StreamBuilder<({Color cor, String emoji})>),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  test('o estado de espera usa a cor neutra, não uma cor inventada', () {
    // Cobre a decisão sem precisar de Firebase: enquanto o documento do
    // usuário não chega, o avatar assume o mesmo cinza de quem nunca escolheu
    // cor — em vez de sumir da linha ou segurar a lista esperando rede.
    expect(kCorAvatarNeutra, const Color(0xFFE5E7EB));
    expect(kEmojiAvatarPadrao, isNotEmpty);
  });

  testWidgets(
    'linha da lista pede o avatar pelo uid, não por dado pré-carregado',
    (tester) async {
      // A LinhaParticipante monta AvatarDoParticipante com o uid: é o que faz o
      // custo dos avatares acompanhar as linhas visíveis. Se alguém voltar a
      // passar cor/emoji prontos e remover o uid, este teste acusa.
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [AppCores.claro]),
          home: const Scaffold(
            body: LinhaParticipante(
              nome: 'Fulano',
              valor: r'R$ 30,00',
              cotas: 5,
              premio: r'R$ 100,00',
              uid: null, // sem uid não toca no Firestore
              destacado: false,
            ),
          ),
        ),
      );

      expect(find.byType(AvatarDoParticipante), findsOneWidget);
      final avatar = tester.widget<AvatarDoParticipante>(
        find.byType(AvatarDoParticipante),
      );
      expect(avatar.tamanho, 32);
      expect(tester.takeException(), isNull);
    },
  );
}
