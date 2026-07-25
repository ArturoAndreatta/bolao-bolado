// Remove do `build/web` arquivos que o Flutter sempre copia mas que este
// app nunca busca em runtime, e tira as entradas correspondentes do
// `flutter_service_worker.js`.
//
// Por que isso importa: o service worker gerado pelo Flutter baixa o
// conteúdo inteiro de `RESOURCES` em segundo plano na primeira visita. Sem
// enxugar, isso eram ~36 MB por primeira abertura — em rede lenta, esse
// download em paralelo sufoca as próprias leituras do Firestore e a tela
// fica no skeleton por vários segundos.
//
// O que é removido, e por quê é seguro:
//
//   * `canvaskit/skwasm*` — só são carregados quando o app é compilado com
//     `--wasm` (renderer `skwasm`). Este build usa dart2js + canvaskit, e o
//     script confere isso no `buildConfig` antes de remover: se algum dia o
//     projeto passar a compilar para wasm, o skwasm é preservado sozinho.
//
//   * `**/*.symbols` — mapas de símbolo usados por `flutter symbolize` e
//     pelo DevTools ao desofuscar um stack trace. Nada no app os busca (o
//     bootstrap e o canvaskit.js não os referenciam), então servi-los só
//     ocupa banda.
//
// Rodar SEMPRE depois do `flutter build web` e ANTES do deploy — o build
// regenera os arquivos, então o efeito não é permanente.
//
// Uso: dart run tool/enxugar_build_web.dart

import 'dart:convert';
import 'dart:io';

const _dirBuild = 'build/web';

void main(List<String> args) {
  if (!enxugarBuildWeb()) exitCode = 1;
}

/// Executa a poda. Devolve `false` se o build nem existe (nada foi feito).
///
/// Separada de [main] para o `tool/deploy.dart` chamar direto, em vez de
/// duplicar a lógica ou depender de rodar o script como subprocesso — assim
/// as duas rotas de deploy nunca divergem.
bool enxugarBuildWeb() {
  final build = Directory(_dirBuild);
  if (!build.existsSync()) {
    stderr.writeln(
      'Pasta $_dirBuild não existe. Rode `flutter build web` antes.',
    );
    return false;
  }

  final usaSkwasm = _renderers().contains('skwasm');
  if (usaSkwasm) {
    stdout.writeln(
      'buildConfig usa o renderer skwasm — os arquivos skwasm* serão mantidos.',
    );
  }

  final aRemover = <File>[];
  for (final entidade in build.listSync(recursive: true)) {
    if (entidade is! File) continue;

    final caminho = entidade.path.replaceAll(r'\', '/');
    final nome = caminho.split('/').last;

    if (nome.endsWith('.symbols')) {
      aRemover.add(entidade);
      continue;
    }
    if (!usaSkwasm && nome.startsWith('skwasm')) {
      aRemover.add(entidade);
    }
  }

  if (aRemover.isEmpty) {
    stdout.writeln('Nada a remover — build já está enxuto.');
    return true;
  }

  // Relativiza antes de apagar: são essas chaves que precisam sair do
  // manifesto do service worker.
  final prefixo = build.path.replaceAll(r'\', '/');
  final chaves = aRemover
      .map((f) => f.path.replaceAll(r'\', '/').substring(prefixo.length + 1))
      .toSet();

  var bytesLiberados = 0;
  for (final arquivo in aRemover) {
    bytesLiberados += arquivo.lengthSync();
    arquivo.deleteSync();
  }

  final removidasDoManifesto = _limparServiceWorker(chaves);

  stdout.writeln(
    'Removidos ${aRemover.length} arquivos '
    '(${(bytesLiberados / 1e6).toStringAsFixed(1)} MB) e '
    '$removidasDoManifesto entradas do flutter_service_worker.js.',
  );
  return true;
}

/// Renderers declarados no `_flutter.buildConfig` do flutter_bootstrap.js.
/// Devolve vazio se não conseguir ler — e aí o script preserva skwasm por
/// precaução, em vez de apagar algo que talvez seja necessário.
Set<String> _renderers() {
  final bootstrap = File('$_dirBuild/flutter_bootstrap.js');
  if (!bootstrap.existsSync()) return {'skwasm'};

  final match = RegExp(
    r'_flutter\.buildConfig\s*=\s*(\{.*?\});',
    dotAll: true,
  ).firstMatch(bootstrap.readAsStringSync());
  if (match == null) return {'skwasm'};

  try {
    final config = jsonDecode(match.group(1)!) as Map<String, dynamic>;
    final builds = (config['builds'] as List?) ?? const [];
    return builds
        .whereType<Map<String, dynamic>>()
        .map((b) => b['renderer']?.toString())
        .whereType<String>()
        .toSet();
  } catch (_) {
    return {'skwasm'};
  }
}

/// Tira as [chaves] do objeto `RESOURCES` do service worker. Sem isso o
/// `cache.addAll()` da instalação bateria em 404 nos arquivos apagados e o
/// cache offline inteiro falharia.
int _limparServiceWorker(Set<String> chaves) {
  final sw = File('$_dirBuild/flutter_service_worker.js');
  if (!sw.existsSync()) return 0;

  final conteudo = sw.readAsStringSync();
  final bloco = RegExp(
    r'const RESOURCES = \{(.*?)\};',
    dotAll: true,
  ).firstMatch(conteudo);
  if (bloco == null) return 0;

  final entradas = RegExp(r'"([^"]+)":\s*"([0-9a-f]+)"')
      .allMatches(bloco.group(1)!)
      .where((m) => !chaves.contains(m.group(1)))
      .map((m) => '"${m.group(1)}": "${m.group(2)}"')
      .toList();

  final total = RegExp(
    r'"([^"]+)":\s*"([0-9a-f]+)"',
  ).allMatches(bloco.group(1)!).length;

  sw.writeAsStringSync(
    conteudo.replaceRange(
      bloco.start,
      bloco.end,
      'const RESOURCES = {${entradas.join(',\n')}};',
    ),
  );

  return total - entradas.length;
}
