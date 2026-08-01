/// Limite de valor por aposta configurado na sala (campo `valorMaximo`).
///
/// O campo é opcional: sala sem `valorMaximo` (ou com valor <= 0) não tem
/// teto e aceita qualquer aposta que feche cotas inteiras. Por isso a
/// ausência do limite é representada por `null` em vez de zero — zero seria
/// indistinguível de "teto de R$0", que travaria a sala inteira.
///
/// Funções puras, sem Firestore, para o limite poder ser testado sem mocks:
/// é uma regra que decide se dinheiro real entra ou não no bolão.
library;

/// Lê o `valorMaximo` cru do documento da sala e devolve o teto efetivo, ou
/// `null` quando a sala não impõe limite.
///
/// Aceita `num` (como o Firestore devolve) e normaliza valores inúteis
/// (nulos, negativos ou zero) para `null`: um teto não-positivo só poderia
/// rejeitar toda e qualquer aposta, então é tratado como "sem limite".
double? valorMaximoDe(Object? bruto) {
  final valor = (bruto as num?)?.toDouble();
  if (valor == null || valor <= 0) return null;
  return valor;
}

/// O valor apostado respeita o teto da sala?
///
/// Sem teto ([valorMaximo] nulo), qualquer valor passa. O limite é
/// inclusivo: apostar exatamente o máximo configurado é válido — o campo é
/// exibido ao usuário como "Valor máx. aposta", e um teto que recusasse o
/// próprio número mostrado na tela seria incoerente.
bool valorRespeitaMaximo(double valor, double? valorMaximo) {
  if (valorMaximo == null) return true;
  // Comparação em centavos inteiros, mesmo motivo de
  // valorFechaCotasInteiras: com cota fracionada (Lotofácil, R$3,50) o valor
  // apostado tem centavos, e comparar doubles direto faz uma aposta igual ao
  // teto ser recusada por resíduo de ponto flutuante.
  return (valor * 100).round() <= (valorMaximo * 100).round();
}
