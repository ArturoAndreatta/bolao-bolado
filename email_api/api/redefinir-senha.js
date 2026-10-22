// POST /api/redefinir-senha { email: string }
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
// A página de redefinição padrão do Firebase (firebaseapp.com/__/auth/action)
// é genérica e sem a cara do app — e a opção "Personalizar URL acionável" do
// Console do Firebase está quebrada neste projeto (mesmo bug do editor de
// modelos). Por isso o link gerado pelo Admin SDK é reescrito abaixo pra
// apontar pra nossa própria página (/redefinir-senha.html, hospedada neste
// mesmo projeto Vercel), que usa o Firebase Auth SDK no client
// (verifyPasswordResetCode / confirmPasswordReset) pra validar o oobCode e
// trocar a senha — funciona em qualquer domínio, não só no authDomain
// configurado no Firebase.
//
// SEGURANÇA — o que este endpoint faz e o que NÃO faz:
// - Nunca revela se um e-mail existe na base: sempre responde com a mesma
//   mensagem genérica de sucesso, exista o usuário ou não (evita
//   enumeração de contas).
// - Limita pedidos por e-mail, por IP e no total do dia (ver LIMITES). Sem
//   isso, dava pra disparar centenas de e-mails pra caixa de uma vítima e,
//   de quebra, esgotar a cota diária do Gmail — e aí ninguém mais consegue
//   redefinir senha até o dia virar. Os contadores ficam no Upstash Redis
//   quando as variáveis do Upstash estão configuradas (ver urlUpstash); sem eles, caem
//   num Map em memória, que só vale dentro de uma instância quente (cold
//   start zera, instâncias paralelas não se enxergam). O Map é paliativo:
//   em produção, configure o Upstash.
// - Exige o header `x-app-secret` batendo com APP_SHARED_SECRET, e recusa
//   tudo se a variável não estiver configurada (antes, sem ela, a checagem
//   era pulada em silêncio). É uma barreira simples, não um segredo forte —
//   o app é web pública, então dá pra extrair esse valor do bundle. Serve só
//   pra afastar bots genéricos varrendo endpoints abertos.

const {
  admin,
  transportador,
  NOME_APP,
  excedeuLimite,
  excedeuCotaDiariaDeEmails,
  ipDe,
  emailDoPedido,
  prepararPedido,
} = require('./_comum');
const { montarHtmlRedefinicaoSenha } = require('./_template');

// URL da página customizada de redefinição de senha (hospedada neste mesmo
// projeto Vercel, arquivo /redefinir-senha.html na raiz do repo).
const URL_PAGINA_REDEFINICAO = 'https://bolao-bolado-email-api.vercel.app/redefinir-senha.html';

// Quantos pedidos cabem em cada janela. O teto diário de e-mails é
// compartilhado com o login por código (ver excedeuCotaDiariaDeEmails).
const LIMITES = {
  porEmail: { maximo: 3, janelaSegundos: 60 * 60 },
  porIp: { maximo: 10, janelaSegundos: 60 * 60 },
};

// Erros do Admin SDK que significam "não há conta com esse e-mail". O SDK
// devolve `auth/email-not-found` para generatePasswordResetLink — tratar só
// `auth/user-not-found`, como antes, fazia e-mail inexistente cair no ramo de
// erro 500, enquanto e-mail cadastrado recebia 200: a diferença revelava
// quem tem conta, exatamente o que a resposta genérica deveria esconder.
const CODIGOS_SEM_CONTA = new Set(['auth/email-not-found', 'auth/user-not-found']);

// Com a proteção contra enumeração de e-mail ligada no Firebase (padrão em
// projetos novos, e ligada neste), o servidor nem diz mais que a conta não
// existe: responde sucesso SEM link, e o Admin SDK transforma isso num
// `auth/internal-error` com esta mensagem. É o mesmo caso "sem conta" acima,
// só que disfarçado — e sem tratá-lo, e-mail inexistente devolvia 500.
function ehContaInexistente(erro) {
  if (CODIGOS_SEM_CONTA.has(erro.code)) return true;
  return (
    erro.code === 'auth/internal-error' &&
    String(erro.message).includes('Unable to create the email action link')
  );
}

// Troca o domínio padrão do Firebase (firebaseapp.com/__/auth/action) pela
// nossa página customizada, preservando mode/oobCode/apiKey e demais
// parâmetros que o Firebase colocou na query string.
function reescreverLinkParaPaginaCustomizada(linkOriginal) {
  const url = new URL(linkOriginal);
  return `${URL_PAGINA_REDEFINICAO}${url.search}`;
}

module.exports = async function handler(req, res) {
  if (!prepararPedido(req, res)) return;

  const email = emailDoPedido(req);
  if (!email) {
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

  // Limite por IP responde 429 (quem martela merece saber que parou); o por
  // e-mail e o total respondem a mensagem genérica, senão o bloqueio de um
  // e-mail específico viraria mais um jeito de sondar a base.
  try {
    if (await excedeuLimite(`redefinir-senha:porIp:${ipDe(req)}`, LIMITES.porIp)) {
      res.status(429).json({ error: 'Muitos pedidos. Tente de novo mais tarde.' });
      return;
    }
    if (
      (await excedeuLimite(`redefinir-senha:porEmail:${email}`, LIMITES.porEmail)) ||
      (await excedeuCotaDiariaDeEmails())
    ) {
      res.status(200).json(respostaGenerica);
      return;
    }
  } catch (erro) {
    // Falha no Redis não derruba a redefinição de senha de quem precisa: o
    // abuso possível numa janela de pane é bem menor que o estrago de deixar
    // todo mundo sem conseguir entrar.
    console.error('Falha ao consultar limites:', erro);
  }

  try {
    const linkOriginal = await admin.auth().generatePasswordResetLink(email);
    const link = reescreverLinkParaPaginaCustomizada(linkOriginal);

    await transportador.sendMail({
      from: `"${NOME_APP}" <${process.env.GMAIL_USER}>`,
      to: email,
      subject: `Redefina sua senha do ${NOME_APP}`,
      html: montarHtmlRedefinicaoSenha({ nomeApp: NOME_APP, email, link }),
    });
  } catch (erro) {
    // usuário não existe: trata como sucesso silencioso (não vaza a
    // existência da conta). Qualquer outro erro é falha de verdade.
    if (!ehContaInexistente(erro)) {
      console.error('Falha ao gerar/enviar redefinição de senha:', erro);
      res.status(500).json({ error: 'Erro ao processar o pedido. Tente de novo em instantes.' });
      return;
    }
  }

  res.status(200).json(respostaGenerica);
};
