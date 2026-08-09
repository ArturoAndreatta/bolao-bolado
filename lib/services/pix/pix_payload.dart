// Monta o payload EMV ("BR Code") de um QR code PIX estático a partir da
// chave PIX simples cadastrada na sala (e-mail, CPF, telefone ou aleatória).
// Formato oficial do Banco Central: TLV (tag-length-value) encadeado, com
// CRC16 no final. Referência: manual "BR Code" do BCB.
class PixPayload {
  static String gerar({
    required String chave,
    String nome = 'BOLAO BOLADO',
    String cidade = 'SAO PAULO',
    String? txId,
    double? valor,
  }) {
    final payload = StringBuffer()
      ..write(_campo('00', '01')) // Payload Format Indicator
      ..write(
        _campo(
          '26',
          <String>[_campo('00', 'BR.GOV.BCB.PIX'), _campo('01', chave)].join(),
        ),
      ) // Merchant Account Information
      ..write(_campo('52', '0000')) // Merchant Category Code
      ..write(_campo('53', '986')) // Moeda: BRL
      ..write(
        valor != null && valor > 0
            ? _campo('54', valor.toStringAsFixed(2))
            : '',
      ) // Valor da transação
      ..write(_campo('58', 'BR')) // País
      ..write(_campo('59', _normalizar(nome, max: 25)))
      ..write(_campo('60', _normalizar(cidade, max: 15)))
      ..write(_campo('62', _campo('05', txId ?? '***'))) // Additional Data
      ;

    final semCrc = '${payload.toString()}6304';
    final crc = _crc16(semCrc);
    return '$semCrc$crc';
  }

  static String _campo(String id, String valor) {
    final tamanho = valor.length.toString().padLeft(2, '0');
    return '$id$tamanho$valor';
  }

  // Campos de texto livre do EMV (nome do recebedor, cidade) só aceitam ASCII
  // e têm tamanho máximo próprio: remove acentos, descarta o que sobra fora
  // da faixa e trunca. Um caractere fora do ASCII aqui invalida o payload
  // inteiro, e o banco recusa o QR code na leitura.
  //
  // Não se aplica à chave PIX em si, que entra crua no campo 26 — ela vem do
  // cadastro da sala e precisa ser transmitida exatamente como foi digitada.
  static String _normalizar(String texto, {required int max}) {
    const comAcento = 'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ';
    const semAcento = 'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC';
    var resultado = texto;
    for (var i = 0; i < comAcento.length; i++) {
      resultado = resultado.replaceAll(comAcento[i], semAcento[i]);
    }
    resultado = resultado.replaceAll(RegExp(r'[^A-Za-z0-9 ]'), '');
    return resultado.length > max ? resultado.substring(0, max) : resultado;
  }

  static String _crc16(String data) {
    const polinomio = 0x1021;
    var resultado = 0xFFFF;
    for (final byte in data.codeUnits) {
      resultado ^= byte << 8;
      for (var i = 0; i < 8; i++) {
        resultado = (resultado & 0x8000) != 0
            ? ((resultado << 1) ^ polinomio) & 0xFFFF
            : (resultado << 1) & 0xFFFF;
      }
    }
    return resultado.toRadixString(16).toUpperCase().padLeft(4, '0');
  }
}
