/// Monta o conteúdo CSV das apostas para exportação/cópia pelo admin.
///
/// Função pura (sem Flutter/Firestore) para poder ser testada isoladamente:
/// o formato do arquivo exportado não deve depender de mocks de UI nem de
/// banco. Recebe as mesmas linhas já montadas por `getBets`/`streamBets`
/// (nome, valor, cotas, premio, verificado).
///
/// Escapa vírgula, aspas e quebra de linha no padrão CSV (RFC 4180): campos
/// com esses caracteres vão entre aspas e as aspas internas são duplicadas.
String montarCsvApostas(List<Map<String, dynamic>> rows) {
  final buffer = StringBuffer();
  buffer.writeln('Nome,Valor,Cotas,Premio,Verificado');

  for (final row in rows) {
    final nome = row['nome']?.toString() ?? '';
    final valor = ((row['valor'] as num?)?.toDouble() ?? 0).toStringAsFixed(2);
    final cotas = (row['cotas'] as num?)?.toInt() ?? 0;
    final premio = ((row['premio'] as num?)?.toDouble() ?? 0).toStringAsFixed(
      2,
    );
    final verificado = row['verificado'] == true ? 'sim' : 'nao';

    buffer.writeln(
      [_escaparCsv(nome), valor, '$cotas', premio, verificado].join(','),
    );
  }

  return buffer.toString();
}

String _escaparCsv(String campo) {
  if (campo.contains(',') || campo.contains('"') || campo.contains('\n')) {
    return '"${campo.replaceAll('"', '""')}"';
  }
  return campo;
}
