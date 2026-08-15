// Testes das regras de Mensagens (firestore.rules) contra o emulador real.
//
// Existem por causa da reação: ela é o único UPDATE que uma mensagem publicada
// aceita, e a regra que a libera precisa acertar duas coisas ao mesmo tempo —
// deixar passar qualquer emoji e continuar barrando texto. As duas só valem o
// que o motor de regras realmente aplica: o `matches()` é RE2, com escape
// próprio, e `size()` numa string não tem semântica óbvia (caractere? byte?).
// Ler o arquivo não responde nenhuma das duas.
//
// Rodar:
//   cd test/rules && npm install
//   npm test
//
// Precisa de Java instalado (requisito do emulador do Firestore).
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import assert from 'node:assert';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import { doc, setDoc, updateDoc, deleteDoc, deleteField, setLogLevel } from 'firebase/firestore';

setLogLevel('error');

const SALA = 'Salas/sala1';
const MSG = `${SALA}/Mensagens/msg1`;
const aquiDir = path.dirname(fileURLToPath(import.meta.url));
const rules = fs.readFileSync(
  path.join(aquiDir, '..', '..', 'firestore.rules'),
  'utf8'
);

const env = await initializeTestEnvironment({
  projectId: 'demo-bolao-rules-msg',
  firestore: { rules, host: '127.0.0.1', port: 8080 },
});

async function semear() {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'usuarios/admin1'), { nome: 'Admin', isAdmin: true });
    await setDoc(doc(db, 'usuarios/user1'), { nome: 'User', isAdmin: false });
    await setDoc(doc(db, SALA), { nome: 'Principal', principal: true });
    // user1 e user2 apostaram (podem falar no chat); user9 não.
    await setDoc(doc(db, `${SALA}/Participantes/user1`), { nome: 'User', valor: '6' });
    await setDoc(doc(db, `${SALA}/Participantes/user2`), { nome: 'Outro', valor: '6' });
    await setDoc(doc(db, `${SALA}/Participantes/admin1`), { nome: 'Admin', valor: '6' });
    // Mensagem já publicada, com uma reação de OUTRA pessoa: é ela que não
    // pode ser tocada por quem não a fez.
    await setDoc(doc(db, MSG), {
      texto: 'bora fechar',
      autorUid: 'user2',
      autorNome: 'Outro',
      reacoes: { user2: '🔥' },
    });
  });
}

const user = () => env.authenticatedContext('user1').firestore();
const admin = () => env.authenticatedContext('admin1').firestore();
const forasteiro = () => env.authenticatedContext('user9').firestore();
const anon = () =>
  env.authenticatedContext('anon1', { firebase: { sign_in_provider: 'anonymous' } })
    .firestore();

const casos = [];
const teste = (nome, corpo) => casos.push([nome, corpo]);

// ── Reagir com qualquer emoji ─────────────────────────────────────────────
// O ponto da mudança: antes a regra só aceitava seis emojis fixos.
teste('PERMITE: reagir com um dos emojis da barra rápida', async () => {
  await assertSucceeds(updateDoc(doc(user(), MSG), { 'reacoes.user1': '👍' }));
});

teste('PERMITE: reagir com emoji FORA da antiga lista fechada', async () => {
  await assertSucceeds(updateDoc(doc(user(), MSG), { 'reacoes.user1': '🤡' }));
});

teste('PERMITE: emoji com seletor de variação (❤️ = 2764 FE0F)', async () => {
  await assertSucceeds(updateDoc(doc(user(), MSG), { 'reacoes.user1': '❤️' }));
});

teste('PERMITE: sequência ZWJ longa (família)', async () => {
  // O caso legítimo mais comprido que existe — é ele que calibra o teto de
  // tamanho da regra.
  await assertSucceeds(
    updateDoc(doc(user(), MSG), { 'reacoes.user1': '👨‍👩‍👧‍👦' })
  );
});

teste('PERMITE: emoji com tom de pele', async () => {
  await assertSucceeds(updateDoc(doc(user(), MSG), { 'reacoes.user1': '👍🏽' }));
});

teste('PERMITE: bandeira (par de indicadores regionais)', async () => {
  await assertSucceeds(updateDoc(doc(user(), MSG), { 'reacoes.user1': '🇧🇷' }));
});

teste('PERMITE: trocar a própria reação por outra', async () => {
  await assertSucceeds(updateDoc(doc(user(), MSG), { 'reacoes.user1': '👍' }));
  await assertSucceeds(updateDoc(doc(user(), MSG), { 'reacoes.user1': '😂' }));
});

teste('PERMITE: remover a própria reação', async () => {
  await assertSucceeds(updateDoc(doc(user(), MSG), { 'reacoes.user1': '👍' }));
  await assertSucceeds(
    updateDoc(doc(user(), MSG), { 'reacoes.user1': deleteField() })
  );
});

teste('PERMITE: primeira reação numa mensagem sem o campo `reacoes`', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), `${SALA}/Mensagens/msg2`), {
      texto: 'sem reação ainda',
      autorUid: 'user2',
      autorNome: 'Outro',
    });
  });
  await assertSucceeds(
    updateDoc(doc(user(), `${SALA}/Mensagens/msg2`), { 'reacoes.user1': '🎉' })
  );
});

// ── O que a reação NÃO pode virar ─────────────────────────────────────────
teste('BLOQUEIA: reação com texto ASCII', async () => {
  await assertFails(updateDoc(doc(user(), MSG), { 'reacoes.user1': 'oi' }));
});

teste('BLOQUEIA: emoji seguido de texto ASCII', async () => {
  await assertFails(
    updateDoc(doc(user(), MSG), { 'reacoes.user1': '👍 me paga' })
  );
});

teste('BLOQUEIA: reação vazia', async () => {
  await assertFails(updateDoc(doc(user(), MSG), { 'reacoes.user1': '' }));
});

teste('BLOQUEIA: recado longo em caracteres não-ASCII', async () => {
  // Acentuada não passa (tem ASCII no meio), então o abuso restante seria um
  // alfabeto inteiro sem ASCII. O teto de tamanho é o que fecha essa porta.
  await assertFails(
    updateDoc(doc(user(), MSG), { 'reacoes.user1': 'мне нужны деньги сейчас' })
  );
});

teste('BLOQUEIA: reação que não é string', async () => {
  await assertFails(updateDoc(doc(user(), MSG), { 'reacoes.user1': 42 }));
});

teste('BLOQUEIA: mexer na reação de outra pessoa', async () => {
  await assertFails(updateDoc(doc(user(), MSG), { 'reacoes.user2': '💩' }));
});

teste('BLOQUEIA: apagar a reação de outra pessoa', async () => {
  await assertFails(
    updateDoc(doc(user(), MSG), { 'reacoes.user2': deleteField() })
  );
});

teste('BLOQUEIA: reagir por vários de uma vez', async () => {
  await assertFails(
    updateDoc(doc(user(), MSG), { 'reacoes.user1': '👍', 'reacoes.user3': '👍' })
  );
});

// ── O texto continua imutável ─────────────────────────────────────────────
teste('BLOQUEIA: editar o texto da mensagem', async () => {
  await assertFails(updateDoc(doc(user(), MSG), { texto: 'outra coisa' }));
});

teste('BLOQUEIA: editar o texto junto com a reação', async () => {
  await assertFails(
    updateDoc(doc(user(), MSG), { texto: 'outra coisa', 'reacoes.user1': '👍' })
  );
});

teste('BLOQUEIA (admin): editar o texto de uma mensagem publicada', async () => {
  // Nem moderador reescreve fala de terceiro — apagar é o caminho.
  await assertFails(updateDoc(doc(admin(), MSG), { texto: 'censurado' }));
});

// ── Quem pode reagir ──────────────────────────────────────────────────────
teste('BLOQUEIA: anônimo reagir', async () => {
  await assertFails(updateDoc(doc(anon(), MSG), { 'reacoes.anon1': '👍' }));
});

teste('BLOQUEIA: logado que não apostou reagir', async () => {
  await assertFails(updateDoc(doc(forasteiro(), MSG), { 'reacoes.user9': '👍' }));
});

// ── Envio de mensagem (invariantes que já existiam) ───────────────────────
teste('PERMITE: participante enviar mensagem', async () => {
  await assertSucceeds(
    setDoc(doc(user(), `${SALA}/Mensagens/nova`), {
      texto: 'e aí',
      autorUid: 'user1',
      autorNome: 'User',
    })
  );
});

teste('BLOQUEIA: enviar mensagem em nome de outro', async () => {
  await assertFails(
    setDoc(doc(user(), `${SALA}/Mensagens/nova`), {
      texto: 'e aí',
      autorUid: 'user2',
      autorNome: 'Outro',
    })
  );
});

teste('BLOQUEIA: mensagem acima de 200 caracteres', async () => {
  await assertFails(
    setDoc(doc(user(), `${SALA}/Mensagens/nova`), {
      texto: 'a'.repeat(201),
      autorUid: 'user1',
      autorNome: 'User',
    })
  );
});

teste('BLOQUEIA: mais de 10 menções numa mensagem', async () => {
  await assertFails(
    setDoc(doc(user(), `${SALA}/Mensagens/nova`), {
      texto: 'todo mundo',
      autorUid: 'user1',
      autorNome: 'User',
      mencoes: Array.from({ length: 11 }, (_, i) => ({
        uid: `u${i}`,
        nome: 'X',
        inicio: 0,
        fim: 1,
      })),
    })
  );
});

teste('BLOQUEIA: não-participante enviar mensagem', async () => {
  await assertFails(
    setDoc(doc(forasteiro(), `${SALA}/Mensagens/nova`), {
      texto: 'oi',
      autorUid: 'user9',
      autorNome: 'Forasteiro',
    })
  );
});

// ── Moderação ─────────────────────────────────────────────────────────────
teste('BLOQUEIA: autor apagar a própria mensagem', async () => {
  const db = env.authenticatedContext('user2').firestore();
  await assertFails(deleteDoc(doc(db, MSG)));
});

teste('PERMITE (admin): apagar mensagem', async () => {
  await assertSucceeds(deleteDoc(doc(admin(), MSG)));
});

let falhas = 0;
for (const [nome, corpo] of casos) {
  await semear();
  try {
    await corpo();
    console.log(`  ok   ${nome}`);
  } catch (erro) {
    falhas++;
    console.log(`  FALHA ${nome}`);
    console.log(`        ${String(erro.message).split('\n')[0]}`);
  }
}

await env.cleanup();
console.log(`\n${casos.length - falhas}/${casos.length} passaram`);
assert.equal(falhas, 0, `${falhas} teste(s) de regra falharam`);
