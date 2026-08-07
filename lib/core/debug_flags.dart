import 'package:bolao_bolado/pages/participants/participants_estilo_entrada.dart';
import 'package:flutter/foundation.dart';

/// Flags de debug/dev acionáveis em runtime pelo painel de admin.
///
/// Só refletem para quem abre o Painel ADM (rota protegida por isAdmin), então
/// o estado não vaza para usuários comuns. Não persiste entre sessões: ao
/// recarregar o app, volta ao padrão.

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
/// duas telas precisarem se conhecer.
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
/// aposta seguinte.
final ValueNotifier<EstiloEntrada> estiloEntradaGlobal = ValueNotifier(
  EstiloEntrada.batida,
);
