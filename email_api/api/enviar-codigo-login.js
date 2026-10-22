// POST /api/enviar-codigo-login { email: string }
//
// Primeira metade do login sem senha por código de uso único (OTP): sorteia
// um código de 6 dígitos, guarda o HASH dele no Redis com prazo de validade e
// manda o código por e-mail. A segunda metade, que confere o código e devolve
// o token de login, é o entrar-com-codigo.js.
//
// SEGURANÇA — o que este endpoint faz e o que NÃO faz:
// - Só manda código para conta que JÁ EXISTE no Firebase Auth (e não está
//   desativada). Login por código não cria conta: senão virava um cadastro
//   sem nome nem avatar, por fora do fluxo de cadastro do app.
// - Nunca revela se o e-mail tem conta: responde a mesma mensagem genérica
//   nos dois casos (mesmo cuidado do redefinir-senha.js).
// - Guarda só o HMAC do código, nunca o código em si — quem ler o Redis não
//   tem o código pronto para usar.
// - Pedir um código novo substitui o anterior e zera as tentativas: só o
//   último código enviado vale.
// - Limita pedidos por e-mail e por IP, e conta no teto diário de e-mails
//   compartilhado com a redefinição de senha.
// - Exige o Upstash configurado. Diferente dos contadores de limite, o código
//   PRECISA ser lido por outra função (entrar-com-codigo.js), que roda em
//   outra instância — um Map em memória nunca seria encontrado lá.

const crypto = require('crypto');
const {
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
} = require('./_comum');
const { hashDoCodigo, chaveCodigo, chaveTentativas, VALIDADE_CODIGO_SEGUNDOS } = require('./_codigo_login');
const { montarHtmlCodigoLogin } = require('./_template');

const LIMITES = {
  porEmail: { maximo: 3, janelaSegundos: 60 * 60 },
  porIp: { maximo: 10, janelaSegundos: 60 * 60 },
};

// randomInt usa o gerador criptográfico do Node; Math.random seria
// previsível. O padStart mantém códigos como 004213 com 6 dígitos.
function sortearCodigo() {
  return String(crypto.randomInt(0, 1000000)).padStart(6, '0');
}

// true se o e-mail pertence a uma conta ativa. Conta inexistente cai no
// `auth/user-not-found`; qualquer outro erro é falha de verdade e sobe.
async function contaAtiva(email) {
  try {
    const usuario = await admin.auth().getUserByEmail(email);
    return !usuario.disabled;
  } catch (erro) {
    if (erro.code === 'auth/user-not-found') return false;
    throw erro;
  }
}

module.exports = async function handler(req, res) {
  if (!prepararPedido(req, res)) return;

  if (!upstashConfigurado) {
    console.error('Upstash não configurado — login por código indisponível.');
    res.status(503).json({ error: 'Serviço indisponível.' });
    return;
  }

  const email = emailDoPedido(req);
  if (!email) {
    res.status(400).json({ error: 'E-mail inválido.' });
    return;
  }

  const respostaGenerica = {
    success: true,
    message: 'Se esse e-mail tiver conta, você vai receber um código em instantes.',
  };

  // Mesma lógica de resposta do redefinir-senha.js: IP estourado recebe 429,
  // e-mail estourado recebe a mensagem genérica (senão o bloqueio de um
  // e-mail específico revelaria que ele tem conta). Aqui, porém, falha no
  // Redis não deixa passar: sem Redis não há onde guardar o código.
  try {
    if (await excedeuLimite(`codigo-login:porIp:${ipDe(req)}`, LIMITES.porIp)) {
      res.status(429).json({ error: 'Muitos pedidos. Tente de novo mais tarde.' });
      return;
    }
    if (
      (await excedeuLimite(`codigo-login:porEmail:${email}`, LIMITES.porEmail)) ||
      (await excedeuCotaDiariaDeEmails())
    ) {
      res.status(200).json(respostaGenerica);
      return;
    }

    if (!(await contaAtiva(email))) {
      res.status(200).json(respostaGenerica);
      return;
    }

    const codigo = sortearCodigo();
    await redis([
      ['SET', chaveCodigo(email), hashDoCodigo(email, codigo), 'EX', String(VALIDADE_CODIGO_SEGUNDOS)],
      ['DEL', chaveTentativas(email)],
    ]);

    await transportador.sendMail({
      from: `"${NOME_APP}" <${process.env.GMAIL_USER}>`,
      to: email,
      subject: `${codigo} é seu código de acesso ao ${NOME_APP}`,
      html: montarHtmlCodigoLogin({
        nomeApp: NOME_APP,
        email,
        codigo,
        minutos: VALIDADE_CODIGO_SEGUNDOS / 60,
      }),
    });
  } catch (erro) {
    console.error('Falha ao gerar/enviar código de login:', erro);
    res.status(500).json({ error: 'Erro ao processar o pedido. Tente de novo em instantes.' });
    return;
  }

  res.status(200).json(respostaGenerica);
};
