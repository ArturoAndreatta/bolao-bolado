class Bet {
  String nome;
  int valor;
  Bet({required this.nome, required this.valor});

  Map<String, dynamic> toMap() {
    return {'nome': nome, 'valor': valor};
  }

  Bet.fromMap(Map<String, dynamic> map)
    : nome = map['nome'],
      valor = map['valor'];
}
