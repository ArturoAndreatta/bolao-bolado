import 'package:bolao_bolado/services/avatar/avatar_service.dart';
import 'package:flutter/material.dart';

/// Avatar de um participante, resolvido SOB DEMANDA a partir do uid.
///
/// Existe para o custo dos avatares acompanhar o que está na tela, não o
/// tamanho da sala. Antes, montar a lista de apostas aquecia o cache com
/// TODOS os uids de uma vez — e como o cache
/// abre um `snapshots()` por uid, uma sala de 300 apostas abria 300 listeners
/// do Firestore no F5, todos disputando a mesma conexão com o chat e o card
/// "Minha Aposta", que por isso demoravam a carregar.
///
/// Aqui cada linha pede o próprio avatar quando é construída. Como a tabela
/// do desktop recicla (`ListView.builder`), só as ~12 linhas visíveis pedem,
/// e rolar troca quais uids estão sendo observados em vez de somar mais.
///
/// Enquanto o documento não chega, desenha o avatar neutro — mesmo estado que
/// a lista já mostrava antes enquanto os avatares vinham em segundo plano.
class AvatarDoParticipante extends StatelessWidget {
  final String? uid;
  final double tamanho;

  /// Usados quando não há uid (aposta manual lançada pelo admin, que não tem
  /// usuário) ou como valor imediato, sem esperar o Firestore.
  final Color? corFallback;
  final String? emojiFallback;

  final Color? corBorda;
  final double larguraBorda;

  const AvatarDoParticipante({
    super.key,
    required this.uid,
    required this.tamanho,
    this.corFallback,
    this.emojiFallback,
    this.corBorda,
    this.larguraBorda = 2,
  });

  @override
  Widget build(BuildContext context) {
    final id = uid;
    if (id == null) return _avatar(corFallback, emojiFallback);

    final cache = AvatarColorCache.instance;

    // Já em memória (outra linha ou o chat já observou este uid): desenha
    // direto, sem StreamBuilder e sem piscar no estado neutro.
    final conhecido = cache.avatarConhecido(id);
    if (conhecido != null) return _avatar(conhecido.cor, conhecido.emoji);

    return StreamBuilder<({Color cor, String emoji})>(
      // A stream é memoizada por uid dentro do cache, então reconstruir este
      // widget não reassina o listener.
      stream: cache.avatarStream(id),
      builder: (context, snapshot) {
        final dados = snapshot.data;
        return _avatar(
          dados?.cor ?? corFallback,
          dados?.emoji ?? emojiFallback,
        );
      },
    );
  }

  Widget _avatar(Color? cor, String? emoji) => AvatarEmoji(
    tamanho: tamanho,
    cor: cor ?? kCorAvatarNeutra,
    emoji: emoji ?? kEmojiAvatarPadrao,
    corBorda: corBorda,
    larguraBorda: larguraBorda,
  );
}

/// Avatar circular com emoji, usado no chat, na lista de participantes, no
/// painel admin e no drawer.
///
/// Existe para os quatro lugares pararem de montar seu próprio `CircleAvatar`
/// com um fontSize escolhido no olho: cada um usava uma proporção diferente
/// entre círculo e emoji (13/28, 14/32, 16/32, 20/52), então o mesmo avatar
/// aparecia com pesos visuais diferentes dependendo da tela.
class AvatarEmoji extends StatelessWidget {
  /// Diâmetro do círculo.
  final double tamanho;
  final Color cor;
  final String emoji;

  /// Borda opcional ao redor do círculo (usada no drawer e na seleção).
  final Color? corBorda;
  final double larguraBorda;

  const AvatarEmoji({
    super.key,
    required this.tamanho,
    required this.cor,
    required this.emoji,
    this.corBorda,
    this.larguraBorda = 2,
  });

  @override
  Widget build(BuildContext context) {
    // 0.58 do diâmetro deixa uma margem visual constante entre o emoji e a
    // borda do círculo em qualquer tamanho.
    final tamanhoEmoji = tamanho * 0.58;

    return Container(
      width: tamanho,
      height: tamanho,
      decoration: BoxDecoration(
        color: cor,
        shape: BoxShape.circle,
        border: corBorda != null
            ? Border.all(color: corBorda!, width: larguraBorda)
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        emoji,
        textAlign: TextAlign.center,
        // height: 1 e o textHeightBehavior descartando as métricas de linha
        // são o que centraliza o emoji de fato. Sem isso o Text reserva o
        // leading da fonte acima e abaixo do glifo, e como esse espaço é
        // assimétrico o emoji assenta uns 2px acima do centro do círculo —
        // sutil isolado, mas visível numa coluna de avatares empilhados.
        textHeightBehavior: const TextHeightBehavior(
          applyHeightToFirstAscent: false,
          applyHeightToLastDescent: false,
        ),
        style: TextStyle(fontSize: tamanhoEmoji, height: 1),
      ),
    );
  }
}
