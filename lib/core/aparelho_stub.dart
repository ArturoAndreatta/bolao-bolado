import 'package:flutter/foundation.dart';

/// Fora da web o sistema informado pelo Flutter é o do aparelho.
bool get aparelhoMovel =>
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;
