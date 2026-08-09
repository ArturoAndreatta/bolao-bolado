// Sorteia um novo fundo (cor) e um novo emoji de avatar para os usuários em
// `usuarios/{uid}`, sobrescrevendo `avatarColor` e `avatarEmoji` existentes.
//
// Usa o Admin SDK porque as Firestore rules só permitem que cada usuário
// escreva o próprio doc (ou o admin escreva doc de terceiro em outras
// coleções) — não existe um caminho de escrita em massa via client SDK aqui,
// então este script roda fora do app, autenticado com uma service account.
//
// Uso:
//   1. Baixe uma service account key em:
//      Firebase Console > Configurações do projeto > Contas de serviço >
//      Gerar nova chave privada (projeto bolaobolado-app).
//   2. Rode:
//      GOOGLE_APPLICATION_CREDENTIALS=caminho/para/service-account.json node tool/sortear_avatares.mjs
//
// Flags:
//   --simular      mostra o que seria gravado, sem escrever nada no Firestore.
//   --incluir-admin  sorteia também para contas com isAdmin: true (por padrão
//                    elas são puladas, ver abaixo).
//
// Contas admin são puladas de propósito: a cor roxa kCorBaseAdmin identifica
// o admin no chat e na lista, e no app ela só é aplicada enquanto NÃO existe
// `avatarColor` gravado (ver AvatarService.buscarCor). Gravar uma cor sorteada
// aqui apagaria esse padrão de forma permanente.
//
// A paleta de cores e a lista de emojis são reimplementadas aqui (copiadas de
// lib/services/avatar/avatar_service.dart) porque este script roda em Node,
// fora da VM do Dart/Flutter — não há como importar o arquivo .dart direto.
// Se a paleta ou a lista de emojis mudarem lá, replique aqui também.

import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const CHAVE_ADMIN_HUE = 274.9748743718593; // matiz de kCorBaseAdmin (0xFF7400C7)

function hslParaRgbHex(h, s, l) {
  const c = (1 - Math.abs(2 * l - 1)) * s;
  const x = c * (1 - Math.abs(((h / 60) % 2) - 1));
  const m = l - c / 2;
  let [r, g, b] = [0, 0, 0];
  if (h < 60) [r, g, b] = [c, x, 0];
  else if (h < 120) [r, g, b] = [x, c, 0];
  else if (h < 180) [r, g, b] = [0, c, x];
  else if (h < 240) [r, g, b] = [0, x, c];
  else if (h < 300) [r, g, b] = [x, 0, c];
  else [r, g, b] = [c, 0, x];
  const canal = (v) => Math.round((v + m) * 255);
  return ((0xff << 24) | (canal(r) << 16) | (canal(g) << 8) | canal(b)) >>> 0;
}

const DESLOCAMENTOS_HUE = [30, 60, 90, 120, 150, 200, 260, 320];
const LUMINOSIDADES = [0.4, 0.5];
const SATURACAO = 0.62; // abaixo da saturação da cor base — ver avatar_service.dart

const CORES_AVATAR = LUMINOSIDADES.flatMap((l) =>
  DESLOCAMENTOS_HUE.map((deslocamento) => hslParaRgbHex((CHAVE_ADMIN_HUE + deslocamento) % 360, SATURACAO, l)),
);

// Mesma ordem das categorias em kCategoriasEmojiAvatar.
const EMOJIS_AVATAR = [
  // Sorte
  '🍀', '🎲', '🏆', '💰', '💎', '🔮', '🎯', '🧿',
  // Bichos
  '🦁', '🐯', '🐵', '🦊', '🐼', '🐨', '🐷', '🐶', '🐱', '🐮', '🐸', '🦉',
  // Caras
  '😎', '🤠', '🤑', '🥳', '🤖', '👽', '👻', '🤡',
  // Coisas
  '🔥', '⚡', '🚀', '⚽', '🏀', '🍕', '🍔', '🎸',
];

function sortear(lista) {
  return lista[Math.floor(Math.random() * lista.length)];
}

const simular = process.argv.includes('--simular');
const incluirAdmin = process.argv.includes('--incluir-admin');

initializeApp({ credential: applicationDefault() });
const db = getFirestore();

const snapshot = await db.collection('usuarios').get();
console.log(
  `${simular ? '[SIMULAÇÃO] ' : ''}Sorteando fundo e emoji para ${snapshot.size} usuário(s)...`,
);

let lote = db.batch();
let contadorLote = 0;
let total = 0;
let pulados = 0;

for (const doc of snapshot.docs) {
  if (!incluirAdmin && doc.data().isAdmin === true) {
    console.log(`  ${doc.id}: pulado (admin)`);
    pulados++;
    continue;
  }

  const avatarColor = sortear(CORES_AVATAR);
  const avatarEmoji = sortear(EMOJIS_AVATAR);
  console.log(`  ${doc.id}: ${avatarEmoji} #${(avatarColor & 0xffffff).toString(16).padStart(6, '0')}`);

  if (!simular) {
    lote.set(doc.ref, { avatarColor, avatarEmoji }, { merge: true });
    contadorLote++;

    // Firestore limita 500 escritas por batch.
    if (contadorLote === 500) {
      await lote.commit();
      lote = db.batch();
      contadorLote = 0;
    }
  }
  total++;
}

if (!simular && contadorLote > 0) await lote.commit();

const resumoPulados = pulados > 0 ? ` (${pulados} admin pulado(s))` : '';
console.log(
  simular
    ? `\n[SIMULAÇÃO] Nada foi gravado. ${total} avatar(es) seriam sorteados${resumoPulados}.`
    : `\nPronto: ${total} avatar(es) sorteado(s)${resumoPulados}.`,
);
