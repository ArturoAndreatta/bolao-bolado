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
