import 'package:bolao_bolado/dev/simulador_apostas.dart';
import 'package:flutter/material.dart';

// Diálogo apenas exibe/controla o SimuladorApostas recebido de participants.dart;
// a instância é mantida no state da página pai para sobreviver ao fechar/reabrir
// do diálogo e ser parada em dispose() caso a tela seja abandonada rodando.
class DialogoSimulacaoApostas extends StatefulWidget {
  final SimuladorApostas simulador;
  final String salaId;

  const DialogoSimulacaoApostas({
    super.key,
    required this.simulador,
    required this.salaId,
  });

  @override
  State<DialogoSimulacaoApostas> createState() =>
      _DialogoSimulacaoApostasState();
}

class _DialogoSimulacaoApostasState extends State<DialogoSimulacaoApostas> {
  bool _limpando = false;

  @override
  Widget build(BuildContext context) {
    final rodando = widget.simulador.rodando;

    return AlertDialog(
      title: const Text('Simular apostas'),
      content: const Text(
        'Gera, edita e remove apostas fictícias automaticamente, '
        'apenas para visualização de como a tela fica com muitos '
        'participantes. Não afeta apostas reais.',
      ),
      actions: [
        TextButton(
          onPressed: _limpando
              ? null
              : () async {
                  setState(() => _limpando = true);
                  // Para a simulação antes de limpar para evitar que o
                  // gerador recrie apostas fictícias durante a limpeza.
                  widget.simulador.parar();
                  await widget.simulador.limparSimulados(widget.salaId);
                  if (mounted) setState(() => _limpando = false);
                },
          child: const Text('Limpar simulados'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
        ),
        FilledButton(
          onPressed: _limpando
              ? null
              : () {
                  setState(() {
                    if (rodando) {
                      widget.simulador.parar();
                    } else {
                      widget.simulador.iniciar(widget.salaId);
                    }
                  });
                },
          child: Text(rodando ? 'Parar simulação' : 'Iniciar simulação'),
        ),
      ],
    );
  }
}
