import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/core/app_radii.dart';
import 'package:bolao_bolado/services/chat/emoji_reacao.dart';
import 'package:flutter/material.dart';

/// A pílula flutuante que aparece sobre a bolha: reações rápidas, "mais
/// emojis" e o acesso às ações da mensagem.
///
/// Ela é o ÚNICO ponto de entrada das ações da mensagem no toque. Antes tudo
/// vivia num menu de contexto que só abria por toque longo ou botão direito —
/// dois gestos que ninguém tenta num chat sem alguém mostrar antes, e no mobile
/// o toque longo ainda disputa com a seleção de texto. Reagir passou a ter uma
/// afordância visível, e as ações menos usadas (copiar, fixar, apagar) ficaram
/// atrás do "⋯" em vez de na frente.
class BarraReacoes extends StatelessWidget {
  /// Emoji com que ESTE usuário já reagiu, para marcá-lo na fileira.
  final String? reacaoAtual;

  final void Function(String emoji) onEscolher;

  /// Abre o seletor com o catálogo completo.
  final VoidCallback onMais;

  /// Abre o menu de ações (copiar/fixar/apagar).
  final VoidCallback onAcoes;

  const BarraReacoes({
    super.key,
    required this.reacaoAtual,
    required this.onEscolher,
    required this.onMais,
    required this.onAcoes,
  });

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);

    return Material(
      color: cores.superficieAlta,
      elevation: 4,
      shadowColor: cores.sombra,
      borderRadius: AppRadii.circularPill,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: AppRadii.circularPill,
          border: Border.all(color: cores.borda),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final emoji in kReacoesRapidas)
              _Botao(
                marcado: reacaoAtual == emoji,
                onTap: () => onEscolher(emoji),
                child: Text(emoji, style: const TextStyle(fontSize: 19)),
              ),
            // A reação atual pode não estar entre as rápidas (veio do
            // catálogo). Sem este slot, o emoji escolhido some da barra e o
            // único jeito de desfazer vira o chip de baixo — parece que a
            // reação não pegou.
            if (reacaoAtual != null && !kReacoesRapidas.contains(reacaoAtual))
              _Botao(
                marcado: true,
                onTap: () => onEscolher(reacaoAtual!),
                child: Text(reacaoAtual!, style: const TextStyle(fontSize: 19)),
              ),
            _divisor(cores),
            // Sem tooltip nestes dois. A barra já flutua POR CIMA da conversa,
            // então o balão do tooltip caía bem em cima da mensagem que se
            // está lendo — atrapalhava mais do que explicava, e os dois ícones
            // são convenção de chat.
            _Botao(
              marcado: false,
              onTap: onMais,
              child: Icon(
                Icons.add_reaction_outlined,
                size: 18,
                color: cores.textoSuave,
              ),
            ),
            _Botao(
              marcado: false,
              onTap: onAcoes,
              child: Icon(
                Icons.more_horiz_rounded,
                size: 18,
                color: cores.textoSuave,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divisor(AppCores cores) => Container(
    width: 1,
    height: 20,
    margin: const EdgeInsets.symmetric(horizontal: 2),
    color: cores.borda,
  );
}

class _Botao extends StatelessWidget {
  final Widget child;
  final bool marcado;
  final VoidCallback onTap;

  const _Botao({
    required this.child,
    required this.marcado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        // 34px: aperta um pouco o alvo de toque recomendado para a barra caber
        // na largura de um celular com oito posições. O alvo real é maior que
        // isto, porque o InkWell herda o padding vertical da pílula.
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: marcado ? cores.fundoAzul : Colors.transparent,
        ),
        child: child,
      ),
    );
  }
}
