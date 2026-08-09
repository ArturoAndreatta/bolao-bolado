import 'package:bolao_bolado/pages/participants/participants_estilo_entrada.dart';
import 'package:flutter/foundation.dart';

/// Flags/preferências acionáveis em runtime pelo painel de admin.
///
/// Só o CONTROLE fica restrito a admin (o Painel ADM é rota protegida por
/// isAdmin). O que cada notifier faz com o valor varia:
///
/// - [forcarSkeletonGlobal] é uma flag de TESTE pontual, só em memória — ao
///   recarregar o app volta ao padrão. De propósito: é usada para checar o
///   visual do skeleton, e persistir arriscaria alguém esquecer ligada e
///   travar o app para usuários reais.
/// - Os demais ([intervaloSimulacaoMsGlobal], [estiloEntradaGlobal],
///   [quantidadeRajadaSimulacaoGlobal], [atrasoRajadaSimulacaoMsGlobal]) são
///   PREFERÊNCIAS globais de verdade: persistem no campo `configuracoes` da
///   sala principal (ver services/configuracoes/configuracoes_service.dart)
///   e valem para qualquer um com o app aberto, não só para quem está no
///   Painel ADM. O valor inicial aqui é só o padrão até a primeira leitura
///   do Firestore chegar — ver `ouvirConfiguracoesGlobais()`, chamada uma
///   vez no boot (main.dart).

/// Quando `true`, força o skeleton loading das telas Minha Aposta,
/// Participantes e Chat a ficar travado (nunca sai do estado de loading).
/// Alternável pelo switch "Forçar skeleton" no Painel ADM.
final ValueNotifier<bool> forcarSkeletonGlobal = ValueNotifier(false);

/// Intervalo (em milissegundos) entre dois passos do simulador de apostas.
/// Ajustável pelo slider "Ritmo da simulação" no Painel ADM.
///
/// Fica aqui, e não dentro do [SimuladorApostas], porque o controle está numa
/// tela (Painel ADM) e o simulador vive em outra (Participantes): um notifier
/// global é o que permite mudar o ritmo COM a simulação já rodando, sem as
/// duas telas precisarem se conhecer. O valor de fato persiste no Firestore —
/// ver a nota no topo do arquivo.
final ValueNotifier<int> intervaloSimulacaoMsGlobal = ValueNotifier(
  kIntervaloSimulacaoPadraoMs,
);

/// Padrão de 900ms — o valor fixo que o simulador usava antes do ritmo virar
/// configurável.
const int kIntervaloSimulacaoPadraoMs = 900;

/// Piso do intervalo. Abaixo disso cada passo (leitura da coleção + escrita)
/// não termina antes do tick seguinte: o simulador já pula ticks sobrepostos,
/// então o ritmo real deixaria de acompanhar o slider e só sobraria carga de
/// escrita no Firestore.
const int kIntervaloSimulacaoMinMs = 100;

/// Teto do intervalo (10s por passo) — mais lento que isso a tela parece
/// travada em vez de simulando.
const int kIntervaloSimulacaoMaxMs = 10000;

/// Estilo da animação de entrada de uma aposta nova na tabela.
///
/// Mesmo arranjo do ritmo da simulação: o controle está no Painel ADM e a
/// animação acontece na tela de Participantes, então um notifier global é o
/// que permite trocar o estilo com a outra tela já aberta e ver o efeito na
/// aposta seguinte. Persiste no Firestore — ver a nota no topo do arquivo.
final ValueNotifier<EstiloEntrada> estiloEntradaGlobal = ValueNotifier(
  EstiloEntrada.batida,
);

/// Quantas apostas fake o simulador cria de uma vez em cada inclusão (uma
/// "rajada"). Ajustável pelo campo "Apostas por rajada" no Painel ADM.
/// Persiste no Firestore — ver a nota no topo do arquivo.
///
/// `1` reproduz o comportamento original (uma aposta por vez). Acima disso,
/// o atraso entre cada uma dentro da rajada é [atrasoRajadaSimulacaoMsGlobal].
final ValueNotifier<int> quantidadeRajadaSimulacaoGlobal = ValueNotifier(
  kQuantidadeRajadaSimulacaoPadrao,
);

/// Padrão de 1 (rajada desligada) — igual ao comportamento antes deste campo
/// existir.
const int kQuantidadeRajadaSimulacaoPadrao = 1;

/// Teto de apostas por rajada. Acima disso a "rajada" deixa de simular gente
/// apostando em sequência e vira só uma forma cara de pedir muitos passos do
/// simulador de uma vez.
const int kQuantidadeRajadaSimulacaoMax = 10;

/// Atraso (em milissegundos) entre cada aposta DENTRO de uma rajada — não
/// confundir com [intervaloSimulacaoMsGlobal], que é o intervalo entre um
/// PASSO do simulador e o próximo. Ajustável pelo slider "Atraso entre
/// apostas da rajada" no Painel ADM. Persiste no Firestore — ver a nota no
/// topo do arquivo.
///
/// `0` faz a rajada inteira sair no mesmo instante (mesmo batch), como a
/// antiga "aposta dupla" fazia.
final ValueNotifier<int> atrasoRajadaSimulacaoMsGlobal = ValueNotifier(
  kAtrasoRajadaSimulacaoPadraoMs,
);

/// Padrão de 500ms entre apostas da mesma rajada.
const int kAtrasoRajadaSimulacaoPadraoMs = 500;

/// Teto do atraso entre apostas da rajada (5s) — mais lento que isso não é
/// mais "gente apostando em sequência rápida", é só o ritmo normal do
/// simulador duplicado.
const int kAtrasoRajadaSimulacaoMaxMs = 5000;

/// Quando `true` (padrão, igual ao comportamento original), o simulador
/// grava as apostas fake no Firestore de verdade — é assim que elas entram
/// na tabela real e podem ser conferidas/apagadas depois. Quando `false`, o
/// simulador passa a manter as apostas fake só em memória (dentro do próprio
/// [SimuladorApostas] da sessão), sem nenhuma leitura/escrita no banco: serve
/// para testar só a ANIMAÇÃO da tela sem sujar dados nem gastar cota do
/// Firestore, mas as apostas somem ao sair da tela de Participantes (F5,
/// trocar de rota) já que nunca foram persistidas.
///
/// Ajustável pelo switch "Gravar no Firestore" no Painel ADM. Persiste no
/// Firestore — ver a nota no topo do arquivo (a flag em si é sempre
/// gravada, mesmo que ela própria diga "não grave as apostas fake").
final ValueNotifier<bool> gravarSimulacaoFirestoreGlobal = ValueNotifier(true);
