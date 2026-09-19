# bolao-bolado-email-api

Backend serverless (Vercel) que substitui o e-mail padrão de redefinição de
senha do Firebase Auth por um envio próprio, com o design do Bolão Bolado —
o editor de modelos do Firebase está bloqueado neste projeto ("As
atualizações de modelos de e-mail não estão disponíveis para este
projeto").

O envio sai pelo **SMTP do Gmail** (via `nodemailer`), não por um provedor
tipo SendGrid/Resend — ambos pedem cartão ou domínio próprio pra funcionar
de verdade; Gmail é grátis pra sempre e não pede nenhum dos dois (limite:
500 destinatários/dia, bem acima do volume do bolão).

## Como funciona

`POST /api/redefinir-senha` com `{ "email": "..." }`:

**1)** Gera o link de redefinição via Firebase Admin SDK (`generatePasswordResetLink`).

**2)** Monta o e-mail em HTML com a paleta do tema claro do app (`api/_template.js`).

**3)** Envia via SMTP do Gmail.

**4)** Sempre responde com a mesma mensagem genérica de sucesso — não revela se o e-mail existe na base (evita enumeração de contas). Ver os comentários no topo de `api/redefinir-senha.js` pra entender os limites de segurança (limite de pedidos por e-mail, IP e dia; sem reCAPTCHA).

## Configurar (variáveis de ambiente na Vercel)

Nenhuma dessas eu configuro por você — são credenciais, e credencial eu não
digito em formulário nenhum. Em **Project Settings → Environment Variables**
no painel da Vercel, adicione:

| Variável | De onde tirar |
|---|---|
| `FIREBASE_SERVICE_ACCOUNT_BASE64` | Firebase Console → ⚙️ Configurações do projeto → Contas de serviço → **Gerar nova chave privada** (baixa um `.json`). Depois converta pra base64 numa linha só e cole o resultado — no PowerShell: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("caminho\para\o-arquivo.json")) | Set-Clipboard` (já copia pra área de transferência). |
| `GMAIL_USER` | `arturoandreatta@gmail.com` |
| `GMAIL_APP_PASSWORD` | Uma **senha de app** gerada em myaccount.google.com/apppasswords (exige verificação em duas etapas ativada na conta) — não é a senha normal da conta. |
| `ALLOWED_ORIGIN` | Origens que podem chamar o endpoint, separadas por vírgula: `https://bolaobolado-app.web.app,https://bolaobolado-app.firebaseapp.com` (some `http://localhost:PORTA` enquanto testa local). |
| `APP_SHARED_SECRET` | **Obrigatória**: sem ela o endpoint recusa tudo. Precisa ser igual a `_segredoRecuperarSenha` em `lib/services/authentication/auth_service.dart` do app, que manda esse valor no header `x-app-secret`. É só uma barreira contra bot varrendo endpoints, não segredo forte (ver aviso no código). |
| `UPSTASH_REDIS_REST_URL` / `UPSTASH_REDIS_REST_TOKEN` | Redis grátis do Upstash (integração no marketplace da Vercel ou upstash.com, aba **REST API**). Guarda os contadores do limite de pedidos (3 por e-mail/hora, 10 por IP/hora, 300 no dia). Sem elas o limite só vale dentro de uma instância da função. |

Depois de configurar, faça um redeploy (a Vercel não aplica env var nova em
deploy já existente).

## Limpeza única de dados expostos

`scripts/limpar_dados_privados.js` apaga o `email` que ficou nos perfis
públicos e move a senha das salas para o documento privado. Roda local, com
a chave de conta de serviço (não versione o `.json`):

```bash
npm install
node scripts/limpar_dados_privados.js caminho/da/chave.json
node scripts/limpar_dados_privados.js caminho/da/chave.json --aplicar
```

A primeira chamada só conta o que vai mudar; a segunda grava.

## Testar

```bash
curl -X POST https://SEU-PROJETO.vercel.app/api/redefinir-senha \
  -H "Content-Type: application/json" \
  -H "x-app-secret: SEU_SEGREDO" \
  -d '{"email":"seu-email-de-teste@gmail.com"}'
```

## Histórico

Este projeto passou por dois provedores de e-mail antes de chegar no Gmail
SMTP: **Resend** foi descartado por exigir domínio próprio verificado
(sem domínio, só manda pro próprio e-mail da conta); **SendGrid** foi
descartado porque o plano gratuito virou um trial de 60 dias — depois disso
o envio para até você assinar um plano pago (a partir de US$ 19,95/mês).
Gmail SMTP não tem nenhuma dessas pegadinhas: é grátis pra sempre, sem
domínio, limite de 500 destinatários/dia.
