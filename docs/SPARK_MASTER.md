# Conecta Master no Spark

O Firebase Spark não hospeda Cloud Functions. Esta versão usa um painel Web informativo e um utilitário local privilegiado. **Não há criação de contas pelo navegador**.

## Configuração local (não colocar segredos no repositório)
1. Use um computador confiável com Node.js e Firebase Admin SDK.
2. Configure Application Default Credentials com uma identidade autorizada no projeto `contatos-6c266`. Em ambientes locais, um arquivo de conta de serviço pode ser necessário; mantenha-o fora do repositório, com permissões restritas, e nunca envie sua chave ao chat.
3. Execute `cd admin-local && npm install`.
4. Para criar conta: `npm run admin -- create pessoa@example.com "Nome Sobrenome"`. A senha temporária é solicitada no terminal (a entrada é visível; evite telas compartilhadas).
5. Para listar: `npm run admin -- list`.
6. Para bloquear: `npm run admin -- disable UID`. Para desbloquear: `npm run admin -- enable UID`.
7. Para conceder Master a uma conta previamente verificada: `npm run admin -- grant-admin UID`. Faça novo login.

## Segurança
- As contas criadas localmente recebem custom claim `managed: true` e podem fazer login sem confirmação de e-mail, mas `emailVerified` permanece false.
- A conta Master precisa ter e-mail verificado antes da promoção.
- O cadastro público continua exigindo verificação de e-mail.
- A senha temporária deve ser trocada pelo usuário. A recuperação por e-mail de uma conta não verificada pode ser inadequada; confirme identidade por outro canal.
- Custom claims só são verificadas no cliente para navegação; qualquer futuro acesso a dados privilegiados deve ser autorizado em Firestore Security Rules e/ou backend confiável.
- Revogar refresh tokens não invalida imediatamente todos os ID tokens já emitidos; considerar o prazo de expiração e validação de revogação.
- Nunca hospedar o utilitário local no GitHub Pages nem executar operações Admin SDK em Flutter.
- O código antigo em `functions/` é legado e **não deve ser implantado no Spark**.
- Não foi configurada auditoria de ações nem proteção antiabuso para cadastro público. Antes de divulgação ampla, implementar controles apropriados.

## Publicação
A branch `feat/master-spark` não está publicada. Valide CI e revise o Pull Request antes de integrar à main.
