// O `flutter build web` troca os {{...}} e grava o resultado em
// build/web/flutter_bootstrap.js. Sem este arquivo o Flutter gera um padrão,
// que registra `flutter_service_worker.js?v=<número>`.
//
// SEM `serviceWorkerSettings`: quem registra o worker é o script de detecção
// de versão nova no `web/index.html`, num endereço FIXO. O `?v=` muda quando o
// index.html, este molde ou o SDK mudam, e aí o flutter.js registrava o worker
// de novo logo depois do "Atualizar agora": baixava o app outra vez e o aviso
// de versão nova reabria já na versão nova. O deploy barra a volta do `?v=`.
//
// O CanvasKit vem do próprio Hosting pelo `--no-web-resources-cdn` do build
// (ver CLAUDE.md), não por config aqui.
{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load();
