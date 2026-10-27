import 'atualizacao_app_stub.dart'
    if (dart.library.js_interop) 'atualizacao_app_web.dart'
    as plataforma;

/// A ponte entre o service worker e o aviso de versão nova
/// ([AvisoVersaoNova]).
///
/// **Quem descobre a versão nova é o service worker, não o app.** O script do
/// `web/index.html` pede ao navegador que confira o service worker a cada 30s
/// (e ao voltar para a aba); como o `flutter_service_worker.js` traz o hash de
/// cada arquivo do build, todo deploy que muda o app muda o worker, e o
/// navegador percebe sozinho. O app não guarda número de versão nem pergunta
/// nada ao Hosting: seria uma segunda conta do mesmo fato.
///
/// O aviso chega em dois tempos: **descoberta** (o worker novo apareceu,
/// ainda baixando) e **pronto** (baixou e assumiu). O aviso abre na descoberta
/// e o botão espera o pronto.
///
/// Só existe na web. App instalado pela loja atualiza pela loja.
class PonteAtualizacao {
  const PonteAtualizacao();

  /// Se esta plataforma sabe avisar de versão nova.
  bool get suportado => plataforma.suportado;

  /// Se uma versão nova já tinha sido descoberta antes de alguém perguntar.
  ///
  /// O evento pode chegar antes de o widget existir para ouvi-lo: por isso a
  /// marca global, lida ao nascer.
  bool get encontrada => plataforma.encontrada();

  /// Se a versão nova já estava baixada e ativa antes de alguém perguntar.
  bool get pronta => plataforma.pronta();

  /// Avisa quando uma versão nova é descoberta com o app aberto.
  Stream<void> get aoEncontrar => plataforma.aoEncontrar();

  /// Avisa quando a versão nova terminou de baixar e assumiu.
  Stream<void> get aoFicarPronta => plataforma.aoFicarPronta();

  /// Recarrega a página, que sobe na versão nova. Antes do "pronto" também
  /// resolve, só demora mais: no reload o navegador ativa o worker novo antes
  /// de servir.
  void recarregar() => plataforma.recarregar();
}
