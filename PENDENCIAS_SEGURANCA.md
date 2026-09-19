# Pendências de segurança

Registro do que foi configurado fora do código (Vercel, Firebase, Google
Cloud) na varredura de segurança de 19/09/2026, e do que ainda falta.

## Feito

- [x] **Deploy do app e das regras novas do Firestore.**
- [x] **Limpeza dos dados expostos** (`email_api/scripts/limpar_dados_privados.js`):
      e-mail saiu dos 11 perfis públicos e a senha das 7 salas foi para
      `Salas/{id}/Privado/acesso`.
- [x] **API de e-mail (Vercel):** a API é publicada a partir do repositório
      **`ArturoAndreatta/bolao-bolado-email-api`** — NÃO desta pasta
      `email_api/`, que é uma cópia de referência (sincronizada com ele em
      19/09/2026). Mudança na API precisa ir para aquele repositório.
      - Limite de pedidos com Redis Upstash (banco
        `bolao-limites-redefinir-senha`, plano Free, ligado ao projeto; as
        variáveis vieram com o nome `KV_REST_API_URL`/`KV_REST_API_TOKEN`, e
        o código aceita esses nomes).
      - Não revela mais quem tem conta. Com a proteção contra enumeração do
        Firebase ligada, e-mail inexistente chega como `auth/internal-error`
        e antes virava erro 500 — era um vazamento real, confirmado em
        produção.
      - Página de nova senha (`redefinir-senha.html`) exige 8 caracteres com
        letras e números.
- [x] **Firebase Authentication:** proteção contra enumeração de e-mail (já
      estava ligada) e política de senha em modo **Exigir**: mínimo 8, com
      número, sem forçar troca no login (quem tem senha antiga continua
      entrando). "Caractere minúsculo" ficou desmarcado de propósito: o app
      aceita letra maiúscula ou minúscula, e a opção recusaria senha só com
      maiúsculas.
- [x] **App Check, em modo de monitoramento (não exigido):** chave reCAPTCHA
      Enterprise `6LenMcQtAAAAACDkO8MEK-kOk0FC1S0HMghW5Gnx` (domínios
      `bolaobolado-app.web.app`, `bolaobolado-app.firebaseapp.com`,
      `localhost`), registrada no app web e já no código
      (`lib/core/app_check.dart`). Conferido em produção: o site gera e troca
      o token normalmente.

- [x] **App Check EXIGIDO no Cloud Firestore** (19/09/2026). Feito no mesmo
      dia, sem o período de observação, porque o app só é usado na web e
      ainda só por alguns amigos testando.
      - **Os nomes dos apps web no console estão TROCADOS.** O site usa o
        app chamado "Bolão Bolado (Windows)" (`1:854630072700:web:4ef98...`);
        o chamado "Bolão Bolado" (`...web:a581c...`) é o do Windows. O
        primeiro registro no App Check foi feito só no errado, o token nunca
        foi aceito, e ao exigir o site parou de ler o Firestore até o app
        certo ser registrado. Hoje os dois estão registrados com a mesma
        chave. Confira pelo App ID (`firebase apps:list WEB`), nunca pelo
        nome.
      - **Só a web funciona com o Firestore agora.** Os apps Android, iOS e
        Windows não têm App Check e são recusados. Para voltar a usá-los:
        registrar o Android (Play Integrity) / iOS (App Attest) no App Check,
        ou um token de depuração para rodar no Windows.
      - **Não exigir no Authentication.** A página de nova senha da Vercel
        (`bolao-bolado-email-api.vercel.app/redefinir-senha.html`) usa o Auth
        e não tem App Check: exigir lá quebra a redefinição de senha.
      - Rodando local (`flutter run -d chrome`), o App Check funciona porque
        `localhost` está entre os domínios da chave reCAPTCHA.
      - Cota: o reCAPTCHA Enterprise é grátis até 10 mil avaliações por mês
        (uma por visita a cada hora de uso). Muito acima do volume atual, mas
        o projeto não tem cobrança ativada: se estourar, a verificação falha
        e o app para de ler o Firestore.

## Falta

Nada obrigatório.

## Decidido não fazer

- **Restringir a chave de API do navegador por site.** A chave da web é a
  mesma do app de Windows, que não manda endereço de site — a restrição o
  derrubaria. E um script consegue falsificar esse endereço, então a
  proteção de verdade é o App Check.

## Opcional, depois

- Atualizar o `firebase-admin` do repositório da API (os avisos do
  `npm install` vêm dele) e testar o e-mail de redefinição depois.
- Atualizar os pacotes `firebase_*` do app Flutter — o `firebase_app_check`
  ficou numa versão antiga porque a atual obriga a subir todos juntos.
- Investigar a exceção que aparece no console do navegador ao abrir o site
  (já existia antes do App Check).
