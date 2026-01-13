import 'package:bolao_bolado/components/default/footer.dart';
import 'package:bolao_bolado/components/default/gradient_decoration.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class DefaultLayout extends StatelessWidget {
  final Widget child;
  const DefaultLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktopWeb = kIsWeb && width >= 900;

    return Container(
      decoration: GradientDecoration.backgroundGradient(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        bottomNavigationBar: isDesktopWeb ? const Footer() : null,
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
          child: Center(child: child),
        ),
      ),
    );
  }
}
