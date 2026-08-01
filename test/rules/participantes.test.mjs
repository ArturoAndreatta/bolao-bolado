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
import { doc, setDoc, updateDoc, deleteDoc, setLogLevel } from 'firebase/firestore';

setLogLevel('error');

const SALA = 'Salas/sala1';
const SALA_SEM_TETO = 'Salas/sala2';
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
    // Teto de R$120 por aposta: exercita respeitaValorMaximo() nas regras.
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
