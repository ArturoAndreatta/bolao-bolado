import 'package:bolao_bolado/pages/admin/widgets/exportar_apostas.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('montarCsvApostas', () {
    test('sempre inclui o cabeçalho', () {
      final csv = montarCsvApostas([]);
      expect(csv.trim(), 'Nome,Valor,Cotas,Premio,Verificado');
    });

    test('formata valores e prêmios com 2 casas', () {
      final csv = montarCsvApostas([
        {
          'nome': 'João',
          'valor': 12,
          'cotas': 2,
          'premio': 100.5,
          'verificado': true,
        },
      ]);
      expect(csv, contains('João,12.00,2,100.50,sim'));
    });

    test('mapeia verificado false para "nao"', () {
      final csv = montarCsvApostas([
        {
          'nome': 'Ana',
          'valor': 6,
          'cotas': 1,
          'premio': 0,
          'verificado': false,
        },
      ]);
      expect(csv, contains('Ana,6.00,1,0.00,nao'));
    });

    test('escapa nome com vírgula entre aspas', () {
      final csv = montarCsvApostas([
        {'nome': 'Silva, José', 'valor': 6, 'cotas': 1, 'premio': 0},
      ]);
      expect(csv, contains('"Silva, José",6.00,1,0.00,nao'));
    });

    test('duplica aspas internas no padrão CSV', () {
      final csv = montarCsvApostas([
        {'nome': 'Ze "Bolado"', 'valor': 6, 'cotas': 1, 'premio': 0},
      ]);
      expect(csv, contains('"Ze ""Bolado""",6.00'));
    });

    test('trata campos ausentes como zero/vazio', () {
      final csv = montarCsvApostas([<String, dynamic>{}]);
      expect(csv, contains(',0.00,0,0.00,nao'));
    });
  });
}
