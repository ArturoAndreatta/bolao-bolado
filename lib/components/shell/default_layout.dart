import 'package:bolao_bolado/components/shell/footer.dart';
import 'package:bolao_bolado/components/shell/gradient_decoration.dart';
import 'package:bolao_bolado/core/responsive.dart';
import 'package:flutter/material.dart';

class DefaultLayout extends StatelessWidget {
  final Widget child;
  final Widget? drawer;
  final void Function(bool isOpened)? onDrawerChanged;
  final bool showLogo;
  const DefaultLayout({
    super.key,
    required this.child,
    this.drawer,
    this.onDrawerChanged,
    this.showLogo = true,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Container(
      decoration: GradientDecoration.backgroundGradient(),
      child: Scaffold(
        drawer: drawer,
        onDrawerChanged: onDrawerChanged,
        backgroundColor: Colors.transparent,
        // Footer só aparece em telas maiores; no mobile o espaço é escasso
        // e o rodapé atrapalharia o conteúdo principal.
        bottomNavigationBar: isMobile ? null : const Footer(),
        appBar: drawer != null
            ? AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
                automaticallyImplyLeading: true,
                iconTheme: const IconThemeData(color: Color(0xFF1F2937)),
                centerTitle: true,
                title: showLogo
                    ? SizedBox(
                        height: 50,
                        child: Image.asset(
                          'images/logo4.png',
                          fit: BoxFit.contain,
                        ),
                      )
                    : null,
              )
            : null,
        body: Stack(
          children: [
            SingleChildScrollView(
              child: Center(child: Column(children: [child])),
            ),
          ],
        ),
      ),
    );
  }
}
