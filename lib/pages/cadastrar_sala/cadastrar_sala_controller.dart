import 'package:bolao_bolado/components/formatters/formatters.dart';
import 'package:bolao_bolado/components/formatters/money_input_format.dart';
import 'package:bolao_bolado/components/shared/custom_fields.dart';
import 'package:bolao_bolado/pages/cadastrar_sala/cadastrar_sala_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// Opções do dropdown "Sorteio", únicas para CadastrarSalaDesktop e
// CadastrarSalaMobile (antes duplicadas, hardcoded, em cada tela).
const List<DropdownMenuItem<String>> opcoesSorteio = [
  DropdownMenuItem(value: 'mega', child: Text('Mega-Sena')),
  DropdownMenuItem(value: 'loto', child: Text('Lotofácil')),
  DropdownMenuItem(value: 'outros', child: Text('Outros')),
];

// Estado e regras de carregar/salvar sala, compartilhados entre
// CadastrarSalaDesktop e CadastrarSalaMobile — os dois formulários têm os
// mesmos campos e a mesma lógica de persistência, só o layout muda.
class CadastrarSalaController {
  final String? salaId;

  CadastrarSalaController({this.salaId});

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final TextEditingController nameController = TextEditingController();
  final TextEditingController descricaoController = TextEditingController();
  final TextEditingController horaController = TextEditingController();
  final TextEditingController dataController = TextEditingController();
  final TextEditingController premioController = TextEditingController();
  final TextEditingController valorMaximoApostaController =
      TextEditingController();
  final TextEditingController senhaSalaController = TextEditingController();
  final TextEditingController chavePixController = TextEditingController();
  TimeOfDay? horaSelecionada;
  String? sorteio;
  bool saving = false;
  bool loadingSala = true;

  bool get editando => salaId != null;

  void dispose() {
    nameController.dispose();
    descricaoController.dispose();
    horaController.dispose();
    dataController.dispose();
    premioController.dispose();
    valorMaximoApostaController.dispose();
    senhaSalaController.dispose();
    chavePixController.dispose();
  }

  Future<void> carregarSala() async {
    final doc = await firestore.collection('Salas').doc(salaId).get();
    final dados = doc.data();
    if (dados != null) {
      nameController.text = dados['nome']?.toString() ?? '';
      descricaoController.text = dados['descricao']?.toString() ?? '';
      sorteio = dados['sorteio']?.toString();
      final dataHora = dados['dataHora'];
      if (dataHora is Timestamp) {
        final dt = dataHora.toDate();
        dataController.text = Formatters.data.format(dt);
        horaSelecionada = TimeOfDay(hour: dt.hour, minute: dt.minute);
        horaController.text = CustomTimeField.format(horaSelecionada!);
      }
      // Reaplica a formatação pt-BR (ex: "1.234,56") ao carregar o valor
      // numérico salvo no Firestore, mantendo consistência com o que o
      // MoneyInputFormat exibiria durante a digitação.
      final premio = (dados['premio'] as num?)?.toDouble();
      if (premio != null) {
        premioController.text = Formatters.moedaSemSimbolo
            .format(premio)
            .trim();
      }
      final valorMaximo = (dados['valorMaximo'] as num?)?.toDouble();
      if (valorMaximo != null) {
        valorMaximoApostaController.text = Formatters.moedaSemSimbolo
            .format(valorMaximo)
            .trim();
      }
      senhaSalaController.text = dados['senha']?.toString() ?? '';
      chavePixController.text = dados['chavePix']?.toString() ?? '';
    }
    loadingSala = false;
  }

  Future<void> salvar() async {
    final dataHora = juntarDataHora(dataController.text, horaController.text);
    final dados = {
      'nome': nameController.text,
      'descricao': descricaoController.text,
      'sorteio': sorteio,
      'dataHora': Timestamp.fromDate(dataHora),
      'premio': MoneyInputFormat.parse(premioController.text),
      'valorMaximo': MoneyInputFormat.parse(valorMaximoApostaController.text),
      'senha': senhaSalaController.text,
      'chavePix': chavePixController.text,
    };
    if (editando) {
      await firestore.collection('Salas').doc(salaId).update(dados);
    } else {
      await firestore.collection('Salas').add(dados);
    }
  }
}
