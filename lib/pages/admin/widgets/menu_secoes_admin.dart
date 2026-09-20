import 'package:bolao_bolado/core/app_radii.dart';
import 'package:bolao_bolado/pages/admin/admin_abas.dart';
import 'package:bolao_bolado/pages/admin/widgets/admin_widgets.dart';
import 'package:flutter/material.dart';

/// Menu lateral e cabeçalho de seção do Painel ADM no desktop — as duas peças
/// que dizem "você está aqui" no layout de uma seção por vez.
///
/// Ficam fora de painel_admin.dart porque não dependem de nada do estado do
/// painel: recebem a seção ativa e devolvem a escolhida.

/// Cor de cada seção do painel. Cada uma tem a sua e um porquê: verde-água
/// para participantes (o tom "de gente" do gradiente do app), dourado para
/// ranking (prêmio/pódio), roxo para sala (administrativo, deliberadamente
/// fora da paleta operacional das outras), coral para configurações (quente
/// como o vermelho de alerta, mas sem ser ele — configuração não é erro) e
/// azul para o resumo, que é o neutro.
///
/// Hoje ela aparece em pouca coisa: o ícone e o traço de 3px do item ativo no
/// menu, e o ícone do cabeçalho da seção. Já foi a barra colorida inteira do
/// cabeçalho de cada card, com os quatro tons visíveis ao mesmo tempo — é o
/// que fazia o painel parecer letreiro.
Color corDaSecao(AdminCores cores, AbaAdmin aba) => switch (aba) {
  AbaAdmin.visaoGeral => cores.azul,
  AbaAdmin.participantes => cores.verdeAgua,
  AbaAdmin.ranking => cores.dourado,
  AbaAdmin.sala => cores.roxo,
  AbaAdmin.config => cores.coral,
};

/// Coluna de seções do painel (desktop), na ordem de [kAbasAdmin].
class MenuSecoesAdmin extends StatelessWidget {
  final AbaAdmin ativa;

  /// Apostas esperando verificação — vira um selo no item de Participantes,
  /// que é onde a pendência se resolve. É um atalho, não um aviso solto.
  final int pendentes;

  final ValueChanged<AbaAdmin> onSelecionar;

  const MenuSecoesAdmin({
    super.key,
    required this.ativa,
    required this.pendentes,
    required this.onSelecionar,
  });

  @override
  Widget build(BuildContext context) {
    final cores = AdminCores.de(context);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cores.fundoSecao,
        borderRadius: AppRadii.circularLg,
        border: Border.all(color: cores.borda),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < kAbasAdmin.length; i++) ...[
            if (i > 0) const SizedBox(height: 6),
            _ItemMenu(
              meta: kAbasAdmin[i],
              cor: corDaSecao(cores, kAbasAdmin[i].aba),
              ativo: kAbasAdmin[i].aba == ativa,
              pendentes: kAbasAdmin[i].aba == AbaAdmin.participantes
                  ? pendentes
                  : 0,
              onTap: () => onSelecionar(kAbasAdmin[i].aba),
            ),
          ],
        ],
      ),
    );
  }
}

/// Item do menu lateral.
///
/// O estado ativo não é só a cor do texto: é o fundo tingido MAIS o traço de
/// 3px na borda esquerda. Só a cor do texto some quando a pessoa não está
/// olhando direto para o menu, e o traço é o que se enxerga de canto de olho —
/// é o mesmo recurso que a tabela de apostas usa para estado de linha no tema
/// escuro (ver larguraBarraEstado em AppCores).
class _ItemMenu extends StatelessWidget {
  final AbaAdminMeta meta;
  final Color cor;
  final bool ativo;
  final int pendentes;
  final VoidCallback onTap;

  const _ItemMenu({
    required this.meta,
    required this.cor,
    required this.ativo,
    required this.pendentes,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cores = AdminCores.de(context);
    return Material(
      // alphaBlend a 22% (e não os `fundo*` da paleta): é a mesma faixa da aba
      // ativa do Fichario, onde tingir a superfície funciona nos dois temas.
      color: ativo
          ? Color.alphaBlend(cor.withValues(alpha: 0.22), cores.fundoCard)
          : Colors.transparent,
      borderRadius: AppRadii.circularSmd,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.circularSmd,
        hoverColor: cores.fundoTile,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              // Sempre ocupa o mesmo espaço, pintado ou não: um traço que
              // aparece e some empurraria o rótulo 12px para o lado a cada
              // troca de seção.
              Container(
                width: 3,
                height: 22,
                decoration: BoxDecoration(
                  color: ativo ? cor : Colors.transparent,
                  borderRadius: AppRadii.circularXs,
                ),
              ),
              const SizedBox(width: 9),
              Icon(meta.icone, size: 19, color: ativo ? cor : cores.textoSuave),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  meta.texto,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: ativo ? FontWeight.w700 : FontWeight.w600,
                    color: ativo ? cores.texto : cores.textoSuave,
                  ),
                ),
              ),
              if (pendentes > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    // Escurecida no tema escuro para o branco continuar
                    // legível — ver [AdminCores.barraDeSecao].
                    color: cores.barraDeSecao(cores.vermelho),
                    borderRadius: AppRadii.circularPill,
                  ),
                  child: Text(
                    '$pendentes',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Cabeçalho do painel de conteúdo: ícone na cor da seção + título + a linha
/// que diz o que dá pra fazer ali ([AbaAdminMeta.descricao]).
class CabecalhoSecaoAdmin extends StatelessWidget {
  final AbaAdminMeta meta;

  /// Ação da seção ativa (ex: copiar a planilha, no Ranking). Fica aqui, e
  /// não dentro da seção, para não gastar uma linha da altura útil da lista.
  final Widget? acao;

  const CabecalhoSecaoAdmin({super.key, required this.meta, this.acao});

  @override
  Widget build(BuildContext context) {
    final cores = AdminCores.de(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
      child: Row(
        children: [
          Icon(meta.icone, size: 20, color: corDaSecao(cores, meta.aba)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  meta.texto,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                    color: cores.texto,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  meta.descricao,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.2,
                    color: cores.textoSuave,
                  ),
                ),
              ],
            ),
          ),
          if (acao != null) acao!,
        ],
      ),
    );
  }
}
