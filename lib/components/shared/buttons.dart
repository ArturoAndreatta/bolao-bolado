import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/core/app_radii.dart';
import 'package:flutter/material.dart';

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final double width;
  // Reduz padding/fonte para uso dentro de cards/painéis densos (ex: cards
  // do dashboard admin), onde o tamanho padrão (pensado para CTAs de tela
  // cheia como login/cadastro) chamava mais atenção que o próprio card.
  final bool compact;
  // Mantém o botão com forma/tamanho inalterados durante uma ação
  // assíncrona, trocando só o texto por um spinner pequeno e desabilitando
  // o toque — padrão de mercado (evita o layout "pular" ao trocar o botão
  // inteiro por um CircularProgressIndicator solto).
  final bool loading;

  const PrimaryButton({
    super.key,
    required this.text,
    required this.onTap,
    this.width = 300,
    this.compact = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);

    return Container(
      width: width,
      decoration: BoxDecoration(
        borderRadius: AppRadii.circularXl,
        boxShadow: [
          BoxShadow(
            // Sombra mais contida no escuro: sobre fundo escuro a sombra
            // preta forte do tema claro vira uma mancha suja em volta do
            // botão em vez de profundidade.
            color: cores.sombra.withValues(
              alpha: cores.escuro
                  ? (compact ? 0.35 : 0.5)
                  : (compact ? 0.15 : 0.3),
            ),
            blurRadius: compact ? 6 : 10,
            offset: Offset(0, compact ? 2 : 4),
          ),
        ],
      ),
      child: Material(
        color: cores.acaoPrimaria,
        borderRadius: AppRadii.circularXl,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: loading ? null : onTap,
          child: SizedBox(
            // Altura fixa (em vez de Padding + tamanho intrínseco do
            // conteúdo): texto e spinner têm alturas de linha ligeiramente
            // diferentes, então sem isso o botão "pulava" 1-2px ao trocar
            // entre os dois, o que empurrava o card do Pix embaixo dele.
            height: compact ? 38 : 54,
            child: Center(
              child: loading
                  ? SizedBox(
                      width: compact ? 16 : 20,
                      height: compact ? 16 : 20,
                      child: CircularProgressIndicator(
                        color: cores.textoSobreAcao,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      text,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: cores.textoSobreAcao,
                        fontSize: compact ? 14 : 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final double width;

  const SecondaryButton({
    super.key,
    required this.text,
    required this.onTap,
    this.width = 300,
  });

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);

    return Container(
      width: width,
      decoration: BoxDecoration(
        borderRadius: AppRadii.circularXl,
        border: Border.all(color: cores.acaoPrimaria, width: 2),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadii.circularXl,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 0),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                // Acompanha o primário: com o "Confirmar" dourado e este ainda
                // azul, os dois botões empilhados brigariam entre si.
                color: cores.acaoPrimaria,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
