// Build web + deploy pro Firebase, na ordem certa e sem esquecer nenhum passo.
//
// Uso:
//   dart run tool/deploy.dart                  # completo (verifica, builda, poda, publica)
//   dart run tool/deploy.dart --limpar         # com flutter clean antes (ver abaixo)
//   dart run tool/deploy.dart --rapido         # pula analyze/test
//   dart run tool/deploy.dart --sem-deploy     # para depois da poda, não publica
//   dart run tool/deploy.dart --dry-run        # só mostra o que seria feito
//   dart run tool/deploy.dart --no-color       # saída sem cor (útil pra log de CI)
//   dart run tool/deploy.dart --only hosting   # argumentos extras vão pro firebase deploy
//
// Existe como script Dart, e não como alias de shell, porque o projeto é
// usado tanto do PowerShell quanto do Git Bash — e porque um alias mora na
// máquina de uma pessoa só, enquanto isto fica versionado junto do código
// que ele depende.

import 'dart:io';

import 'cli.dart';
import 'enxugar_build_web.dart';

Future<void> main(List<String> args) async {
  const flagsLocais = {
    '--rapido',
    '--sem-deploy',
    '--limpar',
    '--dry-run',
    '--no-color',
  };

  final rapido = args.contains('--rapido');
  final semDeploy = args.contains('--sem-deploy');
  final limpar = args.contains('--limpar');
  final dryRun = args.contains('--dry-run');
  final paint = Paint(enabled: !args.contains('--no-color'));
  // O que sobra é repassado ao firebase deploy (ex: --only hosting).
  final extrasFirebase = args.where((a) => !flagsLocais.contains(a)).toList();

  final steps = Steps(
    // Passos fixos (repositório, limpeza, dependências, build, poda) + 2 se
    // não for --rapido (analyze/test) + 1 se não for --sem-deploy (publicar).
    total: 5 + (rapido ? 0 : 2) + (semDeploy ? 0 : 1),
    dryRun: dryRun,
    paint: paint,
  );
  final started = DateTime.now();

  final flags = [
    if (dryRun) 'simulação',
    if (rapido) 'sem conferência',
    if (limpar) 'com limpeza total',
    if (semDeploy) 'sem publicar',
  ];
  banner(
    paint,
    'Bolão Bolado · deploy',
    subtitulo: flags.isEmpty ? null : flags.join(' · '),
  );

  steps.begin('Conferindo o repositório');
  requireRepositoryRoot(paint, 'deploy.dart');
  steps.done('raiz confirmada');

  if (!rapido) {
    steps.begin('Analisando o código');
    await steps.run('flutter', ['analyze']);
    steps.done('sem problemas');

    steps.begin('Rodando os testes');
    await steps.run('flutter', ['test']);
    steps.done('tudo passou');
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
    steps.begin('Limpando tudo', hint: 'flutter clean');
    await steps.run('flutter', ['clean']);
    steps.done('cache zerado');
  } else {
    steps.begin('Limpando build/web');
    if (!dryRun) {
      final build = Directory('build/web');
      if (build.existsSync()) await _apagarComRetentativa(build);
    }
    steps.done('sem sobra de build anterior');
  }

  steps.begin('Instalando dependências');
  await steps.run('flutter', ['pub', 'get']);
  steps.done('pubspec resolvido');

  // --no-web-resources-cdn: serve o CanvasKit do próprio Hosting em vez do
  // gstatic.com. Ver CLAUDE.md (seção Deploy) para o porquê.
  steps.begin('Compilando para web', hint: 'a primeira vez demora');
  await steps.run('flutter', [
    'build',
    'web',
    '--release',
    '--no-web-resources-cdn',
  ]);
  steps.done('build pronto');

  steps.begin('Enxugando o build');
  if (!dryRun && !enxugarBuildWeb()) {
    fail(paint, 'Poda falhou — deploy abortado.');
  }
  steps.done(dryRun ? 'simulado' : 'symbols/skwasm fora do bundle');

  if (semDeploy) {
    _resumo(
      paint,
      elapsed: DateTime.now().difference(started),
      dryRun: dryRun,
      publicado: false,
    );
    return;
  }

  steps.begin('Publicando no Firebase Hosting');
  await steps.run('firebase', ['deploy', ...extrasFirebase]);
  steps.done('no ar');

  _resumo(
    paint,
    elapsed: DateTime.now().difference(started),
    dryRun: dryRun,
    publicado: true,
  );
}

void _resumo(
  Paint paint, {
  required Duration elapsed,
  required bool dryRun,
  required bool publicado,
}) {
  stdout.writeln('');
  if (dryRun) {
    stdout
      ..writeln(paint.dim('  Nada foi executado (--dry-run).'))
      ..writeln('');
    return;
  }

  final tamanho = _tamanhoDoBuild();
  stdout
    ..writeln(
      '  ${paint.ok('●')} '
      '${paint.title(publicado ? 'Publicado' : 'Build pronto (não publicado)')}',
    )
    ..writeln('  ${paint.dim('│')}')
    ..writeln('  ${paint.dim('├─ tempo total   ${formatDuration(elapsed)}')}')
    ..writeln('  ${paint.dim('├─ arquivos      ${tamanho.arquivos}')}')
    ..writeln(
      '  ${paint.dim('└─ peso          ${formatBytes(tamanho.bytes)}')}',
    )
    ..writeln('');
}

/// Quantos arquivos e quantos bytes foram publicados.
class _TamanhoBuild {
  const _TamanhoBuild(this.arquivos, this.bytes);

  final int arquivos;
  final int bytes;
}

_TamanhoBuild _tamanhoDoBuild() {
  var arquivos = 0;
  var bytes = 0;
  final dir = Directory('build/web');
  if (!dir.existsSync()) return const _TamanhoBuild(0, 0);
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is File) {
      arquivos++;
      bytes += entity.lengthSync();
    }
  }
  return _TamanhoBuild(arquivos, bytes);
}

/// Apaga [dir] recursivamente, tentando de novo se o Windows devolver
/// "arquivo já está sendo usado por outro processo" (comum logo após rodar
/// os testes — o antivírus/indexador do Windows abre e solta um handle na
/// pasta recém-tocada, e o `deleteSync` não espera isso passar sozinho).
Future<void> _apagarComRetentativa(Directory dir) async {
  const tentativas = 5;
  for (var i = 1; i <= tentativas; i++) {
    try {
      dir.deleteSync(recursive: true);
      return;
    } on FileSystemException {
      if (i == tentativas) rethrow;
      await Future<void>.delayed(Duration(milliseconds: 300 * i));
    }
  }
}
