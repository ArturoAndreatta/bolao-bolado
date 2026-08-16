import 'package:bolao_bolado/components/shared/buttons.dart';
import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/core/app_radii.dart';
import 'package:bolao_bolado/services/bet/jogos_aposta.dart';
import 'package:bolao_bolado/services/bet/preco_cota.dart';
import 'package:flutter/material.dart';

/// Modal onde o participante monta os próprios jogos, em vez de deixar a
/// escolha dos números por conta de quem compra os bilhetes.
///
/// O orçamento é o mesmo dinheiro já digitado no campo Valor, convertido em
/// COTAS: R$120 numa sala de Mega são 20 cotas. Cada jogo consome
/// [cotasDoJogo] cotas conforme o seu tamanho — um jogo de 6 custa 1 cota, um
/// de 7 custa 7, um de 8 custa 28 (é o preço oficial da Caixa, ver
/// preco_cota.dart). Assim o participante escolhe entre muitos jogos simples
/// e poucos jogos grandes com o mesmo dinheiro.
///
/// Sobrar cota é válido e não bloqueia nada: escolher números é opcional, e
/// sobra significa "o resto quem compra escolhe por mim". Só o EXCESSO (jogos
/// custando mais cotas do que foi apostado) trava a confirmação, porque aí a
/// aposta não teria como ser comprada.
///
/// Devolve a lista de jogos ao confirmar, ou `null` se o usuário cancelar.
/// Lista vazia é resultado válido: significa "apagar os jogos salvos".
Future<List<List<int>>?> mostrarSelecaoJogos(
  BuildContext context, {
  required String? sorteio,
  required int cotasDisponiveis,
  required List<List<int>> jogosIniciais,
}) {
  return showDialog<List<List<int>>>(
    context: context,
    builder: (context) => _SelecaoJogosDialog(
      sorteio: sorteio,
      cotasDisponiveis: cotasDisponiveis,
      jogosIniciais: jogosIniciais,
    ),
  );
}

/// Teto do modal. Vale como limite das duas telas e também como altura solta
/// da tela que sai durante a troca (ver o `layoutBuilder` do AnimatedSwitcher).
const double _alturaMaxima = 620;

class _SelecaoJogosDialog extends StatefulWidget {
  final String? sorteio;
  final int cotasDisponiveis;
  final List<List<int>> jogosIniciais;

  const _SelecaoJogosDialog({
    required this.sorteio,
    required this.cotasDisponiveis,
    required this.jogosIniciais,
  });

  @override
  State<_SelecaoJogosDialog> createState() => _SelecaoJogosDialogState();
}

/// Jogo aberto na grade de números. `indice` null = jogo novo, ainda não
/// adicionado à lista; caso contrário é a posição do jogo sendo editado.
class _JogoEmEdicao {
  _JogoEmEdicao({
    required this.indice,
    required this.tamanho,
    required this.numeros,
  });

  final int? indice;
  int tamanho;
  final Set<int> numeros;
}

class _SelecaoJogosDialogState extends State<_SelecaoJogosDialog> {
  late final List<List<int>> _jogos = widget.jogosIniciais
      .map((jogo) => [...jogo])
      .toList();

  /// Jogos que ainda devem ENTRAR animados na lista.
  ///
  /// Sem isto, toda volta da grade para a lista reconstruía o subárvore inteiro
  /// e as linhas ANTIGAS repipocavam em cascata junto com a nova — salvar um
  /// jogo parecia ter recriado a lista toda, em vez de acrescentado uma linha.
  ///
  /// Identidade por objeto (`Set.identity`), não por conteúdo: dois jogos com
  /// os mesmos números são linhas diferentes e não podem compartilhar estado.
  /// Sai do conjunto quando a entrada termina, então cada jogo anima uma vez
  /// só na vida do modal.
  late final Set<List<int>> _paraAnimar = Set<List<int>>.identity()
    ..addAll(_jogos);

  // Null = tela da lista de jogos; preenchido = grade de números aberta.
  _JogoEmEdicao? _edicao;

  // Sentido da última navegação entre as duas telas do modal, só para a
  // transição saber para que lado deslizar: entrando na grade o conteúdo vem
  // da direita, voltando para a lista vem da esquerda. Sem isso as duas
  // viradas seriam iguais e o "voltar" não pareceria voltar.
  bool _abrindoGrade = true;

  int get _tamanhoSimples => quantidadeNumerosPara(widget.sorteio);
  int get _numeroMaximo => numeroMaximoPara(widget.sorteio);

  int get _cotasUsadas => cotasDosJogos(_jogos, widget.sorteio);
  int get _cotasLivres => widget.cotasDisponiveis - _cotasUsadas;

  /// Orçamento disponível para o jogo aberto na grade: as cotas livres mais
  /// as que o próprio jogo já ocupava (senão editar um jogo de 7 nunca
  /// permitiria voltar a escolher 7 — as 7 cotas dele contariam como gastas).
  int get _orcamentoDaEdicao {
    final edicao = _edicao;
    if (edicao == null) return _cotasLivres;
    final indice = edicao.indice;
    final devolvidas = indice == null
        ? 0
        : cotasDoJogo(_jogos[indice].length, widget.sorteio);
    return _cotasLivres + devolvidas;
  }

  /// Tamanhos de jogo que cabem no orçamento atual, do simples até o teto da
  /// Caixa. Na prática o dinheiro corta bem antes de 20: um jogo de 9 na Mega
  /// já custa 84 cotas (R$504).
  List<int> get _tamanhosPossiveis {
    final orcamento = _orcamentoDaEdicao;
    return [
      for (var t = _tamanhoSimples; t <= kTamanhoMaximoJogo; t++)
        if (cotasDoJogo(t, widget.sorteio) <= orcamento) t,
    ];
  }

  /// Posição do jogo [indice] entre os que estão entrando agora — é o passo
  /// da cascata. Quem não está entrando não usa o valor.
  int _ordemDeEntrada(int indice) {
    var ordem = 0;
    for (var i = 0; i < indice; i++) {
      if (_paraAnimar.contains(_jogos[i])) ordem++;
    }
    return ordem;
  }

  void _abrirGrade({int? indice}) {
    setState(() {
      _abrindoGrade = true;
      final numeros = indice == null ? <int>[] : _jogos[indice];
      _edicao = _JogoEmEdicao(
        indice: indice,
        tamanho: numeros.isEmpty ? _tamanhoSimples : numeros.length,
        numeros: numeros.toSet(),
      );
    });
  }

  void _alternarNumero(int numero) {
    final edicao = _edicao!;
    setState(() {
      if (edicao.numeros.contains(numero)) {
        edicao.numeros.remove(numero);
      } else if (edicao.numeros.length < edicao.tamanho) {
        edicao.numeros.add(numero);
      }
    });
  }

  void _mudarTamanho(int tamanho) {
    final edicao = _edicao!;
    setState(() {
      edicao.tamanho = tamanho;
      // Diminuir o jogo com a cartela cheia deixaria a seleção acima do novo
      // limite: descarta os últimos marcados, mantendo os menores.
      if (edicao.numeros.length > tamanho) {
        final mantidos = (edicao.numeros.toList()..sort()).take(tamanho);
        edicao.numeros
          ..clear()
          ..addAll(mantidos);
      }
    });
  }

  /// Completa a cartela aberta com números sorteados.
  ///
  /// Com [refazer] falso, o que já estava marcado é preservado — o botão
  /// serve para terminar uma cartela começada na mão. Com a cartela já cheia
  /// não haveria o que completar, então aí ele vira "Refazer" e sorteia tudo
  /// de novo.
  void _surpresinha({bool refazer = false}) {
    final edicao = _edicao!;
    setState(() {
      final sorteados = sortearNumeros(
        tamanho: edicao.tamanho,
        numeroMaximo: _numeroMaximo,
        fixos: refazer ? const [] : edicao.numeros.toList(),
      );
      edicao.numeros
        ..clear()
        ..addAll(sorteados);
    });
  }

  void _salvarJogo() {
    final edicao = _edicao!;
    final numeros = edicao.numeros.toList()..sort();
    setState(() {
      _abrindoGrade = false;
      if (edicao.indice == null) {
        _jogos.add(numeros);
      } else {
        _jogos[edicao.indice!] = numeros;
      }
      // Vale também para EDIÇÃO: `numeros` é objeto novo, e a linha que mudou
      // reentrar é o retorno visual de que a alteração pegou.
      _paraAnimar.add(numeros);
      _edicao = null;
    });
  }

  void _sortearRestante(EstiloSorteio estilo) {
    setState(() {
      final completos = sortearJogosRestantes(
        jogosAtuais: _jogos,
        cotasDisponiveis: widget.cotasDisponiveis,
        sorteio: widget.sorteio,
        estilo: estilo,
      );
      // Só os jogos RECÉM-criados entram animados — é a cascata deles que
      // mostra quantos foram gerados. Os que já estavam na lista continuam
      // parados, senão a tela inteira pipoca e o ganho some no meio.
      final jaExistiam = Set<List<int>>.identity()..addAll(_jogos);
      _paraAnimar.addAll(completos.where((j) => !jaExistiam.contains(j)));
      _jogos
        ..clear()
        ..addAll(completos);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);

    return Dialog(
      backgroundColor: cores.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.circularXxl,
        side: BorderSide(color: cores.borda, width: 1),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 460,
          maxHeight: _alturaMaxima,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          // As duas telas têm alturas bem diferentes (a lista vazia é curta, a
          // grade da Lotofácil é alta). Sem o AnimatedSize o modal saltava de
          // tamanho no mesmo frame da troca, e o salto chamava mais atenção do
          // que o conteúdo novo.
          child: AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              // Duas correções ao layout padrão:
              //
              // 1. O padrão empilha os filhos CENTRALIZADOS, o que durante a
              //    troca desalinha o título da tela que entra. Alinhados pelo
              //    topo, os dois cabeçalhos ficam no mesmo lugar e só o corpo
              //    desliza.
              // 2. Só a tela que ENTRA dita o tamanho da pilha. No padrão as
              //    duas dimensionam o Stack, que então reporta sempre a MAIOR
              //    das alturas: ABRIR a grade já dava a altura final no
              //    primeiro frame e o AnimatedSize crescia junto com o
              //    deslize, mas VOLTAR mantinha a caixa alta pelos 220ms da
              //    troca e só encolhia depois — o mesmo movimento em ordens
              //    diferentes, e o fechamento lia como uma segunda animação
              //    em vez do inverso da abertura. Fora do fluxo, o alvo do
              //    AnimatedSize muda no frame do toque nos dois sentidos.
              //
              // O `OverflowBox` existe porque `Positioned.fill` sozinho impõe
              // à tela que sai a altura da que entra: esticada (indo para a
              // grade) o rodapé de botões da lista desceria até o fim da tela
              // nova, e espremida (voltando) a grade estoura em RenderFlex —
              // os pedaços fixos dela (título, chips, dois rodapés) não cabem
              // na altura da lista. Solto até `_alturaMaxima` e preso ao topo,
              // ele mantém a altura natural; quem recorta o excedente é o
              // `clipBehavior` do próprio AnimatedSize, e nesse ponto a tela
              // que sai já está quase invisível.
              layoutBuilder: (atual, anteriores) => Stack(
                alignment: Alignment.topCenter,
                children: [
                  for (final anterior in anteriores)
                    Positioned.fill(
                      child: OverflowBox(
                        alignment: Alignment.topCenter,
                        minHeight: 0,
                        maxHeight: _alturaMaxima,
                        child: anterior,
                      ),
                    ),
                  if (atual != null) atual,
                ],
              ),
              transitionBuilder: _transicaoEntreTelas,
              child: KeyedSubtree(
                key: ValueKey(_edicao == null ? 'lista' : 'grade'),
                child: _edicao == null
                    ? _buildLista(cores)
                    : _buildGrade(cores),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Deslize horizontal curto (12% da largura) + fade entre a lista e a grade.
  ///
  /// Curto de propósito: é navegação DENTRO de um modal de 460px, então o
  /// gesto de página cheia ficaria exagerado — o suficiente para o olho
  /// entender que uma tela deu lugar à outra, e não que os textos trocaram.
  Widget _transicaoEntreTelas(Widget child, Animation<double> animacao) {
    final entrando = child.key == ValueKey(_edicao == null ? 'lista' : 'grade');
    final sentido = _abrindoGrade ? 1.0 : -1.0;
    final inicio = Offset(0.12 * sentido * (entrando ? 1 : -1), 0);

    return FadeTransition(
      // Fade em DOIS TEMPOS, e não cruzado: a tela que sai some antes de a que
      // entra aparecer. Cruzando as duas, as linhas de jogo — que têm fundo
      // próprio (`cores.campo`) — continuavam pintadas ATRÁS da grade durante
      // os 220ms, e liam como uma caixa cinza atravessada nos números, que
      // some sozinha. Com o intervalo, quem sai zera antes de o outro nascer.
      //
      // `drive` e não CurvedAnimation: isto roda a cada build da transição, e
      // uma CurvedAnimation por build precisaria ser descartada uma a uma.
      opacity: animacao.drive(CurveTween(curve: const Interval(0.55, 1))),
      child: SlideTransition(
        position: Tween(begin: inicio, end: Offset.zero).animate(animacao),
        child: child,
      ),
    );
  }

  // ── Tela 1: lista dos jogos montados ───────────────────────────────────
  Widget _buildLista(AppCores cores) {
    final excedente = _cotasLivres < 0 ? -_cotasLivres : 0;
    final cabeJogoNovo =
        _cotasLivres >= 1 && _jogos.length < kMaximoJogosPorAposta;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Titulo(
          texto: 'Meus jogos',
          // Subtítulo só no caso em que a tela não se explica sozinha: sem
          // valor apostado não há cota, e os dois botões nascem desabilitados
          // sem motivo aparente.
          subtitulo: widget.cotasDisponiveis == 0
              ? 'Informe um valor para liberar as cotas'
              : null,
          cores: cores,
        ),
        // A faixa de excesso aparece e some conforme se adiciona ou remove
        // jogo. Entrando de supetão ela empurrava a lista inteira para baixo
        // no mesmo frame, e o usuário perdia de vista a linha que acabou de
        // tocar.
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: excedente > 0
              ? Padding(
                  key: const ValueKey('aviso'),
                  padding: const EdgeInsets.only(top: 12),
                  child: _AvisoExcedente(cores: cores, excedente: excedente),
                )
              : const SizedBox(
                  key: ValueKey('sem-aviso'),
                  width: double.infinity,
                ),
        ),
        const SizedBox(height: 12),
        Flexible(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _jogos.isEmpty
                ? _VazioJogos(key: const ValueKey('vazio'), cores: cores)
                : ListView.separated(
                    key: const ValueKey('lista-jogos'),
                    shrinkWrap: true,
                    itemCount: _jogos.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final jogo = _jogos[i];
                      final novo = _paraAnimar.contains(jogo);
                      return _EntradaSuave(
                        // Chave pela IDENTIDADE do jogo, não pelo índice:
                        // remover uma linha do meio desloca todas as de baixo,
                        // e com chave por índice o estado de animação de uma
                        // linha passaria para a vizinha.
                        key: ValueKey(identityHashCode(jogo)),
                        animar: novo,
                        // Escalonado entre os NOVOS: "Sortear resto" cria
                        // vários de uma vez, e a cascata mostra quantos foram
                        // criados. Conta só os que animam — com o índice cru,
                        // salvar o 8º jogo daria a ele 210ms de espera parado.
                        atraso: Duration(
                          milliseconds: 35 * _ordemDeEntrada(i).clamp(0, 6),
                        ),
                        onEntrou: () => _paraAnimar.remove(jogo),
                        child: _LinhaJogo(
                          posicao: i + 1,
                          numeros: jogo,
                          onEditar: () => _abrirGrade(indice: i),
                          onRemover: () => setState(() => _jogos.removeAt(i)),
                        ),
                      );
                    },
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _BotaoSecundario(
                icone: Icons.add,
                texto: 'Jogo',
                habilitado: cabeJogoNovo,
                onTap: () => _abrirGrade(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MenuSortearResto(
                cotas: _cotasLivres,
                sorteio: widget.sorteio,
                habilitado: cabeJogoNovo,
                onEscolher: _sortearRestante,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (_jogos.isNotEmpty)
              TextButton(
                onPressed: () => setState(_jogos.clear),
                child: Text(
                  'Limpar',
                  style: TextStyle(color: cores.textoSuave),
                ),
              ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancelar',
                style: TextStyle(color: cores.textoSuave),
              ),
            ),
            const SizedBox(width: 8),
            // Excesso trava: uma aposta com jogos custando mais do que foi
            // pago não tem como ser comprada. Sobra, ao contrário, passa.
            _BotaoPrincipal(
              texto: 'Confirmar',
              habilitado: excedente == 0,
              onTap: () => Navigator.of(context).pop(_jogos),
            ),
          ],
        ),
      ],
    );
  }

  // ── Tela 2: grade de números de UM jogo ────────────────────────────────
  Widget _buildGrade(AppCores cores) {
    final edicao = _edicao!;
    final completo = edicao.numeros.length == edicao.tamanho;
    final tamanhos = _tamanhosPossiveis;
    final custo = cotasDoJogo(edicao.tamanho, widget.sorteio);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Titulo(
          texto: edicao.indice == null ? 'Novo jogo' : 'Editar jogo',
          subtitulo:
              '${edicao.numeros.length} de ${edicao.tamanho} '
              '· $custo ${custo == 1 ? 'cota' : 'cotas'}',
          subtituloDestacado: completo,
          cores: cores,
        ),
        const SizedBox(height: 12),
        // Tamanho do jogo. Só aparecem os tamanhos que cabem no orçamento —
        // o de 8 na Mega (28 cotas) some de uma aposta de R$60.
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: tamanhos.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (context, i) {
              final tamanho = tamanhos[i];
              return _ChipTamanho(
                tamanho: tamanho,
                selecionado: tamanho == edicao.tamanho,
                onTap: () => _mudarTamanho(tamanho),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Flexible(
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_numeroMaximo, (i) {
                final numero = i + 1;
                return _BolaNumero(
                  numero: numero,
                  selecionado: edicao.numeros.contains(numero),
                  onTap: () => _alternarNumero(numero),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _BotaoSecundario(
                icone: Icons.auto_awesome,
                texto: completo ? 'Refazer' : 'Surpresinha',
                onTap: () => _surpresinha(refazer: completo),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _BotaoSecundario(
                icone: Icons.backspace_outlined,
                texto: 'Limpar',
                habilitado: edicao.numeros.isNotEmpty,
                onTap: () => setState(edicao.numeros.clear),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Spacer(),
            TextButton(
              onPressed: () => setState(() {
                _abrindoGrade = false;
                _edicao = null;
              }),
              child: Text('Voltar', style: TextStyle(color: cores.textoSuave)),
            ),
            const SizedBox(width: 8),
            _BotaoPrincipal(
              texto: 'Salvar jogo',
              habilitado: completo,
              onTap: _salvarJogo,
            ),
          ],
        ),
      ],
    );
  }
}

/// CTA do modal. [PrimaryButton] não tem estado desabilitado próprio (o
/// `loading` dele serve a outra coisa), então o bloqueio é feito aqui: o
/// toque é ignorado e a opacidade sinaliza o motivo — cartela incompleta na
/// grade, jogos acima do orçamento na lista.
class _BotaoPrincipal extends StatelessWidget {
  final String texto;
  final bool habilitado;
  final VoidCallback onTap;

  const _BotaoPrincipal({
    required this.texto,
    required this.habilitado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: habilitado ? 1 : 0.45,
      child: IgnorePointer(
        ignoring: !habilitado,
        child: PrimaryButton(
          text: texto,
          width: 130,
          compact: true,
          onTap: onTap,
        ),
      ),
    );
  }
}

class _Titulo extends StatelessWidget {
  final String texto;
  final String? subtitulo;
  final bool subtituloDestacado;
  final AppCores cores;

  const _Titulo({
    required this.texto,
    required this.subtitulo,
    required this.cores,
    this.subtituloDestacado = false,
  });

  @override
  Widget build(BuildContext context) {
    final subtitulo = this.subtitulo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          texto,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: cores.texto,
          ),
        ),
        if (subtitulo != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitulo,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: subtituloDestacado ? cores.verde : cores.textoSuave,
            ),
          ),
        ],
      ],
    );
  }
}

/// Aviso do único estado que impede confirmar: jogos custando mais cotas do
/// que o valor apostado compra.
///
/// Sobra NÃO tem faixa: é o caso normal (escolher números é opcional) e a
/// contagem no subtítulo já diz quanto sobrou. Uma tarja permanente para
/// dizer "está tudo certo" ocupa a altura da lista de jogos sem informar
/// nada que o contador não informe.
class _AvisoExcedente extends StatelessWidget {
  final AppCores cores;
  final int excedente;

  const _AvisoExcedente({required this.cores, required this.excedente});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cores.fundoVermelho,
        borderRadius: AppRadii.circularMd,
        border: Border.all(color: cores.bordaVermelho),
      ),
      child: Text(
        'Seus jogos passam $excedente ${excedente == 1 ? 'cota' : 'cotas'} '
        'do valor apostado. Remova algum para confirmar.',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: cores.vermelho,
        ),
      ),
    );
  }
}

/// Entrada de um item que acabou de nascer na tela: sobe 10px enquanto
/// aparece.
///
/// Existe porque a lista de jogos ganha linhas de duas maneiras muito
/// diferentes — uma por vez (montada na mão) ou dez de uma vez ("Sortear
/// resto") —, e no segundo caso o aparecimento instantâneo lia como a tela
/// ter sido trocada, não preenchida.
///
/// Só a ENTRADA é animada. Remover continua imediato: quem toca no X quer a
/// linha fora, e segurar o que foi descartado por 200ms é o tipo de enfeite
/// que atrapalha.
class _EntradaSuave extends StatefulWidget {
  final Widget child;
  final Duration atraso;

  /// Falso = já está na tela desde antes; aparece pronto, sem animar.
  final bool animar;

  /// Chamado quando a entrada termina, para o dono marcar o jogo como já
  /// mostrado — é o que impede a linha de reanimar na próxima volta da grade.
  final VoidCallback? onEntrou;

  const _EntradaSuave({
    required super.key,
    required this.child,
    this.atraso = Duration.zero,
    this.animar = true,
    this.onEntrou,
  });

  @override
  State<_EntradaSuave> createState() => _EntradaSuaveState();
}

class _EntradaSuaveState extends State<_EntradaSuave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controlador = AnimationController(
    duration: const Duration(milliseconds: 240),
    vsync: this,
  );

  late final CurvedAnimation _curva = CurvedAnimation(
    parent: _controlador,
    curve: Curves.easeOutCubic,
  );

  @override
  void initState() {
    super.initState();
    if (!widget.animar) {
      _controlador.value = 1;
      return;
    }
    if (widget.atraso == Duration.zero) {
      _iniciar();
    } else {
      // O timer não é cancelado no dispose porque `mounted` já barra o
      // forward() depois que o State sai — guardar o Timer só para isso não
      // pagaria o campo a mais.
      Future.delayed(widget.atraso, () {
        if (mounted) _iniciar();
      });
    }
  }

  void _iniciar() {
    _controlador.forward().whenCompleteOrCancel(() {
      if (mounted && _controlador.status == AnimationStatus.completed) {
        widget.onEntrou?.call();
      }
    });
  }

  @override
  void dispose() {
    _curva.dispose();
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curva,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.18),
          end: Offset.zero,
        ).animate(_curva),
        child: widget.child,
      ),
    );
  }
}

class _VazioJogos extends StatelessWidget {
  final AppCores cores;

  const _VazioJogos({super.key, required this.cores});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.casino_outlined, size: 34, color: cores.textoFraco),
          const SizedBox(height: 10),
          Text(
            'Nenhum jogo montado',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: cores.textoSuave,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Sortear resto" com escolha de estilo.
///
/// O mesmo dinheiro compra poucos jogos com mais dezenas ou muitos jogos
/// mínimos, e não há resposta certa — é aposta. Por isso o botão não decide
/// sozinho: abre um menu com a composição exata que cada estilo produz
/// (`2×7` contra `14×6`), para a escolha ser sobre o resultado e não sobre o
/// nome da opção.
class _MenuSortearResto extends StatelessWidget {
  final int cotas;
  final String? sorteio;
  final bool habilitado;
  final ValueChanged<EstiloSorteio> onEscolher;

  const _MenuSortearResto({
    required this.cotas,
    required this.sorteio,
    required this.habilitado,
    required this.onEscolher,
  });

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    final casca = _BotaoSecundario(
      icone: Icons.casino_outlined,
      texto: 'Sortear resto',
      habilitado: habilitado,
      // Toque tratado pelo PopupMenuButton em volta.
      onTap: null,
    );

    if (!habilitado) return casca;

    return PopupMenuButton<EstiloSorteio>(
      tooltip: '',
      position: PopupMenuPosition.under,
      onSelected: onEscolher,
      itemBuilder: (context) => [
        for (final estilo in EstiloSorteio.values)
          PopupMenuItem(
            value: estilo,
            child: _OpcaoEstilo(
              titulo: switch (estilo) {
                EstiloSorteio.maiores => 'Jogos maiores primeiro',
                EstiloSorteio.simples => 'Só jogos simples',
              },
              composicao: resumoDeTamanhos(
                tamanhosParaCotas(cotas, sorteio, estilo),
              ),
              cores: cores,
            ),
          ),
      ],
      child: casca,
    );
  }
}

class _OpcaoEstilo extends StatelessWidget {
  final String titulo;
  final String composicao;
  final AppCores cores;

  const _OpcaoEstilo({
    required this.titulo,
    required this.composicao,
    required this.cores,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          titulo,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: cores.texto,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          composicao,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: cores.textoSuave,
          ),
        ),
      ],
    );
  }
}

/// Um jogo na lista: posição e números escolhidos.
class _LinhaJogo extends StatelessWidget {
  final int posicao;
  final List<int> numeros;
  final VoidCallback onEditar;
  final VoidCallback onRemover;

  const _LinhaJogo({
    required this.posicao,
    required this.numeros,
    required this.onEditar,
    required this.onRemover,
  });

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: cores.campo,
        borderRadius: AppRadii.circularMd,
        border: Border.all(color: cores.bordaCampo),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Jogo $posicao · ${numeros.length} números',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: cores.textoFraco,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final numero in numeros)
                      _PastilhaNumero(numero: numero),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEditar,
            icon: Icon(Icons.edit_outlined, size: 18, color: cores.textoSuave),
            tooltip: 'Editar',
          ),
          IconButton(
            onPressed: onRemover,
            icon: Icon(Icons.close, size: 18, color: cores.textoSuave),
            tooltip: 'Remover',
          ),
        ],
      ),
    );
  }
}

/// Número já escolhido, no resumo da lista. Menor que a bola da grade: aqui
/// ele é leitura, não alvo de toque.
class _PastilhaNumero extends StatelessWidget {
  final int numero;

  const _PastilhaNumero({required this.numero});

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: cores.acaoPrimaria,
      ),
      child: Text(
        numero.toString().padLeft(2, '0'),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: cores.textoSobreAcao,
        ),
      ),
    );
  }
}

/// Tamanho de jogo oferecido no topo da grade.
///
/// O custo em cotas não vem no chip: o subtítulo já mostra o do tamanho
/// selecionado ("4 de 7 · 7 cotas"), e a lista só oferece tamanhos que cabem
/// no orçamento — o que não cabe nem aparece.
class _ChipTamanho extends StatelessWidget {
  final int tamanho;
  final bool selecionado;
  final VoidCallback onTap;

  const _ChipTamanho({
    required this.tamanho,
    required this.selecionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.circularMd,
      // Trocar de tamanho reordena a cartela inteira embaixo; a cor do chip
      // atravessando junto amarra as duas coisas como um movimento só.
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selecionado ? cores.acaoPrimaria : cores.campo,
          borderRadius: AppRadii.circularMd,
          border: Border.all(
            color: selecionado ? cores.acaoPrimaria : cores.bordaCampo,
          ),
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 180),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selecionado ? cores.textoSobreAcao : cores.textoSuave,
          ),
          child: Text('$tamanho números'),
        ),
      ),
    );
  }
}

/// Botão de ação secundária dentro do modal (adicionar jogo, surpresinha).
///
/// [habilitado] é separado de `onTap` porque a mesma casca também serve de
/// filho de um PopupMenuButton, que trata o toque por fora — nesse uso o
/// `onTap` é null e o botão continua aceso.
class _BotaoSecundario extends StatelessWidget {
  final IconData icone;
  final String texto;
  final VoidCallback? onTap;
  final bool habilitado;

  const _BotaoSecundario({
    required this.icone,
    required this.texto,
    required this.onTap,
    this.habilitado = true,
  });

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    return Opacity(
      opacity: habilitado ? 1 : 0.4,
      child: InkWell(
        onTap: habilitado ? onTap : null,
        borderRadius: AppRadii.circularMd,
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: AppRadii.circularMd,
            border: Border.all(color: cores.acaoPrimaria, width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icone, size: 16, color: cores.acaoPrimaria),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  texto,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: cores.acaoPrimaria,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bola da grade — o alvo de toque que mais se repete no modal.
///
/// A marcação tem duas partes: a cor atravessa em 160ms (`AnimatedContainer`)
/// e a bola dá um "pulinho" de 12% quando é MARCADA. O pulo só acontece ao
/// marcar, nunca ao desmarcar: ele é a confirmação física do acerto, e dar o
/// mesmo destaque para tirar um número faria a cartela pipocar inteira quando
/// se troca de ideia.
///
/// É um estouro curto (200ms) e sem `elasticOut`: a grade tem 60 bolas, e uma
/// curva elástica em algo que se toca seis vezes seguidas cansa depressa.
class _BolaNumero extends StatefulWidget {
  final int numero;
  final bool selecionado;
  final VoidCallback onTap;

  const _BolaNumero({
    required this.numero,
    required this.selecionado,
    required this.onTap,
  });

  @override
  State<_BolaNumero> createState() => _BolaNumeroState();
}

class _BolaNumeroState extends State<_BolaNumero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controlador = AnimationController(
    duration: const Duration(milliseconds: 200),
    vsync: this,
  );

  late final CurvedAnimation _curva = CurvedAnimation(
    parent: _controlador,
    curve: Curves.easeOut,
  );

  late final Animation<double> _pulo = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.12), weight: 40),
    TweenSequenceItem(tween: Tween(begin: 1.12, end: 1.0), weight: 60),
  ]).animate(_curva);

  @override
  void didUpdateWidget(_BolaNumero anterior) {
    super.didUpdateWidget(anterior);
    if (widget.selecionado && !anterior.selecionado) {
      _controlador.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _curva.dispose();
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    final selecionado = widget.selecionado;
    return InkWell(
      onTap: widget.onTap,
      customBorder: const CircleBorder(),
      child: ScaleTransition(
        scale: _pulo,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selecionado ? cores.acaoPrimaria : cores.campo,
            border: Border.all(
              color: selecionado ? cores.acaoPrimaria : cores.bordaCampo,
              width: 1.5,
            ),
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 160),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: selecionado ? cores.textoSobreAcao : cores.texto,
            ),
            child: Text(widget.numero.toString()),
          ),
        ),
      ),
    );
  }
}
