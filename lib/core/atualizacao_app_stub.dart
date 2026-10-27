/// Fora da web não há service worker para avisar. Ver `PonteAtualizacao`.
library;

const bool suportado = false;

bool encontrada() => false;

bool pronta() => false;

Stream<void> aoEncontrar() => const Stream<void>.empty();

Stream<void> aoFicarPronta() => const Stream<void>.empty();

void recarregar() {}
