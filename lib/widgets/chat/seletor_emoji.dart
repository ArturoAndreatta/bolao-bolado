import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/core/app_radii.dart';
import 'package:bolao_bolado/services/chat/emoji_reacao.dart';
import 'package:flutter/material.dart';

/// Abre o seletor de emoji e devolve o escolhido (null se fechou sem escolher).
///
/// Folha inferior nos dois formatos, com largura travada em 440: no mobile ela
/// sobe da borda como se espera, e no desktop a mesma folha fica centrada e
/// estreita em vez de virar uma faixa de ponta a ponta. Um diálogo próprio só
/// para telas largas duplicaria a montagem da grade sem mudar nada do uso.
Future<String?> escolherEmoji(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    constraints: const BoxConstraints(maxWidth: 440),
    builder: (_) => const _FolhaEmoji(),
  );
}

class _FolhaEmoji extends StatefulWidget {
  const _FolhaEmoji();

  @override
  State<_FolhaEmoji> createState() => _FolhaEmojiState();
}

class _FolhaEmojiState extends State<_FolhaEmoji> {
  int _categoria = 0;

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    final categoria = kCatalogoEmoji[_categoria];

    return Container(
      height: 380,
      decoration: BoxDecoration(
        color: cores.card,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadii.xxl),
        ),
        border: Border.all(color: cores.borda),
      ),
      child: Column(
        children: [
          // Puxador: a folha é arrastável, e sem a alça isso não se comunica.
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cores.borda,
                borderRadius: AppRadii.circularPill,
              ),
            ),
          ),
          _abas(cores),
          Divider(height: 1, color: cores.borda),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              // Extensão fixa em vez de contagem de colunas: a folha vai de
              // 320 a 440 de largura, e travar o número de colunas mudaria o
              // TAMANHO do emoji junto com a tela.
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 44,
              ),
              itemCount: categoria.emojis.length,
              itemBuilder: (context, i) {
                final emoji = categoria.emojis[i];
                return InkWell(
                  onTap: () => Navigator.of(context).pop(emoji),
                  customBorder: const CircleBorder(),
                  child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 24)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _abas(AppCores cores) {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        itemCount: kCatalogoEmoji.length,
        itemBuilder: (context, i) {
          final ativa = i == _categoria;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
            child: Tooltip(
              message: kCatalogoEmoji[i].rotulo,
              child: InkWell(
                onTap: () => setState(() => _categoria = i),
                borderRadius: AppRadii.circularSm,
                child: Container(
                  width: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: ativa ? cores.fundoAzul : Colors.transparent,
                    borderRadius: AppRadii.circularSm,
                  ),
                  child: Text(
                    kCatalogoEmoji[i].icone,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
