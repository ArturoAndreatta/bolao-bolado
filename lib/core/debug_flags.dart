import 'package:flutter/foundation.dart';

/// Flags de debug/dev acionáveis em runtime pelo painel de admin.
///
/// Só refletem para quem abre o Painel ADM (rota protegida por isAdmin), então
/// o estado não vaza para usuários comuns. Não persiste entre sessões: ao
/// recarregar o app, volta ao padrão.

/// Quando `true`, força o skeleton loading das telas Minha Aposta,
/// Participantes e Chat a ficar travado (nunca sai do estado de loading).
/// Alternável pelo switch "Forçar skeleton" no Painel ADM.
final ValueNotifier<bool> forcarSkeletonGlobal = ValueNotifier(false);
