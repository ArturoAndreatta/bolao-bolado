// Monta o HTML do e-mail de redefinição de senha, seguindo a paleta do
// tema claro do app (AppCores.claro em lib/core/app_cores.dart): o app
// não tem dark mode em e-mail (clientes de e-mail não respeitam o tema do
// app), então o e-mail usa sempre as cores do tema claro.
// O e-mail entra no HTML como texto digitado por quem pediu (o regex da API
// aceita `<` e aspas), e o link vem do Firebase: os dois passam por aqui
// antes de virar HTML, senão dava pra injetar marcação no e-mail enviado.
function escaparHtml(texto) {
  return String(texto)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function montarHtmlRedefinicaoSenha({ nomeApp, email: emailBruto, link: linkBruto }) {
  const email = escaparHtml(emailBruto);
  const link = escaparHtml(linkBruto);
    return `<div style="background-color:#F3F1EF;padding:32px 16px;font-family:Arial,Helvetica,sans-serif;">
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:480px;margin:0 auto;background-color:#FEFEFE;border-radius:16px;overflow:hidden;border:1px solid #E5E7EB;">
          <tr>
                <td style="background:linear-gradient(135deg,#FFE082,#7CC8B5);padding:28px 24px;text-align:center;">
                        <img src="https://bolaobolado-app.web.app/assets/images/logo4.png" alt="${nomeApp}" width="140" style="display:block;margin:0 auto;border-radius:8px;">
                              </td>
                                  </tr>
                                      <tr>
                                            <td style="padding:32px 32px 8px 32px;">
                                                    <p style="margin:0 0 16px 0;font-size:20px;font-weight:bold;color:#1F2937;">Redefinir sua senha</p>
                                                            <p style="margin:0 0 16px 0;font-size:15px;line-height:1.6;color:#1F2937;">
                                                                      Recebemos um pedido para redefinir a senha da sua conta <strong>${email}</strong> no ${nomeApp}.
                                                                              </p>
                                                                                      <p style="margin:0 0 24px 0;font-size:15px;line-height:1.6;color:#1F2937;">
                                                                                                Clique no botão abaixo para escolher uma nova senha:
                                                                                                        </p>
                                                                                                              </td>
                                                                                                                  </tr>
                                                                                                                      <tr>
                                                                                                                            <td style="padding:0 32px 24px 32px;text-align:center;">
                                                                                                                                    <a href="${link}" style="display:inline-block;background-color:#487DE5;color:#FEFEFE;font-size:15px;font-weight:bold;text-decoration:none;padding:14px 32px;border-radius:10px;">Redefinir senha</a>
                                                                                                                                          </td>
                                                                                                                                              </tr>
                                                                                                                                                  <tr>
                                                                                                                                                        <td style="padding:0 32px 32px 32px;">
                                                                                                                                                                <p style="margin:0 0 8px 0;font-size:13px;line-height:1.6;color:#6B7280;">
                                                                                                                                                                          Se o botão não funcionar, copie e cole este link no navegador:
                                                                                                                                                                                  </p>
                                                                                                                                                                                          <p style="margin:0 0 24px 0;font-size:13px;line-height:1.5;word-break:break-all;">
                                                                                                                                                                                                    <a href="${link}" style="color:#487DE5;">${link}</a>
                                                                                                                                                                                                            </p>
                                                                                                                                                                                                                    <p style="margin:0;font-size:13px;line-height:1.6;color:#9CA3AF;">
                                                                                                                                                                                                                              Se você não pediu essa redefinição, pode ignorar este e-mail — sua senha continua a mesma.
                                                                                                                                                                                                                                      </p>
                                                                                                                                                                                                                                            </td>
                                                                                                                                                                                                                                                </tr>
                                                                                                                                                                                                                                                    <tr>
                                                                                                                                                                                                                                                          <td style="padding:16px 32px;background-color:#F3F4F6;text-align:center;">
                                                                                                                                                                                                                                                                  <p style="margin:0;font-size:12px;color:#9CA3AF;">${nomeApp}</p>
                                                                                                                                                                                                                                                                        </td>
                                                                                                                                                                                                                                                                            </tr>
                                                                                                                                                                                                                                                                              </table>
                                                                                                                                                                                                                                                                              </div>`;
}

// E-mail do código de login. Mesma moldura do e-mail de redefinição; o
// código vai em fonte monoespaçada e espaçada, que é o que evita confundir
// dígitos parecidos ao copiar do celular para o computador. O código é
// gerado pelo próprio endpoint (só dígitos), mas passa pelo escape igual.
function montarHtmlCodigoLogin({ nomeApp, email: emailBruto, codigo: codigoBruto, minutos }) {
  const email = escaparHtml(emailBruto);
  const codigo = escaparHtml(codigoBruto);
  return `<div style="background-color:#F3F1EF;padding:32px 16px;font-family:Arial,Helvetica,sans-serif;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:480px;margin:0 auto;background-color:#FEFEFE;border-radius:16px;overflow:hidden;border:1px solid #E5E7EB;">
    <tr>
      <td style="background:linear-gradient(135deg,#FFE082,#7CC8B5);padding:28px 24px;text-align:center;">
        <img src="https://bolaobolado-app.web.app/assets/images/logo4.png" alt="${nomeApp}" width="140" style="display:block;margin:0 auto;border-radius:8px;">
      </td>
    </tr>
    <tr>
      <td style="padding:32px 32px 8px 32px;">
        <p style="margin:0 0 16px 0;font-size:20px;font-weight:bold;color:#1F2937;">Seu código de acesso</p>
        <p style="margin:0 0 24px 0;font-size:15px;line-height:1.6;color:#1F2937;">
          Use o código abaixo para entrar na conta <strong>${email}</strong> no ${nomeApp}:
        </p>
      </td>
    </tr>
    <tr>
      <td style="padding:0 32px 24px 32px;text-align:center;">
        <p style="display:inline-block;margin:0;padding:16px 28px;background-color:#F3F4F6;border-radius:10px;font-family:'Courier New',Courier,monospace;font-size:32px;font-weight:bold;letter-spacing:8px;color:#1F2937;">${codigo}</p>
      </td>
    </tr>
    <tr>
      <td style="padding:0 32px 32px 32px;">
        <p style="margin:0 0 8px 0;font-size:13px;line-height:1.6;color:#6B7280;">
          O código vale por ${minutos} minutos e só pode ser usado uma vez. Não passe ele para ninguém.
        </p>
        <p style="margin:0;font-size:13px;line-height:1.6;color:#9CA3AF;">
          Se você não pediu esse código, pode ignorar este e-mail — ninguém entra na sua conta sem ele.
        </p>
      </td>
    </tr>
    <tr>
      <td style="padding:16px 32px;background-color:#F3F4F6;text-align:center;">
        <p style="margin:0;font-size:12px;color:#9CA3AF;">${nomeApp}</p>
      </td>
    </tr>
  </table>
</div>`;
}

module.exports = { montarHtmlRedefinicaoSenha, montarHtmlCodigoLogin };
