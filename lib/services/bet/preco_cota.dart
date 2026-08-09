/// Preço de uma cota para cada tipo de sorteio suportado.
///
/// Cada cota representa um jogo apostado. O preço varia conforme o custo
/// real de um jogo simples na loteria (Mega-Sena vs. Lotofácil), então
/// nunca deve ser um valor único fixo.
const double kPrecoCotaMega = 6.0;
const double kPrecoCotaLotofacil = 3.5;

/// Retorna o preço da cota de acordo com o campo `sorteio` salvo na sala
/// (`'lotofacil'` ou `'mega'`/qualquer outro valor, que cai no padrão Mega-Sena).
///
/// Aceita também `'loto'` por compatibilidade: esse era o value antigo do
/// dropdown de cadastro, então salas criadas antes da correção têm `sorteio`
/// gravado como `'loto'` no Firestore e continuariam calculando cota errada
/// se não fossem reconhecidas aqui.
double precoCotaPara(String? sorteio) {
  return isLotofacil(sorteio) ? kPrecoCotaLotofacil : kPrecoCotaMega;
}

/// Fonte única de verdade para reconhecer uma sala de Lotofácil a partir do
/// campo `sorteio`. Usada tanto pelo preço de cota quanto pelas estatísticas
/// de probabilidade, para as duas nunca divergirem. Aceita `'loto'` (value
/// antigo do dropdown) além de `'lotofacil'`.
bool isLotofacil(String? sorteio) {
  return sorteio == 'lotofacil' || sorteio == 'loto';
}

/// O valor apostado fecha um número inteiro de cotas ao preço de [precoCota]?
///
/// A comparação é feita em centavos (inteiros) de propósito: com `%` sobre
/// double, um preço fracionário como 3,50 dá resto ≠ 0 mesmo em valores
/// válidos (7.0 % 3.5 não é confiavelmente 0 em ponto flutuante), o que
/// rejeitaria apostas corretas de Lotofácil.
///
/// Zero nunca é válido: não é aposta, ainda que seja múltiplo de qualquer
/// preço.
bool valorFechaCotasInteiras(double valor, double precoCota) {
  if (valor <= 0) return false;
  final valorCentavos = (valor * 100).round();
  final cotaCentavos = (precoCota * 100).round();
  if (cotaCentavos <= 0) return false;
  return valorCentavos % cotaCentavos == 0;
}

/// Move [valor] em [deltaCotas] cotas, mantendo o resultado num múltiplo
/// exato de [precoCota] e dentro do teto [valorMaximo] (quando houver).
///
/// Usada pelos botões +/- do campo Valor. Toda a conta é feita em CENTAVOS
/// INTEIROS: o degrau é o preço da cota, que pode ser fracionário (Lotofácil,
/// R$3,50), e somar/arredondar 3.5 repetidamente em double acumula erro — o
/// stepper acabaria produzindo um valor que [valorFechaCotasInteiras] recusa.
///
/// Valor "quebrado" digitado na mão é alinhado ao múltiplo de cota mais
/// próximo na direção do movimento antes de aplicar o passo. O piso é sempre
/// uma cota: o campo nunca desce a zero pelos botões.
double ajustarValorEmCotas({
  required double valor,
  required int deltaCotas,
  required double precoCota,
  double? valorMaximo,
}) {
  final cotaCentavos = (precoCota * 100).round();
  if (cotaCentavos <= 0) return valor;

  final atualCentavos = (valor * 100).round();
  // Subindo, parte do múltiplo abaixo do valor atual; descendo, do de cima.
  final baseCentavos = deltaCotas > 0
      ? (atualCentavos ~/ cotaCentavos) * cotaCentavos
      : ((atualCentavos + cotaCentavos - 1) ~/ cotaCentavos) * cotaCentavos;

  // Teto: a maior quantidade de cotas inteiras que cabe no valorMaximo. Sala
  // com teto menor que uma cota não tem valor válido a oferecer, então o piso
  // de uma cota prevalece (senão o clamp inverteria, com min > max).
  final maximoCentavos = valorMaximo == null
      ? null
      : ((valorMaximo * 100).round() ~/ cotaCentavos) * cotaCentavos;
  final tetoCentavos = maximoCentavos == null
      ? null
      : (maximoCentavos < cotaCentavos ? cotaCentavos : maximoCentavos);

  var novoCentavos = baseCentavos + deltaCotas * cotaCentavos;
  if (novoCentavos < cotaCentavos) novoCentavos = cotaCentavos;
  if (tetoCentavos != null && novoCentavos > tetoCentavos) {
    novoCentavos = tetoCentavos;
  }

  return novoCentavos / 100;
}

/// Preço da cota formatado em pt-BR para mensagens ao usuário: sem casas
/// decimais quando a cota é inteira (`6`), com vírgula quando é fracionária
/// (`3,50`).
String precoCotaFormatado(double precoCota) {
  return precoCota % 1 == 0
      ? precoCota.toStringAsFixed(0)
      : precoCota.toStringAsFixed(2).replaceAll('.', ',');
}

/// Maior número que pode ser escolhido no jogo do sorteio da sala
/// (Lotofácil vai de 1 a 25, Mega-Sena de 1 a 60).
int numeroMaximoPara(String? sorteio) => isLotofacil(sorteio) ? 25 : 60;

/// Quantidade de números que compõem um jogo simples do sorteio da sala
/// (Lotofácil: 15 números; Mega-Sena: 6 números). Usada tanto para limitar a
/// escolha no modal quanto para validar os números salvos na aposta.
int quantidadeNumerosPara(String? sorteio) => isLotofacil(sorteio) ? 15 : 6;

/// Maior jogo aceito pela Caixa. Vale 20 para os dois sorteios suportados
/// (Mega-Sena vai de 6 a 20 números, Lotofácil de 15 a 20), por isso é uma
/// constante e não uma função de `sorteio`.
const int kTamanhoMaximoJogo = 20;

/// Quantas cotas um jogo de [tamanho] números consome no sorteio da sala.
///
/// Um jogo com mais números que o simples equivale a apostar TODAS as
/// combinações simples que cabem dentro dele, e é exatamente assim que a
/// Caixa cobra: um jogo de 7 na Mega custa C(7,6) = 7 vezes o jogo de 6
/// (R$42), um de 16 na Lotofácil custa C(16,15) = 16 vezes o de 15 (R$56).
///
/// Isso é o que mantém a cota como unidade única de dinheiro do bolão: jogo
/// maior não introduz um preço novo, só consome um número inteiro de cotas.
/// O rateio do prêmio continua sendo feito por cota, sem saber que jogos
/// existem.
///
/// Devolve 0 para tamanho fora da faixa válida do sorteio.
int cotasDoJogo(int tamanho, String? sorteio) {
  final simples = quantidadeNumerosPara(sorteio);
  if (tamanho < simples || tamanho > kTamanhoMaximoJogo) return 0;
  return combinacoes(tamanho, simples);
}

/// C(n, k) por multiplicações e divisões alternadas, sem passar por fatorial.
///
/// O produto parcial é sempre divisível pelo passo atual, então cada divisão
/// inteira é exata. Importa porque `int` na web é o `number` do JS (53 bits
/// de precisão): 20! sozinho já passa disso, enquanto o maior intermediário
/// deste laço para C(20,6) é ~232 mil.
int combinacoes(int n, int k) {
  if (k < 0 || k > n) return 0;
  // Simetria C(n,k) == C(n,n-k): iterar pelo menor dos dois encurta o laço e
  // segura os intermediários mais baixos.
  final passos = k > n - k ? n - k : k;
  var resultado = 1;
  for (var i = 1; i <= passos; i++) {
    resultado = resultado * (n - passos + i) ~/ i;
  }
  return resultado;
}
