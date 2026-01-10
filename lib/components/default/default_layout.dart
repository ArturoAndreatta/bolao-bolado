import 'package:bolao_bolado/components/default/footer.dart';
import 'package:bolao_bolado/components/default/gradient_decoration.dart';
import 'package:flutter/material.dart';

class DefaultLayout extends StatelessWidget {
  final Widget child;
  const DefaultLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: GradientDecoration.backgroundGradient(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        bottomNavigationBar: const Footer(),
        body: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          padding: EdgeInsets.fromLTRB(0, 20, 0, 0),
          child: Center(child: child),
        ),
      ),
    );
  }
}
