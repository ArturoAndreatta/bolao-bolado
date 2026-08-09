import 'dart:math';

import 'package:bolao_bolado/services/bet/preco_cota.dart';

/// Jogos escolhidos pelo participante.
///
/// Dentro do app um jogo é só uma `List<int>` ordenada, e a aposta carrega
/// uma lista deles. No Firestore isso vira:
///
/// ```
/// jogos: [ {numeros: [1,2,3,4,5,6]}, {numeros: [4,8,15,16,23,42]} ]
/// ```
///
/// Array de MAP, e não array de array, porque o Firestore não aceita array
/// como elemento direto de outro array. O map é o embrulho que contorna
/// isso — e deixa espaço para campos por jogo no futuro (conferência de
/// acertos, foto do bilhete) sem migrar de novo.
///
/// Os jogos ficam no MESMO documento da aposta, e não numa subcoleção, por
/// três motivos:
///
/// - A `streamBets()` compartilhada lê só a coleção `Participantes`; uma
///   subcoleção não vem no snapshot, então cada participante viraria um
///   listener extra no Painel ADM — exatamente o custo de latência que a
///   stream compartilhada existe para evitar.
/// - A aposta é gravada num `set()` único. Separada em dois documentos, dava
///   para ficar com o valor novo e os jogos velhos (ou jogos sem aposta).
/// - A regra de segurança precisa de `valor` e `jogos` lado a lado para
///   checar que os jogos cabem nas cotas pagas.
///
/// Teto de jogos por aposta.
///
/// Existe porque `valor` não tem limite obrigatório (sala sem `valorMaximo`),
/// e sortear o restante de uma aposta de R$100 mil geraria dezenas de
/// milhares de jogos — travando a tela e estourando o limite de 1 MiB por
/// documento do Firestore. 500 jogos ocupam ~40 KB, folga suficiente, e bem
/// além do que alguém confere na tela.
const int kMaximoJogosPorAposta = 500;

/// Converte os jogos para o formato gravado no Firestore.
List<Map<String, Object?>> jogosParaDados(List<List<int>> jogos) {
  return jogos.map((jogo) => {'numeros': jogo}).toList();
}

/// Lê os jogos do documento da aposta.
///
/// Aceita o campo legado `numeros` (um único jogo solto na raiz do doc, como
/// era antes de existirem vários jogos) e o devolve como um jogo só — assim
/// apostas gravadas antes desta mudança não perdem os números escolhidos.
/// `jogos` tem prioridade quando os dois existem.
List<List<int>> jogosDeDados(Map<String, dynamic> dados) {
  final jogos = dados['jogos'];
  if (jogos is List) {
    return jogos
        .whereType<Map>()
        .map((jogo) => _numerosDe(jogo['numeros']))
        .where((numeros) => numeros.isNotEmpty)
        .toList();
  }

  final legado = _numerosDe(dados['numeros']);
  return legado.isEmpty ? [] : [legado];
}

List<int> _numerosDe(Object? bruto) {
  if (bruto is! List) return [];
  return bruto.whereType<num>().map((n) => n.toInt()).toList()..sort();
}

/// Soma das cotas consumidas por [jogos] — ver [cotasDoJogo].
int cotasDosJogos(List<List<int>> jogos, String? sorteio) {
  return jogos.fold<int>(
    0,
    (soma, jogo) => soma + cotasDoJogo(jogo.length, sorteio),
  );
}

/// Sorteia um jogo de [tamanho] números na faixa 1..[numeroMaximo],
/// preservando o que já estiver em [fixos] (usado pelo botão que completa
/// uma cartela parcialmente marcada em vez de refazê-la do zero).
List<int> sortearNumeros({
  required int tamanho,
  required int numeroMaximo,
  List<int> fixos = const [],
  Random? aleatorio,
}) {
  final random = aleatorio ?? Random();
  final escolhidos = fixos
      .where((numero) => numero >= 1 && numero <= numeroMaximo)
      .take(tamanho)
      .toSet();
  final alvo = tamanho > numeroMaximo ? numeroMaximo : tamanho;
  // Sorteio por rejeição, em vez de embaralhar a faixa inteira: mesmo no pior
  // caso do app (20 de 25, na Lotofácil) a média fica em ~40 tentativas, mais
  // barato que montar e embaralhar a lista completa a cada jogo gerado.
  while (escolhidos.length < alvo) {
    escolhidos.add(random.nextInt(numeroMaximo) + 1);
  }
  return escolhidos.toList()..sort();
}

/// Como distribuir as cotas que sobram entre jogos, ao sortear o restante.
///
/// As duas trocam a mesma coisa: mais números por bilhete contra mais
/// bilhetes. [maiores] concentra o dinheiro em poucos jogos com mais dezenas
/// marcadas (14 cotas viram dois jogos de 7); [simples] espalha em muitos
/// jogos de tamanho mínimo (14 cotas viram 14 jogos de 6).
enum EstiloSorteio { simples, maiores }

/// Tamanhos de jogo que consomem exatamente [cotas], no estilo pedido.
///
/// Fecha a conta na bucha nos dois estilos, e não por sorte: o jogo simples
/// custa uma cota, então sempre há como gastar o troco de qualquer sobra.
///
/// Em [EstiloSorteio.maiores] a escolha é gulosa — pega o maior jogo que ainda
/// cabe, repete enquanto couber, desce um tamanho e continua. 54 cotas viram
/// 1 de 8 (28) + 3 de 7 (21) + 5 de 6 (5).
///
/// Para em [kMaximoJogosPorAposta] mesmo que ainda sobrem cotas — o excedente
/// fica sem jogo escolhido, como qualquer sobra.
List<int> tamanhosParaCotas(int cotas, String? sorteio, EstiloSorteio estilo) {
  final simples = quantidadeNumerosPara(sorteio);
  final tamanhos = <int>[];
  var restante = cotas;
  var tamanho = estilo == EstiloSorteio.simples ? simples : kTamanhoMaximoJogo;

  while (restante > 0 && tamanhos.length < kMaximoJogosPorAposta) {
    final custo = cotasDoJogo(tamanho, sorteio);
    if (custo > 0 && custo <= restante) {
      tamanhos.add(tamanho);
      restante -= custo;
      continue;
    }
    // Não coube: desce um tamanho. Abaixo do jogo simples não há o que tentar.
    tamanho--;
    if (tamanho < simples) break;
  }
  return tamanhos;
}

/// Resumo curto de uma composição de jogos, do maior para o menor:
/// `1×8 · 3×7 · 5×6`. Usado para o usuário ver o que cada estilo produz
/// ANTES de sortear.
String resumoDeTamanhos(List<int> tamanhos) {
  final contagem = <int, int>{};
  for (final tamanho in tamanhos) {
    contagem[tamanho] = (contagem[tamanho] ?? 0) + 1;
  }
  final chaves = contagem.keys.toList()..sort((a, b) => b.compareTo(a));
  return chaves.map((tamanho) => '${contagem[tamanho]}×$tamanho').join(' · ');
}

/// Preenche o orçamento que sobra com jogos sorteados, preservando
/// [jogosAtuais]. É o atalho para quem apostou alto e não quer marcar dezenas
/// de cartelas na mão.
List<List<int>> sortearJogosRestantes({
  required List<List<int>> jogosAtuais,
  required int cotasDisponiveis,
  required String? sorteio,
  EstiloSorteio estilo = EstiloSorteio.simples,
  Random? aleatorio,
}) {
  final numeroMaximo = numeroMaximoPara(sorteio);
  final restantes = cotasDisponiveis - cotasDosJogos(jogosAtuais, sorteio);
  // O teto vale para a aposta inteira, não só para os jogos novos. O clamp
  // segura o caso de já haver mais jogos que o teto: take() não aceita
  // negativo.
  final vagas = (kMaximoJogosPorAposta - jogosAtuais.length).clamp(
    0,
    kMaximoJogosPorAposta,
  );
  final novos = tamanhosParaCotas(restantes, sorteio, estilo)
      .take(vagas)
      .map(
        (tamanho) => sortearNumeros(
          tamanho: tamanho,
          numeroMaximo: numeroMaximo,
          aleatorio: aleatorio,
        ),
      );

  return [...jogosAtuais, ...novos];
}
