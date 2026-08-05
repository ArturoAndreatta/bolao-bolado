import 'dart:async';
import 'dart:math';

import 'package:bolao_bolado/core/debug_flags.dart';
import 'package:bolao_bolado/services/bet/preco_cota.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Prefixo usado nos uids dos participantes fake gerados pela simulação,
/// permitindo identificá-los e removê-los sem afetar apostas reais.
const String kPrefixoUidSimulado = 'sim-';

/// Teto de participantes fictícios que a simulação consegue criar — é também
/// o tamanho de [_nomesSimulados], já que cada aposta simulada ocupa um nome.
const int kMaximoParticipantesSimulados = 1000;

const List<String> _primeirosNomes = [
  'Carlos',
  'Fernanda',
  'João',
  'Mariana',
  'Rafael',
  'Juliana',
  'Bruno',
  'Camila',
  'Eduardo',
  'Patrícia',
  'Lucas',
  'Aline',
  'Diego',
  'Vanessa',
  'Thiago',
  'Renata',
  'Felipe',
  'Bianca',
  'Marcos',
  'Larissa',
  'Gabriel',
  'Isabela',
  'Rodrigo',
  'Beatriz',
  'André',
  'Natália',
  'Gustavo',
  'Priscila',
  'Vinícius',
  'Débora',
  'Leonardo',
  'Amanda',
  'Matheus',
  'Carolina',
  'Fábio',
  'Letícia',
  'Rogério',
  'Sabrina',
  'Alexandre',
  'Tatiane',
  'Henrique',
  'Cristiane',
  'Daniel',
  'Simone',
  'Paulo',
  'Viviane',
  'Marcelo',
  'Adriana',
  'César',
  'Luana',
];

const List<String> _sobrenomes = [
  'Silva',
  'Costa',
  'Pereira',
  'Alves',
  'Souza',
  'Lima',
  'Rocha',
  'Dias',
  'Nunes',
  'Gomes',
  'Martins',
  'Ferreira',
  'Barbosa',
  'Ribeiro',
  'Cardoso',
  'Almeida',
  'Araújo',
  'Teixeira',
  'Moura',
  'Fonseca',
  'Castro',
  'Monteiro',
  'Correia',
  'Farias',
  'Batista',
  'Carvalho',
  'Duarte',
  'Siqueira',
  'Barros',
  'Peixoto',
  'Moreira',
  'Andrade',
  'Camargo',
  'Vasconcelos',
  'Nogueira',
  'Xavier',
  'Bezerra',
  'Melo',
  'Cavalcanti',
  'Guimarães',
  'Lopes',
  'Tavares',
  'Pinheiro',
  'Sales',
  'Reis',
  'Cunha',
  'Braga',
  'Freire',
  'Machado',
  'Prado',
];

/// Nomes fictícios disponíveis para a simulação, montados combinando primeiro
/// nome × sobrenome (50 × 50 = 2500 combinações possíveis, das quais ficam as
/// primeiras [kMaximoParticipantesSimulados]).
///
/// A lista era escrita à mão com 60 nomes, e era ela que limitava o tamanho
/// da simulação: chegando ao fim, o ciclo parava com
/// [MotivoParada.semNomesDisponiveis] — cedo demais para testar a tela com
/// muitos participantes, que é justamente para o que o simulador existe.
/// Combinar duas listas de 50 dá os 1000 nomes distintos sem 1000 literais.
///
/// A ordem ingênua do produto cartesiano (todos os sobrenomes do primeiro
/// nome, depois os do segundo) colocaria 50 xarás seguidos no começo da lista,
/// e uma simulação curta — que só usa o começo — viraria uma tela de "Carlos
/// Silva, Carlos Costa, Carlos Pereira...". Aqui a volta de fora é o
/// DESLOCAMENTO entre as duas listas: a primeira passada emparelha cada
/// primeiro nome com um sobrenome diferente (50 nomes, todos distintos entre
/// si), a segunda repete deslocando um sobrenome, e assim por diante. Cada par
/// (primeiro nome, sobrenome) sai uma vez só, então não há nome repetido.
final List<String> _nomesSimulados = [
  for (var deslocamento = 0; deslocamento < _sobrenomes.length; deslocamento++)
    for (var i = 0; i < _primeirosNomes.length; i++)
      '${_primeirosNomes[i]} '
          '${_sobrenomes[(i + deslocamento) % _sobrenomes.length]}',
].take(kMaximoParticipantesSimulados).toList();

/// Os nomes fictícios gerados, só para leitura — exposto para os testes
/// conferirem tamanho e ausência de repetição sem precisar do Firestore.
List<String> get nomesSimuladosDisponiveis =>
    List.unmodifiable(_nomesSimulados);

/// O que a simulação faz a cada passo.
///
/// Existe para conseguir olhar UMA animação de cada vez: com tudo misturado,
/// a entrada de uma aposta competia com a reordenação de outra e ficava
/// difícil dizer qual efeito era qual.
enum ModoSimulacao {
  inclusoes('Apenas inclusões', 'Só cria apostas novas.'),
  alteracoes('Apenas alterações', 'Só muda o valor de apostas existentes.'),
  exclusoes('Apenas exclusões', 'Só remove apostas simuladas.'),
  aleatorio('Tudo misturado', 'Cria, altera, verifica e remove ao acaso.');

  final String rotulo;
  final String descricao;

  const ModoSimulacao(this.rotulo, this.descricao);
}

/// Por que a simulação parou sozinha (quando parou).
///
/// Os modos focados esgotam o próprio alvo: "apenas exclusões" acaba com as
/// apostas fake, "apenas alterações" não tem o que alterar numa sala sem
/// aposta simulada. Nesses casos parar e avisar é melhor do que um timer
/// rodando à toa, que na tela parece travamento.
enum MotivoParada {
  semApostasParaExcluir('Acabaram as apostas simuladas para excluir.'),
  semApostasParaAlterar('Não há aposta simulada para alterar.'),
  semNomesDisponiveis('Todos os nomes fictícios já estão em uso.');

  final String mensagem;

  const MotivoParada(this.mensagem);
}

/// Gera/edita/remove apostas fake (uids prefixados com [kPrefixoUidSimulado])
/// na sala principal, simulando o movimento de muitas pessoas apostando.
/// Uso exclusivo para visualização/teste de layout com muitos participantes;
/// nunca deve ser exposto a usuários não-admin.
class SimuladorApostas {
  final _random = Random();
  bool _rodando = false;
  bool _passoEmAndamento = false;
  Timer? _timer;

  /// Listener de [intervaloSimulacaoMsGlobal] ativo enquanto a simulação roda.
  /// Guardado para poder ser removido em [parar] — sem isso o simulador ficaria
  /// pendurado no notifier global depois de parado.
  VoidCallback? _ouvinteIntervalo;

  /// Modo do ciclo em andamento (ou do último que rodou).
  ModoSimulacao _modo = ModoSimulacao.aleatorio;
  ModoSimulacao get modo => _modo;

  /// Avisa a UI que a simulação parou sozinha por falta de alvo. Fica null
  /// quando quem parou foi o usuário.
  void Function(MotivoParada motivo)? aoPararSozinho;

  /// Preço da cota da sala simulada, lido uma vez em [iniciar].
  ///
  /// Começa no padrão da Mega-Sena e é corrigido assim que o doc da sala
  /// responde. Era 6 fixo: numa sala de Lotofácil (cota R$3,50) o simulador
  /// gerava apostas que não fecham cota inteira, então a tela de teste ficava
  /// cheia de valores que o app recusaria de um usuário real.
  double _precoCota = kPrecoCotaMega;

  bool get rodando => _rodando;

  void iniciar(String salaId, {ModoSimulacao modo = ModoSimulacao.aleatorio}) {
    if (_rodando) return;
    _rodando = true;
    _modo = modo;

    // Uma leitura só por sessão de simulação, sem bloquear o primeiro passo:
    // até ela responder os passos usam o padrão da Mega-Sena.
    unawaited(
      FirebaseFirestore.instance.collection('Salas').doc(salaId).get().then((
        doc,
      ) {
        _precoCota = precoCotaPara(doc.data()?['sorteio']?.toString());
      }, onError: (Object _) {}),
    );
    _reagendarTimer(salaId);
    // Mexer no slider do Painel ADM com a simulação rodando troca o ritmo na
    // hora: sem este listener o intervalo novo só valeria no próximo
    // "Iniciar", e quem está ajustando o ritmo justamente olha a tela rodando.
    _ouvinteIntervalo = () => _reagendarTimer(salaId);
    intervaloSimulacaoMsGlobal.addListener(_ouvinteIntervalo!);
  }

  /// (Re)cria o timer periódico com o intervalo configurado no momento.
  ///
  /// `Timer.periodic` tem período fixo, então mudar o ritmo exige cancelar e
  /// criar outro. O passo em andamento (se houver) não é interrompido: quem
  /// protege contra sobreposição é [_passoEmAndamento], que independe de qual
  /// timer disparou.
  void _reagendarTimer(String salaId) {
    _timer?.cancel();
    final intervalo = intervaloSimulacaoMsGlobal.value.clamp(
      kIntervaloSimulacaoMinMs,
      kIntervaloSimulacaoMaxMs,
    );
    _timer = Timer.periodic(Duration(milliseconds: intervalo), (_) async {
      // Evita sobrepor passos: se a leitura+escrita do passo anterior ainda
      // não terminou, duas execuções concorrentes poderiam ler o mesmo
      // conjunto de nomes em uso e escolher o mesmo nome disponível.
      if (_passoEmAndamento) return;
      _passoEmAndamento = true;
      try {
        final motivo = await _executarPasso(salaId);
        if (motivo != null) _pararSozinho(motivo);
      } finally {
        _passoEmAndamento = false;
      }
    });
  }

  void parar() {
    _rodando = false;
    _timer?.cancel();
    _timer = null;
    if (_ouvinteIntervalo != null) {
      intervaloSimulacaoMsGlobal.removeListener(_ouvinteIntervalo!);
      _ouvinteIntervalo = null;
    }
  }

  /// Encerra o ciclo por falta de alvo e avisa quem estiver ouvindo.
  void _pararSozinho(MotivoParada motivo) {
    if (!_rodando) return;
    parar();
    aoPararSozinho?.call(motivo);
  }

  /// Valor (em string, como manda a invariante de `Participantes.valor`) de
  /// uma aposta de [cotas] cotas ao preço da sala. Sem casas decimais quando
  /// a cota é inteira, para o texto ficar igual ao que o app grava.
  String _valorDe(int cotas) {
    final total = cotas * _precoCota;
    return total % 1 == 0 ? total.toStringAsFixed(0) : total.toStringAsFixed(2);
  }

  /// Quantidade de cotas de uma aposta nova, calibrada para a linha CAIR NA
  /// PARTE VISÍVEL da tabela.
  ///
  /// A ordenação padrão da tela é por valor decrescente. Sorteando 1–5 cotas
  /// fixas (como era antes), toda aposta simulada nascia entre as menores da
  /// sala e ia parar no fim de uma lista rolável — a animação de entrada
  /// rodava corretamente, só que fora da área visível, dando a impressão de
  /// que as apostas "aparecem sem animação".
  ///
  /// Aqui o valor sai perto do topo da faixa já existente: entre a mediana e
  /// um pouco acima da maior aposta atual. Assim a linha nova entra no campo
  /// de visão de quem está olhando o começo da tabela.
  int _cotasVisiveis(List<QueryDocumentSnapshot<Map<String, dynamic>>> atuais) {
    final cotasAtuais =
        atuais
            .map(
              (doc) => double.tryParse(doc.data()['valor']?.toString() ?? ''),
            )
            .whereType<double>()
            .map((valor) => (valor / _precoCota).floor())
            .where((cotas) => cotas > 0)
            .toList()
          ..sort();

    // Sala vazia (ou só com apostas ilegíveis): faixa inicial modesta, que
    // vira a referência dos próximos passos.
    if (cotasAtuais.isEmpty) return _random.nextInt(5) + 3;

    final mediana = cotasAtuais[cotasAtuais.length ~/ 2];
    final maior = cotasAtuais.last;

    // Teto um pouco ACIMA da maior aposta para a linha nova às vezes assumir
    // o topo da tabela; piso na mediana para nunca afundar no rodapé.
    final piso = mediana;
    final teto = maior + (maior ~/ 4) + 2;
    return piso + _random.nextInt((teto - piso).clamp(1, 40));
  }

  /// Executa um passo da simulação conforme o [modo] em vigor.
  ///
  /// Devolve o motivo quando o modo ficou sem alvo (e portanto o ciclo deve
  /// parar), ou `null` quando o passo rodou normalmente.
  Future<MotivoParada?> _executarPasso(String salaId) async {
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

    final docs = existentes.docs;

    switch (_modo) {
      case ModoSimulacao.inclusoes:
        if (nomesDisponiveis.isEmpty) {
          return MotivoParada.semNomesDisponiveis;
        }
        await _inserir(participantesRef, nomesDisponiveis, docs);
        return null;

      case ModoSimulacao.alteracoes:
        if (docs.isEmpty) return MotivoParada.semApostasParaAlterar;
        await _alterar(docs);
        return null;

      case ModoSimulacao.exclusoes:
        if (docs.isEmpty) return MotivoParada.semApostasParaExcluir;
        await _excluir(docs);
        return null;

      case ModoSimulacao.aleatorio:
        return _passoAleatorio(participantesRef, nomesDisponiveis, docs);
    }
  }

  /// Passo do modo misto. Nunca para sozinho: sempre sobra alguma ação
  /// possível (sem nomes, ainda dá para alterar/excluir; sem apostas, ainda
  /// dá para inserir). Só a sala impossível — sem nomes E sem apostas —
  /// encerra, e aí o motivo é não haver mais nome para criar.
  Future<MotivoParada?> _passoAleatorio(
    CollectionReference<Map<String, dynamic>> participantesRef,
    List<String> nomesDisponiveis,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final podeAdicionar = nomesDisponiveis.isNotEmpty;
    if (!podeAdicionar && docs.isEmpty) {
      return MotivoParada.semNomesDisponiveis;
    }

    // Inserir é a ação que o simulador existe para mostrar (é ela que dispara
    // a animação de linha nova), então ela é sorteada com peso maior em vez
    // de 1/3 uniforme: com peso igual, dois de cada três passos eram
    // edição/verificação e a tela ficava longos trechos sem nenhuma entrada.
    final sorteio = _random.nextInt(10);
    final acao = !podeAdicionar
        ? 1 + _random.nextInt(2)
        : sorteio < 6
        ? 0
        : sorteio < 8
        ? 1
        : sorteio < 9
        ? 2
        : 3;

    if (docs.isEmpty || acao == 0) {
      await _inserir(participantesRef, nomesDisponiveis, docs);
    } else if (acao == 1) {
      await _alterar(docs);
    } else if (acao == 2) {
      await _verificar(docs);
    } else {
      await _excluir(docs);
    }
    return null;
  }

  /// Adicionar novo apostador fake. `data-hora` é sempre o momento da
  /// inserção, então ordenar por "Última Alteração" mostra o mais recente
  /// no topo/base conforme a direção escolhida.
  Future<void> _inserir(
    CollectionReference<Map<String, dynamic>> participantesRef,
    List<String> nomesDisponiveis,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final nome = nomesDisponiveis[_random.nextInt(nomesDisponiveis.length)];
    final uid = '$kPrefixoUidSimulado${DateTime.now().microsecondsSinceEpoch}';
    await participantesRef.doc(uid).set({
      'nome': nome,
      'valor': _valorDe(_cotasVisiveis(docs)),
      'data-hora': FieldValue.serverTimestamp(),
      'verificado': false,
      'editadoAposVerificacao': false,
    });
  }

  /// Editar um apostador fake existente (nova cota/valor). Atualiza sempre
  /// `data-hora` para o momento da edição, para refletir corretamente a
  /// ordenação por "Última Alteração". Se o apostador já estava verificado,
  /// marca como editado pós-verificação.
  Future<void> _alterar(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final doc = docs[_random.nextInt(docs.length)];
    final jaVerificado = doc.data()['verificado'] == true;
    // Mesma calibragem da inserção: a edição muda o `valor`, o que dispara
    // a animação de linha alterada E reordena a linha. Sorteando cotas
    // baixas, a linha animava enquanto era jogada para o fim da lista.
    await doc.reference.update({
      'valor': _valorDe(_cotasVisiveis(docs)),
      'data-hora': FieldValue.serverTimestamp(),
      if (jaVerificado) 'editadoAposVerificacao': true,
    });
  }

  /// Verificar um apostador fake ainda não verificado. Sem candidato, o passo
  /// simplesmente não faz nada — só acontece no modo misto, que tem outras
  /// ações para sortear no passo seguinte.
  Future<void> _verificar(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final naoVerificados = docs
        .where((doc) => doc.data()['verificado'] != true)
        .toList();
    if (naoVerificados.isEmpty) return;
    final doc = naoVerificados[_random.nextInt(naoVerificados.length)];
    await doc.reference.update({'verificado': true});
  }

  /// Remover um apostador fake existente. O nome volta a ficar disponível
  /// automaticamente, já que a lista de nomes é recalculada a cada passo a
  /// partir do que existe no Firestore.
  Future<void> _excluir(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final doc = docs[_random.nextInt(docs.length)];
    await doc.reference.delete();
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
