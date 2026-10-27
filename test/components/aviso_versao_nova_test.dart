import 'dart:async';

import 'package:bolao_bolado/components/shell/aviso_versao_nova.dart';
import 'package:bolao_bolado/core/app_tema.dart';
import 'package:bolao_bolado/core/atualizacao_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz o papel do service worker: diz o que já tinha acontecido antes de o
/// aviso nascer, e avisa quando a versão nova é achada e quando fica pronta.
class _PonteFalsa implements PonteAtualizacao {
  _PonteFalsa({this.encontradaNoInicio = false, this.prontaNoInicio = false});

  final bool encontradaNoInicio;
  final bool prontaNoInicio;
  final _encontrou = StreamController<void>.broadcast();
  final _ficouPronta = StreamController<void>.broadcast();
  int recargas = 0;

  void descobrir() => _encontrou.add(null);
  void publicar() => _ficouPronta.add(null);

  @override
  bool get suportado => true;

  @override
  bool get encontrada => encontradaNoInicio;

  @override
  bool get pronta => prontaNoInicio;

  @override
  Stream<void> get aoEncontrar => _encontrou.stream;

  @override
  Stream<void> get aoFicarPronta => _ficouPronta.stream;

  @override
  void recarregar() => recargas++;
}

const _titulo = 'Versão nova!';
const _botao = 'Atualizar agora';

Future<void> _montar(WidgetTester tester, _PonteFalsa ponte) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTema.claro(),
      builder: (context, child) => AvisoVersaoNova(ponte: ponte, child: child!),
      home: const Scaffold(),
    ),
  );
  await _assentar(tester);
}

/// Não é `pumpAndSettle`: com o download em curso o botão gira sem parar, e a
/// tela nunca assenta.
Future<void> _assentar(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('sem versão nova, nada aparece', (tester) async {
    await _montar(tester, _PonteFalsa());
    expect(find.text(_titulo), findsNothing);
  });

  testWidgets('descoberta abre na hora, com o botão esperando', (tester) async {
    final ponte = _PonteFalsa();
    await _montar(tester, ponte);

    ponte.descobrir();
    await _assentar(tester);
    expect(find.text(_titulo), findsOneWidget);
    expect(find.text(_botao), findsNothing);

    ponte.publicar();
    await _assentar(tester);
    await tester.tap(find.text(_botao));
    await tester.pump();
    expect(ponte.recargas, 1);
  });

  testWidgets('download que não termina libera o botão depois da espera', (
    tester,
  ) async {
    final ponte = _PonteFalsa(encontradaNoInicio: true);
    await _montar(tester, ponte);
    expect(find.text(_botao), findsNothing);

    await tester.pump(kPacienciaDownloadVersao);
    await _assentar(tester);
    await tester.tap(find.text(_botao));
    await tester.pump();
    expect(ponte.recargas, 1);
  });

  testWidgets('versão pronta antes do widget existir já abre liberada', (
    tester,
  ) async {
    final ponte = _PonteFalsa(prontaNoInicio: true);
    await _montar(tester, ponte);

    await tester.tap(find.text(_botao));
    await tester.pump();
    expect(ponte.recargas, 1);
  });

  testWidgets('sem saída: tocar fora não fecha', (tester) async {
    await _montar(tester, _PonteFalsa(prontaNoInicio: true));

    await tester.tapAt(const Offset(4, 4));
    await _assentar(tester);
    expect(find.text(_titulo), findsOneWidget);
  });
}
