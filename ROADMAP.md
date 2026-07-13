# Roadmap / Pendências — Bolão Bolado

Levantamento de melhorias, correções e ideias para evolução do app, organizado por prioridade.
Gerado a partir de uma análise completa da base de código em 2026-07-09.

---

## 🔴 Segurança (prioridade alta)

- [ ] **Vazamento de dados entre salas**: as regras do Firestore (`firestore.rules`) permitem que qualquer usuário autenticado (inclusive anônimo, no caso de `Mensagens`) leia `Participantes`/`Mensagens` de **qualquer** sala, não só das que participa. Isso expõe valores apostados por terceiros. Deveria restringir leitura a quem tem doc próprio em `Participantes` daquela sala.
- [ ] **Regra de negócio só validada no client**: o valor da aposta precisa ser múltiplo do preço da cota (ex. R$6 na Mega-Sena), mas isso só é checado no Dart (`informar_aposta.dart`, `painel_admin.dart`), não nas Firestore Rules. Um cliente malicioso pode escrever valores inválidos direto no Firestore.
- [ ] **Sem verificação de e-mail** no cadastro (`auth_service.dart`) — qualquer email, mesmo falso, cria conta. Considerar `sendEmailVerification()`.
- [ ] **Ferramenta de simulação de apostas exposta em produção**: `lib/dev/simulador_apostas.dart` e o botão correspondente no `painel_admin.dart` parecem acessíveis fora do modo debug. Confirmar se está atrás de `kDebugMode` ou remover/isolar por flavor.
- [ ] **`functions/node_modules` (62MB) commitado no git**: a pasta `functions/` não tem `package.json` nem `index.js` — é scaffold 100% vazio (só dependências instaladas e commitadas por engano). O README e a lista de tecnologias citam "Cloud Functions" como parte do stack, mas não existe nenhuma função implementada — toda regra de negócio roda só no client. Ação: adicionar `.gitignore` para `functions/node_modules` e decidir se vale implementar validação/triggers server-side de verdade (rate limiting, validação de valor múltiplo de cota, notificação ao confirmar aposta, etc.) ou remover a pasta e a menção no README.
- [ ] **Sem Firebase App Check**: `firebase_options.dart` e `android/app/google-services.json` estão commitados no repositório (esperado para apps Firebase, chaves são públicas por design), mas sem App Check configurado essas chaves ficam mais expostas a abuso/scraping por bots.
- [ ] **User enumeration no "esqueci minha senha"**: `lib/pages/auth/forgot_password.dart` (~linha 120) mostra "E-mail não encontrado." quando o código de erro é `user-not-found`, permitindo a um atacante descobrir quais e-mails estão cadastrados. Corrigir para sempre exibir mensagem genérica ("se o e-mail existir, enviaremos um link"), independente do resultado.
 
## 🟠 Observabilidade (hoje é zero)

- [ ] **Adicionar Firebase Crashlytics** — sem isso, crashes em produção passam despercebidos.
- [ ] **Adicionar Firebase Analytics** (ou similar) para entender uso real do app.
- [ ] Erros hoje só vão para `debugPrint`, que não aparece fora do modo debug — criar um serviço central de log de erro.

## 🟡 Funcionalidades pendentes/incompletas

- [ ] **Excluir sala**: comentado no `firestore.rules` como "ajuste futuro: apenas o criador da sala", nunca implementado. Precisa também guardar `criadorUid` no doc da sala.
- [ ] **Múltiplas salas x "sala principal"**: o app tem cadastro/consulta de várias salas, mas o fluxo real de apostar sempre usa uma "sala principal" fixa (`buscarSalaPrincipalId()` com fallback hardcoded). Decidir: abraçar multi-sala de verdade, ou simplificar removendo a parte não usada.
- [ ] **Rejeitar aposta**: o admin só pode confirmar apostas pendentes no painel, não recusar/apagar uma errada.
- [ ] **Aposta manual sem dono**: apostas lançadas pelo admin para quem não tem conta ficam com ID artificial (`manual_<timestamp>`) e não podem ser "reivindicadas" depois se a pessoa criar conta — gera duplicidade potencial.
- [ ] **Notificações push**: nada de `firebase_messaging` no projeto. Avisar quando a aposta é confirmada ou chega mensagem no chat.
- [ ] **Sem forma de convidar/compartilhar sala**: nenhum `share_plus`, QR code ou link de convite — hoje a única forma de entrar numa sala é o admin adicionar manualmente. Lacuna grande para um produto que é literalmente "bolão entre amigos".
- [ ] **Sem histórico de bolões passados**: não há coleção/tela de resultados de sorteios anteriores nem estatísticas históricas do usuário ao longo de múltiplas rodadas — o app só enxerga o bolão/sala corrente.
- [ ] **Sem exportação de dados**: o admin não tem como baixar a lista de participantes/apostas em CSV/Excel para análise externa.
- [ ] **Sem onboarding/tutorial**: nenhuma explicação in-app de como funciona o bolão, como apostar, como funciona a cota — usuário novo cai direto nas telas de cadastro/login sem contexto.

## 🟢 Qualidade/manutenção

- [ ] **Cobertura de testes muito baixa**: só a função pura de cálculo de cotas/prêmios (`bet_service_test.dart`) é testada. Faltam testes de widget, de regras do Firestore (`@firebase/rules-unit-testing`), e dos services de auth/chat.
- [ ] **`intl: any` no pubspec.yaml** sem faixa de versão fixada — risco de quebra silenciosa num `flutter pub upgrade`.
- [ ] **Paginação ausente** na lista de apostas pendentes do admin (`collectionGroup` sem `limit`) — pode ficar lento com volume de dados.
- [ ] **l10n declarado mas não usado**: `flutter_localizations` está no pubspec mas não há pasta `l10n/` nem arquivos `.arb` — app é 100% português hardcoded. Só relevante se algum dia quiser suportar outro idioma.
- [ ] **CI não faz build/deploy**: pipeline atual (`.github/workflows/ci.yml`) só roda format + analyze + test. Poderia automatizar deploy do web/Firebase Hosting.
- [ ] Rodar `flutter pub outdated` periodicamente para revisar dependências.
- [ ] **Zero acessibilidade**: nenhum `Semantics(label: ...)` em todo o `lib/`, `Tooltip` usado em um único arquivo. Leitores de tela não conseguem descrever botões de ícone (ex. mostrar/ocultar senha no `signup.dart`). Sem verificação de contraste WCAG na paleta de cores nem de área mínima de toque (48x48dp).
- [ ] **Sem tratamento de conectividade/offline**: nenhum uso de `connectivity_plus`, nenhum indicador de "sem conexão" em nenhuma tela, e nenhum tratamento de `TimeoutException`/`SocketException`/erro `unavailable` do Firestore em lugar nenhum do código. Se o Firestore ficar indisponível, o app provavelmente trava em loading indefinido.
- [ ] **Avatares PNG excessivamente pesados**: `avatars/avatar_1.png` a `avatar_7.png` pesam ~2MB cada (deveriam ser <100KB, ideal em WebP). Sem uso de `cacheWidth`/`cacheHeight` nas imagens, agravando consumo de memória.
- [ ] **Validação de senha fraca no cadastro**: `lib/pages/auth/signup.dart` (~linha 71) não tem `validator` de tamanho mínimo/força de senha (só checa não-vazio) nem campo de "confirmar senha" — usuário só descobre a exigência de 6+ caracteres quando o Firebase rejeita no submit.
- [ ] **Sem `CHANGELOG.md`** e versão do `pubspec.yaml` nunca incrementada (segue em `1.0.0+1`) — sem disciplina de versionamento/release notes.
- [ ] **README com imprecisão**: lista "Cloud Functions (`/functions`)" como tecnologia usada, mas a pasta está vazia (ver item de Cloud Functions acima) — corrigir para não confundir novos colaboradores.

---

## Notas de contexto (do levantamento original)

- Estrutura organizada por tipo técnico (`lib/pages`, `lib/services`, `lib/components`), não por feature — funciona, mas há lógica de acesso a dados espalhada direto nas telas em vez de repositórios centralizados.
- Só 2 models tipados (`Sala`, `Mensagem`); participantes/apostas são `Map<String, dynamic>` soltos na maior parte do código.
- Telas mobile/desktop separadas em alguns fluxos (ex. `cadastrar_sala_mobile.dart` / `cadastrar_sala_desktop.dart`) — funciona mas duplica lógica de formulário e pode divergir com o tempo.
- Painel admin (`lib/pages/admin/painel_admin.dart`) é robusto: dashboard de stats, lista de pendentes, lançamento manual — mas sem paginação e sem opção de rejeitar aposta.
- Autenticação sempre mantém uma sessão (anônima por padrão), o que é uma escolha de design interessante para permitir leitura pública sem forçar login — importante notar que isso também significa que nunca existe estado "deslogado" de verdade, e sessões não expiram por timeout de inatividade.
- Validação de formulário em geral é boa: componente central `CustomField` com `AutovalidateMode.onUserInteraction` usado de forma consistente na maior parte do app (a exceção é a senha do cadastro, listada acima).
- Performance geral está ok: `ListView.builder` usado corretamente nas listas longas, sem `StreamBuilder`s aninhados perigosos — os problemas de performance encontrados são pontuais (peso dos assets de avatar).
