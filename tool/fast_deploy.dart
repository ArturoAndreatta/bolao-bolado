// Deploy mínimo: só o necessário pra colocar o site no ar, o mais rápido
// possível. Sem analyze, sem test, sem pub get, sem clean — assume que o
// projeto já está num estado buildável (é o caso do dia a dia; use
// deploy.dart quando quiser as verificações completas).
//
// Uso:
//   dart run tool/fast_deploy.dart
//
// Ver CLAUDE.md (seção Deploy) para o porquê de cada flag/passo do build.

import 'dart:io';

import 'enxugar_build_web.dart';

Future<void> main(List<String> args) async {
  final build = Directory('build/web');
  if (build.existsSync()) {
    stdout.writeln('\n▶ Limpando build/web');
    build.deleteSync(recursive: true);
  }

  // --no-web-resources-cdn: serve o CanvasKit do próprio Hosting em vez do
  // gstatic.com, senão ele é baixado duas vezes (ver CLAUDE.md).
  await _rodar('flutter', [
    'build',
    'web',
    '--release',
    '--no-web-resources-cdn',
  ], 'Build web');

  stdout.writeln('\n▶ Enxugando o build');
  if (!enxugarBuildWeb()) {
    stderr.writeln('Poda falhou — deploy abortado.');
    exit(1);
  }

  // Só hosting: pula a publicação de firestore.rules/indexes, que não
  // costumam mudar entre um deploy rápido e outro.
  await _rodar('firebase', ['deploy', '--only', 'hosting', ...args], 'Deploy');
  stdout.writeln('\n✓ Publicado.');
}

/// Roda um comando mostrando a saída ao vivo e aborta tudo se ele falhar.
///
/// `runInShell` é obrigatório no Windows: `flutter` e `firebase` são .bat/.cmd
/// lá, e sem o shell o Process não consegue resolvê-los.
Future<void> _rodar(String comando, List<String> args, String rotulo) async {
  stdout.writeln('\n▶ $rotulo: $comando ${args.join(' ')}');

  final processo = await Process.start(
    comando,
    args,
    runInShell: true,
    mode: ProcessStartMode.inheritStdio,
  );

  final codigo = await processo.exitCode;
  if (codigo != 0) {
    stderr.writeln(
      '\n✗ "$rotulo" falhou (código $codigo). Nada foi publicado.',
    );
    exit(codigo);
  }
}
