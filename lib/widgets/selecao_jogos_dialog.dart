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

  // Null = tela da lista de jogos; preenchido = grade de números aberta.
  _JogoEmEdicao? _edicao;

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

  void _abrirGrade({int? indice}) {
    setState(() {
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
      if (edicao.indice == null) {
        _jogos.add(numeros);
      } else {
        _jogos[edicao.indice!] = numeros;
      }
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
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: _edicao == null ? _buildLista(cores) : _buildGrade(cores),
        ),
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
        if (excedente > 0) ...[
          const SizedBox(height: 12),
          _AvisoExcedente(cores: cores, excedente: excedente),
        ],
        const SizedBox(height: 12),
        Flexible(
          child: _jogos.isEmpty
              ? _VazioJogos(cores: cores)
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: _jogos.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _LinhaJogo(
                    posicao: i + 1,
                    numeros: _jogos[i],
                    onEditar: () => _abrirGrade(indice: i),
                    onRemover: () => setState(() => _jogos.removeAt(i)),
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
              onPressed: () => setState(() => _edicao = null),
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

class _VazioJogos extends StatelessWidget {
  final AppCores cores;

  const _VazioJogos({required this.cores});

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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selecionado ? cores.acaoPrimaria : cores.campo,
          borderRadius: AppRadii.circularMd,
          border: Border.all(
            color: selecionado ? cores.acaoPrimaria : cores.bordaCampo,
          ),
        ),
        child: Text(
          '$tamanho números',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selecionado ? cores.textoSobreAcao : cores.textoSuave,
          ),
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

class _BolaNumero extends StatelessWidget {
  final int numero;
  final bool selecionado;
  final VoidCallback onTap;

  const _BolaNumero({
    required this.numero,
    required this.selecionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
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
        child: Text(
          numero.toString(),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: selecionado ? cores.textoSobreAcao : cores.texto,
          ),
        ),
      ),
    );
  }
}
