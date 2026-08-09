import 'dart:async';

import 'package:bolao_bolado/core/debug_flags.dart';
import 'package:bolao_bolado/pages/participants/participants_estilo_entrada.dart';
import 'package:bolao_bolado/services/bet/bet_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Onde ficam as preferências do simulador de apostas: ritmo, tamanho da
/// rajada, atraso entre apostas da rajada, se grava no Firestore de
/// verdade, e estilo da animação de entrada — todas configuráveis pelo
/// Painel ADM.
///
/// Vivem dentro do campo `configuracoes` do doc da SALA (`Salas/{salaId}`),
/// não numa coleção à parte — o app tem hoje uma única sala (a principal),
/// mas o modelo já prevê múltiplas salas no futuro, e cada uma terá seu
/// próprio simulador/ritmo. `forcarSkeletonGlobal` (a quarta flag do Painel
/// ADM) fica de fora de propósito: é uma flag de teste pontual que trava a
/// tela em loading, e persistir ela arrisca alguém esquecer ligada e travar
/// o app para usuários reais.
const String _campo = 'configuracoes';

/// Cast defensivo do sub-mapa `configuracoes`: o Firestore (e testes que
/// passam `Map<dynamic, dynamic>` literal) nem sempre entregam
/// `Map<String, dynamic>` diretamente.
Map<String, dynamic>? _configDe(Map<String, dynamic>? dadosSala) {
  final valor = dadosSala?[_campo];
  if (valor is Map) return Map<String, dynamic>.from(valor);
  return null;
}

/// Extrai o intervalo salvo em `configuracoes.intervaloSimulacaoMs` da sala,
/// já dentro dos limites permitidos ([kIntervaloSimulacaoMinMs]/
/// [kIntervaloSimulacaoMaxMs]).
///
/// `null` quando o campo não existe (nunca escrito) — quem chama decide o
/// padrão nesse caso, em vez desta função aplicar um às cegas. Função pura,
/// sem Firestore, para poder testar a regra de clamp isolada (mesmo motivo
/// de [calcularCotasEPremios] em bet_service.dart).
int? intervaloDeConfiguracoes(Map<String, dynamic>? dadosSala) {
  final config = _configDe(dadosSala);
  final intervalo = config?['intervaloSimulacaoMs'] as int?;
  if (intervalo == null) return null;
  return intervalo.clamp(kIntervaloSimulacaoMinMs, kIntervaloSimulacaoMaxMs);
}

/// Extrai o estilo de animação salvo em `configuracoes.estiloEntrada` da sala.
///
/// `null` quando o campo não existe, OU quando o nome salvo não corresponde
/// a nenhum [EstiloEntrada] atual — o que acontece se um estilo for removido
/// do enum depois de já ter sido gravado por alguém. Nos dois casos quem
/// chama deve MANTER o valor atual em vez de aplicar um padrão, porque um
/// nome desconhecido não é o mesmo que "sem configuração".
EstiloEntrada? estiloDeConfiguracoes(Map<String, dynamic>? dadosSala) {
  final config = _configDe(dadosSala);
  final nome = config?['estiloEntrada'] as String?;
  if (nome == null) return null;
  return EstiloEntrada.values.where((e) => e.name == nome).firstOrNull;
}

/// Extrai a quantidade de apostas por rajada salva em
/// `configuracoes.quantidadeRajada` da sala, já dentro dos limites permitidos
/// (1–[kQuantidadeRajadaSimulacaoMax]).
///
/// `null` quando o campo não existe (nunca escrito) — quem chama decide o
/// padrão nesse caso, mesmo arranjo de [intervaloDeConfiguracoes].
int? quantidadeRajadaDeConfiguracoes(Map<String, dynamic>? dadosSala) {
  final config = _configDe(dadosSala);
  final quantidade = config?['quantidadeRajada'] as int?;
  if (quantidade == null) return null;
  return quantidade.clamp(1, kQuantidadeRajadaSimulacaoMax);
}

/// Extrai o atraso entre apostas da rajada salvo em
/// `configuracoes.atrasoRajadaMs` da sala, já dentro dos limites permitidos
/// (0–[kAtrasoRajadaSimulacaoMaxMs]).
///
/// `null` quando o campo não existe (nunca escrito) — quem chama decide o
/// padrão nesse caso, mesmo arranjo de [intervaloDeConfiguracoes].
int? atrasoRajadaDeConfiguracoes(Map<String, dynamic>? dadosSala) {
  final config = _configDe(dadosSala);
  final atraso = config?['atrasoRajadaMs'] as int?;
  if (atraso == null) return null;
  return atraso.clamp(0, kAtrasoRajadaSimulacaoMaxMs);
}

/// Extrai a flag de gravação no Firestore salva em
/// `configuracoes.gravarSimulacaoFirestore` da sala.
///
/// `null` quando o campo não existe (nunca escrito) — quem chama decide o
/// padrão nesse caso, mesmo arranjo de [intervaloDeConfiguracoes].
bool? gravarSimulacaoFirestoreDeConfiguracoes(Map<String, dynamic>? dadosSala) {
  final config = _configDe(dadosSala);
  return config?['gravarSimulacaoFirestore'] as bool?;
}

/// Começa a observar `configuracoes` da sala principal e mantém
/// [intervaloSimulacaoMsGlobal], [estiloEntradaGlobal],
/// [quantidadeRajadaSimulacaoGlobal] e [atrasoRajadaSimulacaoMsGlobal]
/// sincronizados com o que está salvo — em qualquer aba, de qualquer usuário
/// (ver a doc dos notifiers em debug_flags.dart).
///
/// Chamado uma vez no boot do app (main.dart), sem `await`: os notifiers já
/// nascem com o padrão local, e passam a refletir o Firestore assim que a
/// primeira emissão chegar — igual ao padrão já usado para
/// `buscarSalaPrincipal()`, que também não bloqueia a primeira tela.
///
/// A leitura de `Salas/{id}` já é pública para qualquer autenticado (ver
/// firestore.rules), incluindo anônimo: o estilo de animação afeta a tela de
/// Participantes, visível antes do login.
Future<StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>
ouvirConfiguracoesGlobais() async {
  final sala = await buscarSalaPrincipal();
  return sala.reference.snapshots().listen((doc) {
    final dados = doc.data();
    final intervalo = intervaloDeConfiguracoes(dados);
    if (intervalo != null) intervaloSimulacaoMsGlobal.value = intervalo;

    final estilo = estiloDeConfiguracoes(dados);
    if (estilo != null) estiloEntradaGlobal.value = estilo;

    final quantidadeRajada = quantidadeRajadaDeConfiguracoes(dados);
    if (quantidadeRajada != null) {
      quantidadeRajadaSimulacaoGlobal.value = quantidadeRajada;
    }

    final atrasoRajada = atrasoRajadaDeConfiguracoes(dados);
    if (atrasoRajada != null) {
      atrasoRajadaSimulacaoMsGlobal.value = atrasoRajada;
    }

    final gravar = gravarSimulacaoFirestoreDeConfiguracoes(dados);
    if (gravar != null) gravarSimulacaoFirestoreGlobal.value = gravar;
  }, onError: (Object _) {});
  // Erro de leitura (ex: sem rede na primeira abertura) não derruba o app:
  // os notifiers seguem com o padrão local até a próxima emissão chegar.
}

/// Grava um campo dentro de `configuracoes` da sala principal, sem tocar nos
/// demais (merge no subcaminho, não no doc inteiro — evita apagar prêmio,
/// chave PIX etc. e evita que duas configs escritas em sequência rápida uma
/// sobrescreva a outra).
Future<void> _salvarCampoConfiguracao(String campo, Object? valor) async {
  final sala = await buscarSalaPrincipal();
  await sala.reference.set({
    _campo: {campo: valor},
  }, SetOptions(mergeFields: ['$_campo.$campo']));
}

/// Grava o ritmo do simulador da sala principal. Escrita só permitida a
/// admin (ver firestore.rules) — o Painel ADM é o único chamador.
///
/// Não atualiza [intervaloSimulacaoMsGlobal] diretamente: quem faz isso é o
/// listener de [ouvirConfiguracoesGlobais], reagindo à própria escrita assim
/// que o Firestore confirma. Escrever local E remoto aqui arriscaria os dois
/// divergirem se a escrita falhasse silenciosamente.
Future<void> salvarRitmoSimulacao(int intervaloMs) {
  return _salvarCampoConfiguracao('intervaloSimulacaoMs', intervaloMs);
}

/// Grava o estilo de animação de entrada da sala principal. Mesma observação
/// de [salvarRitmoSimulacao] sobre não atualizar o notifier localmente.
Future<void> salvarEstiloEntrada(EstiloEntrada estilo) {
  return _salvarCampoConfiguracao('estiloEntrada', estilo.name);
}

/// Grava a quantidade de apostas por rajada da sala principal. Mesma
/// observação de [salvarRitmoSimulacao] sobre não atualizar o notifier
/// localmente.
Future<void> salvarQuantidadeRajada(int quantidade) {
  return _salvarCampoConfiguracao('quantidadeRajada', quantidade);
}

/// Grava o atraso entre apostas da rajada da sala principal. Mesma
/// observação de [salvarRitmoSimulacao] sobre não atualizar o notifier
/// localmente.
Future<void> salvarAtrasoRajada(int atrasoMs) {
  return _salvarCampoConfiguracao('atrasoRajadaMs', atrasoMs);
}

/// Grava a flag de gravação no Firestore da sala principal. Mesma
/// observação de [salvarRitmoSimulacao] sobre não atualizar o notifier
/// localmente.
Future<void> salvarGravarSimulacaoFirestore(bool ativo) {
  return _salvarCampoConfiguracao('gravarSimulacaoFirestore', ativo);
}
