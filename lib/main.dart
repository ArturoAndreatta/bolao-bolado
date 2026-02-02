import 'package:bolao_bolado/bolao_bolado.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Atual:
// Criar novo botão "Telas" na página inicial pra acessar e ir para uma tela
// com vários botões com o nome de cada tela.
// Fazer isso para facilitar o acesso a todas as telas, depois será retirado.

// Implementações:
// Cadastrar com e-mail/número e senha
// Criação do perfil preenchendo nome, sobrenome e foto de perfil
// Possibilidade de criar salas de apostas. Com os campos:
// - Nome da sala
// - Descrição
// - Sorteio (Mega sena, loto fácil, etc)
// - Data/Hora do sorteio
// - Prêmio do sorteio
// - Números apostados
// - Números sorteados
// - Opção para colocar um valor máximo de aposta (por pessoa)
// - Sorteio Privado (com senha) [SIM/NÃO]
// - Pix (Gerar um QR Code a partir da chave pix para facilitar o pagamento)
//
// [BOTÃO SALVAR] [BOTÃO EXCLUIR] [BOTÃO LIMPAR]
//
// Deve ser possível que o criador da sala possa remover pessoas da sala
//
// X minutos ou horas depois da data/hora do sorteio, notificar (por e-mail)
// o criador da sala para ele informar os números sorteados na sala criada,
// assim que ele informar e confirmar, será enviado um e-mail/mensagem para
// todos os participantes, informando os números sorteados, um anexo
// (ou direto no e-mail) com os números apostados e um link que irá
// redirecionar para a sala da aposta
//
// Na tela inicial:
// - Criar conta
// - Logar
// Após criar conta/logar:
// Criar Sala
// Consultar Salas
//
// Ao clicar em "Consultar Salas", irá mostrar uma consulta com todas as salas
// existentes, deve ter filtro para facilitar a pesquisa, a sala oficial do
// Bolão Bolado sempre será a primeira e em destaque
// Botão "Entrar com código" que é gerado na criação da sala
//
// Chat dentro da sala
//
// Perguntar em algum momento se o usuário gostaria de ser notificado por
// e-mail quando um novo sorteio fosse iniciado (ex: mega da virada)
//
//
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (FirebaseAuth.instance.currentUser == null) {
    await FirebaseAuth.instance.signInAnonymously();
  }
  runApp(BolaoBolado());
}
