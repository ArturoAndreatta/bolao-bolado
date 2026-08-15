/// Emojis de reação do chat: o que a barra rápida oferece, o catálogo completo
/// do seletor e a validação que decide se uma string é reação aceitável.
///
/// Antes a reação era uma lista fechada de seis emojis, validada por
/// pertinência tanto aqui quanto em `firestore.rules`. A lista caiu: reagir
/// com qualquer emoji é o comportamento que as pessoas já esperam de um chat,
/// e travar em seis fazia a reação parecer quebrada ("cadê o 🤡?").
///
/// O motivo original da lista fechada continua válido, porém: a regra do
/// Firestore não sabe dizer "isto é um emoji", e um campo de texto livre no
/// lugar dela viraria um segundo canal de recado sem moderação. A troca é de
/// lista por FORMATO — vale qualquer string curta feita só de caracteres de
/// emoji. Quem garante isso são duas camadas com critérios diferentes:
///
/// - aqui, [ehEmojiReacao] exige que cada rune caia numa faixa de emoji
///   conhecida (ver [_faixasEmoji]);
/// - na regra, que não tem laço nem faixa de rune, o critério é mais grosso:
///   string curta e SEM nenhum caractere ASCII.
///
/// O cliente é o mais restrito de propósito, e é isso que mantém as duas
/// camadas compatíveis: tudo que passa aqui passa lá. O contrário não vale —
/// alguém escrevendo direto no Firestore consegue gravar um punhado de
/// caracteres não-ASCII que não são emoji. O estrago é cosmético (um chip
/// torto embaixo de uma bolha) e some quando a pessoa desfaz a reação.
library;

/// Os emojis da barra que abre no hover/toque longo.
///
/// São só os atalhos: qualquer outro emoji entra pelo botão de "mais" do
/// seletor. Seis é o que cabe numa pílula sem ela virar uma régua no mobile.
const List<String> kReacoesRapidas = ['👍', '🔥', '😂', '😮', '😢', '🎉'];

/// Teto de code units UTF-16 numa reação.
///
/// Uma família (👨‍👩‍👧‍👦) gasta 11 code units entre os quatro emojis e os ZWJ, e é
/// o caso legítimo mais longo que existe. 16 dá folga para sequências com tom
/// de pele sem chegar perto de caber texto.
const int kMaximoUnidadesEmoji = 16;

/// Junta emoji a emoji numa sequência (👨‍👩‍👧 é três pessoas com ZWJ no meio).
const int _zwj = 0x200D;

/// Seletores de variação: pedem a forma colorida (FE0F) ou a de texto (FE0E).
const int _seletorVariacaoTexto = 0xFE0E;
const int _seletorVariacaoEmoji = 0xFE0F;

/// Faixas de rune aceitas numa reação, como pares `[início, fim]` inclusivos.
///
/// Não é a tabela Unicode de emoji inteira — é o que o catálogo usa mais uma
/// margem. Faixa de menos só impede um emoji de ser aceito; faixa demais
/// deixaria passar letra de alfabeto não-latino, que é justamente o que a
/// checagem existe para barrar.
const List<List<int>> _faixasEmoji = [
  [0x00A9, 0x00A9], // ©
  [0x00AE, 0x00AE], // ®
  [0x203C, 0x2049], // ‼ ⁉
  [0x2122, 0x2122], // ™
  [0x2190, 0x21FF], // setas
  [0x2300, 0x23FF], // ⌚ ⏰ ⏳ e controles de mídia
  [0x25A0, 0x25FF], // formas geométricas (▶ ◀ ◼)
  [0x2600, 0x27BF], // ☀ ☂ ★ ✅ ❤ ➡ — o grosso dos símbolos
  [0x2934, 0x2935], // ⤴ ⤵
  [0x2B00, 0x2BFF], // ⬅ ⬆ ⭐ ⭕
  [0x3030, 0x3030], // 〰
  [0x303D, 0x303D], // 〽
  [0x3297, 0x3299], // ㊗ ㊙
  [0x1F000, 0x1F02F], // mahjong
  [0x1F0A0, 0x1F0FF], // cartas
  [
    0x1F100,
    0x1F1FF,
  ], // fechados em quadrado + indicadores regionais (bandeiras)
  [0x1F200, 0x1F2FF], // ideogramas fechados
  [0x1F300, 0x1FAFF], // o bloco principal de emoji, tons de pele inclusos
];

/// A string é uma reação aceitável?
///
/// Rejeita vazio, sequência longa demais e qualquer rune fora das faixas de
/// emoji. Note que emoji de teclinha (1️⃣, #️⃣) NÃO passa: ele começa com um
/// caractere ASCII, e a regra do Firestore barra ASCII sem exceção. Deixar o
/// cliente aceitar o que o servidor recusa só produziria reação que some
/// sozinha, então ele também recusa — e o catálogo não oferece nenhum.
bool ehEmojiReacao(String valor) {
  if (valor.isEmpty) return false;
  if (valor.length > kMaximoUnidadesEmoji) return false;

  var temEmojiDeVerdade = false;
  for (final rune in valor.runes) {
    if (rune == _zwj ||
        rune == _seletorVariacaoEmoji ||
        rune == _seletorVariacaoTexto) {
      // Sozinhos não formam nada, então não contam como "emoji de verdade" —
      // só acompanham. Uma string feita só de ZWJ é invisível na tela e cairia
      // como chip fantasma.
      continue;
    }
    if (!_emFaixaDeEmoji(rune)) return false;
    temEmojiDeVerdade = true;
  }
  return temEmojiDeVerdade;
}

bool _emFaixaDeEmoji(int rune) {
  for (final faixa in _faixasEmoji) {
    if (rune >= faixa[0] && rune <= faixa[1]) return true;
  }
  return false;
}

/// Uma aba do seletor de emoji.
class CategoriaEmoji {
  final String rotulo;

  /// Emoji que representa a categoria na barra de abas.
  final String icone;

  final List<String> emojis;

  CategoriaEmoji({
    required this.rotulo,
    required this.icone,
    required String emojis,
  }) : emojis = emojis.split(' ');
}

/// Catálogo do seletor.
///
/// É lista em código, e não um pacote de emoji: os pacotes prontos trazem
/// fonte própria ou a tabela Unicode inteira, e peso de bundle é exatamente o
/// que este projeto vem cortando (ver a nota do precache do service worker no
/// CLAUDE.md). Aqui o custo é só o texto destas linhas, e quem desenha o emoji
/// é a fonte do sistema — a mesma que já pinta os da barra rápida.
///
/// Cada categoria é UMA STRING separada por espaço, e não uma lista de
/// literais, por causa do `dart format`: lista com vírgula final vira um
/// elemento por linha, e o catálogo ocupava 700 linhas com um emoji em cada.
/// O `split` roda uma vez no carregamento da classe.
///
/// Sem campo de busca de propósito: buscar exigiria um nome por emoji, o que
/// multiplicaria o catálogo por algo entre 3 e 5 sem resolver um problema real
/// numa lista deste tamanho.
///
/// Nada de emoji de teclinha (1️⃣, #️⃣) aqui: ele carrega um caractere ASCII, e
/// a regra do Firestore recusa ASCII — ver [ehEmojiReacao].
final List<CategoriaEmoji> kCatalogoEmoji = [
  CategoriaEmoji(
    rotulo: 'Rostos',
    icone: '😀',
    emojis:
        '😀 😃 😄 😁 😆 😅 🤣 😂 🙂 🙃 😉 😊 😇 🥰 😍 🤩 😘 😗 😚 😙 '
        '😋 😛 😜 🤪 😝 🤑 🤗 🤭 🤫 🤔 🤐 🤨 😐 😑 😶 😏 😒 🙄 😬 😮 '
        '🤥 😌 😔 😪 🤤 😴 😷 🤒 🤕 🤢 🤮 🤧 🥵 🥶 🥴 😵 🤯 🤠 🥳 😎 '
        '🤓 🧐 😕 😟 🙁 😯 😲 😳 🥺 😦 😧 😨 😰 😥 😢 😭 😱 😖 😣 😞 '
        '😓 😩 😫 🥱 😤 😡 😠 🤬 😈 👿 💀 ☠️ 💩 🤡 👻 👽 🤖 🎃',
  ),
  CategoriaEmoji(
    rotulo: 'Gestos',
    icone: '👍',
    emojis:
        '👍 👎 👌 🤌 🤏 ✌️ 🤞 🫰 🤟 🤘 🤙 👈 👉 👆 👇 ☝️ ✋ 🤚 🖐️ 🖖 '
        '👋 🤝 🙏 ✍️ 💅 🤳 💪 🦾 👏 🙌 👐 🤲 🫡 🫶 ✊ 👊 🤛 🤜 🖕 🫵',
  ),
  CategoriaEmoji(
    rotulo: 'Coração',
    icone: '❤️',
    emojis:
        '❤️ 🧡 💛 💚 💙 💜 🤎 🖤 🤍 💔 ❣️ 💕 💞 💓 💗 💖 💘 💝 💟 ♥️ '
        '😻 😍 🥰 😘 💋 🫂 💐 🌹 🌷 👑',
  ),
  CategoriaEmoji(
    rotulo: 'Bichos',
    icone: '🐶',
    emojis:
        '🐶 🐱 🐭 🐹 🐰 🦊 🐻 🐼 🐨 🐯 🦁 🐮 🐷 🐸 🐵 🙈 🙉 🙊 🐔 🐧 '
        '🐦 🐤 🦆 🦅 🦉 🦇 🐺 🐗 🐴 🦄 🐝 🐛 🦋 🐌 🐞 🐜 🕷️ 🦂 🐢 🐍 '
        '🦎 🐙 🦑 🦐 🦞 🦀 🐠 🐟 🐬 🐳 🐋 🦈 🐊 🐅 🦓 🦍 🐘 🦏 🐫 🦒 '
        '🐁 🐇 🐿️ 🦔 🐾 🌵 🌲 🌳 🌴 🌱 🍀 🍁 🍄 🌾 🌺 🌻 🌼 🌸 🌍 🌙 '
        '⭐ 🌟 ✨ ⚡ 🔥 🌈 ☀️ ⛅ ☁️ ❄️',
  ),
  CategoriaEmoji(
    rotulo: 'Comida',
    icone: '🍔',
    emojis:
        '🍏 🍎 🍐 🍊 🍋 🍌 🍉 🍇 🍓 🫐 🍈 🍒 🍑 🥭 🍍 🥥 🥝 🍅 🥑 🍆 '
        '🥔 🥕 🌽 🌶️ 🥒 🥬 🥦 🧄 🧅 🍞 🥐 🥖 🥨 🧀 🥚 🍳 🧈 🥞 🧇 🥓 '
        '🍔 🍟 🍕 🌭 🥪 🌮 🌯 🥙 🧆 🥘 🍝 🍜 🍲 🍛 🍣 🍱 🥟 🍤 🍚 🍙 '
        '🍦 🍩 🍪 🎂 🍰 🧁 🥧 🍫 🍬 🍭 🍿 🧂 ☕ 🍵 🧃 🥤 🍺 🍻 🥂 🍷 '
        '🥃 🍸 🍹 🧉 🍾 🧊',
  ),
  CategoriaEmoji(
    rotulo: 'Festa',
    icone: '🎉',
    emojis:
        '🎉 🎊 🎈 🎁 🎀 🥳 🍾 🎆 🎇 🧨 ✨ 🎏 🎐 🎑 🎃 🎄 🎅 🤶 🔔 🕯️ '
        '⚽ 🏀 🏈 ⚾ 🎾 🏐 🏉 🎱 🏓 🏸 🥅 ⛳ 🏹 🎣 🥊 🥋 🎽 ⛸️ 🎿 🛷 '
        '🏆 🥇 🥈 🥉 🏅 🎖️ 🎗️ 🎫 🎟️ 🎪 🎭 🎨 🎬 🎤 🎧 🎼 🎵 🎶 🎹 🥁 '
        '🎷 🎺 🎸 🪕 🎻 🎲 🎯 🎳 🎮 🕹️ 🃏 🀄 🎴 🧩',
  ),
  CategoriaEmoji(
    rotulo: 'Grana',
    icone: '💰',
    emojis:
        '💰 💸 💵 💴 💶 💷 🪙 💳 🧾 💎 ⚖️ 🏦 🏧 💹 📈 📉 📊 🤑 🫰 🎰 '
        '🎲 🍀 🔮 🧿 🪄 🎯 🥂 🏆 👑 💍',
  ),
  CategoriaEmoji(
    rotulo: 'Símbolos',
    icone: '✅',
    emojis:
        '✅ ❌ ⭕ ❗ ❓ ⚠️ 🚫 💯 🔝 🆗 🆒 🆕 🔥 💥 💫 💦 💨 🕳️ 💣 🗯️ '
        '💬 💭 🔊 📢 📣 ⏰ ⌛ ⏳ 📌 📍 🔒 🔓 🔑 🔨 🛠️ ⚙️ 🧰 🔗 📎 ✂️ '
        '📝 📄 📅 📆 🗓️ 📋 📁 🗑️ 💡 🔋 📱 💻 ⌨️ 🖥️ 🖨️ 📷 📺 📻 ☎️ 📞 '
        '➡️ ⬅️ ⬆️ ⬇️ 🔄 🔃 ▶️ ⏸️ ⏹️ ⏺️ ♻️ ⚜️ 🔱 ⚫ ⚪ 🔴 🟠 🟡 🟢 🔵 '
        '🟣 🟤 🟥 🟧 🟨 🟩 🟦 🟪 ⬛ ⬜',
  ),
];
