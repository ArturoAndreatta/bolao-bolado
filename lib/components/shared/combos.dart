import 'package:bolao_bolado/components/shared/custom_field_decoration.dart';
import 'package:bolao_bolado/core/app_cores.dart';
import 'package:bolao_bolado/core/app_radii.dart';
import 'package:flutter/material.dart';

/// Uma opção de qualquer um dos dois combos deste arquivo.
///
/// [cor] só faz sentido quando a opção representa um ESTADO (pendente,
/// verificado): aí ela pinta o disco, o rótulo e a casca inteira do
/// [ComboFiltro]. Opção que é só um campo de ordenação ou um tipo de sorteio
/// não tem cor própria e cai no azul da paleta.
@immutable
class OpcaoCombo<T> {
  final T valor;
  final String rotulo;
  final Color? cor;

  const OpcaoCombo(this.valor, this.rotulo, {this.cor});
}

/// Peças do menu suspenso, compartilhadas por [ComboFiltro] e [ComboCampo].
///
/// Os dois combos têm cascas diferentes de propósito (um é chip de filtro, o
/// outro é campo de formulário), mas o menu que abre é o MESMO: mesma borda,
/// mesmo fundo, disco de cor à esquerda e check na opção ativa. Antes de isso
/// existir, cada dropdown do app desenhava o seu — e o do cadastro de sala não
/// marcava a opção selecionada de forma nenhuma.
class _MenuCombo {
  /// `PopupMenuButton` sempre abre logo abaixo do botão quando recebe offset —
  /// diferente do `DropdownButton`, que alinha o ITEM SELECIONADO com o campo
  /// e joga o menu pra cima quando a opção marcada não é a primeira da lista.
  /// É por isso que os dois combos aqui são construídos sobre ele.
  static Offset offsetAbaixoDe(double altura) => Offset(0, altura + 6);

  /// Menu flutua ACIMA de tudo, então no escuro ele precisa ser a superfície
  /// mais clara da cena — lá a profundidade vem da luminosidade, e sombra
  /// quase não aparece. No claro o branco do card já se destaca do fundo, e
  /// `superficieAlta` (um cinza) deixaria o menu com cara de desabilitado.
  static Color fundo(AppCores cores) =>
      cores.escuro ? cores.superficieAlta : cores.card;

  /// Borda explícita: no escuro o menu e o card ficam a poucos pontos de L\*
  /// de distância e, sem ela, o menu não tem recorte nenhum contra o que está
  /// atrás. O `popupMenuTheme` de [AppTema] não a define porque vale para
  /// qualquer menu do Material, inclusive os de uma linha só.
  static RoundedRectangleBorder forma(AppCores cores) => RoundedRectangleBorder(
    borderRadius: AppRadii.circularSmd,
    side: BorderSide(color: cores.borda),
  );

  static List<PopupMenuEntry<T>> itens<T>({
    required AppCores cores,
    required List<OpcaoCombo<T>> opcoes,
    required T? selecionado,
    required double alturaItem,
  }) => [
    for (final opcao in opcoes)
      PopupMenuItem<T>(
        value: opcao.valor,
        height: alturaItem,
        child: Row(
          children: [
            if (opcao.cor != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: opcao.cor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                opcao.rotulo,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: opcao.valor == selecionado
                      ? (opcao.cor ?? cores.azul)
                      : cores.texto,
                ),
              ),
            ),
            if (opcao.valor == selecionado)
              Icon(Icons.check, size: 16, color: opcao.cor ?? cores.azul),
          ],
        ),
      ),
  ];
}

/// Combo de FILTRO: casca compacta que mostra a opção ativa e abre o menu
/// padrão. É o formato usado no card de Participantes do painel admin, agora
/// compartilhado — para filtro de estado, campo de ordenação e qualquer
/// escolha que não faça parte de um formulário (para essas, ver [ComboCampo]).
///
/// Quando a opção ativa tem [OpcaoCombo.cor], a casca inteira se tinge dela:
/// o filtro passa a dizer qual estado está selecionado antes de a pessoa ler
/// o texto. Sem cor, a casca fica neutra (fundo de campo, rótulo azul), que é
/// o certo para escolhas que não são estado — pintar "ordenar por Nome" de
/// azul-forte sugeriria um filtro ativo onde não há nenhum.
class ComboFiltro<T> extends StatelessWidget {
  final T selecionado;
  final List<OpcaoCombo<T>> opcoes;
  final ValueChanged<T> onSelecionar;
  final double altura;

  /// `true`: o rótulo ocupa a largura disponível e o menu nasce com a largura
  /// da casca. `false`: a casca encolhe até o conteúdo e o menu ganha uma
  /// largura mínima, senão ele muda de tamanho conforme a opção marcada (o
  /// check só aparece na ativa, e o rótulo mais comprido não é sempre o mesmo).
  final bool expandido;

  const ComboFiltro({
    super.key,
    required this.selecionado,
    required this.opcoes,
    required this.onSelecionar,
    this.altura = 36,
    this.expandido = true,
  });

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    final opcaoAtual = opcoes.firstWhere(
      (o) => o.valor == selecionado,
      orElse: () => opcoes.first,
    );
    final corAtual = opcaoAtual.cor;
    // Sem cor de estado, o azul fica só no texto/ícone e o fundo continua
    // sendo o de um campo: no claro o card (o campo branco já é o mais claro
    // dali), no escuro o tom de campo, que recua em vez de saltar.
    final corRotulo = corAtual ?? cores.azul;

    return LayoutBuilder(
      builder: (context, restricoes) => PopupMenuButton<T>(
        initialValue: selecionado,
        onSelected: onSelecionar,
        offset: _MenuCombo.offsetAbaixoDe(altura),
        // Zero: a altura visível do combo é só [altura], para ele alinhar com
        // os campos vizinhos da mesma linha. O default do PopupMenuButton
        // (8px em volta) somava 16px invisíveis e esticava a linha.
        padding: EdgeInsets.zero,
        tooltip: '',
        elevation: 6,
        color: _MenuCombo.fundo(cores),
        shape: _MenuCombo.forma(cores),
        constraints: expandido && restricoes.hasBoundedWidth
            ? BoxConstraints.tightFor(width: restricoes.maxWidth)
            : const BoxConstraints(minWidth: 160),
        itemBuilder: (context) => _MenuCombo.itens(
          cores: cores,
          opcoes: opcoes,
          selecionado: selecionado,
          alturaItem: 40,
        ),
        child: Container(
          height: altura,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color:
                corAtual?.withValues(alpha: 0.1) ??
                (cores.escuro ? cores.campo : cores.card),
            borderRadius: AppRadii.circularSmd,
            border: Border.all(
              color: corAtual?.withValues(alpha: 0.35) ?? cores.borda,
            ),
          ),
          child: Row(
            mainAxisSize: expandido ? MainAxisSize.max : MainAxisSize.min,
            children: [
              if (corAtual != null)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: corAtual,
                    shape: BoxShape.circle,
                  ),
                ),
              // Flexible em vez de Expanded: com a casca encolhida ao
              // conteúdo, Expanded pediria largura infinita dentro de um Row
              // sem limite próprio.
              Flexible(
                fit: expandido ? FlexFit.tight : FlexFit.loose,
                child: Text(
                  opcaoAtual.rotulo,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: corRotulo,
                  ),
                ),
              ),
              Icon(Icons.arrow_drop_down, size: 20, color: corRotulo),
            ],
          ),
        ),
      ),
    );
  }
}

/// Combo de FORMULÁRIO: mesma decoração, altura e validação de [CustomField],
/// com o menu padrão de [_MenuCombo] no lugar do dropdown do Material.
///
/// A casca NÃO é a do [ComboFiltro] de propósito: aqui o combo fica numa
/// coluna de campos de texto, e um chip tingido de 36px no meio deles quebraria
/// o alinhamento e a leitura da coluna. O que os dois compartilham é o menu.
///
/// Substituiu o `DropdownButtonFormField2` (pacote `dropdown_button2`), que
/// pintava o menu com uma cor diferente da do campo, sem borda, com sombra
/// preta fixa fora da paleta e sem marca nenhuma na opção selecionada.
class ComboCampo<T> extends StatelessWidget {
  final String hint;
  final IconData? icon;
  final T? valor;
  final List<OpcaoCombo<T>> opcoes;
  final ValueChanged<T> onChanged;
  final double? maxWidth;
  final String? Function(T?)? validator;
  final bool enabled;

  /// Mesma altura do [CustomField] com rótulo flutuante. Fixa porque o menu
  /// abre a partir dela: um valor calculado exigiria medir o campo antes de
  /// montar o offset do menu.
  static const double altura = 56;

  const ComboCampo({
    super.key,
    required this.hint,
    required this.valor,
    required this.opcoes,
    required this.onChanged,
    this.icon,
    this.maxWidth,
    this.validator,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final cores = AppCores.de(context);
    final opcaoAtual = valor == null
        ? null
        : opcoes.where((o) => o.valor == valor).firstOrNull;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth ?? 300),
      child: FormField<T>(
        initialValue: valor,
        validator: validator,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        builder: (estado) {
          // O valor é controlado pelo pai, mas o FormField guarda uma cópia
          // (é ela que o validator recebe). Quando o pai muda o valor por
          // fora — o formulário carregando uma sala existente, por exemplo —
          // a cópia precisa acompanhar, senão o Form valida contra um valor
          // que a tela nem mostra mais. Em post-frame porque didChange chama
          // setState, proibido durante o build.
          if (estado.value != valor) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (estado.mounted) estado.didChange(valor);
            });
          }

          return LayoutBuilder(
            builder: (context, restricoes) => PopupMenuButton<T>(
              enabled: enabled,
              initialValue: valor,
              onSelected: (v) {
                onChanged(v);
                estado.didChange(v);
              },
              offset: _MenuCombo.offsetAbaixoDe(altura),
              // Sem isso o padding default do botão afastaria a decoração das
              // bordas e o campo deixaria de ter a largura dos irmãos.
              padding: EdgeInsets.zero,
              tooltip: '',
              elevation: 6,
              color: _MenuCombo.fundo(cores),
              shape: _MenuCombo.forma(cores),
              // Menu com a largura exata do campo: é o que faz ele ler como
              // continuação do campo em vez de um pop-up solto por cima.
              constraints: restricoes.hasBoundedWidth
                  ? BoxConstraints.tightFor(width: restricoes.maxWidth)
                  : const BoxConstraints(minWidth: 200),
              itemBuilder: (context) => _MenuCombo.itens(
                cores: cores,
                opcoes: opcoes,
                selecionado: valor,
                alturaItem: 48,
              ),
              child: InputDecorator(
                // errorText herda o errorStyle de altura zero da decoração
                // compartilhada: o erro vira só borda vermelha, sem reservar
                // linha de texto (o campo vive em card/dialog que não pode
                // crescer).
                decoration: CustomFieldDecoration.build(
                  context,
                  hint: hint,
                  icon: icon,
                  suffix: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: cores.textoSuave,
                  ),
                ).copyWith(errorText: estado.errorText, enabled: enabled),
                // Enquanto vazio o rótulo fica no centro, fazendo papel de
                // placeholder; com valor escolhido ele sobe, igual ao
                // CustomField.
                isEmpty: opcaoAtual == null,
                child: opcaoAtual == null
                    ? null
                    : Row(
                        children: [
                          if (opcaoAtual.cor != null) ...[
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: opcaoAtual.cor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            child: Text(
                              opcaoAtual.rotulo,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: enabled ? cores.texto : cores.textoFraco,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}
