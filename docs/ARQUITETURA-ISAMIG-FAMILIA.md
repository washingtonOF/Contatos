# Arquitetura IsaMig Família — implementação incremental

## Produtos

- **Android do dependente:** Flutter, Firebase Auth e Firestore. Comunicação, compartilhamento explícito de localização e uso. O app existente continua disponível enquanto a migração ocorre.
- **Web do responsável:** Flutter Web na rota `/responsavel` (alternativa `/familia`). Lista apenas vínculos confirmados em que o usuário é o primeiro membro, com chat e painel de dados já compartilhados.
- **Administração da plataforma:** separada dos responsáveis. Não conceder acesso automático a mensagens, localização, câmera ou microfone.

## Controle de acesso

O campo `familyProfiles.supervisor` indica o perfil escolhido no cadastro, **não** é prova de tutela, autoridade legal ou privilégio de acesso. A interface web o usa somente para apresentação. Regras do Firestore e vínculo confirmado devem autorizar **cada leitura e escrita**. Nunca liberar acesso por esconder/mostrar widgets.

A interface atual não permite mudar `supervisor` depois da criação (regra em desenvolvimento). Para produção, adicionar fluxo de recuperação/migração de perfis e verificação de responsáveis, sem permitir autoatribuição de privilégios.

## Publicação

A configuração do host deve servir `index.html` nas rotas `/responsavel` e `/familia` (fallback SPA). Não apontar DNS ou substituir o site institucional até testar login, regras, links e chamadas. As rotas web não garantem que a compilação Flutter Web esteja configurada: validar build e deploy em ambiente de homologação.

## Matriz de capacidades

| Recurso | Estado |
| --- | --- |
| Chat e grupos | Código existente; testar Android e web |
| Chamadas Jitsi | Integração existente; testar navegador e Android |
| Localização compartilhada | Código existente, envio autorizado e expiração |
| Relatório de uso | Código existente, envio autorizado e expiração |
| Encontrar aparelho | Somente última localização compartilhada; não equivale a Find My Device |
| Histórico de sites | Não implementado; requer solução explícita, sem coleta oculta |
| Limites/bloqueios | Não implementado; avaliar Android DevicePolicyManager e permissões reais, sem prometer paridade com Family Link |
| Configuração remota | Não implementada; definir comandos permitidos, confirmação e trilha de auditoria |
| Microfone/câmera | Somente em chamadas visíveis e aceitas; nunca ativação remota silenciosa |

## Próximas entregas

1. Testar `flutter analyze`, `flutter test` e builds web/Android em CI.
2. Revisar regras de segurança e emuladores Firebase; validar isolamento entre famílias.
3. Implantar painel web em homologação, com fallback SPA e OAuth configurado.
4. Testar chamadas, consentimento, revogação e relatórios em dois aparelhos.
5. Definir controles Android permitidos e implementar em módulos independentes.
