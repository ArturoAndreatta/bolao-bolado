// Ponte entre o gerenciador de senhas do navegador e os campos de login.
//
// Por que isso existe: o `AutofillGroup` + `autofillHints` faz o Flutter web
// criar um `<form>` de verdade no DOM, com `autocomplete="username"` e
// `current-password`, e é assim que o gerenciador enxerga o login. Só que
// gerenciadores que abrem a lista de credenciais numa JANELA À PARTE — o
// Chaveiro do iCloud é o caso — tiram o foco da página no momento do clique.
// O Flutter trata a perda de foco como fim da sessão de edição: desliga os
// ouvintes e deixa o form no DOM apenas como sobra (todos os campos com
// tamanho zero). A extensão então escreve os valores nessa sobra, e nada chega
// ao app — na tela os campos continuam vazios.
//
// Os valores ficam lá, legíveis. Esta ponte vigia esses inputs e devolve o que
// aparecer, para a tela de login copiar nos seus controllers.
//
// Só faz sentido na web; nas outras plataformas o autofill do sistema entrega o
// texto pelo caminho normal do Flutter, então a implementação é vazia.
//
// Isso é remendo de bug do próprio Flutter, não do app: flutter/flutter#174773
// (aberto, P1, ainda reproduzível na 3.41.x — aqui rodamos a 3.38.5). Nenhum
// pacote do pub cobre o caso: `password_credential` usa outra API
// (navigator.credentials, só Chrome) e está sem manutenção. Quando a correção
// oficial sair, esta ponte inteira pode ser apagada — o `AutofillGroup` e os
// `autofillHints` das telas continuam valendo, são eles que fazem o navegador
// reconhecer o login.
export 'autofill_navegador_stub.dart'
    if (dart.library.js_interop) 'autofill_navegador_web.dart';
