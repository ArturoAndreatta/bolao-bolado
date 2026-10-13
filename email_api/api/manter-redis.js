// GET /api/manter-redis — chamado pelo cron diário da Vercel (ver vercel.json).
//
// O Redis do Upstash que guarda os contadores de LIMITES em redefinir-senha.js
// só recebe tráfego quando alguém pede redefinição de senha. No plano grátis
// do marketplace da Vercel, banco sem tráfego por algumas semanas é arquivado
// — e aí o limite de pedidos desliga em silêncio: o redefinir-senha.js trata
// falha no Redis como "deixa passar" (de propósito, pra não travar quem
// precisa entrar), então ninguém percebe que a proteção sumiu. Este endpoint
// existe só pra manter o banco com tráfego.
//
// Grava (SET) em vez de só PING: escrita conta como atividade sem margem de
// dúvida, e a chave serve de pista de quando o cron rodou pela última vez.
//
// A Vercel manda `Authorization: Bearer <CRON_SECRET>` nas chamadas do cron
// quando a variável existe. Sem ela o endpoint recusa tudo: aberto, qualquer
// um gastaria a cota de comandos do Upstash chamando em loop.

const urlUpstash = process.env.UPSTASH_REDIS_REST_URL || process.env.KV_REST_API_URL;
const tokenUpstash = process.env.UPSTASH_REDIS_REST_TOKEN || process.env.KV_REST_API_TOKEN;

module.exports = async function handler(req, res) {
  const segredoCron = process.env.CRON_SECRET;
  if (!segredoCron) {
    console.error('CRON_SECRET não configurado — recusando pedidos.');
    res.status(503).json({ error: 'Serviço indisponível.' });
    return;
  }
  if (req.headers.authorization !== `Bearer ${segredoCron}`) {
    res.status(401).json({ error: 'Não autorizado.' });
    return;
  }

  if (!urlUpstash || !tokenUpstash) {
    console.error('Variáveis do Upstash ausentes — nada a manter ativo.');
    res.status(500).json({ error: 'Upstash não configurado.' });
    return;
  }

  try {
    const resposta = await fetch(`${urlUpstash}/set/redefinir-senha:ultimo-cron`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${tokenUpstash}` },
      body: new Date().toISOString(),
    });
    if (!resposta.ok) throw new Error(`Upstash respondeu ${resposta.status}`);
    res.status(200).json({ ok: true });
  } catch (erro) {
    // Status de erro de verdade: é ele que aparece vermelho na aba Cron Jobs
    // da Vercel, único lugar onde alguém vai notar que o banco sumiu.
    console.error('Falha ao manter o Redis ativo:', erro);
    res.status(502).json({ error: 'Falha ao falar com o Upstash.' });
  }
};
