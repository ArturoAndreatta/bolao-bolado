import 'package:bolao_bolado/components/shared/avatar_emoji.dart';
import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/core/app_radii.dart';
import 'package:bolao_bolado/services/chat/emoji_reacao.dart';
import 'package:flutter/material.dart';

/// Uma pessoa na lista de quem reagiu.
typedef ReacaoDe = ({String uid, String nome, String emoji, bool souEu});

/// Ordena o mapa `{uid: emoji}` do jeito que a tela mostra.
///
/// Agrupa por emoji na mesma ordem dos chips (as reações rápidas primeiro, na
/// ordem da barra, depois as vindas do catálogo) e, dentro do grupo, coloca
/// VOCÊ na frente e o resto em ordem alfabética. Alfabética e não ordem de
/// chegada porque o mapa do Firestore não guarda quando cada reação entrou —
/// sem um critério fixo a lista trocaria de ordem a cada abertura.
List<ReacaoDe> ordenarReacoes({
  required Map<String, String> reacoes,
  required String? uidAtual,
  required String Function(String uid) nomeDe,
}) {
  final emojis = <String>[
    for (final emoji in kReacoesRapidas)
      if (reacoes.containsValue(emoji)) emoji,
    for (final emoji in reacoes.values)
      if (!kReacoesRapidas.contains(emoji)) emoji,
  ];

  final vistos = <String>{};
  final resultado = <ReacaoDe>[];
  for (final emoji in emojis) {
    if (!vistos.add(emoji)) continue;

    final doGrupo =
        <ReacaoDe>[
          for (final entrada in reacoes.entries)
            if (entrada.value == emoji)
              (
                uid: entrada.key,
                nome: nomeDe(entrada.key),
                emoji: emoji,
                souEu: entrada.key == uidAtual,
              ),
        ]..sort((a, b) {
          if (a.souEu != b.souEu) return a.souEu ? -1 : 1;
          return a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
        });
    resultado.addAll(doGrupo);
  }
  return resultado;
}

/// Resumo curto para o tooltip do chip: "Ana, Bruno e mais 3".
///
/// Corta em três nomes porque o tooltip é uma linha só — a lista inteira sai
/// na folha, que é para onde o toque leva.
String resumoQuemReagiu(List<String> nomes) {
  if (nomes.isEmpty) return '';
  if (nomes.length == 1) return nomes.first;
  if (nomes.length == 2) return '${nomes[0]} e ${nomes[1]}';
  if (nomes.length == 3) return '${nomes[0]}, ${nomes[1]} e ${nomes[2]}';
  return '${nomes[0]}, ${nomes[1]} e mais ${nomes.length - 2}';
}

/// Abre a folha com todo mundo que reagiu na mensagem.
///
/// Chega-se aqui por três caminhos, porque o toque simples no chip é o atalho
/// para REAGIR e não podia ser gasto com isto: toque longo no chip, item
/// "Quem reagiu" no menu de ações, e — no desktop — o tooltip do chip já
/// responde sem abrir nada. O item de menu existe justamente porque toque
/// longo é um gesto que ninguém descobre sozinho.
Future<void> mostrarQuemReagiu(
  BuildContext context, {
  required Map<String, String> reacoes,
  required String? uidAtual,
  required String Function(String uid) nomeDe,
  required VoidCallback onRemoverMinha,
}) {
  final linhas = ordenarReacoes(
    reacoes: reacoes,
    uidAtual: uidAtual,
    nomeDe: nomeDe,
  );

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    constraints: const BoxConstraints(maxWidth: 440),
    builder: (contextoFolha) => _FolhaQuemReagiu(
      linhas: linhas,
      onRemoverMinha: () {
        Navigator.of(contextoFolha).pop();
        onRemoverMinha();
      },
    ),
  );
}

class _FolhaQuemReagiu extends StatelessWidget {
  final List<ReacaoDe> linhas;
  final VoidCallback onRemoverMinha;

  const _FolhaQuemReagiu({required this.linhas, required this.onRemoverMinha});

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);

    return Container(
      // Encolhe até o conteúdo: com três reações a folha não precisa ocupar
      // meia tela. O teto evita que uma sala cheia empurre o cabeçalho para
      // fora.
      constraints: const BoxConstraints(maxHeight: 420),
      decoration: BoxDecoration(
        color: cores.card,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadii.xxl),
        ),
        border: Border.all(color: cores.borda),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Row(
              children: [
                Text(
                  'Quem reagiu',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: cores.texto,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${linhas.length}',
                  style: TextStyle(fontSize: 13, color: cores.textoFraco),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: cores.borda),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: linhas.length,
              itemBuilder: (context, i) => _Linha(
                dados: linhas[i],
                onRemover: linhas[i].souEu ? onRemoverMinha : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Linha extends StatelessWidget {
  final ReacaoDe dados;

  /// Só a SUA linha é tocável, e o que ela faz é remover a sua reação.
  final VoidCallback? onRemover;

  const _Linha({required this.dados, required this.onRemover});

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);

    return InkWell(
      onTap: onRemover,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            AvatarDoParticipante(uid: dados.uid, tamanho: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dados.nome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: dados.souEu
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: cores.texto,
                    ),
                  ),
                  if (dados.souEu)
                    Text(
                      'Toque para remover',
                      style: TextStyle(fontSize: 11, color: cores.textoFraco),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(dados.emoji, style: const TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}
