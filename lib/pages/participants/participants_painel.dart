import 'package:bolao_bolado/components/shared/header_card.dart';
import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/core/app_radii.dart';
import 'package:bolao_bolado/core/debug_flags.dart';
import 'package:bolao_bolado/core/responsive.dart';
import 'package:bolao_bolado/pages/participants/participants_busca.dart';
import 'package:bolao_bolado/pages/participants/participants_estatisticas.dart';
import 'package:bolao_bolado/pages/participants/participants_lista.dart';
import 'package:bolao_bolado/pages/participants/participants_skeletons.dart';
import 'package:bolao_bolado/pages/participants/participants_tabela.dart';
import 'package:bolao_bolado/services/bet/bet_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Painel de participantes (estatísticas + busca + tabela/lista).
///
/// Mantém o estado de busca/ordenação isolado do restante da página,
/// para que digitar no filtro não force o rebuild do chat lateral.
class PainelParticipantes extends StatefulWidget {
  final String? currentUid;
  final bool loading;
  final List<Map<String, dynamic>> rowsData;
  final bool isAdmin;
  final String? sorteio;
  final DateTime? dataSorteio;
  final double premioSala;
  final Widget Function() onEditarSala;
  final bool mobile;
  final bool expandirConteudo;
  final bool mostrarCabecalho;
  // Altura que o card de seção cedeu ao painel no mobile (a página mede com
  // LayoutBuilder): estatísticas e busca ficam fixas no topo e só a lista
  // rola no que sobra. Sem ela a lista cresceria com a quantidade de apostas
  // e empurraria o card para fora da tela.
  final double? alturaMobile;

  const PainelParticipantes({
    super.key,
    required this.currentUid,
    required this.loading,
    required this.rowsData,
    required this.isAdmin,
    required this.sorteio,
    required this.dataSorteio,
    required this.premioSala,
    required this.onEditarSala,
    required this.mobile,
    this.expandirConteudo = false,
    this.mostrarCabecalho = true,
    this.alturaMobile,
  });

  @override
  State<PainelParticipantes> createState() => _PainelParticipantesState();
}

class _PainelParticipantesState extends State<PainelParticipantes> {
  String _busca = '';
  final FocusNode _buscaFocusNode = FocusNode();

  // Ordenação padrão: valor decrescente
  int _colunaOrdenada = 1; // 0=nome, 1=valor, 2=cotas, 3=premio, 4=data
  bool _ascendente = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKeyEvent);
    _buscaFocusNode.dispose();
    super.dispose();
  }

  // Atalho Ctrl+F foca a busca em vez de abrir o find do navegador,
  // já que a lista de participantes costuma ser o alvo dessa busca.
  bool _onKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.keyF &&
        HardwareKeyboard.instance.isControlPressed) {
      _buscaFocusNode.requestFocus();
      return true;
    }
    return false;
  }

  void _ordenar(List<Map<String, dynamic>> rows) {
    rows.sort((a, b) {
      dynamic va;
      dynamic vb;

      switch (_colunaOrdenada) {
        case 0:
          va = (a['nome'] ?? '').toString().toLowerCase();
          vb = (b['nome'] ?? '').toString().toLowerCase();
          break;
        case 1:
          va = (a['valor'] as num?)?.toDouble() ?? 0;
          vb = (b['valor'] as num?)?.toDouble() ?? 0;
          break;
        case 2:
          va = (a['cotas'] as num?)?.toInt() ?? 0;
          vb = (b['cotas'] as num?)?.toInt() ?? 0;
          break;
        case 3:
          va = (a['premio'] as num?)?.toDouble() ?? 0;
          vb = (b['premio'] as num?)?.toDouble() ?? 0;
          break;
        case 4:
          // Escrita ainda não confirmada pelo servidor vale "agora" em vez de
          // época zero, senão a aposta recém-criada nasce na última linha e
          // pula para o topo quando o timestamp chega (ver dataHoraOrdenacao).
          va = dataHoraOrdenacao(
            a['data-hora'],
            pendente: a['pendente'] == true,
            uid: a['uid']?.toString(),
          );
          vb = dataHoraOrdenacao(
            b['data-hora'],
            pendente: b['pendente'] == true,
            uid: b['uid']?.toString(),
          );
          break;
        default:
          return 0;
      }

      final cmp = va is String
          ? va.compareTo(vb)
          : (va as num).compareTo(vb as num);
      if (cmp != 0) return _ascendente ? cmp : -cmp;

      // Empate: desempata pelo uid, que nunca muda.
      //
      // `List.sort` do Dart NÃO é estável — com chaves iguais a ordem final
      // depende da ordem de ENTRADA. E a ordem de entrada muda sozinha: a
      // consulta do Firestore é ordenada por `data-hora`, e uma aposta
      // recém-criada entra com `data-hora` null e só ganha o valor real
      // quando o servidor confirma, o que a reposiciona na lista de origem.
      //
      // Sem este desempate, várias apostas de mesmo valor (o simulador gera
      // muitas) trocavam de lugar entre si a cada emissão do stream. Cada
      // troca virava uma reordenação para a ColunaReordenavel animar, e o
      // resultado era a linha nova animando e logo em seguida sendo mandada
      // para outra posição.
      //
      // O desempate é sempre crescente, independente de `_ascendente`: ele
      // não é um critério de exibição, é só um jeito de a ordem ser sempre a
      // mesma para os mesmos dados.
      final uidA = a['uid']?.toString() ?? '';
      final uidB = b['uid']?.toString() ?? '';
      return uidA.compareTo(uidB);
    });
  }

  void _onCabecalhoTap(int coluna) {
    setState(() {
      if (_colunaOrdenada == coluna) {
        _ascendente = !_ascendente;
      } else {
        _colunaOrdenada = coluna;
        _ascendente = false;
      }
    });
  }

  Widget _textoSelecionavel({
    required BuildContext context,
    required Widget child,
  }) {
    // Seleção de texto só em web/desktop: em mobile atrapalharia gestos
    // de scroll/toque na lista.
    final habilitarSelecao = kIsWeb || Responsive.isDesktop(context);
    return habilitarSelecao ? SelectionArea(child: child) : child;
  }

  // Resultado do último filtro+ordenação e as entradas que o produziram.
  //
  // Filtrar e ordenar percorre a lista inteira (o `sort` ainda faz `toString`
  // e lookup de mapa por comparação), e isso acontecia dentro do build — ou
  // seja, a cada emissão do stream, a cada tecla na busca e a cada tick do
  // simulador, mesmo quando nada tinha mudado. Numa rajada de apostas em sala
  // grande era o custo dominante do frame.
  //
  // `rowsData` é comparada por IDENTIDADE, não conteúdo: `streamBets()` só
  // emite lista nova quando algo mudou de verdade, então identidade igual
  // significa dados iguais — e comparar 1000 mapas campo a campo custaria
  // quase o mesmo que refazer a conta.
  List<Map<String, dynamic>>? _linhasCache;
  List<Map<String, dynamic>>? _rowsDataDoCache;
  String? _buscaDoCache;
  int? _colunaDoCache;
  bool? _ascendenteDoCache;

  List<Map<String, dynamic>> _linhasFiltradas() {
    final cache = _linhasCache;
    if (cache != null &&
        identical(_rowsDataDoCache, widget.rowsData) &&
        _buscaDoCache == _busca &&
        _colunaDoCache == _colunaOrdenada &&
        _ascendenteDoCache == _ascendente) {
      return cache;
    }

    // Descarta posições memorizadas de apostas que saíram da sala (ver
    // esquecerOrdemDeChegada). Usa a lista COMPLETA, não a filtrada: filtrar
    // pela busca não é motivo para uma aposta perder o lugar que já tinha.
    esquecerOrdemDeChegada(
      widget.rowsData.map((row) => row['uid']?.toString()).whereType<String>(),
    );

    final termo = _busca.trim().toLowerCase();
    final rows = termo.isEmpty
        ? List<Map<String, dynamic>>.from(widget.rowsData)
        : widget.rowsData
              .where(
                (item) => (item['nome'] ?? '')
                    .toString()
                    .toLowerCase()
                    .contains(termo),
              )
              .toList();
    _ordenar(rows);

    _linhasCache = rows;
    _rowsDataDoCache = widget.rowsData;
    _buscaDoCache = _busca;
    _colunaDoCache = _colunaOrdenada;
    _ascendenteDoCache = _ascendente;
    return rows;
  }

  // Loading efetivo = loading real do pai OU o toggle "Forçar skeleton" do
  // Painel ADM. Setado no build() a partir do ValueListenableBuilder e lido
  // pelos _buildMobile/_buildDesktop.
  bool _loadingEfetivo = false;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: forcarSkeletonGlobal,
      builder: (context, forcarSkeleton, _) {
        _loadingEfetivo = widget.loading || forcarSkeleton;
        return widget.mobile ? _buildMobile(context) : _buildDesktop(context);
      },
    );
  }

  // No mobile o painel devolve só o CONTEÚDO: o card com título e subtítulo
  // em volta é montado pela página, igual ao card de Minha Aposta e ao do
  // Chat, para as três seções terem a mesma moldura.
  Widget _buildMobile(BuildContext context) {
    final cores = AppCores.de(context);
    if (_loadingEfetivo) {
      return SizedBox(
        height: widget.alturaMobile,
        child: const SkeletonParticipantes(mobile: true),
      );
    }

    final linhasFiltradas = _linhasFiltradas();

    final rodapeLista = RodapeLista(
      total: linhasFiltradas.length,
      valorTotal: linhasFiltradas.fold<double>(
        0,
        (soma, row) => soma + ((row['valor'] as num?)?.toDouble() ?? 0),
      ),
      cotasTotal: linhasFiltradas.fold<int>(
        0,
        (soma, row) => soma + ((row['cotas'] as num?)?.toInt() ?? 0),
      ),
    );

    final listaOuVazio = linhasFiltradas.isEmpty
        ? _EstadoVazioParticipantes(semApostas: widget.rowsData.isEmpty)
        : Container(
            decoration: BoxDecoration(
              border: Border.all(color: cores.borda, width: 1.5),
              borderRadius: AppRadii.circularSmd,
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: widget.alturaMobile != null
                  ? MainAxisSize.max
                  : MainAxisSize.min,
              children: [
                widget.alturaMobile != null
                    // Com altura definida, a lista rola por CONTA PRÓPRIA
                    // (sem SingleChildScrollView envolvendo) — é isso que dá
                    // ao ListView.builder uma viewport finita para reciclar.
                    // Um shrinkWrap dentro de scroll externo faz o Flutter
                    // construir TODOS os itens para medir a altura total,
                    // ainda que só alguns apareçam na tela: com 1000 apostas
                    // isso montava a lista inteira mesmo tendo itemExtent.
                    ? Expanded(
                        child: ListaParticipantes(
                          rows: linhasFiltradas,
                          currentUid: widget.currentUid,
                          rowsCompletas: widget.rowsData,
                        ),
                      )
                    : SingleChildScrollView(
                        child: ListaParticipantes(
                          rows: linhasFiltradas,
                          currentUid: widget.currentUid,
                          rowsCompletas: widget.rowsData,
                          semScrollProprio: true,
                        ),
                      ),
                Divider(height: 1, thickness: 1, color: cores.borda),
                Container(
                  color: cores.superficieAlta,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: rodapeLista,
                ),
              ],
            ),
          );

    // Com o teclado aberto (digitando na busca) a altura cedida despenca, e
    // os três indicadores empilhados sozinhos já ocupam uns 150px: mantidos,
    // a lista ficava sem espaço nenhum justamente quando se está procurando
    // alguém nela. Abaixo deste limite eles saem e voltam ao fechar o teclado.
    // A decisão sai da altura medida, e não de `MediaQuery.viewInsets`, para
    // o teclado não reconstruir o painel inteiro (ver responsive.dart).
    final altura = widget.alturaMobile;
    final mostrarEstatisticas = altura == null || altura >= 420;

    // Mesma ordem do desktop: indicadores no topo, busca, lista.
    return SizedBox(
      height: altura,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (mostrarEstatisticas) ...[
            PainelEstatisticas(
              rows: widget.rowsData,
              currentUid: widget.currentUid,
              sorteio: widget.sorteio,
              dataSorteio: widget.dataSorteio,
              premioSala: widget.premioSala,
            ),
            const SizedBox(height: 12),
          ],
          BarraBuscaOrdenacao(
            busca: _busca,
            onBuscaChanged: (v) => setState(() => _busca = v),
            colunaOrdenada: _colunaOrdenada,
            ascendente: _ascendente,
            onOrdenarPor: _onCabecalhoTap,
          ),
          const SizedBox(height: 12),
          widget.alturaMobile != null
              ? Expanded(child: listaOuVazio)
              : listaOuVazio,
        ],
      ),
    );
  }

  Widget _buildDesktop(BuildContext context) {
    final linhasFiltradas = _linhasFiltradas();

    final conteudo = _loadingEfetivo
        // Mesmo alturaFixa da tabela real logo abaixo: é ele que decide se a
        // tabela preenche a altura cedida ou cresce com o conteúdo.
        ? SkeletonTabela(alturaFixa: widget.expandirConteudo)
        : TabelaApostas(
            rows: linhasFiltradas,
            colunaOrdenada: _colunaOrdenada,
            ascendente: _ascendente,
            onCabecalhoTap: _onCabecalhoTap,
            currentUid: widget.currentUid,
            alturaFixa: widget.expandirConteudo,
            rowsCompletas: widget.rowsData,
            mensagemVazio: linhasFiltradas.isEmpty
                ? _textoSelecionavel(
                    context: context,
                    child: _EstadoVazioParticipantes(
                      semApostas: widget.rowsData.isEmpty,
                      desktop: true,
                    ),
                  )
                : null,
          );

    final painelEstatisticas = _loadingEfetivo
        ? const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: SkeletonEstatisticasDesktop(),
          )
        : Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PainelEstatisticas(
              rows: widget.rowsData,
              currentUid: widget.currentUid,
              sorteio: widget.sorteio,
              dataSorteio: widget.dataSorteio,
              premioSala: widget.premioSala,
            ),
          );

    return HeaderCard(
      text: 'Participantes',
      subtitle: 'Visualize quem está participando',
      showBackButton: false,
      mostrarCabecalho: widget.mostrarCabecalho,
      trailing: widget.isAdmin ? widget.onEditarSala() : null,
      apenasConteudo: widget.expandirConteudo,
      children: widget.expandirConteudo
          ? [
              painelEstatisticas,
              CampoBusca(
                busca: _busca,
                onBuscaChanged: (v) => setState(() => _busca = v),
                focusNode: _buscaFocusNode,
              ),
              const SizedBox(height: 12),
              Expanded(child: SelectionArea(child: conteudo)),
            ]
          : [painelEstatisticas, SelectionArea(child: conteudo)],
    );
  }
}

// Estado vazio exibido tanto na lista mobile quanto na tabela desktop
// (mensagemVazio do TabelaApostas), quando não há apostas ou o filtro de
// busca não encontra ninguém.
class _EstadoVazioParticipantes extends StatelessWidget {
  final bool semApostas;
  final bool desktop;

  const _EstadoVazioParticipantes({
    required this.semApostas,
    this.desktop = false,
  });

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    final mensagem = semApostas
        ? 'Nenhuma aposta ainda.'
        : 'Nenhum participante encontrado.';

    return Padding(
      padding: EdgeInsets.symmetric(vertical: desktop ? 0 : 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.sentiment_dissatisfied_outlined,
            size: 48,
            color: cores.textoFraco,
          ),
          const SizedBox(height: 12),
          Text(
            mensagem,
            style: TextStyle(
              color: cores.textoSuave,
              fontSize: desktop ? 16 : 15,
            ),
          ),
        ],
      ),
    );
  }
}
