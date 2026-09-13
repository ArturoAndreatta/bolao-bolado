// Utilidades de terminal para os scripts de tool/ — passo numerado, cor e
// resumo final. Sem isso cada script reinventava o próprio "[1/7]" na mão.

import 'dart:async';
import 'dart:io';

/// Liga/desliga cor ANSI. Desligado com --no-color (log de CI não entende
/// código de escape, e sobra como \x1B[32m literal no arquivo).
class Paint {
  Paint({required this.enabled});

  final bool enabled;

  String _com(String codigo, String texto) =>
      enabled ? '\x1B[${codigo}m$texto\x1B[0m' : texto;

  String title(String texto) => _com('1', texto);
  String dim(String texto) => _com('2', texto);
  String ok(String texto) => _com('32', texto);
  String erro(String texto) => _com('31', texto);
  String link(String texto) => _com('36', texto);
}

/// Tela inicial do script: uma caixa com o nome e o que está ligado/desligado
/// nesta rodada (--dry-run, --rapido, etc), visível antes do primeiro passo.
void banner(Paint paint, String titulo, {String? subtitulo}) {
  final linhas = [titulo, if (subtitulo != null) subtitulo];
  final largura = linhas.map((l) => l.length).reduce((a, b) => a > b ? a : b);
  final borda = '─' * (largura + 2);

  stdout.writeln('');
  stdout.writeln(paint.dim('┌$borda┐'));
  stdout.writeln(
    '${paint.dim('│')} ${paint.title(titulo.padRight(largura))} ${paint.dim('│')}',
  );
  if (subtitulo != null) {
    stdout.writeln(
      '${paint.dim('│')} ${paint.dim(subtitulo.padRight(largura))} ${paint.dim('│')}',
    );
  }
  stdout.writeln(paint.dim('└$borda┘'));
}

/// Aborta o script com uma mensagem de erro. Nunca retorna.
Never fail(Paint paint, String mensagem) {
  stderr.writeln('\n${paint.erro('✗')} $mensagem');
  exit(1);
}

/// Garante que o script está rodando da raiz do repositório — os caminhos
/// relativos (build/web, firestore.rules) só fazem sentido dali.
void requireRepositoryRoot(Paint paint, String script) {
  if (!File('pubspec.yaml').existsSync() ||
      !File('firebase.json').existsSync()) {
    fail(paint, 'Rode a partir da raiz do repositório: dart run tool/$script');
  }
}

String formatDuration(Duration d) {
  final min = d.inMinutes;
  final seg = d.inSeconds % 60;
  if (min > 0) return '${min}min ${seg}s';
  return '${seg}s';
}

String formatBytes(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Contador de passos numerados ("[2/7] Rodando os testes"), com cronômetro
/// por passo e modo --dry-run (anuncia o comando sem executar nada).
class Steps {
  Steps({required this.total, required this.dryRun, required this.paint});

  final int total;
  final bool dryRun;
  final Paint paint;

  int _atual = 0;
  DateTime? _inicioPasso;
  String? _rotuloPasso;

  void begin(String rotulo, {String? hint}) {
    _atual++;
    _inicioPasso = DateTime.now();
    _rotuloPasso = rotulo;
    final prefixo = paint.dim('[$_atual/$total]');
    final sufixo = hint != null ? ' ${paint.dim('($hint)')}' : '';
    stdout.writeln('\n$prefixo ${paint.title(rotulo)}$sufixo');
  }

  void done(String detalhe) {
    final decorrido = _inicioPasso == null
        ? ''
        : ' ${paint.dim('(${formatDuration(DateTime.now().difference(_inicioPasso!))})')}';
    stdout.writeln('  ${paint.ok('✓')} $detalhe$decorrido');
  }

  /// Roda um comando externo **em silêncio** — nada da saída dele aparece —
  /// e aborta tudo se ele falhar. Em --dry-run só anuncia o comando e não
  /// executa nada.
  ///
  /// A saída fica escondida de propósito: `flutter analyze`/`test`/`build` e
  /// `firebase deploy` despejam páginas de log que não dizem nada a quem só
  /// quer saber se o passo passou. Só quando o comando falha o log completo
  /// (stdout + stderr) aparece — aí sim ele importa, pra achar o erro.
  ///
  /// `runInShell` é obrigatório no Windows: `flutter` e `firebase` são
  /// .bat/.cmd lá, e sem o shell o Process não consegue resolvê-los.
  Future<void> run(String comando, List<String> args) async {
    if (dryRun) {
      stdout.writeln('  ${paint.dim('\$ $comando ${args.join(' ')}')}');
      return;
    }

    // Enquanto o comando roda (build e deploy passam de 1 minuto fácil),
    // uma linha só de "rodando... (Xs)" que se reescreve no lugar — não é
    // log, é só prova de que o script não travou.
    final relogio = Stopwatch()..start();
    final pisca = Timer.periodic(const Duration(seconds: 1), (_) {
      stdout.write(
        '\r  ${paint.dim('rodando... (${formatDuration(relogio.elapsed)})')}'
        '${' ' * 10}',
      );
    });

    final resultado = await Process.run(comando, args, runInShell: true);
    pisca.cancel();
    stdout.write('\r${' ' * 40}\r'); // apaga a linha do "rodando..."

    if (resultado.exitCode != 0) {
      final log = '${resultado.stdout}${resultado.stderr}'.trim();
      if (log.isNotEmpty) {
        stdout.writeln();
        stdout.writeln(log);
      }
      fail(
        paint,
        '"${_rotuloPasso ?? comando}" falhou (código ${resultado.exitCode}).'
        ' Nada foi publicado.',
      );
    }
  }
}
