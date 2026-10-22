// Peças compartilhadas pelos endpoints que mandam e-mail (redefinição de
// senha e login por código). Arquivo com `_` na frente não vira rota na
// Vercel — mesmo motivo do _template.js.
//
// Tudo que é inicializado aqui (Admin SDK, transporte SMTP) acontece uma vez
// por instância quente e é reaproveitado entre invocações, padrão recomendado
// em funções serverless.

const admin = require('firebase-admin');
const nodemailer = require('nodemailer');

const NOME_APP = 'Bolão Bolado';

if (!admin.apps.length) {
  const credencialBase64 = process.env.FIREBASE_SERVICE_ACCOUNT_BASE64;
  if (credencialBase64) {
    const credencial = JSON.parse(
      Buffer.from(credencialBase64, 'base64').toString('utf8')
    );
    admin.initializeApp({ credential: admin.credential.cert(credencial) });
  }
}

// `GMAIL_APP_PASSWORD` é uma senha de app (myaccount.google.com/apppasswords)
// — não é a senha normal da conta, e exige verificação em duas etapas ativada.
const transportador = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.GMAIL_USER,
    pass: process.env.GMAIL_APP_PASSWORD,
  },
});

const origensPermitidas = (process.env.ALLOWED_ORIGIN || '')
  .split(',')
  .map((o) => o.trim())
  .filter(Boolean);

// A integração Upstash do marketplace da Vercel cria as variáveis com o
// prefixo KV_ (herança do antigo Vercel KV); criando o banco direto no
// Upstash, o nome é UPSTASH_REDIS_. Aceita os dois.
const urlUpstash = process.env.UPSTASH_REDIS_REST_URL || process.env.KV_REST_API_URL;
const tokenUpstash = process.env.UPSTASH_REDIS_REST_TOKEN || process.env.KV_REST_API_TOKEN;

const upstashConfigurado = Boolean(urlUpstash && tokenUpstash);

// Roda uma sequência de comandos no Redis numa ida só e devolve o `result`
// de cada um, na mesma ordem.
async function redis(comandos) {
  const resposta = await fetch(`${urlUpstash}/pipeline`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${tokenUpstash}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(comandos),
  });
  if (!resposta.ok) throw new Error(`Upstash respondeu ${resposta.status}`);
  const resultados = await resposta.json();
  return resultados.map((r) => {
    if (r.error) throw new Error(`Upstash: ${r.error}`);
    return r.result;
  });
}

// Fallback em memória quando o Upstash não está configurado: chave ->
// { contagem, expiraEm }. Só vale dentro de uma instância quente (cold start
// zera, instâncias paralelas não se enxergam) — em produção, configure o
// Upstash.
const contadoresLocais = new Map();

// Soma 1 ao contador da chave e devolve o total dentro da janela. A janela
// começa no primeiro pedido (EXPIRE ... NX não renova o prazo a cada INCR),
// então um abuso contínuo não empurra o fim do bloqueio pra frente.
async function contar(chave, janelaSegundos) {
  if (upstashConfigurado) {
    const [total] = await redis([
      ['INCR', chave],
      ['EXPIRE', chave, String(janelaSegundos), 'NX'],
    ]);
    return Number(total);
  }

  const agora = Date.now();
  const atual = contadoresLocais.get(chave);
  if (!atual || atual.expiraEm <= agora) {
    contadoresLocais.set(chave, { contagem: 1, expiraEm: agora + janelaSegundos * 1000 });
    return 1;
  }
  atual.contagem += 1;
  return atual.contagem;
}

// `limite` = { maximo, janelaSegundos }.
async function excedeuLimite(chave, limite) {
  const total = await contar(chave, limite.janelaSegundos);
  return total > limite.maximo;
}

// Teto diário de e-mails somando TODOS os endpoints: a cota de 500
// destinatários/dia do Gmail é uma só, e estourá-la por um caminho derruba o
// outro (código de login esgotado = ninguém consegue redefinir senha).
const LIMITE_EMAILS_DIA = { maximo: 300, janelaSegundos: 24 * 60 * 60 };

function excedeuCotaDiariaDeEmails() {
  return excedeuLimite('emails:total:dia', LIMITE_EMAILS_DIA);
}

// A Vercel coloca o IP real do cliente no começo do x-forwarded-for.
function ipDe(req) {
  const encaminhado = String(req.headers['x-forwarded-for'] || '');
  return encaminhado.split(',')[0].trim() || req.headers['x-real-ip'] || 'desconhecido';
}

const REGEX_EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

// E-mail do corpo do pedido, normalizado, ou null se inválido.
function emailDoPedido(req) {
  const email = (req.body && req.body.email ? String(req.body.email) : '')
    .trim()
    .toLowerCase();
  if (email.length > 254 || !REGEX_EMAIL.test(email)) return null;
  return email;
}

function aplicarCors(req, res) {
  const origin = req.headers.origin;
  if (origin && origensPermitidas.includes(origin)) {
    res.setHeader('Access-Control-Allow-Origin', origin);
  }
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, x-app-secret');
}

// Abertura comum a todo endpoint POST chamado pelo app: CORS, preflight,
// método e o header `x-app-secret`. Devolve false quando já respondeu e o
// handler deve parar.
//
// O segredo é uma barreira simples, não um segredo forte — o app é web
// pública, então dá pra extrair o valor do bundle. Serve só pra afastar bots
// genéricos varrendo endpoints abertos. Sem a variável configurada recusa
// tudo, em vez de pular a checagem em silêncio.
function prepararPedido(req, res) {
  aplicarCors(req, res);

  if (req.method === 'OPTIONS') {
    res.status(204).end();
    return false;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Método não permitido.' });
    return false;
  }

  const segredoEsperado = process.env.APP_SHARED_SECRET;
  if (!segredoEsperado) {
    console.error('APP_SHARED_SECRET não configurado — recusando pedidos.');
    res.status(503).json({ error: 'Serviço indisponível.' });
    return false;
  }
  if (req.headers['x-app-secret'] !== segredoEsperado) {
    res.status(401).json({ error: 'Não autorizado.' });
    return false;
  }

  return true;
}

module.exports = {
  admin,
  transportador,
  NOME_APP,
  upstashConfigurado,
  redis,
  excedeuLimite,
  excedeuCotaDiariaDeEmails,
  ipDe,
  emailDoPedido,
  prepararPedido,
};
