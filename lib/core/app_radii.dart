import 'package:flutter/material.dart';

// Raios de borda padronizados do app. Os valores refletem os que já eram
// usados de forma repetida (e inconsistente) em Container/InputDecoration
// espalhados pelo código antes desta constante existir.
class AppRadii {
  static const double xs = 2;
  static const double sm = 8;
  static const double smd = 10;
  static const double md = 12;
  static const double lg = 14;
  static const double xl = 15;
  static const double xxl = 18;
  static const double pill = 20;
  static const double circle = 999;

  static BorderRadius circularXs = BorderRadius.circular(xs);
  static BorderRadius circularSm = BorderRadius.circular(sm);
  static BorderRadius circularSmd = BorderRadius.circular(smd);
  static BorderRadius circularMd = BorderRadius.circular(md);
  static BorderRadius circularLg = BorderRadius.circular(lg);
  static BorderRadius circularXl = BorderRadius.circular(xl);
  static BorderRadius circularXxl = BorderRadius.circular(xxl);
  static BorderRadius circularPill = BorderRadius.circular(pill);
  static BorderRadius circularCircle = BorderRadius.circular(circle);
}
