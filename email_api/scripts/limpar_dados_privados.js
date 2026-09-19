// Limpeza única dos dados privados que ficaram em documentos públicos.
//
//   node scripts/limpar_dados_privados.js caminho/da/chave.json            # só mostra
//   node scripts/limpar_dados_privados.js caminho/da/chave.json --aplicar  # grava
//
// Roda na máquina de quem administra, com a chave de conta de serviço do
// Firebase (Configurações do projeto > Contas de serviço > Gerar nova chave
// privada). Fica nesta pasta só porque aqui o `firebase-admin` já está nas
// dependências — a Vercel publica apenas `api/`, então isto nunca vira
// endpoint. Não versione a chave: apague o .json depois de usar.
//
// O que faz:
// 1. `usuarios/{uid}.email` — o cadastro gravava o e-mail no perfil, que
//    qualquer visitante (sessão anônima inclusive) consegue ler. O app já
//    parou de gravar e apaga o campo quando o próprio dono abre o app; este
//    script cobre quem não voltar.
// 2. `Salas/{id}.senha` — a senha de acesso da sala estava no doc público da
//    sala. Vai para `Salas/{id}/Privado/acesso`, que só admin lê.
//
// Sem `--aplicar` nada é gravado: primeiro confira o que vai mudar.

const fs = require('fs');
const admin = require('firebase-admin');

const [caminhoChave, flag] = process.argv.slice(2);
if (!caminhoChave) {
  console.error('Uso: node scripts/limpar_dados_privados.js chave.json [--aplicar]');
  process.exit(1);
}
const aplicar = flag === '--aplicar';

admin.initializeApp({
  credential: admin.credential.cert(JSON.parse(fs.readFileSync(caminhoChave, 'utf8'))),
});
const db = admin.firestore();

async function limparEmails() {
  const usuarios = await db.collection('usuarios').get();
  const comEmail = usuarios.docs.filter((doc) => doc.get('email') !== undefined);
  console.log(`usuarios com email exposto: ${comEmail.length} de ${usuarios.size}`);
  if (!aplicar) return;

  // Lotes de 400: um batch aceita no máximo 500 escritas.
  for (let i = 0; i < comEmail.length; i += 400) {
    const batch = db.batch();
    for (const doc of comEmail.slice(i, i + 400)) {
      batch.update(doc.ref, { email: admin.firestore.FieldValue.delete() });
    }
    await batch.commit();
  }
}

async function moverSenhasDeSala() {
  const salas = await db.collection('Salas').get();
  const comSenha = salas.docs.filter((doc) => doc.get('senha') !== undefined);
  console.log(`salas com senha exposta: ${comSenha.length} de ${salas.size}`);
  if (!aplicar) return;

  for (const doc of comSenha) {
    // Mover e apagar juntos: se um falhar, a senha não some nem duplica.
    const batch = db.batch();
    batch.set(doc.ref.collection('Privado').doc('acesso'), { senha: doc.get('senha') });
    batch.update(doc.ref, { senha: admin.firestore.FieldValue.delete() });
    await batch.commit();
  }
}

(async () => {
  await limparEmails();
  await moverSenhasDeSala();
  console.log(aplicar ? 'Pronto.' : 'Nada gravado. Rode de novo com --aplicar.');
})().catch((erro) => {
  console.error(erro);
  process.exit(1);
});
