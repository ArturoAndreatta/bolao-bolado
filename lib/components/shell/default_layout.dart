import 'package:bolao_bolado/components/shell/footer.dart';
import 'package:bolao_bolado/components/shell/gradient_decoration.dart';
import 'package:bolao_bolado/core/responsive.dart';
import 'package:flutter/material.dart';

class DefaultLayout extends StatelessWidget {
  final Widget child;
  final Widget? drawer;
  const DefaultLayout({super.key, required this.child, this.drawer});

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Container(
      decoration: GradientDecoration.backgroundGradient(),
      child: Scaffold(
        drawer: drawer,
        backgroundColor: Colors.transparent,
        bottomNavigationBar: isMobile ? null : const Footer(),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
              child: Center(child: Column(children: [child])),
            ),
            // Positioned(
            //   top: 12,
            //   left: 12,
            //   child: Builder(
            //     builder: (context) => IconButton(
            //       icon: const Icon(Icons.menu, size: 28),
            //       color: Colors.black,
            //       onPressed: () {
            //         Scaffold.of(context).openDrawer();
            //       },
            //     ),
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}
