import 'dart:async';

import 'package:bolao_bolado/components/formatters/formatters.dart';
import 'package:bolao_bolado/components/shared/custom_confirm_dialog.dart';
import 'package:bolao_bolado/components/shared/custom_fields.dart';
import 'package:bolao_bolado/components/shared/custom_show_dialog.dart';
import 'package:bolao_bolado/pages/admin/admin_abas.dart';
import 'package:bolao_bolado/pages/admin/widgets/admin_widgets.dart';
import 'package:bolao_bolado/pages/admin/widgets/exportar_apostas.dart';
import 'package:bolao_bolado/pages/admin/widgets/moderar_chat.dart';
import 'package:bolao_bolado/services/authentication/auth_service.dart';
import 'package:bolao_bolado/services/bet/bet_service.dart';
import 'package:bolao_bolado/services/chat/chat_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  @override
  void initState() {
    super.initState();
    _verificarAcesso();
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

  Future<void> abrirDialogApostaManual() async {
    if (salaId == null) return;

    final nameController = TextEditingController();
    final valueController = TextEditingController();
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

              // Cota do bolão custa R$6, então qualquer valor lançado
              // manualmente precisa ser múltiplo desse preço.
              if (valorNum == 0 || valorNum % 6 != 0) {
                CustomShowDialog.show(
                  dialogContext,
                  "O valor deve ser divisível por 6!",
                );
                return;
              }

              setDialogState(() => salvando = true);
              try {
                await criarApostaManual(
                  salaId: salaId!,
                  nome: nome,
                  valor: valor,
                );
                if (dialogContext.mounted) dialogContext.pop();
                unawaited(_carregarStats());
              } catch (e) {
                debugPrint('Erro ao salvar aposta manual: $e');
                setDialogState(() => salvando = false);
                if (dialogContext.mounted) {
                  CustomShowDialog.show(
                    dialogContext,
                    "Erro ao salvar aposta. Tente novamente.",
                  );
                }
              }
            }

            return AdminDialogFrame(
              titulo: 'Lançar aposta manual',
              salvando: salvando,
              onSalvar: salvar,
              corpo: Form(
                key: formKey,
                child: FocusTraversalGroup(
                  policy: OrderedTraversalPolicy(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                      FocusTraversalOrder(
                        order: const NumericFocusOrder(2),
                        child: CustomField(
                          hint: 'Valor',
                          icon: Icons.attach_money,
                          isNumeric: true,
                          semCentavos: true,
                          controller: valueController,
                          focusNode: valueFocusNode,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => salvar(),
                          maxWidth: 400,
                          isRequired: true,
                          prefix: const Text('R\$ '),
                        ),
                      ),
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

  Future<void> abrirDialogEditarValor(Map<String, dynamic> aposta) async {
    if (salaId == null) return;
    final uid = aposta['uid']?.toString();
    if (uid == null) return;

    final valorAtual = (aposta['valor'] as num?)?.toDouble() ?? 0;
    final estavaVerificado = aposta['verificado'] == true;
    final valueController = TextEditingController(
      text: valorAtual == 0
          ? ''
          : Formatters.moedaSemSimbolo.format(valorAtual).trim().split(',')[0],
    );
    final formKey = GlobalKey<FormState>();
    bool salvando = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> salvar() async {
              if (!formKey.currentState!.validate()) return;
              final valor = valueController.text
                  .trim()
                  .replaceAll('.', '')
                  .replaceAll(',', '.');
              final valorNum = double.tryParse(valor) ?? 0;
              if (valorNum == 0 || valorNum % 6 != 0) {
                CustomShowDialog.show(
                  dialogContext,
                  "O valor deve ser divisível por 6!",
                );
                return;
              }

              setDialogState(() => salvando = true);
              try {
                await editarValorAposta(
                  salaId: salaId!,
                  uid: uid,
                  valor: valor,
                  estavaVerificado: estavaVerificado,
                );
                if (dialogContext.mounted) dialogContext.pop();
                unawaited(_carregarStats());
              } catch (e) {
                debugPrint('Erro ao editar valor: $e');
                setDialogState(() => salvando = false);
                if (dialogContext.mounted) {
                  CustomShowDialog.show(
                    dialogContext,
                    "Erro ao salvar. Tente novamente.",
                  );
                }
              }
            }

            return AdminDialogFrame(
              titulo: 'Editar valor de ${aposta['nome']}',
              salvando: salvando,
              onSalvar: salvar,
              corpo: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomField(
                      hint: 'Valor',
                      icon: Icons.attach_money,
                      isNumeric: true,
                      semCentavos: true,
                      controller: valueController,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => salvar(),
                      maxWidth: 400,
                      isRequired: true,
                      prefix: const Text('R\$ '),
                    ),
                    if (estavaVerificado) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Esta aposta já estava verificada. Editar o valor '
                        'vai marcá-la para re-verificação.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AdminCores.textoSuave,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
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
    } catch (e) {
      debugPrint('Erro ao remover aposta: $e');
      if (mounted) {
        CustomShowDialog.show(context, 'Erro ao remover. Tente novamente.');
      }
    }
  }

  Future<void> alternarVerificacaoAposta(Map<String, dynamic> aposta) async {
    if (salaId == null) return;
    final uid = aposta['uid']?.toString();
    if (uid == null) return;
    final verificar = aposta['verificado'] != true;
    try {
      await alternarVerificacao(
        salaId: salaId!,
        uid: uid,
        verificar: verificar,
      );
      unawaited(_carregarStats());
    } catch (e) {
      debugPrint('Erro ao alternar verificação: $e');
      if (mounted) {
        CustomShowDialog.show(context, 'Erro ao atualizar. Tente novamente.');
      }
    }
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            apagadas == 0
                ? 'O chat já estava vazio.'
                : '$apagadas ${apagadas == 1 ? "mensagem apagada" : "mensagens apagadas"}',
          ),
          backgroundColor: AdminCores.verde,
          behavior: SnackBarBehavior.floating,
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

  Future<void> copiarCsv() async {
    final csv = montarCsvApostas(bets);
    await Clipboard.setData(ClipboardData(text: csv));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${bets.length} apostas copiadas (CSV)'),
          backgroundColor: AdminCores.verde,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
  /// verificadas, pendentes) — compacto, altura própria ao conteúdo.
  Widget conteudoStats(
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> pendentesSnapshot,
  ) {
    return AdminCardStats(
      bets: bets,
      carregandoStats: carregandoStats,
      totalPendentes: _totalPendentes(pendentesSnapshot),
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
        return AbaRanking(
          bets: bets,
          carregando: carregandoStats,
          onExportar: copiarCsv,
        );
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
    return const Padding(
      padding: EdgeInsets.all(40),
      child: Text(
        'Você não tem permissão para acessar esta página.',
        style: TextStyle(color: AdminCores.texto, fontSize: 16),
      ),
    );
  }
}
