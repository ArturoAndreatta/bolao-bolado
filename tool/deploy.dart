// Build web + deploy pro Firebase, na ordem certa e sem esquecer nenhum passo.
//
// Uso:
//   dart run tool/deploy.dart                  # completo (verifica, builda, poda, publica)
//   dart run tool/deploy.dart --limpar         # com flutter clean antes (ver abaixo)
//   dart run tool/deploy.dart --rapido         # pula analyze/test
//   dart run tool/deploy.dart --sem-deploy     # para depois da poda, não publica
//   dart run tool/deploy.dart --only hosting   # argumentos extras vão pro firebase deploy
//
// Existe como script Dart, e não como alias de shell, porque o projeto é
// usado tanto do PowerShell quanto do Git Bash — e porque um alias mora na
// máquina de uma pessoa só, enquanto isto fica versionado junto do código
// que ele depende.

import 'dart:io';

import 'enxugar_build_web.dart';

Future<void> main(List<String> args) async {
  const flagsLocais = {'--rapido', '--sem-deploy', '--limpar'};

  final rapido = args.contains('--rapido');
  final semDeploy = args.contains('--sem-deploy');
  final limpar = args.contains('--limpar');
  // O que sobra é repassado ao firebase deploy (ex: --only hosting).
  final extrasFirebase = args.where((a) => !flagsLocais.contains(a)).toList();

  // Verificação antes de publicar: as mesmas checagens do CI. Publicar é
  // o passo difícil de desfazer aqui, então vale gastar meio minuto.
  if (!rapido) {
    await _rodar('flutter', ['analyze'], 'Análise estática');
    await _rodar('flutter', ['test'], 'Testes');
  }

  // Por padrão apaga só o build/web, em vez de rodar `flutter clean`.
  //
  // O efeito que importa num deploy é não publicar sobra de build anterior —
  // é assim que assets removidos do pubspec continuariam indo pro Hosting — e
  // apagar build/web já resolve isso. O que o clean apaga a mais é o
  // .dart_tool, que é cache incremental indexado por hash de conteúdo e tem o
  // pubspec.yaml entre as entradas: mudou o pubspec, o Flutter reconstrói o
  // bundle sozinho. Limpar sempre só troca ~40s de build por 2+ minutos.
  //
  // --limpar existe para os casos em que o cache realmente pode estar
  // inconsistente: upgrade do SDK do Flutter, troca de versão de dependência,
  // ou um erro de build inexplicável.
  if (limpar) {
    await _rodar('flutter', ['clean'], 'Limpeza completa');
  } else {
    final build = Directory('build/web');
    if (build.existsSync()) {
      stdout.writeln('\n▶ Limpando build/web');
      build.deleteSync(recursive: true);
    }
  }

  await _rodar('flutter', ['pub', 'get'], 'Dependências');

  // --no-web-resources-cdn: serve o CanvasKit do próprio Hosting em vez do
  // gstatic.com. Ver CLAUDE.md (seção Deploy) para o porquê.
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

  if (semDeploy) {
    stdout.writeln(
      '\n✓ Build pronto em build/web (--sem-deploy, não publicado).',
    );
    return;
  }

  await _rodar('firebase', ['deploy', ...extrasFirebase], 'Deploy');
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
