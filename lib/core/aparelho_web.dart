import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

final _userAgentMovel = RegExp(
  r'Android|iPhone|iPad|iPod',
  caseSensitive: false,
);

/// Na web vale o sistema que o Flutter detectou OU o user agent do navegador
/// (ver aparelho.dart). O iPad com iPadOS 13+ se anuncia como Mac; o motor do
/// Flutter já o reconhece como iOS pelos pontos de toque.
bool get aparelhoMovel =>
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS ||
    _userAgentMovel.hasMatch(web.window.navigator.userAgent);
