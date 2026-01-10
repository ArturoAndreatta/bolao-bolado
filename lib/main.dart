import 'package:bolao_bolado/pages/home.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

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
// - Pix (Gerar um QR Code a partir da chave pix para facilitar o pagamento)
//
// [BOTÃO SALVAR] [BOTÃO EXCLUIR] [BOTÃO CANCELAR]
//
// X minutos ou horas depois da data/hora do sorteio, notificar (por e-mail)
// o criador da sala para ele informar os números sorteados na sala criada,
// assim que ele informar e confirmar, será enviado um e-mail/mensagem para
// todos os participantes, informando os números sorteados, um anexo com os
// números apostados e um link que irá redirecionar para a sala da aposta
//
// Na tela inicial:
// - Criar conta
// - Logar
// Após criar conta/logar:
// Criar Sala
// Consultar Salas
//
// Ao clicar em "Consultar Salas", irá mostrar uma consulta com todas as salas
// existentes, deve ter filtros para facilitar a pesquisa, a sala oficial do
// Bolão Bolado sempre será a primeira em destaque
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(BolaoBolado());
}
