import 'package:bolao_bolado/components/shell/gradient_decoration.dart';
import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/core/app_radii.dart';
import 'package:flutter/material.dart';

/// Tela de espera enquanto o Firebase e a sessão sobem.
///
/// **Na web existe uma cópia dela em HTML e CSS puro, em `web/index.html`**,
/// que cobre o intervalo antes de o motor do Flutter montar o primeiro quadro.
/// As duas precisam continuar iguais — logo, tamanhos, espaçamento, barra e
/// cores por tema: a cópia HTML fica por cima desta até o app entrar, e
/// qualquer diferença entre elas aparece como um salto quando uma vira a
/// outra. Mexeu aqui, mexa lá.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _progressAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    return Container(
      decoration: GradientDecoration.backgroundGradient(context),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('images/logo4.png', height: 220, width: 280),
              SizedBox(height: 40),
              SizedBox(
                width: 200,
                child: AnimatedBuilder(
                  animation: _progressAnimation,
                  builder: (context, _) {
                    return ClipRRect(
                      borderRadius: AppRadii.circularSm,
                      child: LinearProgressIndicator(
                        value: _progressAnimation.value,
                        minHeight: 6,
                        backgroundColor: cores.textoSobreCor.withValues(
                          alpha: 0.3,
                        ),
                        valueColor: AlwaysStoppedAnimation<Color>(cores.azul),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
