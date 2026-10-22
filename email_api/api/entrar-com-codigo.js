// POST /api/entrar-com-codigo { email: string, codigo: string }
//
// Segunda metade do login por código (a primeira é o enviar-codigo-login.js):
// confere o código e, se bater, devolve um custom token do Firebase. O app
// entra com `signInWithCustomToken(token)` e a sessão a partir daí é uma
// sessão normal do Firebase Auth, com o mesmo uid da conta.
//
// SEGURANÇA:
// - Código errado, expirado ou de e-mail sem conta respondem a MESMA
//   mensagem: sem isso, "código incorreto" x "expirado" contaria quem pediu
//   código recentemente, ou seja, quem tem conta.
// - Cada código aceita MAXIMO_TENTATIVAS erros; no seguinte, é apagado e a
//   pessoa precisa pedir outro (que custa um e-mail, limitado por hora).
// - Código certo é apagado na hora: uso único.
// - Também limita pedidos por IP, para um IP não sair chutando código de
//   vários e-mails ao mesmo tempo.

const {
  admin,
  upstashConfigurado,
  redis,
  excedeuLimite,
  ipDe,
  emailDoPedido,
  prepararPedido,
} = require('./_comum');
const {
  VALIDADE_CODIGO_SEGUNDOS,
  MAXIMO_TENTATIVAS,
  chaveCodigo,
  chaveTentativas,
  hashDoCodigo,
  hashesIguais,
} = require('./_codigo_login');

const LIMITE_POR_IP = { maximo: 20, janelaSegundos: 60 * 60 };

const REGEX_CODIGO = /^\d{6}$/;

const ERRO_CODIGO = 'Código incorreto ou expirado. Confira ou peça um novo.';

module.exports = async function handler(req, res) {
  if (!prepararPedido(req, res)) return;

  if (!upstashConfigurado) {
    console.error('Upstash não configurado — login por código indisponível.');
    res.status(503).json({ error: 'Serviço indisponível.' });
    return;
  }

  const email = emailDoPedido(req);
  const codigo = req.body && req.body.codigo ? String(req.body.codigo).trim() : '';
  if (!email || !REGEX_CODIGO.test(codigo)) {
    res.status(400).json({ error: ERRO_CODIGO });
    return;
  }

  try {
    if (await excedeuLimite(`codigo-login:conferir:porIp:${ipDe(req)}`, LIMITE_POR_IP)) {
      res.status(429).json({ error: 'Muitas tentativas. Tente de novo mais tarde.' });
      return;
    }

    // A tentativa é contada ANTES de comparar, e no mesmo pipeline da
    // leitura: duas chamadas em paralelo não conseguem as duas ler o
    // contador ainda baixo.
    const [hashGuardado, tentativas] = await redis([
      ['GET', chaveCodigo(email)],
      ['INCR', chaveTentativas(email)],
      ['EXPIRE', chaveTentativas(email), String(VALIDADE_CODIGO_SEGUNDOS), 'NX'],
    ]);

    if (!hashGuardado) {
      res.status(400).json({ error: ERRO_CODIGO });
      return;
    }

    if (Number(tentativas) > MAXIMO_TENTATIVAS) {
      await redis([['DEL', chaveCodigo(email), chaveTentativas(email)]]);
      res.status(400).json({ error: ERRO_CODIGO });
      return;
    }

    if (!hashesIguais(hashGuardado, hashDoCodigo(email, codigo))) {
      res.status(400).json({ error: ERRO_CODIGO });
      return;
    }

    await redis([['DEL', chaveCodigo(email), chaveTentativas(email)]]);

    // A conta pode ter sido apagada ou desativada entre o envio e agora.
    let usuario;
    try {
      usuario = await admin.auth().getUserByEmail(email);
    } catch (erro) {
      if (erro.code === 'auth/user-not-found') {
        res.status(400).json({ error: ERRO_CODIGO });
        return;
      }
      throw erro;
    }
    if (usuario.disabled) {
      res.status(403).json({ error: 'Conta desativada. Entre em contato com o suporte.' });
      return;
    }

    // Acertar o código prova que a pessoa lê aquela caixa de entrada — é a
    // mesma prova que o link de verificação do Firebase pede.
    if (!usuario.emailVerified) {
      await admin.auth().updateUser(usuario.uid, { emailVerified: true });
    }

    const token = await admin.auth().createCustomToken(usuario.uid);
    res.status(200).json({ token });
  } catch (erro) {
    console.error('Falha ao conferir código de login:', erro);
    res.status(500).json({ error: 'Erro ao processar o pedido. Tente de novo em instantes.' });
  }
};
