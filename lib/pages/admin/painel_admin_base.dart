import 'dart:async';

import 'package:bolao_bolado/components/formatters/formatters.dart';
import 'package:bolao_bolado/components/shared/custom_confirm_dialog.dart';
import 'package:bolao_bolado/components/shared/custom_fields.dart';
import 'package:bolao_bolado/components/shared/custom_show_dialog.dart';
import 'package:bolao_bolado/components/shared/snackbar_deslizante.dart';
import 'package:bolao_bolado/core/app_radii.dart';
import 'package:bolao_bolado/pages/admin/admin_abas.dart';
import 'package:bolao_bolado/pages/admin/widgets/admin_widgets.dart';
import 'package:bolao_bolado/pages/admin/widgets/moderar_chat.dart';
import 'package:bolao_bolado/services/authentication/auth_service.dart';
import 'package:bolao_bolado/services/avatar/avatar_service.dart';
import 'package:bolao_bolado/services/bet/bet_service.dart';
import 'package:bolao_bolado/services/bet/preco_cota.dart';
import 'package:bolao_bolado/services/bet/valor_maximo.dart';
import 'package:bolao_bolado/services/chat/chat_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Toda a lógica de estado e ações do painel admin (acesso, carregamento de
/// dados, diálogos, CRUD de apostas/sala), independente de como o painel é
/// desenhado na tela — [PainelAdmin] aplica este mixin e só monta o layout,
/// sem duplicar nenhuma regra de negócio aqui.
mixin PainelAdminMixin<T extends StatefulWidget> on State<T> {
  final AuthService _authService = AuthService();

  bool loading = true;
  bool autorizado = false;
  String? salaId;
  Map<String, dynamic> dadosSala = {};
  User? adminUser;

  List<Map<String, dynamic>> bets = [];
  bool carregandoStats = true;

  // Instanciada uma única vez: se streamApostasPendentes() fosse chamada
  // direto no build(), cada setState() recriaria a Query e o StreamBuilder
  // reiniciaria do zero, piscando a lista.
  //
  // Null até `_verificarAcesso` confirmar que é admin. Como inicializador de
  // campo, ela abria o listener `collectionGroup` no instante em que o State
  // nascia — ou seja, antes de saber se a pessoa pode ver isso. Quem caísse
  // nesta rota sem ser admin (incluindo sessão anônima) disparava uma query que
  // as regras recusam, e o StreamBuilder mostrava o estado de erro do painel em
  // vez do "sem permissão". É o mesmo ajuste já feito no drawer.
  //
  // O StreamBuilder aceita stream nula e simplesmente fica sem dado até ela
  // existir, então nada precisa mudar em quem consome.
  Stream<QuerySnapshot<Map<String, dynamic>>>? apostasPendentesStream;

  // Apostas fake para testar o layout sem tocar no Firestore.
  List<Map<String, dynamic>>? fakePendentes;

  /// Preço da cota da sala principal, derivado do `sorteio` carregado em
  /// [dadosSala]. Nunca assumir R$6 fixo aqui: em sala de Lotofácil a cota
  /// custa R$3,50, e validar contra 6 rejeitava lançamento/edição de apostas
  /// perfeitamente válidas (e aceitava valores que não fecham cota inteira).
  double get precoCota => precoCotaPara(dadosSala['sorteio']?.toString());

  /// Teto por aposta da sala principal; `null` quando a sala não tem limite.
  /// Vale também para o admin: o limite é uma regra da sala, e um lançamento
  /// manual acima dele distorceria o rateio do prêmio do mesmo jeito.
  double? get valorMaximoSala => valorMaximoDe(dadosSala['valorMaximo']);

  // getBets() é um Future avulso (não um stream): monta a lista já com os
  // avatares que estiverem em cache no momento e nunca mais reconsulta
  // sozinho. Diferente de streamBets() (usado em Participantes/chat), que já
  // escuta AvatarColorCache.mudancas e se recompõe quando um avatar chega
  // atrasado — aqui, sem essa assinatura, quem abrisse o Painel ADM com o
  // cache ainda frio (por exemplo, entrando direto nele — ver
  // ultima_rota_admin.dart) via a lista inteira presa no avatar neutro pra
  // sempre, mesmo depois do Firestore responder.
  StreamSubscription<void>? _avatarMudancasSub;

  @override
  void initState() {
    super.initState();
    _verificarAcesso();
    _avatarMudancasSub = AvatarColorCache.instance.mudancas.listen((_) {
      if (!mounted || carregandoStats) return;
      _reaplicarAvatares();
    });
  }

  /// Repinta os avatares da lista com o que o cache já sabe — **sem tocar na
  /// rede**.
  ///
  /// Antes este aviso chamava `_carregarStats()`, ou seja a query COMPLETA de
  /// Participantes mais a releitura do documento da sala (duas, na época). E o
  /// aviso não é raro — cada linha que entra
  /// na tela abre um `snapshots()` em `usuarios/{uid}` e, ao responder, emite
  /// `mudancas`. Ou seja: rolar a lista do painel disparava releituras da
  /// coleção inteira, uma atrás da outra. Numa sala de 300 apostas, cada
  /// rolagem custava algumas centenas de leituras.
  ///
  /// O aviso de avatar não traz dado de aposta nenhum — valor, verificação e
  /// prêmio continuam iguais. O que mudou está em memória, no próprio cache,
  /// então basta reler dele. Rede zero.
  void _reaplicarAvatares() {
    final cache = AvatarColorCache.instance;
    var mudou = false;

    final atualizadas = bets.map((aposta) {
      final uid = aposta['uid']?.toString();
      if (uid == null) return aposta;
      final avatar = cache.avatarConhecido(uid);
      if (avatar == null) return aposta;

      final cor = avatar.cor.toARGB32();
      if (aposta['avatarColor'] == cor &&
          aposta['avatarEmoji'] == avatar.emoji) {
        return aposta;
      }
      mudou = true;
      return {...aposta, 'avatarColor': cor, 'avatarEmoji': avatar.emoji};
    }).toList();

    // Só reconstrói se algum avatar realmente mudou: o cache emite um aviso
    // agrupado por rajada de documentos, e boa parte deles confirma valores que
    // a lista já mostrava.
    if (!mudou) return;
    setState(() => bets = atualizadas);
  }

  @override
  void dispose() {
    _avatarMudancasSub?.cancel();
    super.dispose();
  }

  Future<void> _verificarAcesso() async {
    final user = FirebaseAuth.instance.currentUser;
    // Usuário anônimo nunca é admin: painel exige conta cadastrada com
    // flag isAdmin no Firestore.
    if (user == null || user.isAnonymous) {
      setState(() {
        autorizado = false;
        loading = false;
      });
      return;
    }

    // Independentes entre si: em série custavam dois round-trips antes do
    // painel sair do loading.
    final (isAdmin, id) = await (
      _authService.isAdmin(user.uid),
      buscarSalaPrincipalId(),
    ).wait;

    if (!mounted) return;
    setState(() {
      autorizado = isAdmin;
      salaId = id;
      adminUser = user;
      loading = false;
      // Só agora abre o listener das pendências — ver o campo.
      if (isAdmin) apostasPendentesStream ??= streamApostasPendentes();
    });

    if (isAdmin) {
      unawaited(_carregarStats());
    }
  }

  Future<void> _carregarStats() async {
    // Uma chamada só: antes eram duas funções em paralelo, e cada uma relia o
    // documento da sala por conta própria — duas leituras cobradas pelo mesmo
    // `Salas/{id}` a cada atualização do painel.
    final resultado = await getDadosSalaEApostas();
    if (!mounted) return;
    setState(() {
      bets = resultado.apostas;
      dadosSala = resultado.dadosSala;
      carregandoStats = false;
    });
  }

  void gerarApostasFake([int quantidade = 12]) {
    final nomes = [
      'João Silva',
      'Maria Oliveira',
      'Pedro Santos',
      'Ana Costa',
      'Lucas Pereira',
      'Beatriz Souza',
      'Rafael Lima',
      'Camila Alves',
      'Gustavo Rocha',
      'Fernanda Dias',
      'Thiago Martins',
      'Juliana Ribeiro',
      'Bruno Carvalho',
      'Larissa Gomes',
      'Diego Barbosa',
    ];
    final random = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      fakePendentes = List.generate(quantidade, (index) {
        final nome = nomes[(random + index) % nomes.length];
        final valor = 6.0 * (1 + (index % 5));
        return {
          'id': 'fake_$index',
          'nome': nome,
          'uid': 'fake_uid_$index',
          'valor': valor,
        };
      });
    });
  }

  void limparApostasFake() => setState(() => fakePendentes = null);

  // ---------------------------------------------------------------------------
  // Diálogos / ações
  // ---------------------------------------------------------------------------

  /// Diálogo de valor de aposta, compartilhado por "Lançar aposta manual" e
  /// "Editar valor".
  ///
  /// Os dois eram cópias quase idênticas (mesmo StatefulBuilder, mesma
  /// validação, mesmo tratamento de erro) e divergiam só nos pontos que hoje
  /// são parâmetros. A duplicação não era só verbosidade: a validação de cota
  /// nasceu errada nos DOIS lugares (`% 6` fixo, quebrando salas de
  /// Lotofácil) porque foi copiada junto. Com um formulário só, uma correção
  /// vale para ambos.
  ///
  /// [comCampoNome] liga o campo de nome (só o lançamento manual precisa —
  /// na edição o participante já existe). [avisoRodape] é o texto opcional
  /// abaixo do campo. [onSalvar] recebe nome e valor já normalizados (valor
  /// com ponto decimal, pronto para gravar como string).
  Future<void> _abrirDialogValorAposta({
    required String titulo,
    required bool comCampoNome,
    String nomeInicial = '',
    String valorInicial = '',
    String? avisoRodape,
    required Future<void> Function(String nome, String valor) onSalvar,
    required String mensagemErro,
  }) async {
    final nameController = TextEditingController(text: nomeInicial);
    final valueController = TextEditingController(text: valorInicial);
    final valueFocusNode = FocusNode();
    final formKey = GlobalKey<FormState>();
    bool salvando = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> salvar() async {
              if (!formKey.currentState!.validate()) return;

              final nome = nameController.text.trim();
              final valor = valueController.text
                  .trim()
                  .replaceAll('.', '')
                  .replaceAll(',', '.');
              final valorNum = double.tryParse(valor) ?? 0;

              // O valor precisa fechar cotas inteiras do sorteio DESTA sala
              // (Mega R$6, Lotofácil R$3,50) — ver [precoCota].
              if (!valorFechaCotasInteiras(valorNum, precoCota)) {
                CustomShowDialog.show(
                  dialogContext,
                  'O valor deve ser múltiplo de '
                  'R\$ ${precoCotaFormatado(precoCota)}!',
                );
                return;
              }

              if (!valorRespeitaMaximo(valorNum, valorMaximoSala)) {
                CustomShowDialog.show(
                  dialogContext,
                  'O valor máximo por aposta nesta sala é '
                  '${Formatters.moeda.format(valorMaximoSala)}.',
                );
                return;
              }

              setDialogState(() => salvando = true);
              try {
                await onSalvar(nome, valor);
                if (dialogContext.mounted) dialogContext.pop();
                unawaited(_carregarStats());
              } catch (e) {
                debugPrint('$mensagemErro: $e');
                setDialogState(() => salvando = false);
                if (dialogContext.mounted) {
                  CustomShowDialog.show(
                    dialogContext,
                    '$mensagemErro. Tente novamente.',
                  );
                }
              }
            }

            final campoValor = CustomField(
              hint: 'Valor',
              icon: Icons.attach_money,
              isNumeric: true,
              // Cota inteira (Mega, R$6) dispensa centavos; cota fracionada
              // (Lotofácil, R$3,50) precisa aceitar ",50" — travado em true,
              // o campo não deixava sequer digitar um valor válido de
              // Lotofácil.
              semCentavos: precoCota % 1 == 0,
              controller: valueController,
              focusNode: valueFocusNode,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => salvar(),
              maxWidth: 400,
              isRequired: true,
              prefix: const Text('R\$ '),
            );

            return AdminDialogFrame(
              titulo: titulo,
              salvando: salvando,
              onSalvar: salvar,
              corpo: Form(
                key: formKey,
                child: FocusTraversalGroup(
                  policy: OrderedTraversalPolicy(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (comCampoNome) ...[
                        FocusTraversalOrder(
                          order: const NumericFocusOrder(1),
                          child: CustomField(
                            hint: 'Nome',
                            icon: Icons.person_outline,
                            controller: nameController,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) =>
                                valueFocusNode.requestFocus(),
                            maxWidth: 400,
                            isRequired: true,
                          ),
                        ),
                        const SizedBox(height: 15),
                      ],
                      FocusTraversalOrder(
                        order: const NumericFocusOrder(2),
                        child: campoValor,
                      ),
                      if (avisoRodape != null) ...[
                        const SizedBox(height: 14),
                        _AvisoInfo(texto: avisoRodape),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> abrirDialogApostaManual() async {
    if (salaId == null) return;

    await _abrirDialogValorAposta(
      titulo: 'Lançar aposta manual',
      comCampoNome: true,
      mensagemErro: 'Erro ao salvar aposta',
      onSalvar: (nome, valor) =>
          criarApostaManual(salaId: salaId!, nome: nome, valor: valor),
    );
  }

  Future<void> abrirDialogEditarValor(Map<String, dynamic> aposta) async {
    if (salaId == null) return;
    final uid = aposta['uid']?.toString();
    if (uid == null) return;

    final valorAtual = (aposta['valor'] as num?)?.toDouble() ?? 0;
    final estavaVerificado = aposta['verificado'] == true;
    // Em sala de cota fracionada os centavos fazem parte do valor: cortá-los
    // (como o `.split(',')[0]` antigo fazia sempre) transformava R$3,50 em
    // "3" ao abrir o diálogo, um valor que a própria validação rejeita.
    final valorFormatado = Formatters.moedaSemSimbolo.format(valorAtual).trim();

    await _abrirDialogValorAposta(
      titulo: 'Editar aposta de ${aposta['nome']}',
      comCampoNome: true,
      nomeInicial: aposta['nome']?.toString() ?? '',
      valorInicial: valorAtual == 0
          ? ''
          : (precoCota % 1 == 0
                ? valorFormatado.split(',')[0]
                : valorFormatado),
      avisoRodape: estavaVerificado
          ? 'Esta aposta já estava verificada. Editar o valor vai marcá-la '
                'para re-verificação.'
          : null,
      mensagemErro: 'Erro ao salvar',
      onSalvar: (nome, valor) => editarValorAposta(
        salaId: salaId!,
        uid: uid,
        nome: nome,
        valor: valor,
        // Só marca para re-verificação se o VALOR mudou — trocar o nome
        // (correção de digitação, apelido) não afeta o rateio de prêmio e
        // não deveria tirar a aposta do estado verificado.
        estavaVerificado:
            estavaVerificado && (double.tryParse(valor) ?? 0) != valorAtual,
      ),
    );
  }

  Future<void> confirmarRemocao(Map<String, dynamic> aposta) async {
    if (salaId == null) return;
    final uid = aposta['uid']?.toString();
    if (uid == null) return;

    final confirmar = await CustomConfirmDialog.show(
      context,
      titulo: 'Remover aposta?',
      mensagem:
          'A aposta de "${aposta['nome']}" será apagada permanentemente e '
          'sairá do rateio de cotas e prêmios. Esta ação não pode ser '
          'desfeita.',
      textoConfirmar: 'Remover',
      destrutivo: true,
    );

    if (!confirmar) return;
    try {
      await removerAposta(salaId: salaId!, uid: uid);
      unawaited(_carregarStats());
      if (mounted) {
        // Sem desfazer: removerAposta apaga o doc, não há o que restaurar.
        mostrarSnackBarDeslizante(
          context,
          corFundo: AdminCores.de(context).verde,
          conteudo: Text('Aposta de ${aposta['nome']} removida'),
        );
      }
    } catch (e) {
      debugPrint('Erro ao remover aposta: $e');
      if (mounted) {
        CustomShowDialog.show(context, 'Erro ao remover. Tente novamente.');
      }
    }
  }

  Future<void> alternarVerificacaoAposta(Map<String, dynamic> aposta) async {
    final uid = aposta['uid']?.toString();
    if (uid == null) return;
    await _aplicarVerificacao(
      uid: uid,
      nome: aposta['nome']?.toString(),
      // O estado alvo é derivado UMA vez, aqui, a partir do mapa que a lista
      // acabou de desenhar. Quem desfaz não re-deriva: recebe o alvo pronto.
      verificar: aposta['verificado'] != true,
    );
  }

  /// Grava um estado de verificação ABSOLUTO (não um toggle) e confirma na
  /// tela. Receber o alvo em vez de calculá-lo é o que torna o desfazer
  /// possível: depois de [_carregarStats] a lista é substituída por mapas
  /// novos, então o mapa capturado no clique original vira uma cópia órfã com
  /// o valor antigo — re-derivar `!verificado` a partir dele repetia a mesma
  /// gravação em vez de invertê-la.
  Future<void> _aplicarVerificacao({
    required String uid,
    required String? nome,
    required bool verificar,
  }) async {
    if (salaId == null) return;
    try {
      await alternarVerificacao(
        salaId: salaId!,
        uid: uid,
        verificar: verificar,
      );
      unawaited(_carregarStats());
      if (mounted) {
        _avisarVerificacao(uid: uid, nome: nome, verificado: verificar);
      }
    } catch (e) {
      debugPrint('Erro ao alternar verificação: $e');
      if (mounted) {
        CustomShowDialog.show(context, 'Erro ao atualizar. Tente novamente.');
      }
    }
  }

  /// Confirmação de que a verificação foi aplicada. É snackbar (e não diálogo)
  /// porque verificar é ação leve e repetitiva — o admin percorre a lista
  /// marcando várias apostas seguidas, e um modal a cada clique exigiria um
  /// "OK" no meio do fluxo. Vem com desfazer no lugar de uma confirmação
  /// prévia: a ação é reversível, então o padrão é agir e oferecer volta.
  void _avisarVerificacao({
    required String uid,
    required String? nome,
    required bool verificado,
  }) {
    final cores = AdminCores.de(context);
    final rotulo = (nome == null || nome.isEmpty) ? 'a aposta' : nome;
    mostrarSnackBarDeslizante(
      context,
      corFundo: verificado ? cores.verde : cores.textoSuave,
      conteudo: Text(
        verificado
            ? 'Aposta de $rotulo verificada'
            : 'Aposta de $rotulo marcada como pendente',
      ),
      aoDesfazer: () {
        // Grava o estado INVERSO explicitamente. Chamar o toggle de novo não
        // funcionaria: ele leria a aposta da lista já recarregada e
        // recalcularia o mesmo alvo, regravando o valor atual.
        unawaited(
          _aplicarVerificacao(uid: uid, nome: nome, verificar: !verificado),
        );
      },
    );
  }

  /// Abre o diálogo de moderação (lista de mensagens com botão de apagar).
  Future<void> abrirModeracaoChat() async {
    if (salaId == null) return;
    await abrirDialogModerarChat(context, salaId!);
  }

  /// Apaga TODO o histórico do chat da sala, com confirmação — é a ação mais
  /// destrutiva do painel e não tem desfazer.
  Future<void> confirmarApagarMensagensChat() async {
    if (salaId == null) return;

    final confirmar = await CustomConfirmDialog.show(
      context,
      titulo: 'Apagar todas as mensagens?',
      mensagem:
          'Todo o histórico do chat desta sala será apagado permanentemente '
          'para todos os participantes. Esta ação não pode ser desfeita.',
      textoConfirmar: 'Apagar tudo',
      destrutivo: true,
    );

    if (!confirmar) return;

    try {
      final apagadas = await ChatService().apagarTodasMensagens(salaId!);
      if (!mounted) return;
      mostrarSnackBarDeslizante(
        context,
        corFundo: AdminCores.de(context).verde,
        conteudo: Text(
          apagadas == 0
              ? 'O chat já estava vazio.'
              : '$apagadas ${apagadas == 1 ? "mensagem apagada" : "mensagens apagadas"}',
        ),
      );
    } catch (e) {
      debugPrint('Erro ao apagar mensagens do chat: $e');
      if (mounted) {
        CustomShowDialog.show(
          context,
          'Erro ao apagar as mensagens. Tente novamente.',
        );
      }
    }
  }

  /// Apaga TODAS as apostas da sala, com confirmação. Zera o bolão: ninguém
  /// fica no rateio e os totais do painel voltam a zero. Não tem desfazer,
  /// por isso a confirmação repete o que acontece com o dinheiro.
  Future<void> confirmarApagarTodasApostas() async {
    if (salaId == null) return;

    final confirmar = await CustomConfirmDialog.show(
      context,
      titulo: 'Apagar todas as apostas?',
      mensagem:
          'Todas as apostas desta sala serão apagadas permanentemente, '
          'incluindo as já verificadas. A sala fica sem nenhum participante '
          'e o rateio de cotas e prêmios volta a zero. Esta ação não pode '
          'ser desfeita.',
      textoConfirmar: 'Apagar tudo',
      destrutivo: true,
    );

    if (!confirmar) return;

    try {
      final apagadas = await removerTodasApostas(salaId: salaId!);
      unawaited(_carregarStats());
      if (!mounted) return;
      mostrarSnackBarDeslizante(
        context,
        corFundo: AdminCores.de(context).verde,
        conteudo: Text(
          apagadas == 0
              ? 'A sala já estava sem apostas.'
              : '$apagadas ${apagadas == 1 ? "aposta apagada" : "apostas apagadas"}',
        ),
      );
    } catch (e) {
      debugPrint('Erro ao apagar todas as apostas: $e');
      if (mounted) {
        CustomShowDialog.show(
          context,
          'Erro ao apagar as apostas. Tente novamente.',
        );
      }
    }
  }

  Future<void> recarregarStats() => _carregarStats();

  // ---------------------------------------------------------------------------
  // Conteúdo de cada seção do painel
  // ---------------------------------------------------------------------------

  /// Quantas apostas aguardam verificação.
  ///
  /// O número sai de [bets] — as apostas que `_carregarStats` já carregou —, e
  /// não do `docs.length` da stream do badge. Dois motivos:
  ///
  /// - Aquela query passou a ter teto ([kLimitePendentesBadge]), porque sem
  ///   limite ela baixava a fila inteira de todas as salas só para alimentar um
  ///   contador. Contar os `docs` dela travaria o painel em "100 pendentes"
  ///   numa fila maior.
  /// - `bets` é a fila desta sala, que é exatamente o recorte de todo o resto
  ///   do dashboard (participantes, arrecadado, cotas, verificadas). O
  ///   `collectionGroup` cruza TODAS as salas, então o painel exibia uma
  ///   contagem de escopo diferente das outras ao lado dela.
  ///
  /// E não custa leitura nenhuma: a lista já está em memória.
  ///
  /// O erro da stream continua sendo respeitado. Ele é o sinal de que a
  /// verificação de pendências não está funcionando (regra recusando a query,
  /// índice faltando), e engolir isso mostraria "nada pendente" com a mesma
  /// cara de "tudo verificado" — o oposto do que o admin precisa saber.
  int _totalPendentes(
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> pendentesSnapshot,
  ) {
    if (pendentesSnapshot.hasError) return -1;
    return quantidadePendentes;
  }

  /// Apostas ainda não verificadas pelo admin (as fake, quando o teste de
  /// layout estiver ligado). Também alimenta o selo da seção Apostas na barra
  /// do celular.
  int get quantidadePendentes =>
      fakePendentes?.length ??
      bets.where((b) => b['verificado'] != true).length;

  /// Números da sala (participantes, arrecadado, prêmio, cotas, verificadas,
  /// pendentes). [faixa] é a régua do topo do painel no desktop; `false` é a
  /// pilha de tiles da seção Resumo no celular (ver AdminCardStats.faixa).
  Widget conteudoStats(
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> pendentesSnapshot, {
    bool faixa = true,
  }) {
    return AdminCardStats(
      bets: bets,
      carregandoStats: carregandoStats,
      totalPendentes: _totalPendentes(pendentesSnapshot),
      precoCota: precoCota,
      faixa: faixa,
    );
  }

  /// Constrói o conteúdo de uma seção do painel (participantes, ranking,
  /// sala, configurações). Visão geral tem construtor próprio acima porque
  /// não é uma seção como as outras: no desktop é a faixa fixa do topo, no
  /// celular a seção Resumo.
  ///
  /// [rolarLista] mostra a lista inteira rolando por dentro em vez de
  /// paginada (só o desktop, onde nada mais na tela rola) e
  /// [cabecalhoInterno] desliga o título que a seção desenha por dentro,
  /// quando quem chama já mostra um logo acima.
  Widget conteudoAba(
    AbaAdmin aba,
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> pendentesSnapshot, {
    bool rolarLista = false,
    bool cabecalhoInterno = true,
  }) {
    switch (aba) {
      case AbaAdmin.visaoGeral:
        // Não deveria ser chamado para visaoGeral (ver conteudoStats), mas
        // resolve para os números por segurança em vez de lançar, caso algum
        // código futuro itere kAbasAdmin genericamente sem excluir essa seção.
        return conteudoStats(pendentesSnapshot);
      case AbaAdmin.participantes:
        return AbaParticipantes(
          bets: bets,
          carregando: carregandoStats,
          onLancarManual: abrirDialogApostaManual,
          onEditarValor: abrirDialogEditarValor,
          onRemover: confirmarRemocao,
          onAlternarVerificacao: alternarVerificacaoAposta,
          rolarLista: rolarLista,
        );
      case AbaAdmin.ranking:
        return AbaRanking(
          bets: bets,
          carregando: carregandoStats,
          rolarLista: rolarLista,
        );
      case AbaAdmin.sala:
        return AbaSala(
          salaId: salaId,
          dadosSala: dadosSala,
          carregando: carregandoStats,
          onSalvo: _carregarStats,
          mostrarCabecalho: cabecalhoInterno,
        );
      case AbaAdmin.config:
        return AbaConfig(
          adminUser: adminUser,
          salaId: salaId,
          onModerarChat: abrirModeracaoChat,
          onApagarMensagens: confirmarApagarMensagensChat,
          onApagarApostas: confirmarApagarTodasApostas,
        );
    }
  }

  /// Mensagem de acesso negado (não admin), igual entre os layouts.
  Widget mensagemAcessoNegado() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Text(
        'Você não tem permissão para acessar esta página.',
        style: TextStyle(color: AdminCores.de(context).texto, fontSize: 16),
      ),
    );
  }
}

// Aviso informativo do rodapé dos diálogos de aposta (ex.: "editar o valor
// vai marcar para re-verificação"). Ícone (i) fixo no início da frase, num
// bloco tingido de azul em vez de texto solto — deixa claro que é um aviso,
// não parte do formulário.
class _AvisoInfo extends StatelessWidget {
  final String texto;
  const _AvisoInfo({required this.texto});

  @override
  Widget build(BuildContext context) {
    final cores = AdminCores.de(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cores.azul.withValues(alpha: 0.08),
        borderRadius: AppRadii.circularMd,
        border: Border.all(color: cores.azul.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: cores.azul),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: cores.textoSuave,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
