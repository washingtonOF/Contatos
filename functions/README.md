# Backend administrativo Conecta

Esta pasta **não é publicada pelo GitHub Pages**. A implantação exige um projeto Firebase com faturamento habilitado quando necessário para Cloud Functions.

1. Configure o Firebase CLI no projeto correto.
2. Execute `cd functions && npm install`.
3. Configure o projeto e implante as funções `listManagedUsers` e `setManagedUserDisabled` com Firebase CLI.
4. Configure regras Firestore que neguem acesso direto dos clientes à coleção `admin_audit`.
5. Antes de liberar alterações de contas, valide os fluxos de auditoria, permissões e proteção contra abuso.

Todas as chamadas exigem Firebase Auth com e-mail verificado e custom claim admin. A função também verifica o estado atual da conta no Firebase Auth. Nunca use chaves de service account no Flutter ou no GitHub Pages.
