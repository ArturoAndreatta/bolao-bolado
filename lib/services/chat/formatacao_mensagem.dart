import 'package:bolao_bolado/models/mensagem.dart';

/// O que um pedaço de mensagem é: texto comum, uma menção a alguém, ou um
/// endereço clicável.
enum TipoTrecho { texto, mencao, link }

/// Um pedaço já resolvido do texto de uma mensagem, pronto para virar um
/// `TextSpan`.
///
/// A quebra do texto em trechos vive aqui, fora do widget, porque é lógica
/// pura: dá para testar todo o comportamento de marcação e menção sem montar
/// árvore de widget nenhuma (mesma razão de `calcularCotasEPremios` viver
/// fora da tela).
class TrechoMensagem {
  final TipoTrecho tipo;

  /// O que aparece na tela — já sem os marcadores de formatação.
  final String texto;

  /// UID de quem foi mencionado ([TipoTrecho.mencao]) ou a URL normalizada
  /// ([TipoTrecho.link]). Nulo em texto comum.
  final String? alvo;

  final bool negrito;
  final bool italico;
  final bool riscado;
  final bool mono;

  const TrechoMensagem({
    required this.tipo,
    required this.texto,
    this.alvo,
    this.negrito = false,
    this.italico = false,
    this.riscado = false,
    this.mono = false,
  });

  @override
  String toString() =>
      'TrechoMensagem(${tipo.name}, "$texto"'
      '${alvo != null ? ', alvo: $alvo' : ''}'
      '${negrito ? ', negrito' : ''}'
      '${italico ? ', italico' : ''}'
      '${riscado ? ', riscado' : ''}'
      '${mono ? ', mono' : ''})';
}

/// Quebra o texto de uma mensagem em trechos formatados.
///
/// Marcação no estilo do WhatsApp — `*negrito*`, `_itálico_`, `~riscado~` e
/// `` `mono` `` —, escolhida por ser a que o público deste app já usa sem
/// precisar aprender nada. As regras seguem a de lá: o marcador só abre no
/// começo de uma palavra e só fecha no fim dela, então `snake_case` e `3*4`
/// continuam sendo texto comum.
///
/// A ordem do processamento é deliberada: **menções, links e só então
/// marcação**. Se a marcação viesse antes, uma URL com `_` no caminho
/// (`.../foo_bar_baz`) seria comida como itálico e o link quebraria — que é o
/// erro mais visível dos dois possíveis. O preço é que marcação DENTRO de um
/// link não é interpretada, o que não faz falta.
///
/// Não há aninhamento: `*_texto_*` sai como negrito contendo os underscores
/// literais. Suportar combinação exigiria um parser recursivo para um ganho
/// que ninguém pede numa caixa de 200 caracteres.
List<TrechoMensagem> formatarMensagem(
  String texto, {
  List<Mencao> mencoes = const [],
}) {
  if (texto.isEmpty) return const [];

  final validas = _mencoesValidas(texto, mencoes);
  if (validas.isEmpty) return _trechosSemMencao(texto);

  final trechos = <TrechoMensagem>[];
  var cursor = 0;
  for (final mencao in validas) {
    if (mencao.inicio > cursor) {
      trechos.addAll(_trechosSemMencao(texto.substring(cursor, mencao.inicio)));
    }
    trechos.add(
      TrechoMensagem(
        tipo: TipoTrecho.mencao,
        texto: texto.substring(mencao.inicio, mencao.fim),
        alvo: mencao.uid,
      ),
    );
    cursor = mencao.fim;
  }
  if (cursor < texto.length) {
    trechos.addAll(_trechosSemMencao(texto.substring(cursor)));
  }
  return trechos;
}

/// Token `@...` sendo digitado sob o cursor, que é o que abre a lista de
/// participantes.
class MencaoEmDigitacao {
  /// Índice do `@` no texto.
  final int inicio;

  /// O que já foi digitado depois do `@`, normalizado para comparação.
  final String consulta;

  const MencaoEmDigitacao({required this.inicio, required this.consulta});
}

/// Distância máxima entre o `@` e o cursor para o token ainda contar como uma
/// menção sendo digitada. Sem esse teto, um `@` escrito lá atrás na frase
/// reabriria a lista a cada tecla até o fim da mensagem.
const int kLimiteTokenMencao = 32;

/// Descobre se o cursor está dentro de um `@...` e devolve onde ele começa.
///
/// Lógica separada do widget de propósito: é a peça do autocomplete com mais
/// casos de borda (o `@` no meio de um e-mail, o cursor no meio da palavra, o
/// token longo demais) e a única forma de cobrir isso sem subir o chat inteiro
/// com Firebase é ela ser uma função pura.
MencaoEmDigitacao? detectarMencao(String texto, int cursor) {
  if (cursor < 0 || cursor > texto.length) return null;

  var inicio = -1;
  for (var i = cursor - 1; i >= 0 && cursor - i <= kLimiteTokenMencao; i--) {
    final caractere = texto[i];
    if (caractere == '@') {
      inicio = i;
      break;
    }
    // Espaço e quebra de linha encerram a busca: o token de menção é uma
    // palavra só até aqui — quem escolhe um nome composto o faz pela lista,
    // que continua aberta enquanto o prefixo casar.
    if (caractere == '\n') break;
  }
  if (inicio == -1) return null;

  // O `@` precisa começar palavra, senão um e-mail digitado no chat abriria a
  // lista de participantes no meio da frase.
  if (inicio > 0 && !_ehEspaco(texto[inicio - 1])) return null;

  return MencaoEmDigitacao(
    inicio: inicio,
    consulta: _normalizar(texto.substring(inicio + 1, cursor)),
  );
}

/// Casa pelo começo do nome **ou pelo começo de qualquer sobrenome**: numa
/// sala de amigos as pessoas são chamadas tanto por um quanto pelo outro.
///
/// Compara sem acento: quem digita `@joao` no meio da conversa não vai parar
/// para trocar o teclado, e ver a lista vazia parece que a pessoa não está na
/// sala.
bool nomeCasaConsulta(String nome, String consulta) {
  if (consulta.isEmpty) return true;
  final alvo = _normalizar(nome);
  if (alvo.startsWith(consulta)) return true;
  return alvo.split(' ').any((parte) => parte.startsWith(consulta));
}

/// Troca o token em digitação pelo `@Nome ` completo e diz onde o cursor fica.
({String texto, int cursor}) aplicarMencao({
  required String texto,
  required int cursor,
  required int inicio,
  required String nome,
}) {
  if (inicio < 0 || inicio > cursor || cursor > texto.length) {
    return (texto: texto, cursor: cursor);
  }
  // O espaço no fim é o que separa o token do resto da frase — sem ele, a
  // próxima palavra gruda no nome e a menção deixa de ser reconhecida no
  // envio (ver resolverMencoes). Quando já há espaço logo depois do cursor
  // (menção escolhida no MEIO da frase), não se acrescenta outro: dois
  // espaços seguidos é o tipo de sujeira que a pessoa só descobre depois de
  // mandar.
  final jaTemEspaco = cursor < texto.length && _ehEspaco(texto[cursor]);
  final token = jaTemEspaco ? '@$nome' : '@$nome ';
  return (
    texto: texto.substring(0, inicio) + token + texto.substring(cursor),
    cursor: inicio + token.length,
  );
}

const Map<String, String> _acentos = {
  'á': 'a',
  'à': 'a',
  'ã': 'a',
  'â': 'a',
  'ä': 'a',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'í': 'i',
  'ì': 'i',
  'î': 'i',
  'ï': 'i',
  'ó': 'o',
  'ò': 'o',
  'õ': 'o',
  'ô': 'o',
  'ö': 'o',
  'ú': 'u',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ç': 'c',
  'ñ': 'n',
};

String _normalizar(String valor) {
  final minusculo = valor.toLowerCase();
  final buffer = StringBuffer();
  for (final caractere in minusculo.split('')) {
    buffer.write(_acentos[caractere] ?? caractere);
  }
  return buffer.toString();
}

/// Localiza no texto final os tokens `@Nome` das pessoas escolhidas no
/// autocomplete e devolve as menções com as posições certas.
///
/// A posição é descoberta na hora do envio, e não guardada quando o nome foi
/// escolhido, porque entre uma coisa e outra o usuário edita o texto à
/// vontade: escreve antes, apaga no meio, reescreve. Índice guardado no
/// momento do clique estaria errado na maioria dos envios — e menção apontando
/// para o pedaço errado do texto acende a palavra errada.
///
/// Quem apagou o `@Nome` depois de escolher simplesmente some daqui: a pessoa
/// deixa de ser mencionada, que é o que o texto passou a dizer.
List<Mencao> resolverMencoes(
  String texto,
  List<({String uid, String nome})> escolhidas,
) {
  if (escolhidas.isEmpty || texto.isEmpty) return const [];

  final encontradas = <Mencao>[];
  final ocupados = <int, int>{}; // inicio -> fim
  for (final escolhida in escolhidas) {
    final token = '@${escolhida.nome}';
    var de = 0;
    while (true) {
      final inicio = texto.indexOf(token, de);
      if (inicio == -1) break;
      final fim = inicio + token.length;
      de = inicio + 1;

      final jaUsado = ocupados.entries.any(
        (faixa) => inicio < faixa.value && fim > faixa.key,
      );
      if (jaUsado) continue;
      if (!_limiteDeToken(texto, inicio, fim)) continue;

      ocupados[inicio] = fim;
      encontradas.add(
        Mencao(
          uid: escolhida.uid,
          nome: escolhida.nome,
          inicio: inicio,
          fim: fim,
        ),
      );
      break;
    }
  }

  encontradas.sort((a, b) => a.inicio.compareTo(b.inicio));
  return encontradas;
}

/// O token precisa começar palavra e terminar palavra: sem isso, escolher
/// "Ana" marcaria também o "@Ana" de dentro de "@Anabela", e um `e-mail@Nome`
/// viraria menção.
bool _limiteDeToken(String texto, int inicio, int fim) {
  if (inicio > 0) {
    final anterior = texto[inicio - 1];
    if (!_ehEspaco(anterior) && !_aberturasPermitidas.contains(anterior)) {
      return false;
    }
  }
  if (fim >= texto.length) return true;
  final proximo = texto[fim];
  return _ehEspaco(proximo) || _fechamentosPermitidos.contains(proximo);
}

/// Filtra as menções que realmente descrevem o texto recebido: dentro dos
/// limites, sem sobreposição, começando em `@` e em ordem crescente.
///
/// Os índices vêm do documento do Firestore, que pode ter sido escrito por
/// uma versão antiga do app ou por fora dele. Índice inválido aqui viraria
/// `RangeError` no `substring` — ou seja, uma mensagem malformada derrubando
/// a lista inteira do chat.
List<Mencao> _mencoesValidas(String texto, List<Mencao> mencoes) {
  if (mencoes.isEmpty) return const [];

  final ordenadas = [...mencoes]..sort((a, b) => a.inicio.compareTo(b.inicio));
  final validas = <Mencao>[];
  var limite = 0;
  for (final mencao in ordenadas) {
    if (mencao.inicio < limite) continue; // sobrepõe a anterior
    if (mencao.fim > texto.length) continue;
    if (texto[mencao.inicio] != '@') continue;
    validas.add(mencao);
    limite = mencao.fim;
  }
  return validas;
}

/// Endereços http(s) e os que começam por `www.` — a forma como as pessoas
/// colam link no chat com mais frequência do que digitando o esquema.
final RegExp _regexUrl = RegExp(
  r'(?:https?://|www\.)[^\s]+',
  caseSensitive: false,
);

/// Pontuação que costuma encostar num link colado no meio da frase
/// ("olha lá: exemplo.com/x."). Faz parte da frase, não do endereço.
const String _pontuacaoFinal = '.,;:!?)]}»"\'';

List<TrechoMensagem> _trechosSemMencao(String texto) {
  if (texto.isEmpty) return const [];

  final trechos = <TrechoMensagem>[];
  var cursor = 0;
  for (final achado in _regexUrl.allMatches(texto)) {
    var fim = achado.end;
    while (fim > achado.start && _pontuacaoFinal.contains(texto[fim - 1])) {
      fim--;
    }
    // Sobrou só o esquema depois de tirar a pontuação: não é link.
    if (fim - achado.start < 5) continue;

    if (achado.start > cursor) {
      trechos.addAll(_comMarcacao(texto.substring(cursor, achado.start)));
    }
    final bruto = texto.substring(achado.start, fim);
    trechos.add(
      TrechoMensagem(
        tipo: TipoTrecho.link,
        texto: bruto,
        // `www.x` sem esquema não abre: o url_launcher trataria o endereço
        // como caminho relativo.
        alvo: bruto.toLowerCase().startsWith('www.') ? 'https://$bruto' : bruto,
      ),
    );
    cursor = fim;
  }
  if (cursor < texto.length) {
    trechos.addAll(_comMarcacao(texto.substring(cursor)));
  }
  return trechos;
}

/// Marcadores aceitos e o estilo que cada um liga.
const Map<String, String> _marcadores = {
  '*': 'negrito',
  '_': 'italico',
  '~': 'riscado',
  '`': 'mono',
};

/// Um marcador só ABRE colado no início de uma palavra...
const String _aberturasPermitidas = '([{"\'';

/// ...e só FECHA no fim de uma, encostado em pontuação ou espaço.
const String _fechamentosPermitidos = '.,;:!?)]}"\'';

List<TrechoMensagem> _comMarcacao(String texto) {
  if (texto.isEmpty) return const [];

  final trechos = <TrechoMensagem>[];
  final acumulado = StringBuffer();

  void despejarAcumulado() {
    if (acumulado.isEmpty) return;
    trechos.add(
      TrechoMensagem(tipo: TipoTrecho.texto, texto: acumulado.toString()),
    );
    acumulado.clear();
  }

  var i = 0;
  while (i < texto.length) {
    final caractere = texto[i];
    final estilo = _marcadores[caractere];
    if (estilo != null && _podeAbrir(texto, i)) {
      final fim = _procurarFechamento(texto, i, caractere);
      if (fim != -1) {
        despejarAcumulado();
        trechos.add(
          TrechoMensagem(
            tipo: TipoTrecho.texto,
            texto: texto.substring(i + 1, fim),
            negrito: estilo == 'negrito',
            italico: estilo == 'italico',
            riscado: estilo == 'riscado',
            mono: estilo == 'mono',
          ),
        );
        i = fim + 1;
        continue;
      }
    }
    acumulado.write(caractere);
    i++;
  }
  despejarAcumulado();
  return trechos;
}

bool _podeAbrir(String texto, int i) {
  if (i > 0) {
    final anterior = texto[i - 1];
    if (!_ehEspaco(anterior) && !_aberturasPermitidas.contains(anterior)) {
      return false;
    }
  }
  if (i + 1 >= texto.length) return false;
  final proximo = texto[i + 1];
  return !_ehEspaco(proximo) && proximo != texto[i];
}

int _procurarFechamento(String texto, int abertura, String marcador) {
  for (var j = abertura + 2; j < texto.length; j++) {
    if (texto[j] != marcador) continue;
    if (_ehEspaco(texto[j - 1])) continue;
    if (j + 1 < texto.length) {
      final proximo = texto[j + 1];
      if (!_ehEspaco(proximo) && !_fechamentosPermitidos.contains(proximo)) {
        continue;
      }
    }
    return j;
  }
  return -1;
}

bool _ehEspaco(String caractere) => caractere.trim().isEmpty;
