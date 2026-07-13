import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Prefixo usado nos uids dos participantes fake gerados pela simulação,
/// permitindo identificá-los e removê-los sem afetar apostas reais.
const String kPrefixoUidSimulado = 'sim-';

final List<String> _nomesSimulados = [
  'Carlos Silva',
  'Fernanda Costa',
  'João Pereira',
  'Mariana Alves',
  'Rafael Souza',
  'Juliana Lima',
  'Bruno Rocha',
  'Camila Dias',
  'Eduardo Nunes',
  'Patrícia Gomes',
  'Lucas Martins',
  'Aline Ferreira',
  'Diego Barbosa',
  'Vanessa Ribeiro',
  'Thiago Cardoso',
  'Renata Almeida',
  'Felipe Araújo',
  'Bianca Teixeira',
  'Marcos Vinícius',
  'Larissa Moura',
  'Gabriel Henrique',
  'Isabela Fonseca',
  'Rodrigo Castro',
  'Beatriz Monteiro',
  'André Luiz Pinto',
  'Natália Correia',
  'Gustavo Farias',
  'Priscila Rezende',
  'Vinícius Batista',
  'Débora Carvalho',
  'Leonardo Duarte',
  'Amanda Siqueira',
  'Matheus Barros',
  'Carolina Peixoto',
  'Fábio Moreira',
  'Letícia Andrade',
  'Rogério Camargo',
  'Sabrina Vasconcelos',
  'Alexandre Nogueira',
  'Tatiane Xavier',
  'Henrique Bezerra',
  'Cristiane Melo',
  'Daniel Cavalcanti',
  'Simone Guimarães',
  'Paulo Ricardo Lopes',
  'Viviane Tavares',
  'Marcelo Pinheiro',
  'Adriana Sales',
  'César Augusto Reis',
  'Luana Cunha',
  'Otávio Braga',
  'Roberta Freire',
  'Igor Machado',
  'Sandra Prado',
  'Fernando Teles',
  'Michele Azevedo',
  'Wagner Coutinho',
  'Elaine Portela',
  'Márcio Sampaio',
  'Cíntia Ramalho',
];

/// Gera/edita/remove apostas fake (uids prefixados com [kPrefixoUidSimulado])
/// na sala principal, simulando o movimento de muitas pessoas apostando.
/// Uso exclusivo para visualização/teste de layout com muitos participantes;
/// nunca deve ser exposto a usuários não-admin.
class SimuladorApostas {
  final _random = Random();
  bool _rodando = false;
  bool _passoEmAndamento = false;
  Timer? _timer;

  bool get rodando => _rodando;

  void iniciar(String salaId) {
    if (_rodando) return;
    _rodando = true;
    _timer = Timer.periodic(const Duration(milliseconds: 900), (_) async {
      // Evita sobrepor passos: se a leitura+escrita do passo anterior ainda
      // não terminou, duas execuções concorrentes poderiam ler o mesmo
      // conjunto de nomes em uso e escolher o mesmo nome disponível.
      if (_passoEmAndamento) return;
      _passoEmAndamento = true;
      try {
        await _executarPasso(salaId);
      } finally {
        _passoEmAndamento = false;
      }
    });
  }

  void parar() {
    _rodando = false;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _executarPasso(String salaId) async {
    final firestore = FirebaseFirestore.instance;
    final participantesRef = firestore
        .collection('Salas')
        .doc(salaId)
        .collection('Participantes');

    final existentes = await participantesRef
        .where(
          FieldPath.documentId,
          isGreaterThanOrEqualTo: kPrefixoUidSimulado,
        )
        .where(
          FieldPath.documentId,
          isLessThan: '$kPrefixoUidSimulado${String.fromCharCode(0x10FFFF)}',
        )
        .get();

    // Nomes disponíveis são sempre derivados do que já está no Firestore
    // (nunca de estado local em memória), para não duplicar nomes quando
    // há mais de uma instância do simulador rodando (hot reload, dois
    // admins simulando ao mesmo tempo) ou quando sobram apostas fake de
    // uma sessão anterior que não foi limpa.
    final nomesEmUso = existentes.docs
        .map((doc) => doc.data()['nome']?.toString())
        .whereType<String>()
        .toSet();
    final nomesDisponiveis = _nomesSimulados
        .where((nome) => !nomesEmUso.contains(nome))
        .toList();

    // Só sorteia inserir um novo apostador se ainda houver nome disponível;
    // caso contrário só resta editar ou remover apostadores já existentes.
    final podeAdicionar = nomesDisponiveis.isNotEmpty;
    final acao = podeAdicionar ? _random.nextInt(3) : 1 + _random.nextInt(2);

    if (existentes.docs.isEmpty || acao == 0) {
      // Adicionar novo apostador fake. `data-hora` é sempre o momento da
      // inserção, então ordenar por "Última Alteração" mostra o mais recente
      // no topo/base conforme a direção escolhida.
      final nome = nomesDisponiveis[_random.nextInt(nomesDisponiveis.length)];
      final uid =
          '$kPrefixoUidSimulado${DateTime.now().microsecondsSinceEpoch}';
      final cotas = _random.nextInt(5) + 1;
      await participantesRef.doc(uid).set({
        'nome': nome,
        'valor': (cotas * 6).toString(),
        'data-hora': FieldValue.serverTimestamp(),
        'verificado': false,
        'editadoAposVerificacao': false,
      });
    } else if (acao == 1) {
      // Editar um apostador fake existente (nova cota/valor). Atualiza
      // sempre `data-hora` para o momento da edição, para refletir
      // corretamente a ordenação por "Última Alteração". Se o apostador já
      // estava verificado, marca como editado pós-verificação.
      final doc = existentes.docs[_random.nextInt(existentes.docs.length)];
      final jaVerificado = doc.data()['verificado'] == true;
      final cotas = _random.nextInt(6) + 1;
      await doc.reference.update({
        'valor': (cotas * 6).toString(),
        'data-hora': FieldValue.serverTimestamp(),
        if (jaVerificado) 'editadoAposVerificacao': true,
      });
    } else if (acao == 2) {
      // Verificar um apostador fake ainda não verificado.
      final naoVerificados = existentes.docs
          .where((doc) => doc.data()['verificado'] != true)
          .toList();
      if (naoVerificados.isEmpty) return;
      final doc = naoVerificados[_random.nextInt(naoVerificados.length)];
      await doc.reference.update({'verificado': true});
    } else {
      // Remover um apostador fake existente. O nome volta a ficar
      // disponível automaticamente, já que nomesDisponiveis é recalculado
      // a cada passo a partir do que existe no Firestore.
      final doc = existentes.docs[_random.nextInt(existentes.docs.length)];
      await doc.reference.delete();
    }
  }

  /// Remove todos os participantes fake criados pela simulação.
  Future<void> limparSimulados(String salaId) async {
    final firestore = FirebaseFirestore.instance;
    final participantesRef = firestore
        .collection('Salas')
        .doc(salaId)
        .collection('Participantes');

    final existentes = await participantesRef
        .where(
          FieldPath.documentId,
          isGreaterThanOrEqualTo: kPrefixoUidSimulado,
        )
        .where(
          FieldPath.documentId,
          isLessThan: '$kPrefixoUidSimulado${String.fromCharCode(0x10FFFF)}',
        )
        .get();

    final batch = firestore.batch();
    for (final doc in existentes.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
