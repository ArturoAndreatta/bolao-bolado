import 'dart:async';

import 'package:bolao_bolado/components/formatters/formatters.dart';
import 'package:bolao_bolado/components/shared/custom_confirm_dialog.dart';
import 'package:bolao_bolado/components/shared/custom_fields.dart';
import 'package:bolao_bolado/components/shared/custom_show_dialog.dart';
import 'package:bolao_bolado/components/shared/snackbar_deslizante.dart';
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
/// dados, diálogos, CRUD de apostas/sala), independente de como o dashboard
/// é desenhado na tela — [PainelAdmin] aplica este mixin e só monta a grade
/// de cards, sem duplicar nenhuma regra de negócio aqui.
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
  final Stream<QuerySnapshot<Map<String, dynamic>>> apostasPendentesStream =
      streamApostasPendentes();

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
      unawaited(_carregarStats());
    });
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
    });

    if (isAdmin) {
      unawaited(_carregarStats());
    }
  }

  Future<void> _carregarStats() async {
    // As duas partem da mesma sala (já memoizada) mas não dependem uma da
    // outra: em série o painel esperava dois round-trips em fila.
    final (novasBets, novosDados) = await (
      getBets(),
      getDadosSalaPrincipal(),
    ).wait;
    if (!mounted) return;
    setState(() {
      bets = novasBets;
      dadosSala = novosDados;
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
    String valorInicial = '',
    String? avisoRodape,
    required Future<void> Function(String nome, String valor) onSalvar,
    required String mensagemErro,
  }) async {
    final nameController = TextEditingController();
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
                        const SizedBox(height: 12),
                        Text(
                          avisoRodape,
                          style: TextStyle(
                            fontSize: 12,
                            color: AdminCores.de(dialogContext).textoSuave,
                          ),
                        ),
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
      titulo: 'Editar valor de ${aposta['nome']}',
      comCampoNome: false,
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
      onSalvar: (_, valor) => editarValorAposta(
        salaId: salaId!,
        uid: uid,
        valor: valor,
        estavaVerificado: estavaVerificado,
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

  Future<void> recarregarStats() => _carregarStats();

  // ---------------------------------------------------------------------------
  // Conteúdo de cada seção do dashboard
  // ---------------------------------------------------------------------------

  int _totalPendentes(
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> pendentesSnapshot,
  ) {
    if (fakePendentes != null) return fakePendentes!.length;
    if (pendentesSnapshot.hasError) return -1;
    return pendentesSnapshot.data?.docs.length ?? 0;
  }

  /// Card de estatísticas (participantes, arrecadado, prêmio, cotas,
  /// verificadas, pendentes). [bentoGrid] só vale `true` no layout desktop
  /// (altura fixa do _CardSecao); no fichário mobile a folha rola dentro de
  /// um SingleChildScrollView, então o card precisa encolher pro próprio
  /// conteúdo em vez de usar Expanded (ver AdminCardStats.bentoGrid).
  Widget conteudoStats(
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> pendentesSnapshot, {
    bool bentoGrid = true,
  }) {
    return AdminCardStats(
      bets: bets,
      carregandoStats: carregandoStats,
      totalPendentes: _totalPendentes(pendentesSnapshot),
      precoCota: precoCota,
      bentoGrid: bentoGrid,
    );
  }

  /// Constrói o conteúdo de uma seção do dashboard (participantes, ranking,
  /// sala, configurações). Visão geral tem construtor próprio acima porque
  /// virou card separado, não uma "aba" única. Card de pendentes foi
  /// removido do dashboard — verificação individual de aposta segue
  /// disponível na seção Participantes (onAlternarVerificacao) e o
  /// lançamento manual pelo botão "Lançar" do mesmo card.
  Widget conteudoAba(
    AbaAdmin aba,
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> pendentesSnapshot,
  ) {
    switch (aba) {
      case AbaAdmin.visaoGeral:
        // Não deveria ser chamado para visaoGeral (ver conteudoStats/
        // conteudoPendentes), mas resolve para o card de stats por
        // segurança em vez de lançar, caso algum código futuro itere
        // kAbasAdmin genericamente sem excluir essa seção.
        return conteudoStats(pendentesSnapshot);
      case AbaAdmin.participantes:
        return AbaParticipantes(
          bets: bets,
          carregando: carregandoStats,
          onLancarManual: abrirDialogApostaManual,
          onEditarValor: abrirDialogEditarValor,
          onRemover: confirmarRemocao,
          onAlternarVerificacao: alternarVerificacaoAposta,
        );
      case AbaAdmin.ranking:
        return AbaRanking(bets: bets, carregando: carregandoStats);
      case AbaAdmin.sala:
        return AbaSala(
          salaId: salaId,
          dadosSala: dadosSala,
          carregando: carregandoStats,
          onSalvo: _carregarStats,
        );
      case AbaAdmin.config:
        return AbaConfig(
          adminUser: adminUser,
          salaId: salaId,
          onModerarChat: abrirModeracaoChat,
          onApagarMensagens: confirmarApagarMensagensChat,
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
