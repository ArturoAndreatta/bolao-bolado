import 'package:bolao_bolado/core/app_radii.dart';
import 'package:flutter/material.dart';

// Bloco explicativo "Como funciona", exibido no formulário de Minha Aposta
// para orientar quem está apostando pela primeira vez.
class ComoFunciona extends StatelessWidget {
  const ComoFunciona({super.key});

  static const _passos = [
    ('Você faz sua aposta', 'Escolha o valor e a quantidade de cotas.'),
    ('O bolão é criado', 'Você e outras pessoas participam juntas.'),
    (
      'Se ganhar, o prêmio é dividido',
      'O prêmio é dividido proporcionalmente entre todos os participantes.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF6E3),
        borderRadius: AppRadii.circularMd,
        border: Border.all(color: const Color(0xFFF0E4B8), width: 1.5),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Como funciona?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < _passos.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _PassoItem(
                numero: i + 1,
                titulo: _passos[i].$1,
                descricao: _passos[i].$2,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PassoItem extends StatelessWidget {
  final int numero;
  final String titulo;
  final String descricao;

  const _PassoItem({
    required this.numero,
    required this.titulo,
    required this.descricao,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0xFF7CC8A0),
            shape: BoxShape.circle,
          ),
          child: Text(
            '$numero',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                descricao,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
