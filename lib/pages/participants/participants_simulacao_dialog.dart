import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/core/app_radii.dart';
import 'package:bolao_bolado/core/debug_flags.dart';
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

  // Modo escolhido na lista. Começa no que o simulador já está usando, para
  // reabrir o diálogo com a simulação rodando mostrar o modo certo marcado.
  late ModoSimulacao _modo = widget.simulador.modo;

  // Preenchido quando a simulação para sozinha por falta de alvo ("apenas
  // exclusões" que acabou com as apostas fake, por exemplo). Sem isso o
  // botão voltava para "Iniciar" sem explicação nenhuma.
  MotivoParada? _motivoParada;

  @override
  void initState() {
    super.initState();
    widget.simulador.aoPararSozinho = (motivo) {
      if (mounted) setState(() => _motivoParada = motivo);
    };
  }

  @override
  void dispose() {
    // O simulador vive na página, não aqui: deixar o callback apontando para
    // um State já descartado seguraria este objeto na memória e chamaria
    // setState em widget morto.
    widget.simulador.aoPararSozinho = null;
    super.dispose();
  }

  void _alternarSimulacao() {
    setState(() {
      if (widget.simulador.rodando) {
        widget.simulador.parar();
      } else {
        _motivoParada = null;
        widget.simulador.iniciar(widget.salaId, modo: _modo);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    final rodando = widget.simulador.rodando;

    return AlertDialog(
      title: const Text('Simular apostas'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gera apostas fictícias automaticamente, apenas para ver como a '
              'tela se comporta. Não afeta apostas reais. Vai até '
              '$kMaximoParticipantesSimulados participantes.',
              style: TextStyle(fontSize: 13, color: cores.textoSuave),
            ),
            const SizedBox(height: 8),
            // Ritmo e gravação são ajustados no Painel ADM (Configurações),
            // não aqui: são preferências de dev que valem para a simulação
            // inteira, e o painel é onde as outras ferramentas de dev já
            // moram. Mostrar os dois valores em vigor numa linha só evita a
            // pergunta "por que está lento?"/"por que não salvou?" sem
            // duplicar os controles nem estourar a altura do diálogo.
            ValueListenableBuilder<int>(
              valueListenable: intervaloSimulacaoMsGlobal,
              builder: (context, intervalo, _) => ValueListenableBuilder<bool>(
                valueListenable: gravarSimulacaoFirestoreGlobal,
                builder: (context, gravando, _) => Text(
                  'Ritmo: ${intervalo}ms · '
                  '${gravando ? "gravando no Firestore" : "só visual"} '
                  '(Painel ADM › Configurações).',
                  style: TextStyle(fontSize: 12, color: cores.textoFraco),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Trocar de modo com a simulação rodando exigiria reiniciar o
            // timer no meio; mais simples (e mais previsível) é exigir parar
            // antes, deixando as opções visivelmente desabilitadas.
            RadioGroup<ModoSimulacao>(
              groupValue: _modo,
              onChanged: (modo) {
                // Rodando, a escolha fica travada: cada _OpcaoModo já ignora
                // o toque, e este guarda cobre o caminho por teclado.
                if (rodando || modo == null) return;
                setState(() => _modo = modo);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final modo in ModoSimulacao.values)
                    _OpcaoModo(
                      modo: modo,
                      selecionado: _modo == modo,
                      habilitado: !rodando,
                      onSelecionar: () => setState(() => _modo = modo),
                    ),
                ],
              ),
            ),
            if (_motivoParada != null) ...[
              const SizedBox(height: 12),
              _AvisoParada(motivo: _motivoParada!),
            ],
          ],
        ),
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
                  if (mounted) {
                    setState(() {
                      _limpando = false;
                      _motivoParada = null;
                    });
                  }
                },
          child: const Text('Limpar simulados'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
        ),
        FilledButton(
          onPressed: _limpando ? null : _alternarSimulacao,
          child: Text(rodando ? 'Parar simulação' : 'Iniciar simulação'),
        ),
      ],
    );
  }
}

/// Uma linha da lista de modos: rádio + rótulo + o que o modo faz.
class _OpcaoModo extends StatelessWidget {
  final ModoSimulacao modo;
  final bool selecionado;
  final bool habilitado;
  final VoidCallback onSelecionar;

  const _OpcaoModo({
    required this.modo,
    required this.selecionado,
    required this.habilitado,
    required this.onSelecionar,
  });

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    // Desabilitado continua legível (é preciso saber qual modo está rodando),
    // só perde o contraste de item clicável.
    final corTexto = habilitado ? cores.texto : cores.textoSuave;

    return InkWell(
      onTap: habilitado ? onSelecionar : null,
      borderRadius: AppRadii.circularSmd,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Radio<ModoSimulacao>(
              value: modo,
              enabled: habilitado,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    modo.rotulo,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selecionado
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: corTexto,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    modo.descricao,
                    style: TextStyle(fontSize: 12, color: cores.textoFraco),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bloco explicando que a simulação parou sozinha por falta de alvo.
class _AvisoParada extends StatelessWidget {
  final MotivoParada motivo;

  const _AvisoParada({required this.motivo});

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cores.fundoAmarelo,
        borderRadius: AppRadii.circularSmd,
        border: Border.all(color: cores.bordaAmarelo),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: cores.textoAmarelo),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Simulação encerrada. ${motivo.mensagem}',
              style: TextStyle(fontSize: 12.5, color: cores.textoAmarelo),
            ),
          ),
        ],
      ),
    );
  }
}
