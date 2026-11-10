# Conecta Master — implantação segura

Esta branch contém código, **não** um painel administrativo publicado.

## Pré-requisitos
- O Firebase Authentication já deve estar habilitado.
- Firebase App Check precisa estar configurado para Web (reCAPTCHA Enterprise) e aplicado às chamadas de Functions.
- Cloud Functions pode exigir o plano Blaze e gerar cobranças. Não ativar cobrança sem autorização.
- Implantar com Firebase CLI em ambiente autorizado: `firebase use contatos-6c266`, `cd functions && npm install && cd ..`, `firebase deploy --only functions`.
- Nunca colocar chave de conta de serviço no GitHub ou no Flutter.

## Conceder o primeiro acesso Master
O painel exige o custom claim `admin: true`, emitido **somente** por um operador confiável usando Firebase Admin SDK em ambiente seguro. O primeiro administrador deve ser uma conta existente escolhida e verificada manualmente. Não há cadastro automático de administradores nem credenciais fixas.

## Segurança e limites
- Todas as operações administrativas exigem token autenticado com custom claim admin.
- App Check é exigido nas chamadas administrativas, mas não substitui autenticação nem autorização.
- Usuários criados pelo Master ficam com `emailVerified: false`; o acesso é liberado sem fingir verificação de titularidade.
- O login normal deve aceitar contas administrativamente criadas mesmo sem e-mail verificado. Cadastro público pode continuar exigindo verificação.
- Antes de liberar ao público: rate limiting por usuário/IP no backend, auditoria de operações, política de senhas, regras Firestore, proteção contra abuso e recuperação de conta.
- O bloqueio de contas não substitui regras de autorização por recurso; validar revogação de sessão conforme risco.
- Não usar credenciais reais de terceiros para testes.

## Estado
Backend preparado; deploy e integração visual dependem de App Check, configuração do primeiro Master e confirmação de custo.
