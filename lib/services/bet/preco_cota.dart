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
  return ehLotofacil(sorteio) ? kPrecoCotaLotofacil : kPrecoCotaMega;
}

/// Fonte única de verdade para reconhecer uma sala de Lotofácil a partir do
/// campo `sorteio`. Usada tanto pelo preço de cota quanto pelas estatísticas
/// de probabilidade, para as duas nunca divergirem. Aceita `'loto'` (value
/// antigo do dropdown) além de `'lotofacil'`.
bool ehLotofacil(String? sorteio) {
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
