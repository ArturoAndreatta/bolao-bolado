// POST /api/redefinir-senha  { email: string }
//
// Substitui o e-mail padrão do Firebase Auth (sendPasswordResetEmail) por
// um envio próprio, com o template visual do app — o editor de modelos do
// Firebase está bloqueado neste projeto ("As atualizações de modelos de
// e-mail não estão disponíveis para este projeto"), então o link é gerado
// via Admin SDK e o e-mail sai pelo SMTP do Gmail (nodemailer + senha de
// app). Trocado de SendGrid pra Gmail porque o plano grátis do SendGrid
// acabou virando trial de 60 dias — Gmail SMTP é grátis pra sempre e não
// pede domínio (limite: 500 destinatários/dia, bem acima do que o bolão usa).
//
// SEGURANÇA — o que este endpoint faz e o que NÃO faz:
// - Nunca revela se um e-mail existe na base: sempre responde com a mesma
//   mensagem genérica de sucesso, exista o usuário ou não (evita
//   enumeração de contas).
// - Limita repetição na MESMA instância quente da função (Map em memória).
//   Isso NÃO é um rate limit de verdade — cada cold start reseta o mapa, e
//   a Vercel pode rodar várias instâncias em paralelo. É só uma barreira
//   mínima contra clique repetido acidental. O endpoint padrão do Firebase
//   tem proteção de abuso própria (reCAPTCHA, limite por IP) que este
//   endpoint não reproduz. Se o app crescer, vale colocar um rate limit de
//   verdade (Vercel KV / Upstash) na frente disso.
// - Exige o header `x-app-secret` batendo com APP_SHARED_SECRET. É uma
//   barreira simples, não um segredo forte — o app é web pública, então
//   dá pra extrair esse valor do bundle. Serve só pra afastar bots
//   genéricos varrendo endpoints abertos, não pra parar alguém decidido.

const admin = require('firebase-admin');
const nodemailer = require('nodemailer');
const { montarHtmlRedefinicaoSenha } = require('./_template');

const NOME_APP = 'Bolão Bolado';

// ── Firebase Admin: inicializa uma vez só, reaproveitado entre invocações
// da mesma instância quente (padrão recomendado em funções serverless).
if (!admin.apps.length) {
  const credencialBase64 = process.env.FIREBASE_SERVICE_ACCOUNT_BASE64;
  if (credencialBase64) {
    const credencial = JSON.parse(
      Buffer.from(credencialBase64, 'base64').toString('utf8')
    );
    admin.initializeApp({ credential: admin.credential.cert(credencial) });
  }
}

// ── Transporte SMTP do Gmail: também inicializado uma vez só e reaproveitado
// entre invocações da mesma instância quente. `GMAIL_APP_PASSWORD` é uma
// senha de app (myaccount.google.com/apppasswords) — não é a senha normal
// da conta, e exige verificação em duas etapas ativada.
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

// Barreira mínima contra clique repetido na mesma instância (ver aviso no
// topo do arquivo — não é rate limit de verdade).
const ultimoPedidoPorEmail = new Map();
const JANELA_MINIMA_MS = 60_000;

const REGEX_EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function aplicarCors(req, res) {
  const origin = req.headers.origin;
  if (origin && origensPermitidas.includes(origin)) {
    res.setHeader('Access-Control-Allow-Origin', origin);
  }
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, x-app-secret');
}

module.exports = async function handler(req, res) {
  aplicarCors(req, res);

  if (req.method === 'OPTIONS') {
    res.status(204).end();
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Método não permitido.' });
    return;
  }

  const segredoEsperado = process.env.APP_SHARED_SECRET;
  if (segredoEsperado && req.headers['x-app-secret'] !== segredoEsperado) {
    res.status(401).json({ error: 'Não autorizado.' });
    return;
  }

  const email = (req.body && req.body.email ? String(req.body.email) : '')
    .trim()
    .toLowerCase();

  if (!REGEX_EMAIL.test(email)) {
    res.status(400).json({ error: 'E-mail inválido.' });
    return;
  }

  // Resposta genérica — igual exista ou não o usuário, dado sucesso ou
  // "usuário não encontrado". Só erro de infraestrutura (Firebase/Gmail
  // fora do ar) devolve status de erro de verdade.
  const respostaGenerica = {
    success: true,
    message:
      'Se esse e-mail existir na nossa base, você vai receber um link de redefinição em instantes.',
  };

  const agora = Date.now();
  const ultimoPedido = ultimoPedidoPorEmail.get(email);
  if (ultimoPedido && agora - ultimoPedido < JANELA_MINIMA_MS) {
    res.status(200).json(respostaGenerica);
    return;
  }
  ultimoPedidoPorEmail.set(email, agora);

  try {
    const link = await admin.auth().generatePasswordResetLink(email);

    await transportador.sendMail({
      from: `"${NOME_APP}" <${process.env.GMAIL_USER}>`,
      to: email,
      subject: `Redefina sua senha do ${NOME_APP}`,
      html: montarHtmlRedefinicaoSenha({ nomeApp: NOME_APP, email, link }),
    });
  } catch (erro) {
    // usuário não existe: trata como sucesso silencioso (não vaza a
    // existência da conta). Qualquer outro erro é falha de verdade.
    if (erro.code !== 'auth/user-not-found') {
      console.error('Falha ao gerar/enviar redefinição de senha:', erro);
      res.status(500).json({ error: 'Erro ao processar o pedido. Tente de novo em instantes.' });
      return;
    }
  }

  res.status(200).json(respostaGenerica);
};
