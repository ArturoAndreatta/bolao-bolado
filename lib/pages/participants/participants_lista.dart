import 'package:bolao_bolado/components/formatters/formatters.dart';
import 'package:bolao_bolado/components/shared/avatar_emoji.dart';
import 'package:bolao_bolado/components/shared/selo_manual.dart';
import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/pages/participants/participants_reordenacao.dart';
import 'package:bolao_bolado/pages/participants/participants_tabela.dart'
    show LinhaEntrandoAnimada;
import 'package:bolao_bolado/services/avatar/avatar_service.dart';
import 'package:flutter/material.dart';

/// Altura de uma linha da lista mobile, incluindo o divisor.
///
/// É constante — e não decidida pelo conteúdo — pelo mesmo motivo da tabela
/// desktop ([kAlturaLinhaTabela] em participants_tabela.dart): o corpo usa
/// `ListView.builder` com `itemExtent`, o que exige altura uniforme para
/// montar só as linhas visíveis (em vez de todas de uma vez, que é o que
/// deixava 1000 apostas lentas no mobile) e para o deslize de reordenação
/// calcular a distância certa por índice.
///
/// Isso significa que o NOME nunca quebra linha aqui — antes podia ocupar
/// duas linhas com nome comprido; agora corta com reticências, igual já
/// acontecia na tabela desktop. É a mesma concessão feita lá, pelo mesmo
/// motivo.
///
/// O valor foi MEDIDO (ver test/pages/participants/altura_linha_lista_test.dart),
/// não deduzido: título (14sp) + subtítulo do prêmio (11.5sp) + os espaçamentos
/// entre eles + padding vertical 12 dos dois lados (63) + 1 do divisor.
const double kAlturaLinhaLista = 64;

const List<Color> coresAvatar = [
  Color(0xFF2E7D32),
  Color(0xFF487DE5),
  Color(0xFF7C5CD9),
  Color(0xFFCB8A2C),
  Color(0xFFD9534F),
  Color(0xFF17A398),
];

// Deriva cor determinística a partir do nome (mesmo participante = mesma cor sempre)
Color corAvatarPara(String nome) {
  final soma = nome.codeUnits.fold<int>(0, (acc, c) => acc + c);
  return coresAvatar[soma % coresAvatar.length];
}

// Deriva emoji determinístico a partir do nome (mesmo participante = mesmo emoji sempre)
String emojiAvatarPara(String nome) {
  final soma = nome.codeUnits.fold<int>(0, (acc, c) => acc + c);
  return kEmojisAvatar[soma % kEmojisAvatar.length];
}

class ListaParticipantes extends StatefulWidget {
  final List<Map<String, dynamic>> rows;
  final String? currentUid;

  /// Lista completa (sem filtro de busca), usada só para podar o registro de
  /// linhas já vistas. Ver [TabelaApostas.rowsCompletas].
  final List<Map<String, dynamic>>? rowsCompletas;

  /// Quando `true`, a lista NÃO rola por conta própria: usa `shrinkWrap` e
  /// cede o scroll para um `SingleChildScrollView` ancestral.
  ///
  /// É o modo usado só quando o chamador não tem uma altura definida para
  /// oferecer (`alturaMobile == null` em participants_painel.dart) — um caso
  /// hoje sem uso real na tela de Participantes, mas mantido para outros
  /// consumidores do widget.
  ///
  /// **Custa a reciclagem.** Com `shrinkWrap`, o `ListView.builder` constrói
  /// TODOS os itens para medir a altura total, mesmo com `itemExtent` — é a
  /// viewport finita do próprio ListView que permite montar só o visível, e
  /// `shrinkWrap` abre mão dela. Era assim que 1000 apostas travavam o
  /// mobile mesmo depois de ganhar `itemExtent`: a reciclagem nunca chegava
  /// a acontecer porque a lista sempre estava neste modo.
  final bool semScrollProprio;

  const ListaParticipantes({
    super.key,
    required this.rows,
    required this.currentUid,
    this.rowsCompletas,
    this.semScrollProprio = false,
  });

  @override
  State<ListaParticipantes> createState() => _ListaParticipantesState();
}

class _ListaParticipantesState extends State<ListaParticipantes> {
  // Junta os três pedaços de estado que a entrada/reordenação precisam
  // (valores conhecidos, índices anteriores, deslocamentos do build atual).
  // Mesmo mecanismo usado em _TabelaApostasState (desktop), extraído porque
  // as duas telas repetiam campo por campo.
  final RastreadorDeLinhas _rastreador = RastreadorDeLinhas();

  @override
  Widget build(BuildContext context) {
    final rows = widget.rows;

    // A ordem é registrada no build, ANTES do layout: o deslocamento já sai
    // pronto no mesmo quadro em que a linha muda de lugar.
    _rastreador.registrarBuild(
      rowsCompletas: widget.rowsCompletas ?? rows,
      chavesEmOrdem: [
        for (var i = 0; i < rows.length; i++)
          rows[i]['uid']?.toString() ?? 'linha-$i',
      ],
    );

    // ListView.builder monta só as linhas visíveis (~10-15 de uma tela),
    // não as N da sala inteira — DESDE QUE ele tenha viewport própria, isto
    // é, `semScrollProprio: false` (o padrão). Com 1000 apostas o Column
    // anterior mantinha 1000 linhas vivas e as reconstruía a cada emissão do
    // Firestore; era esse custo, e não a animação em si, que travava o
    // mobile. Ver a doc de [ListaParticipantes.semScrollProprio].
    return ListView.builder(
      shrinkWrap: widget.semScrollProprio,
      physics: widget.semScrollProprio
          ? const NeverScrollableScrollPhysics()
          : null,
      itemExtent: kAlturaLinhaLista,
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final item = rows[index];
        final chave = item['uid']?.toString() ?? 'linha-$index';
        final uid = item['uid']?.toString();
        final valorAtual = item['valor'];
        final isNova = _rastreador.isNovaOuAlterada(uid, valorAtual);
        final andou = _rastreador.deslocamentoDe(chave);

        return LinhaDeslizante(
          // A chave vai aqui, não no filho: é o que faz o ListView (e o
          // deslize) acompanharem a LINHA, não a posição na lista.
          key: ValueKey(chave),
          deslocamento: andou * kAlturaLinhaLista,
          child: LinhaEntrandoAnimada(
            animar: isNova,
            corBase: Colors.transparent,
            // Igual à tabela desktop: dentro da grade de altura fixa, a
            // chegada é encenada por dentro (o conteúdo desliza atrás de um
            // recorte) em vez de abrir espaço de verdade — o ListView já
            // reservou a linha inteira, então abrir espaço não produziria
            // nada visível.
            reservaAlturaFixa: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinhaParticipante(
                  nome: item['nome']?.toString() ?? '—',
                  valor: Formatters.moeda.format(
                    (item['valor'] as num?)?.toDouble() ?? 0,
                  ),
                  cotas: (item['cotas'] as num?)?.toInt() ?? 0,
                  premio: Formatters.moeda.format(
                    (item['premio'] as num?)?.toDouble() ?? 0,
                  ),
                  uid: uid,
                  corAvatar: (item['avatarColor'] as int?) != null
                      ? Color(item['avatarColor'] as int)
                      : null,
                  emojiAvatar: item['avatarEmoji']?.toString(),
                  destacado: item['uid'] == widget.currentUid,
                  verificado: item['verificado'] == true,
                  alterada: item['editadoAposVerificacao'] == true,
                  manual: item['criadoPeloAdmin'] == true,
                ),
                // O divisor entra DENTRO da linha (não como irmão dela) para
                // caber na altura fixa reservada pelo itemExtent, e some na
                // última para não sobrar borda dupla contra o rodapé.
                if (index < rows.length - 1)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: AppCores.de(context).borda,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class LinhaParticipante extends StatelessWidget {
  final String nome;
  final String valor;
  final int cotas;
  final String premio;

  /// Uid do participante, usado para resolver o avatar sob demanda. Nulo em
  /// aposta manual lançada pelo admin, que não tem usuário por trás — aí o
  /// avatar cai no derivado do nome.
  final String? uid;

  final Color? corAvatar;
  final String? emojiAvatar;
  final bool destacado;
  final bool verificado;
  final bool alterada;
  final bool manual;

  const LinhaParticipante({
    super.key,
    required this.nome,
    required this.valor,
    required this.cotas,
    required this.premio,
    this.uid,
    this.corAvatar,
    this.emojiAvatar,
    required this.destacado,
    this.verificado = false,
    this.alterada = false,
    this.manual = false,
  });

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    // Fallback derivado do nome só serve para aposta manual (sem uid, nunca
    // vai existir doc de avatar real). Com uid, aplicar aqui um fallback que
    // não bate com o avatar de verdade fazia o ícone da linha nova NASCER
    // errado e TROCAR assim que o doc do Firestore chegasse — bem no momento
    // em que a animação de entrada chama atenção para o avatar. Nesse caso é
    // melhor deixar `AvatarDoParticipante` usar o próprio neutro enquanto
    // espera, sem "chute" divergente.
    final emoji = emojiAvatar ?? (uid == null ? emojiAvatarPara(nome) : null);
    final cor = corAvatar ?? (uid == null ? corAvatarPara(nome) : null);
    final temEstado = alterada || verificado || destacado;

    // Prioridade visual: edição pós-verificação > verificado/destacado.
    //
    // No claro o estado é o fundo pastel da linha; no escuro esse mesmo
    // fundo, traduzido para tom escuro, empilhava blocos de cor na lista
    // toda — lá o fundo fica transparente e o estado vira a barra lateral
    // (mesma decisão da tabela desktop, ver TabelaApostas.corBarraEstado).
    final corEstado = alterada ? cores.dourado : cores.verde;
    final usaBarra = cores.larguraBarraEstado > 0;
    final corFundo = !temEstado || usaBarra
        ? Colors.transparent
        : (alterada ? cores.fundoAmarelo : cores.fundoVerde);

    return Container(
      color: corFundo,
      foregroundDecoration: (usaBarra && temEstado)
          ? BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: corEstado,
                  width: cores.larguraBarraEstado,
                ),
              ),
            )
          : null,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // O avatar se resolve sozinho a partir do uid, em vez de depender
          // de um pré-carregamento de todos os participantes da sala. As
          // cores derivadas do nome ficam como fallback: valem para aposta
          // manual (sem uid) e enquanto o documento não chega.
          AvatarDoParticipante(
            uid: uid,
            tamanho: 32,
            corFallback: cor,
            emojiFallback: emoji,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Flexible (não Expanded): o nome encolhe com reticências
                    // para o selo caber, em vez de empurrá-lo para fora.
                    Flexible(
                      child: Text(
                        nome,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: destacado
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: cores.texto,
                        ),
                      ),
                    ),
                    if (manual) ...[
                      const SizedBox(width: 6),
                      const SeloManual(),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.emoji_events_outlined,
                      size: 12,
                      color: cores.dourado,
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        premio,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: cores.textoAmarelo,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                valor,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: cores.textoVerde,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                cotas == 1 ? '1 cota' : '$cotas cotas',
                style: TextStyle(fontSize: 12, color: cores.textoFraco),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class RodapeLista extends StatelessWidget {
  final int total;
  final double valorTotal;
  final int cotasTotal;

  const RodapeLista({
    super.key,
    required this.total,
    required this.valorTotal,
    required this.cotasTotal,
  });

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Nessa largura o texto "X participantes" espreme o valor/cotas até
        // cortar; abaixo dela mostra só o ícone + número, sem o rótulo.
        final compacto = constraints.maxWidth < 265;

        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                '${Formatters.moeda.format(valorTotal)} | $cotasTotal Cotas',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: cores.textoFraco),
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.people_outline, size: 15, color: cores.textoFraco),
            const SizedBox(width: 6),
            Text(
              compacto
                  ? '$total'
                  : '$total ${total == 1 ? 'participante' : 'participantes'}',
              style: TextStyle(fontSize: 12, color: cores.textoFraco),
            ),
          ],
        );
      },
    );
  }
}
