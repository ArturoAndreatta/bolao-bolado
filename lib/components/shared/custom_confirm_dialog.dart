import 'package:bolao_bolado/core/app_radii.dart';
import 'package:bolao_bolado/core/responsive.dart';
import 'package:flutter/material.dart';

/// Diálogo de confirmação padrão do app (sim/não), irmão do
/// [CustomShowDialog] — que só sabe exibir erro e some sozinho, sem botões,
/// e por isso não servia para confirmar ação nenhuma.
///
/// Existe porque cada confirmação destrutiva do painel admin montava seu
/// próprio `AlertDialog` com `TextButton`s crus: visual do Material padrão,
/// diferente dos botões do resto do app, e o "Remover"/"Apagar tudo" tinha o
/// mesmo peso visual do "Cancelar" — o botão perigoso não se distinguia.
///
/// Devolve `true` só se o usuário confirmar (fechar no barrier devolve
/// `null`, tratado como não confirmado).
class CustomConfirmDialog {
  static Future<bool> show(
    BuildContext context, {
    required String titulo,
    required String mensagem,
    String textoConfirmar = 'Confirmar',
    String textoCancelar = 'Cancelar',

    /// Ações irreversíveis (apagar, remover) pintam o botão de vermelho e
    /// trocam o ícone para o de alerta.
    bool destrutivo = false,
  }) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _CorpoConfirmacao(
        titulo: titulo,
        mensagem: mensagem,
        textoConfirmar: textoConfirmar,
        textoCancelar: textoCancelar,
        destrutivo: destrutivo,
      ),
    );
    return confirmado == true;
  }
}

class _CorpoConfirmacao extends StatelessWidget {
  final String titulo;
  final String mensagem;
  final String textoConfirmar;
  final String textoCancelar;
  final bool destrutivo;

  const _CorpoConfirmacao({
    required this.titulo,
    required this.mensagem,
    required this.textoConfirmar,
    required this.textoCancelar,
    required this.destrutivo,
  });

  @override
  Widget build(BuildContext context) {
    final corAcao = destrutivo
        ? const Color(0xFFEF4444)
        : const Color(0xFF487DE5);

    // Mesma conta do AdminDialogFrame: 340 fixo estoura em celular estreito
    // depois de somado o padding do AlertDialog.
    final larguraTela = MediaQuery.sizeOf(context).width;
    final largura = Responsive.isMobile(context) ? larguraTela - 80 : 340.0;

    return AlertDialog(
      backgroundColor: const Color(0xFFFEFEFE),
      surfaceTintColor: Colors.transparent,
      elevation: 18,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.circularXxl,
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      contentPadding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      content: SizedBox(
        width: largura,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mesmo cabeçalho ícone + título do CustomShowDialog, para as
            // duas caixas lerem como a mesma família.
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: destrutivo
                        ? const Color(0xFFFEE2E2)
                        : const Color(0xFFE0EAFB),
                    borderRadius: AppRadii.circularLg,
                    border: Border.all(
                      color: destrutivo
                          ? const Color(0xFFFECACA)
                          : const Color(0xFFC7DAF7),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      destrutivo ? '⚠️' : '❓',
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              mensagem,
              style: const TextStyle(
                height: 1.35,
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
      actions: [
        Row(
          children: [
            Expanded(
              child: _BotaoContorno(
                texto: textoCancelar,
                cor: const Color(0xFF487DE5),
                onTap: () => Navigator.of(context).pop(false),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _BotaoSolido(
                texto: textoConfirmar,
                cor: corAcao,
                onTap: () => Navigator.of(context).pop(true),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Versão enxuta do PrimaryButton: aceita cor variável (o vermelho das ações
/// destrutivas) e altura menor, proporcional à caixa de confirmação.
class _BotaoSolido extends StatelessWidget {
  final String texto;
  final Color cor;
  final VoidCallback onTap;

  const _BotaoSolido({
    required this.texto,
    required this.cor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: cor,
      borderRadius: AppRadii.circularXl,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 46,
          child: Center(
            child: Text(
              texto,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFFEFEFE),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BotaoContorno extends StatelessWidget {
  final String texto;
  final Color cor;
  final VoidCallback onTap;

  const _BotaoContorno({
    required this.texto,
    required this.cor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: AppRadii.circularXl,
        border: Border.all(color: cor, width: 2),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadii.circularXl,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            // 46 - 2*2 da borda: o contorno soma na altura externa, então sem
            // descontar os dois botões ficavam desalinhados por 4px.
            height: 42,
            child: Center(
              child: Text(
                texto,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
