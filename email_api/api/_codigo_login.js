// Regras do código de login compartilhadas entre quem envia
// (enviar-codigo-login.js) e quem confere (entrar-com-codigo.js). Ficam num
// lugar só porque as duas pontas precisam concordar exatamente no nome das
// chaves e no hash — divergir em um caractere e nenhum código bate.

const crypto = require('crypto');

const VALIDADE_CODIGO_SEGUNDOS = 10 * 60;

// Erros aceitos para o MESMO código antes de ele ser descartado. Com 6
// dígitos, 5 chutes dão 1 chance em 200 mil por código enviado — e cada
// código novo custa um e-mail, que já é limitado por hora.
const MAXIMO_TENTATIVAS = 5;

const chaveCodigo = (email) => `codigo-login:codigo:${email}`;
const chaveTentativas = (email) => `codigo-login:tentativas:${email}`;

// HMAC com o e-mail junto: o mesmo código sorteado para duas contas gera
// hashes diferentes. A chave é o APP_SHARED_SECRET, que já é obrigatório
// nesses endpoints; ele não é segredo forte (ver _comum.js), então o hash
// serve para o código não ficar legível no Redis, não para resistir a força
// bruta de quem tiver o banco E o bundle do app.
function hashDoCodigo(email, codigo) {
  return crypto
    .createHmac('sha256', process.env.APP_SHARED_SECRET)
    .update(`${email}:${codigo}`)
    .digest('hex');
}

// Comparação em tempo constante: `===` para no primeiro caractere diferente,
// e a diferença de tempo daria pista de quanto do hash já bate.
function hashesIguais(a, b) {
  const bufA = Buffer.from(String(a));
  const bufB = Buffer.from(String(b));
  return bufA.length === bufB.length && crypto.timingSafeEqual(bufA, bufB);
}

module.exports = {
  VALIDADE_CODIGO_SEGUNDOS,
  MAXIMO_TENTATIVAS,
  chaveCodigo,
  chaveTentativas,
  hashDoCodigo,
  hashesIguais,
};
