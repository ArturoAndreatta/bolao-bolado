import 'package:bolao_bolado/components/shared/custom_card.dart';
import 'package:bolao_bolado/components/shared/header_paginas.dart';
import 'package:flutter/material.dart';

/// Padrão de card usado em toda tela do Bolão Bolado: um CustomCard externo
/// com HeaderPaginas + um CustomCard(isChild: true) interno para o conteúdo.
/// Substitui a montagem manual desse par (CustomCard dentro de CustomCard)
/// espalhada pelas páginas, evitando divergências de padding/altura entre
/// cards que precisam ficar alinhados lado a lado.
class HeaderCard extends StatelessWidget {
  final String text;
  final String subtitle;
  final Widget? trailing;
  final bool showBackButton;
  final VoidCallback? onBack;
  final bool mostrarCabecalho;

  final List<Widget> children;
  final Color color;
  final double maxWidth;
  final double? height;

  // Quando true, este widget renderiza só o CustomCard(isChild: true)
  // interno, sem o CustomCard externo nem o header — usado quando um card
  // externo com header já foi montado por um widget pai (ex: um header que
  // cobre vários cards filhos lado a lado, como Participantes + Chat).
  final bool apenasCardFilho;

  // Quando true, renderiza só os `children` (sem nenhum CustomCard, nem
  // header) — usado quando este conteúdo já vai ocupar uma "fatia" de um
  // CustomCard(isChild: true) montado por um widget pai (ex: Participantes
  // dividindo o card-filho com o Chat lado a lado).
  final bool apenasConteudo;

  // Repassado ao CustomCard externo: zera o arredondamento do canto superior
  // esquerdo/direito individualmente, quando esse lado do card encosta em
  // algo acima (ex: aba ativa do FicharioAbas, quando ela é a primeira/
  // última da fileira e por isso encosta na borda lateral do card).
  final bool cantoSuperiorEsquerdoReto;
  final bool cantoSuperiorDireitoReto;
  // Repassado ao CustomCard externo: faz o card ocupar toda a largura
  // disponível do pai (até maxWidth), em vez de encolher para o conteúdo.
  final bool esticarLargura;
  // Repassado ao CustomCard externo: margem extra lateral/inferior que
  // revela a cor de fundo por trás (faixa do pill cinza no fichário).
  final double margemFichario;

  const HeaderCard({
    super.key,
    required this.text,
    required this.subtitle,
    required this.children,
    this.trailing,
    this.showBackButton = true,
    this.onBack,
    this.mostrarCabecalho = true,
    this.color = const Color(0xFFF3F1EF),
    this.maxWidth = 730,
    this.height,
    this.apenasCardFilho = false,
    this.apenasConteudo = false,
    this.cantoSuperiorEsquerdoReto = false,
    this.cantoSuperiorDireitoReto = false,
    this.esticarLargura = false,
    this.margemFichario = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (apenasConteudo) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }

    final cardFilho = CustomCard(
      isChild: true,
      height: height,
      maxWidth: maxWidth,
      children: children,
    );

    if (apenasCardFilho) return cardFilho;

    return CustomCard(
      color: color,
      maxWidth: maxWidth,
      cantoSuperiorEsquerdoReto: cantoSuperiorEsquerdoReto,
      cantoSuperiorDireitoReto: cantoSuperiorDireitoReto,
      esticarLargura: esticarLargura,
      margemFichario: margemFichario,
      children: [
        if (mostrarCabecalho)
          HeaderPaginas(
            text: text,
            subtitle: subtitle,
            trailing: trailing,
            showBackButton: showBackButton,
            onBack: onBack,
          ),
        cardFilho,
      ],
    );
  }
}
