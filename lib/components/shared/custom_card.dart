import 'package:flutter/material.dart';

class CustomCard extends StatelessWidget {
  final List<Widget> children;
  final Color color;
  final bool isChild;
  final double maxWidth;

  const CustomCard({
    super.key,
    required this.children,
    this.color = const Color(0xFFFEFEFE),
    this.isChild = false,
    this.maxWidth = 730,
  });

  @override
  Widget build(BuildContext context) {
    final maxWidthChild = maxWidth - 15;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Card(
          elevation: isChild ? 3 : 20,
          color: color,
          child: Padding(
            padding: isChild
                ? const EdgeInsets.fromLTRB(10, 10, 10, 10)
                : EdgeInsets.zero,
            child: SizedBox(
              width: maxWidthChild,
              child: Column(children: children),
            ),
          ),
        ),
      ),
    );
  }
}
