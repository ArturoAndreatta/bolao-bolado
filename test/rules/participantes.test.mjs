// Testes das regras de Participantes (firestore.rules) contra o emulador
// real do Firestore — as invariantes de dinheiro do bolão (quem entra no
// rateio, quem pode editar aposta aprovada) valem o que o motor de regras
// realmente aplica, não o que a leitura do arquivo sugere.
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
import { doc, setDoc, updateDoc, deleteDoc, getDoc, setLogLevel } from 'firebase/firestore';

setLogLevel('error');

const SALA = 'Salas/sala1';
const SALA_SEM_TETO = 'Salas/sala2';
const SALA_LOTO = 'Salas/sala3';
const aquiDir = path.dirname(fileURLToPath(import.meta.url));
const rules = fs.readFileSync(
  path.join(aquiDir, '..', '..', 'firestore.rules'),
  'utf8'
);

const env = await initializeTestEnvironment({
  projectId: 'demo-bolao-rules',
  firestore: { rules, host: '127.0.0.1', port: 8080 },
});

// Semeia estado inicial sem passar pelas regras.
async function semear() {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'usuarios/admin1'), { nome: 'Admin', isAdmin: true });
    await setDoc(doc(db, 'usuarios/user1'), { nome: 'User', isAdmin: false });
    // Teto de R$120 por aposta: exercita apostaCabeNaSala() nas regras.
    // Sem campo `sorteio`, a regra cai no padrão Mega-Sena (cota de R$6).
    await setDoc(doc(db, SALA), {
      nome: 'Principal',
      principal: true,
      valorMaximo: 120,
    });
    // Sala sem `valorMaximo`: o limite é opcional e a ausência dele não pode
    // bloquear aposta nenhuma.
    await setDoc(doc(db, SALA_SEM_TETO), {
      nome: 'Sem teto',
      principal: false,
    });
    // Sala de Lotofácil: a cota é R$3,50, então a mesma quantia compra mais
    // cotas — e a regra precisa converter valor em cotas com o preço certo.
    await setDoc(doc(db, SALA_LOTO), {
      nome: 'Lotofácil',
      principal: false,
      sorteio: 'lotofacil',
    });
    // Aposta já aprovada pelo admin.
    await setDoc(doc(db, `${SALA}/Participantes/user1`), {
      nome: 'User',
      valor: '18',
      verificado: true,
      editadoAposVerificacao: false,
    });
    // Aposta ainda pendente, de outro usuário.
    await setDoc(doc(db, `${SALA}/Participantes/user2`), {
      nome: 'Outro',
      valor: '6',
      verificado: false,
      editadoAposVerificacao: false,
    });
  });
}

const user = () => env.authenticatedContext('user1').firestore();
const admin = () => env.authenticatedContext('admin1').firestore();
const anon = () =>
  env.authenticatedContext('anon1', { firebase: { sign_in_provider: 'anonymous' } })
    .firestore();

const casos = [];
const teste = (nome, corpo) => casos.push([nome, corpo]);

// ── O buraco que o item #3 fecha ──────────────────────────────────────────
teste('BLOQUEIA: editar aposta verificada sem marcar editadoAposVerificacao', async () => {
  await assertFails(
    updateDoc(doc(user(), `${SALA}/Participantes/user1`), {
      valor: '60',
      verificado: false,
    })
  );
});

teste('PERMITE: editar aposta verificada marcando editadoAposVerificacao', async () => {
  await assertSucceeds(
    updateDoc(doc(user(), `${SALA}/Participantes/user1`), {
      valor: '60', // dentro do teto de 120 da sala
      verificado: false,
      editadoAposVerificacao: true,
    })
  );
});

teste('BLOQUEIA: manter verificado:true ao editar a própria aposta', async () => {
  await assertFails(
    updateDoc(doc(user(), `${SALA}/Participantes/user1`), {
      valor: '60',
      editadoAposVerificacao: true,
    })
  );
});

// ── Invariantes que já existiam, para não regredirem ──────────────────────
teste('BLOQUEIA: usuário se auto-verificar ao criar aposta', async () => {
  await assertFails(
    setDoc(doc(user(), `${SALA}/Participantes/user1`), {
      nome: 'User',
      valor: '60',
      verificado: true,
    })
  );
});

teste('BLOQUEIA: gravar valor como número (invariante string)', async () => {
  await assertFails(
    setDoc(doc(user(), `${SALA}/Participantes/user1`), {
      nome: 'User',
      valor: 18,
      verificado: false,
    })
  );
});

teste('BLOQUEIA: escrever na aposta de outro usuário', async () => {
  await assertFails(
    updateDoc(doc(user(), `${SALA}/Participantes/user2`), { valor: '60' })
  );
});

teste('BLOQUEIA: usuário apagar a própria aposta', async () => {
  await assertFails(deleteDoc(doc(user(), `${SALA}/Participantes/user1`)));
});

teste('BLOQUEIA: anônimo criar aposta', async () => {
  await assertFails(
    setDoc(doc(anon(), `${SALA}/Participantes/anon1`), {
      nome: 'Anon',
      valor: '6',
      verificado: false,
    })
  );
});

// user3 não tem aposta semeada: este é o caminho de CREATE de verdade.
teste('PERMITE: usuário criar a própria aposta pendente', async () => {
  const db = env.authenticatedContext('user3').firestore();
  await assertSucceeds(
    setDoc(doc(db, `${SALA}/Participantes/user3`), {
      nome: 'Novo',
      valor: '6',
      verificado: false,
      editadoAposVerificacao: false,
    })
  );
});

// Reaposta via set() sobre doc existente é UPDATE para as regras. É o que
// _confirmar() faz: manda editadoAposVerificacao = jaEstavaVerificada.
teste('PERMITE: reapostar (set) sobre aposta verificada, marcando o rastro', async () => {
  await assertSucceeds(
    setDoc(doc(user(), `${SALA}/Participantes/user1`), {
      nome: 'User',
      valor: '60',
      uid: 'user1',
      verificado: false,
      editadoAposVerificacao: true,
    })
  );
});

// Reaposta sobre aposta que ainda estava pendente: nada a preservar, o
// rastro continua false — não pode ser exigido aqui.
teste('PERMITE: reapostar (set) sobre aposta pendente sem marcar rastro', async () => {
  const db = env.authenticatedContext('user2').firestore();
  await assertSucceeds(
    setDoc(doc(db, `${SALA}/Participantes/user2`), {
      nome: 'Outro',
      valor: '12',
      uid: 'user2',
      verificado: false,
      editadoAposVerificacao: false,
    })
  );
});

// ── Jogos escolhidos pelo participante (campo opcional `jogos`) ───────────
// Cada jogo custa no mínimo uma cota, então a regra usa a contagem de jogos
// como limite exato contra as cotas pagas (valor / preço da cota).
const jogo = (inicio) => ({
  numeros: [inicio, inicio + 1, inicio + 2, inicio + 3, inicio + 4, inicio + 5],
});

teste('PERMITE: jogos cabendo nas cotas pagas', async () => {
  const db = env.authenticatedContext('user3').firestore();
  await assertSucceeds(
    setDoc(doc(db, `${SALA}/Participantes/user3`), {
      nome: 'Novo',
      valor: '12', // 2 cotas
      verificado: false,
      editadoAposVerificacao: false,
      jogos: [jogo(1), jogo(10)],
    })
  );
});

teste('PERMITE: sobrar cota sem jogo escolhido', async () => {
  const db = env.authenticatedContext('user3').firestore();
  await assertSucceeds(
    setDoc(doc(db, `${SALA}/Participantes/user3`), {
      nome: 'Novo',
      valor: '120', // 20 cotas, um jogo só
      verificado: false,
      editadoAposVerificacao: false,
      jogos: [jogo(1)],
    })
  );
});

teste('BLOQUEIA: mais jogos do que as cotas pagas', async () => {
  const db = env.authenticatedContext('user3').firestore();
  await assertFails(
    setDoc(doc(db, `${SALA}/Participantes/user3`), {
      nome: 'Novo',
      valor: '6', // 1 cota, 2 jogos
      verificado: false,
      editadoAposVerificacao: false,
      jogos: [jogo(1), jogo(10)],
    })
  );
});

teste('BLOQUEIA: mais jogos do que o teto absoluto (500)', async () => {
  const db = env.authenticatedContext('user3').firestore();
  await assertFails(
    // Sala sem valorMaximo: as cotas sozinhas não seguram o tamanho do doc.
    setDoc(doc(db, `${SALA_SEM_TETO}/Participantes/user3`), {
      nome: 'Novo',
      valor: '3006', // 501 cotas
      verificado: false,
      editadoAposVerificacao: false,
      jogos: Array.from({ length: 501 }, () => jogo(1)),
    })
  );
});

teste('BLOQUEIA: `jogos` que não é lista', async () => {
  const db = env.authenticatedContext('user3').firestore();
  await assertFails(
    setDoc(doc(db, `${SALA}/Participantes/user3`), {
      nome: 'Novo',
      valor: '6',
      verificado: false,
      editadoAposVerificacao: false,
      jogos: 'nao é lista',
    })
  );
});

teste('PERMITE: sala de Lotofácil converte cota a R$3,50', async () => {
  const db = env.authenticatedContext('user3').firestore();
  await assertSucceeds(
    setDoc(doc(db, `${SALA_LOTO}/Participantes/user3`), {
      nome: 'Novo',
      valor: '7', // 2 cotas de R$3,50 — na Mega isso seria 1 só
      verificado: false,
      editadoAposVerificacao: false,
      jogos: [jogo(1), jogo(10)],
    })
  );
});

teste('BLOQUEIA: Lotofácil com mais jogos que as cotas de R$3,50', async () => {
  const db = env.authenticatedContext('user3').firestore();
  await assertFails(
    setDoc(doc(db, `${SALA_LOTO}/Participantes/user3`), {
      nome: 'Novo',
      valor: '7', // 2 cotas, 3 jogos
      verificado: false,
      editadoAposVerificacao: false,
      jogos: [jogo(1), jogo(10), jogo(20)],
    })
  );
});

// Limitação conhecida, fixada aqui de propósito: a linguagem de regras não
// itera lista, então o TAMANHO de cada jogo (e o custo combinatório dele)
// passa sem checagem. Quem valida isso é a UI (selecao_jogos_dialog.dart).
// O estrago é limitado — cota vem de `valor`, que é checado —, então o pior
// caso é um jogo que o organizador simplesmente não compra.
teste('LIMITAÇÃO: a regra não enxerga o tamanho do jogo', async () => {
  const db = env.authenticatedContext('user3').firestore();
  await assertSucceeds(
    setDoc(doc(db, `${SALA}/Participantes/user3`), {
      nome: 'Novo',
      valor: '6', // 1 cota, mas um jogo de 7 números custaria 7
      verificado: false,
      editadoAposVerificacao: false,
      jogos: [{ numeros: [1, 2, 3, 4, 5, 6, 7] }],
    })
  );
});

// ── Campo legado `numeros` (jogo único na raiz do doc) ────────────────────
teste('PERMITE: criar aposta com números escolhidos válidos', async () => {
  const db = env.authenticatedContext('user3').firestore();
  await assertSucceeds(
    setDoc(doc(db, `${SALA}/Participantes/user3`), {
      nome: 'Novo',
      valor: '6',
      verificado: false,
      editadoAposVerificacao: false,
      numeros: [1, 2, 3, 4, 5, 6],
    })
  );
});

teste('PERMITE: criar aposta sem escolher números', async () => {
  const db = env.authenticatedContext('user3').firestore();
  await assertSucceeds(
    setDoc(doc(db, `${SALA}/Participantes/user3`), {
      nome: 'Novo',
      valor: '6',
      verificado: false,
      editadoAposVerificacao: false,
    })
  );
});

teste('BLOQUEIA: números com duplicata', async () => {
  const db = env.authenticatedContext('user3').firestore();
  await assertFails(
    setDoc(doc(db, `${SALA}/Participantes/user3`), {
      nome: 'Novo',
      valor: '6',
      verificado: false,
      editadoAposVerificacao: false,
      numeros: [1, 1, 2, 3, 4, 5],
    })
  );
});

teste('BLOQUEIA: mais números do que o teto (25) permite', async () => {
  const db = env.authenticatedContext('user3').firestore();
  await assertFails(
    setDoc(doc(db, `${SALA}/Participantes/user3`), {
      nome: 'Novo',
      valor: '6',
      verificado: false,
      editadoAposVerificacao: false,
      numeros: Array.from({ length: 26 }, (_, i) => i + 1),
    })
  );
});

// ── Teto por aposta da sala (valorMaximo) ─────────────────────────────────
teste('BLOQUEIA: criar aposta acima do valorMaximo da sala', async () => {
  const db = env.authenticatedContext('user3').firestore();
  await assertFails(
    setDoc(doc(db, `${SALA}/Participantes/user3`), {
      nome: 'Novo',
      valor: '126', // teto é 120
      verificado: false,
      editadoAposVerificacao: false,
    })
  );
});

teste('PERMITE: criar aposta exatamente no valorMaximo (teto inclusivo)', async () => {
  const db = env.authenticatedContext('user3').firestore();
  await assertSucceeds(
    setDoc(doc(db, `${SALA}/Participantes/user3`), {
      nome: 'Novo',
      valor: '120',
      verificado: false,
      editadoAposVerificacao: false,
    })
  );
});

teste('BLOQUEIA: editar a própria aposta para valor acima do teto', async () => {
  const db = env.authenticatedContext('user2').firestore();
  await assertFails(
    updateDoc(doc(db, `${SALA}/Participantes/user2`), { valor: '600' })
  );
});

teste('PERMITE: sala sem valorMaximo aceita qualquer valor', async () => {
  const db = env.authenticatedContext('user3').firestore();
  await assertSucceeds(
    setDoc(doc(db, `${SALA_SEM_TETO}/Participantes/user3`), {
      nome: 'Novo',
      valor: '99999',
      verificado: false,
      editadoAposVerificacao: false,
    })
  );
});

teste('PERMITE (admin): lançar aposta acima do teto da sala', async () => {
  // Decisão explícita: quem define o teto é o admin, e lançar acima dele
  // (alguém que pagou mais por fora) é caso de uso legítimo do painel.
  await assertSucceeds(
    setDoc(doc(admin(), `${SALA}/Participantes/manual_alto`), {
      nome: 'Sem Conta',
      valor: '600',
      verificado: false,
      editadoAposVerificacao: false,
      criadoPeloAdmin: true,
    })
  );
});

// ── Fluxos reais do app que NÃO podem quebrar ─────────────────────────────
teste('PERMITE (admin): verificar aposta pendente', async () => {
  await assertSucceeds(
    updateDoc(doc(admin(), `${SALA}/Participantes/user2`), {
      verificado: true,
      editadoAposVerificacao: false,
    })
  );
});

teste('PERMITE (admin): reverter aposta verificada para pendente', async () => {
  await assertSucceeds(
    updateDoc(doc(admin(), `${SALA}/Participantes/user1`), {
      verificado: false,
      editadoAposVerificacao: false,
    })
  );
});

teste('PERMITE (admin): editar valor de aposta verificada', async () => {
  await assertSucceeds(
    updateDoc(doc(admin(), `${SALA}/Participantes/user1`), {
      valor: '60',
      editadoAposVerificacao: true,
    })
  );
});

teste('PERMITE (admin): lançar aposta manual em nome de terceiro', async () => {
  await assertSucceeds(
    setDoc(doc(admin(), `${SALA}/Participantes/manual_123`), {
      nome: 'Sem Conta',
      valor: '12',
      uid: 'manual_123',
      verificado: false,
      editadoAposVerificacao: false,
      criadoPeloAdmin: true,
    })
  );
});

teste('PERMITE (admin): remover aposta', async () => {
  await assertSucceeds(deleteDoc(doc(admin(), `${SALA}/Participantes/user2`)));
});

teste('BLOQUEIA (admin): gravar valor como número', async () => {
  await assertFails(
    setDoc(doc(admin(), `${SALA}/Participantes/manual_9`), {
      nome: 'Sem Conta',
      valor: 12,
      verificado: false,
    })
  );
});

// ── configuracoes da sala (ritmo do simulador, estilo de animação, aposta
// dupla) — campo dentro de Salas/{salaId}, não coleção à parte, porque cada
// sala (no futuro, mais de uma) tem seu próprio simulador. ─────────────────
teste('PERMITE (anônimo): ler configurações da sala', async () => {
  // A tela de Participantes é visível antes do login, e a animação de
  // entrada depende de saber o estilo configurado.
  await assertSucceeds(getDoc(doc(anon(), SALA)));
});

teste('PERMITE (usuário comum): ler configurações da sala', async () => {
  await assertSucceeds(getDoc(doc(user(), SALA)));
});

teste('BLOQUEIA (usuário comum): escrever configurações da sala', async () => {
  await assertFails(
    setDoc(
      doc(user(), SALA),
      { configuracoes: { intervaloSimulacaoMs: 100 } },
      { merge: true }
    )
  );
});

teste('BLOQUEIA (anônimo): escrever configurações da sala', async () => {
  await assertFails(
    setDoc(
      doc(anon(), SALA),
      { configuracoes: { estiloEntrada: 'glitch' } },
      { merge: true }
    )
  );
});

teste('PERMITE (admin): escrever configurações da sala', async () => {
  await assertSucceeds(
    setDoc(
      doc(admin(), SALA),
      { configuracoes: { estiloEntrada: 'glitch' } },
      { merge: true }
    )
  );
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
