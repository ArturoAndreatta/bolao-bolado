/// Preço de uma cota para cada tipo de sorteio suportado.
///
/// Cada cota representa um jogo apostado. O preço varia conforme o custo
/// real de um jogo simples na loteria (Mega-Sena vs. Lotofácil), então
/// nunca deve ser um valor único fixo.
const double kPrecoCotaMega = 6.0;
const double kPrecoCotaLotofacil = 3.5;

/// Retorna o preço da cota de acordo com o campo `sorteio` salvo na sala
/// (`'lotofacil'` ou `'mega'`/qualquer outro valor, que cai no padrão Mega-Sena).
double precoCotaPara(String? sorteio) {
  return sorteio == 'lotofacil' ? kPrecoCotaLotofacil : kPrecoCotaMega;
}
