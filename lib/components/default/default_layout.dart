import 'package:bolao_bolado/components/default/footer.dart';
import 'package:bolao_bolado/components/default/gradient_decoration.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class DefaultLayout extends StatelessWidget {
  final Widget child;
  final Widget? drawer;
  const DefaultLayout({super.key, required this.child, this.drawer});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktopWeb = kIsWeb && width >= 900;

    return Container(
      decoration: GradientDecoration.backgroundGradient(),
      child: Scaffold(
        drawer: drawer,
        backgroundColor: Colors.transparent,
        bottomNavigationBar: isDesktopWeb ? const Footer() : null,
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
              child: Center(child: Column(children: [child])),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu, size: 28),
                  color: Colors.black,
                  onPressed: () {
                    Scaffold.of(context).openDrawer();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
