import 'package:flutter/material.dart';

class GradientDecoration {
  static BoxDecoration backgroundGradient() {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFE082), Color(0xFF7CC8B5)],
        stops: [0.5, 0.9],
      ),
    );
  }
}
