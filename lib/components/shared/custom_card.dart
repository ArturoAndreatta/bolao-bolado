import 'package:flutter/material.dart';

class CustomCard extends StatelessWidget {
  final List<Widget> children;
  final Color? color;
  final bool? isChild;

  const CustomCard({
    super.key,
    required this.children,
    this.color = const Color(0xFFFEFEFE),
    this.isChild = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 730),
        child: Card(
          elevation: isChild! ? 3 : 20,
          color: color,
          child: Padding(
            padding: isChild!
                ? EdgeInsets.fromLTRB(10, 0, 10, 0)
                : EdgeInsets.zero,
            child: SizedBox(width: 715, child: Column(children: children)),
          ),
        ),
      ),
    );
  }
}
