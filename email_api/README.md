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

1. Gera o link de redefinição via Firebase Admin SDK (`generatePasswordResetLink`).
2. Monta o e-mail em HTML com a paleta do tema claro do app (`api/_template.js`).
3. Envia via SMTP do Gmail.
4. Sempre responde com a mesma mensagem genérica de sucesso — não revela se
   o e-mail existe na base (evita enumeração de contas). Ver os comentários
   no topo de `api/redefinir-senha.js` pra entender os limites de segurança
   (não tem rate limit de verdade nem reCAPTCHA, ao contrário do endpoint
   padrão do Firebase).

## Configurar (variáveis de ambiente na Vercel)

Nenhuma dessas eu configuro por você — são credenciais, e credencial eu não
digito em formulário nenhum. Em **Project Settings → Environment Variables**
no painel da Vercel, adicione:

| Variável | De onde tirar |
|---|---|
| `FIREBASE_SERVICE_ACCOUNT_BASE64` | Firebase Console → ⚙️ Configurações do projeto → Contas de serviço → **Gerar nova chave privada** (baixa um `.json`). Depois converta pra base64 numa linha só e cole o resultado — no PowerShell: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("caminho\para\o-arquivo.json")) \| Set-Clipboard` (já copia pra área de transferência). |
| `GMAIL_USER` | O endereço do Gmail que envia os e-mails (o mesmo em que a senha de app abaixo foi gerada). |
| `GMAIL_APP_PASSWORD` | Uma **senha de app** gerada em myaccount.google.com/apppasswords (exige verificação em duas etapas ativada na conta) — não é a senha normal da conta. |
| `ALLOWED_ORIGIN` | Origens que podem chamar o endpoint, separadas por vírgula: `https://bolaobolado-app.web.app,https://bolaobolado-app.firebaseapp.com` (some `http://localhost:PORTA` enquanto testa local). |
| `APP_SHARED_SECRET` | Qualquer string aleatória sua (ex: gere um UUID). O app Flutter manda ela no header `x-app-secret` — é só uma barreira simples contra bot varrendo endpoints, não é segredo forte (ver aviso no código). |

Depois de configurar, faça um redeploy (a Vercel não aplica env var nova em
deploy já existente).

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
