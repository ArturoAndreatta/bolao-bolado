# CLAUDE.md

Guia para agentes de IA trabalhando neste repositório. O código, comentários e
identificadores estão em **português** — mantenha esse padrão ao escrever código
novo, comentários e mensagens de commit.

## Como responder ao usuário

As respostas em texto (não o código) devem seguir isto:

- **Linguagem direta, sem jargão desnecessário.** Nada de enfeitar a resposta
  com termo técnico onde uma palavra normal serve.
- Comece pelo **que muda na prática** — o que aparece na tela, o que fica mais
  rápido, o que pode quebrar — e só depois detalhe como foi feito.
- Respostas **curtas**, sem despejar código ou logs que não foram pedidos. Se um
  trecho de código ajudar a explicar, mostre só ele.
- Quando um termo específico do projeto for necessário (stream compartilhada,
  precache do service worker, sala principal), **diga em uma frase o que ele
  significa aqui** em vez de assumir o contexto.
- Se o usuário pedir mais profundidade ("explica melhor", "como funciona por
  baixo"), aí sim entre no detalhe técnico completo.

Isso vale só para a conversa: **o código, os comentários e os commits continuam
no padrão técnico e em português** descrito no resto deste arquivo.

## O que é o projeto

**Bolão Bolado** — app Flutter multiplataforma (web, Android, iOS, desktop) para
organizar e participar de bolões: cadastro de salas, gerenciamento de
participantes, registro/simulação de apostas, chat em tempo real e painel
administrativo. Backend em **Firebase** (Auth, Cloud Firestore, Hosting).

## Comandos

```bash
flutter pub get                 # instalar dependências
flutter run -d chrome           # rodar na web
flutter run                     # rodar em emulador/dispositivo mobile
flutter run -d windows          # rodar no desktop

flutter analyze                 # análise estática (deve passar limpo)
dart format .                   # formatar (o CI falha se algo não estiver formatado)
flutter test                    # rodar todos os testes
flutter test test/services/bet_service_test.dart   # um arquivo só
```

O **CI** (`.github/workflows/ci.yml`, roda em push/PR para `main`) executa, nesta
ordem: `flutter pub get` → `dart format --set-exit-if-changed` → `flutter analyze`
→ `flutter test`. **Rode os três (format, analyze, test) localmente antes de
finalizar qualquer mudança** — o CI trava com qualquer um deles falhando.

Existe um hook de pre-commit (`.git/hooks/pre-commit`) que formata os arquivos
Dart staged automaticamente, mas não confie só nele: ele só cobre o que está
staged.

## Deploy (Firebase — projeto `bolaobolado-app`)

```bash
dart run tool/deploy.dart                  # caminho normal: verifica, builda, poda e publica
dart run tool/deploy.dart --limpar         # idem, com flutter clean antes
dart run tool/deploy.dart --rapido         # pula analyze/test
dart run tool/deploy.dart --sem-deploy     # só gera build/web, não publica
dart run tool/deploy.dart --only hosting   # argumentos extras vão pro firebase deploy
```

**Use o comando pelado por padrão.** As flags são exceção:

- `--limpar` só quando o cache de build pode estar inconsistente de verdade
  (upgrade do SDK do Flutter, troca de versão de dependência, erro de build
  inexplicável). Rodar `flutter clean` sempre troca ~40s de build por 2+
  minutos sem ganho: apagar `build/web` — o que o script já faz sozinho — é o
  que evita publicar sobra de build antigo, e o `.dart_tool` tem o
  `pubspec.yaml` entre suas entradas, então mudança de asset já invalida o
  bundle sem clean.
- `--rapido` economiza poucos segundos (analyze ~2s, testes <1s). Quase nunca
  vale pular a verificação antes de publicar.

[tool/deploy.dart](tool/deploy.dart) roda, nesta ordem: `flutter analyze` →
`flutter test` → apaga `build/web` → `flutter pub get` →
`flutter build web --release --no-web-resources-cdn` → poda
([tool/enxugar_build_web.dart](tool/enxugar_build_web.dart)) → `firebase deploy`.
Qualquer passo que falhe aborta antes de publicar.

Regras e índices do Firestore ficam em `firestore.rules` e
`firestore.indexes.json` na raiz; o `firebase deploy` sem `--only` publica eles
junto com o hosting. O hosting serve `build/web`.

Equivalente manual, se precisar rodar passo a passo:

```bash
flutter build web --no-web-resources-cdn
dart run tool/enxugar_build_web.dart
firebase deploy --only hosting
```

**Não simplifique o build para `flutter build web` puro** — as duas flags/passos
extras existem por causa do peso do carregamento inicial:

- `--no-web-resources-cdn` faz o CanvasKit ser servido pelo próprio Hosting em
  vez do `www.gstatic.com`. Sem isso o build copia o CanvasKit para
  `build/web/canvaskit/` (e o service worker o pré-cacheia!) mas em runtime o
  bootstrap busca tudo de novo no gstatic — paga-se o download duas vezes, e a
  cópia do gstatic é cross-origin, então o service worker não consegue reusá-la
  nas próximas aberturas.
- `tool/enxugar_build_web.dart` remove do build os `*.symbols` e os `skwasm*`
  (só usados em build `--wasm`) e tira as entradas correspondentes do
  `flutter_service_worker.js`. Ver o cabeçalho do script para o porquê.

O service worker do Flutter baixa **todo** o `RESOURCES` em segundo plano na
primeira visita, então cada MB desnecessário ali é banda disputando com as
leituras do Firestore na primeira carga. Hoje esse precache está em ~21 MB
(era ~52 MB). Se ele voltar a crescer, conferir com:

```bash
python -c "import re,os;s=open('build/web/flutter_service_worker.js',encoding='utf8').read();e=re.findall(r'\"([^\"]+)\":\s*\"[0-9a-f]+\"',re.search(r'const RESOURCES = \{(.*?)\};',s,re.S).group(1));print('%.1f MB'%(sum(os.path.getsize('build/web/'+x) for x in e)/1e6))"
```

Por isso também os assets no `pubspec.yaml` são listados **arquivo a arquivo**,
nunca por pasta: declarar `images/`/`avatars/` arrastava ~16 MB de imagens sem
uso para dentro do bundle e do precache.

## Arquitetura

```
lib/
├── main.dart              # entrada: inicializa Firebase + login (ver abaixo)
├── bolao_bolado.dart      # widget raiz (MaterialApp + tema)
├── router/app_router.dart # go_router: AppRoutes + redirect de auth
├── core/                  # utilitários centrais (responsive, app_radii, debug_flags)
├── models/                # Sala, Mensagem (com factory .fromDoc)
├── services/              # regras de negócio + acesso ao Firestore
├── pages/                 # telas (uma pasta por tela complexa)
├── components/            # UI reutilizável (shared/ e shell/)
├── widgets/               # widgets compostos específicos de telas
└── dev/                   # ferramentas de dev (ex: simulador_apostas)
```

**Navegação:** `go_router`. Todas as rotas ficam em `AppRoutes` em
[app_router.dart](lib/router/app_router.dart). O `redirect` global protege rotas:
usuário só é "logado de verdade" quando `user != null && !user.isAnonymous` —
usuários **anônimos** contam como não-logados para efeito de rotas privadas.
Transições de página são instantâneas (`_noTransitionPage`, `Duration.zero`).

**Camada de serviços:** funções top-level (não classes) que encapsulam Firestore,
em `services/`. É onde vive a lógica de apostas, avatares, chat, auth e PIX.

## Cores e tema (claro/escuro)

O app tem **dark mode**, e por isso **nenhum widget escreve cor literal**. Toda
cor sai da paleta semântica de [app_cores.dart](lib/core/app_cores.dart):

```dart
final cores = AppCores.de(context);   // resolve pelo Theme.of(context).brightness
Container(color: cores.card, child: Text('x', style: TextStyle(color: cores.texto)));
```

Os nomes descrevem o **papel** da cor, não o tom (`card`, `cardExterno`, `campo`,
`superficieAlta`, `texto`, `textoSuave`, `textoFraco`, `borda`, `azul`, `verde`,
`fundoVerde`/`bordaVerde`/`textoVerde` para blocos de estado, etc). Ao precisar
de uma cor nova, **adicione um campo nos dois temas** em vez de escrever um hex
no widget — um `Color(0xFF...)` solto fica correto num tema e quebra no outro.

- Os valores do tema claro são exatamente os hex que existiam antes do dark
  mode: **o tema claro não mudou de aparência**.
- O tema escuro **não é o claro invertido**. As superfícies sobem de tom
  conforme se aproximam do usuário (`ficharioFundo` < `cardExterno` < `card` <
  `campo`) — no escuro a sombra quase não aparece, então a hierarquia vem da
  luminosidade. Azul e verde são versões CLAREADAS (o `#2E7D32` original tem
  ~2:1 de contraste sobre fundo escuro, ilegível).
- **Traduzir cor do claro para o escuro é baixar SATURAÇÃO, não só
  luminosidade.** Escurecer os tons originais mantendo a saturação foi o que
  produziu, nas primeiras tentativas, uma tela lodosa/amarronzada. Vale para
  o gradiente de fundo (que preserva os matizes exatos do claro — 43° e 163°)
  e para os `fundoVerde`/`fundoAmarelo` dos cards.
- **A metáfora do tema escuro é MESA DE JOGO: feltro e ouro.** Toda a escala de
  superfícies (`ficharioFundo` → `superficieAlta`) usa o matiz **163°**, que é
  o do `#7CC8B5` do gradiente claro, com saturação caindo de 20% a 13% conforme
  sobe. O `dourado` (`#E5C061`, sat 72%) é a cor de acento e lê como metal
  sobre o feltro. Isso não é decoração arbitrária: é a identidade que o tema
  claro já tinha (gradiente ouro→verde-água), agora levada a sério no escuro —
  e combina com um produto de bolão/aposta em vez de um dashboard genérico.
- **Superfície e gradiente compartilham o matiz de propósito.** Duas tentativas
  anteriores erraram os extremos: azul-ardósia a sat 25% (matiz 222°) brigava
  com o gradiente dourado/verde-água — ~175° de distância, praticamente
  complementares, e o card lia como placa colada por cima; e carvão neutro a
  sat 6% era correto porém sem personalidade nenhuma. Usar o **mesmo matiz** na
  escala inteira torna o conflito impossível por construção, e é o que libera
  o gradiente a ter saturação alta (~43%) sem risco.
- **O gradiente escuro é MAIS ESCURO que o card** (contraste ~1.12), e usa
  `paradasGradiente` `[0.0, 1.0]` em vez do `[0.5, 0.9]` do claro. Os dois
  detalhes resolvem problemas opostos: mais escuro faz o card flutuar sobre a
  mesa (no escuro a sombra some, a profundidade vem da luminosidade), e
  espalhar o degradê pela tela inteira é o que torna a diagonal ouro→feltro
  perceptível apesar da amplitude curta — com os stops do claro, metade do
  viewport ficava em cor chapada e o fundo lia como preto uniforme. **Ao mexer
  no fundo, mexa junto no `card`**: clarear o fundo para destacar a diagonal
  faz o card afundar, escurecer para destacar o card apaga a diagonal.
- **Estado de linha no escuro é BARRA, não fundo.** Pintar a linha inteira de
  verde/âmbar (a tradução direta do claro) transformava a tabela num tabuleiro
  de faixas que competia com os dados. No escuro o fundo fica na cor da zebra
  e o estado vira uma barra de 3px na borda esquerda — `cores.larguraBarraEstado`
  (0 no claro, 3 no escuro) é o que decide, e `TabelaApostas.corLinhaEstado` /
  `corBarraEstado` encapsulam a regra para tabela e lista mobile.
- **Blocos coloridos grandes precisam ser insinuados no escuro.** Cards de
  estatística, a moldura do Fichario e a **aba ativa** usam `Color.alphaBlend`
  da cor de marca a 7–30% sobre a superfície. Cor chapada num bloco grande
  vira a coisa mais forte da tela. Cuidado ao inverter isso: pintar o RÓTULO
  com a cor cheia sobre o fundo tingido da mesma cor não passa AA (o roxo e o
  azul ficam em ~3.4:1) — nas abas o texto continua branco, e é o fundo que
  identifica a seção.
- **Toda cor nova precisa passar AA (4.5:1) sobre `card` e `campo`.** Vale
  também para `textoFraco`, que apesar do nome carrega dado real (cotas,
  timestamps na lista) — ele já foi clareado duas vezes por isso.
- **CTA usa `acaoPrimaria`/`textoSobreAcao`, nunca `azul` direto.** Azul no
  claro, dourado no escuro: sobre feltro o botão azul era a única coisa fria
  da tela, e branco sobre ele dava 2.74:1 (reprovado, no botão que confirma
  dinheiro). O `azul` continua na paleta para cursor, chips, ícones e a 2ª cor
  do Fichario — o que mudou foi só o papel de ação primária.
- `AdminCores.de(context)` ([admin_widgets.dart](lib/pages/admin/widgets/admin_widgets.dart))
  é a mesma ideia com nomes do painel admin (`fundoSecao`, `fundoTile`).
- `cores.escuro` existe para os poucos casos em que a decisão não é uma cor e
  sim uma medida (elevação do card, campo que precisa recuar em vez de saltar).
- **Cuidado com `const`:** a paleta não é mais `const`, então `const TextStyle(
  color: cores.texto)` não compila. Tire o `const` do literal mais interno.
- **A troca de tema é ANIMADA (450ms), e a estrutura que permite isso é
  frágil.** `AppCores` é um `ThemeExtension` com `lerp`, registrado em
  `ThemeData.extensions` — é o que faz os ~95 pontos que leem a paleta
  atravessarem juntos, sem precisar de `AnimatedContainer` em lugar nenhum. Ao
  adicionar um campo, adicione a linha correspondente no `lerp`, senão ele
  salta enquanto o resto desliza. Campos `bool` (como `escuro`) viram em
  `t < 0.5`: quem decide por eles escolhe uma forma, não uma cor, e forma não
  tem meio-termo.
- **Em [bolao_bolado.dart](lib/bolao_bolado.dart) o `MaterialApp` fica FORA do
  `ValueListenableBuilder` do tema, e a animação acontece num `AnimatedTheme`
  dentro do `builder`.** Não inverta: com o notifier envolvendo o
  `MaterialApp`, trocar de tema reconstrói o próprio `MaterialApp` e o
  `AnimatedTheme` interno perde o estado — fica sem tema anterior de onde
  partir, e `themeAnimationDuration` não produz animação nenhuma (as cores
  saltam no primeiro frame). Pelo mesmo motivo o `themeMode` do `MaterialApp`
  é fixo em `light`: quem decide o tema exibido é o `AnimatedTheme`.

O modo (claro/escuro/sistema) vive em `temaModoGlobal`
([tema_controller.dart](lib/core/tema_controller.dart)), **persistido** via
`shared_preferences` e lido em `main.dart` **antes do primeiro frame** (junto do
`Firebase.initializeApp`, com `.wait`) — senão o app pinta claro e pisca para o
escuro. O seletor fica no rodapé do Drawer. Os `ThemeData` dos dois modos são
montados em [app_tema.dart](lib/core/app_tema.dart), que também cobre o que o
Material desenha sozinho (menus, date/time picker, tooltip, seleção de texto).

**Assets precisam de alpha real.** `images/logo.png` é opaco com fundo branco
chapado — invisível no tema claro, um retângulo branco no escuro. Por isso o
`Logo` usa `logo4.png` por padrão. Ao trocar arte, confira o canal alfa.

## Firebase / Firestore — modelo de dados

Estrutura das coleções:

- `usuarios/{uid}` — perfil (inclui `isAdmin`, cor e emoji do avatar).
- `Salas/{salaId}` — sala de bolão (nome, prêmio, sorteio, `chavePix`, `senha`,
  `valorMaximo`, flag `principal`).
- `Salas/{salaId}/Participantes/{uid}` — **as apostas**. O doc ID É o uid do
  usuário. Campos: `nome`, `valor` (sempre **string**), `verificado`,
  `editadoAposVerificacao`, `data-hora`.
- `Salas/{salaId}/Mensagens/{id}` — chat da sala (histórico imutável).

**Invariantes de segurança** (reforçadas em `firestore.rules` — leia antes de
mexer em qualquer escrita):

- `valor` da aposta é **sempre salvo como string**; o parse pra número acontece
  na leitura. Não grave `valor` como num.
- Um usuário comum **não pode** se auto-marcar `verificado: true` — só admin
  aprova apostas (isso decide quem entra no rateio do prêmio).
- Só admin pode criar/editar sala `principal: true` (a sala principal define a
  chave PIX que recebe o dinheiro).
- `isAdmin` nunca pode ser alterado pelo próprio usuário (só via console/admin SDK).

**Sala principal:** nunca assuma o ID fixo. Use `buscarSalaPrincipalId()`
([bet_service.dart](lib/services/bet/bet_service.dart)), que consulta
`where('principal', isEqualTo: true)`; a constante `kSalaPrincipalIdFallback` é só
fallback de segurança. A descoberta é **memoizada por sessão** (`buscarSalaPrincipal()`
guarda o `Future`): qual sala é a principal só muda via console/admin SDK, então
redescobri-la a cada chamada era só round-trip desperdiçado. Os **dados** da sala
(prêmio, sorteio, chave PIX) continuam ao vivo via `streamSalaPrincipal()` — nunca
devolva o snapshot memoizado como fonte de valores de dinheiro, ele envelhece.

**Latência é o gargalo desta app, não CPU.** O caminho crítico já foi enxugado e
é fácil de estragar sem perceber. Ao mexer em `services/` ou nos `initState` das
telas:

- **Nunca encadeie `await`s independentes.** Use `(futuroA, futuroB).wait`. As
  telas de Participantes, Minha Aposta, Painel ADM e o drawer todas dependem
  disso — cada `await` extra em série é um round-trip inteiro de atraso.
- **`streamBets()` é compartilhada** (broadcast em nível de módulo, com replay
  do último valor por assinante). A página de Participantes e o `MinhaApostaCard`
  escutam a MESMA instância. Não volte a criar um stream novo por chamada: isso
  dobra os listeners do Firestore e o trabalho de montar avatares.
- **`AvatarColorCache` abre um único `snapshots()` por uid**, compartilhado entre
  cor e emoji (saem do mesmo doc `usuarios/{uid}`). As streams derivadas também
  são memoizadas, senão o `StreamBuilder` das bolhas do chat reassina a cada
  rebuild. Use `avatarDe(uid)` quando precisar dos dois de uma vez.
- **Cache local persistente está ligado** (`_configurarFirestore()` em
  [main.dart](lib/main.dart)). É o que faz os `snapshots()` pintarem a tela na
  hora, do IndexedDB, antes da rede responder. Não remova sem medir.

**Preço da cota** varia por tipo de sorteio — nunca use um valor fixo único. Use
`precoCotaPara(sorteio)` ([preco_cota.dart](lib/services/bet/preco_cota.dart)):
Mega-Sena R$6,00, Lotofácil R$3,50. O value legado `'loto'` ainda precisa ser
reconhecido como Lotofácil.

## Autenticação

`main.dart` inicializa o Firebase, aguarda o primeiro evento de
`authStateChanges()` (não só `currentUser`, para restaurar sessão persistida) e
**garante sempre um usuário** — se ninguém logou, faz login anônimo, para o
Firestore permitir leitura pública antes do login real.

**Login automático de dev:** só em `kDebugMode` e só se `DEV_LOGIN_EMAIL` /
`DEV_LOGIN_SENHA` forem passados via `--dart-define-from-file=dev.env.json`
(config "Flutter (auto-login dev)" no `.vscode/launch.json`). Credenciais **nunca**
ficam no código — em release essas const ficam vazias e o bloco não roda. Copie
`dev.env.json.example` para `dev.env.json` (git-ignored) para usar.

## Convenções

- **Idioma:** tudo em português — nomes de variáveis/funções/classes, comentários
  e mensagens de commit (ver histórico do git).
- **Lints:** além do `flutter_lints`, o `analysis_options.yaml` ativa regras
  extras — atenção especial a `use_build_context_synchronously` (não use
  `BuildContext` após `await` sem checar `mounted`), `unawaited_futures`,
  `cancel_subscriptions` e `close_sinks`. Onde um `StreamController` é
  intencionalmente mantido aberto por toda a vida do app, isso é suprimido com
  `// ignore: close_sinks` e um comentário explicando o porquê.
- **Comentários explicam o porquê**, não o quê. O código existente é densamente
  comentado com o raciocínio de decisões não óbvias (caches de stream, fallbacks,
  invariantes) — siga esse padrão em vez de comentários redundantes.
- **Responsividade:** use `core/responsive.dart`. Três faixas: mobile (<600),
  intermediária/tablet (600–1024) e desktop (≥1024). `Responsive.isCompact` (<1440)
  decide quando a tela de Participantes cai do layout lado a lado para abas.

## Testes

Testes em `test/`, espelhando a estrutura de `lib/`. Prioridade para **lógica pura
testável isoladamente** — ex: `calcularCotasEPremios` em `bet_service.dart` é uma
função pura sem Firestore justamente para o cálculo de dinheiro real (rateio de
prêmio) ser validado sem mocks de banco. Ao mexer em cálculo de cotas/prêmios,
atualize/adicione testes em `test/services/bet_service_test.dart`.

## Observações

- `functions/` está preparado para Cloud Functions mas ainda **não tem código-fonte
  versionado** (só `package-lock.json`); `node_modules` é git-ignored.
- Flags de debug de runtime (ex: forçar skeleton de loading) ficam em
  `core/debug_flags.dart` e só são acionáveis pelo Painel ADM — não persistem
  entre sessões.
- Consulte `ROADMAP.md` para o planejamento de funcionalidades.
