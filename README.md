# IsaMig Mensagens

IsaMig Mensagens é um protótipo Flutter de comunicação familiar.

A versão Web oferece cadastro e login por e-mail. No Android, o fluxo familiar usa login com e-mail verificado e senha, convite de uso único, busca por número entre familiares vinculados e conversas individuais e grupos com aprovação de entrada.

## Login com Google (branch de desenvolvimento)

A tela de autenticação oferece **Continuar com Google** além de e-mail/senha. No Android, o seletor do Google permite usar uma conta disponível no aparelho; na Web, o Firebase abre a autenticação do provedor Google.

Antes de testar:

1. No Firebase Console do projeto `contatos-6c266`, abra **Authentication > Sign-in method** e habilite o provedor Google, definindo o e-mail de suporte.
2. Em **Project settings > Your apps**, confirme o aplicativo Android `com.washingtonof.conecta_messenger` e cadastre os fingerprints **SHA-1 e SHA-256** do certificado que assina o APK de teste. Se a assinatura mudar entre builds, os fingerprints também precisam ser atualizados.
3. Confira a configuração OAuth do Android e a autorização de domínio na Web. Mantenha as variáveis `CONECTA_ANDROID_API_KEY` e `CONECTA_ANDROID_APP_ID` já usadas pelo projeto.
4. Execute `flutter pub get`, `flutter analyze` e os testes Flutter. Instale o APK em um Android e teste login, cancelamento do seletor, conta já existente e retorno à sessão.
5. Teste com uma conta de responsável e outra de dependente. **Selecionar um perfil não concede permissões de supervisão:** essas permissões exigem regras e validação de vínculo no backend, ainda pendentes nesta branch.

**Status:** integração de código inicial; não foi verificada em um dispositivo nem implantada no Firebase. Não publique um APK como versão de produção antes de completar a auditoria e os testes.

## Configurar e testar no Android

1. Instale o SDK do Android e o Flutter. Execute `flutter doctor`.
2. No projeto Firebase `contatos-6c266`, cadastre um app Android com pacote `com.washingtonof.conecta_messenger`.
3. No Firebase Authentication, verifique se o provedor **E-mail/senha** está ativo. Para o teste familiar, use duas contas com e-mails aos quais você tenha acesso e confirme os e-mails recebidos. O número de celular no perfil familiar é opcional e serve para a busca entre familiares vinculados.
4. Crie um banco Firestore e ative o Cloud Storage no mesmo projeto. Aplique `firestore.rules`, `firestore.indexes.json` e `storage.rules` ao ambiente de teste. Se já houver regras ou índices, combine as configurações antes de publicar. Habilite na Console do Firebase a permissão do Storage para consultar as regras de acesso no Firestore quando solicitada.
5. Rode com a chave de API e o App ID fornecidos pelo Firebase para o app Android:

   ```sh
   flutter pub get
   flutter run -d "<dispositivo>" \
     --dart-define=CONECTA_ANDROID_API_KEY="<chave>" \
     --dart-define=CONECTA_ANDROID_APP_ID="<app-id>" \
     --dart-define=CONECTA_CALL_BASE_URL="https://meet.jit.si"
   ```

6. Em dois aparelhos ou emuladores, entre com contas de e-mail verificadas diferentes. Gere um convite no aparelho do responsável, cole no outro e aceite. Abra o familiar pelo painel, envie mensagens nos dois sentidos e verifique que desfazer o vínculo encerra o acesso à conversa.


## Aplicar as regras ao Firebase

A partir da raiz do projeto, use uma conta autorizada no Firebase CLI. Confira as regras e os índices ativos do projeto antes de publicar, especialmente se o IsaMig Mensagens Web já usa o mesmo banco.

```sh
firebase login
firebase deploy --project contatos-6c266 --only firestore:rules
```

Com o Cloud Storage ativo, publique também as regras de mídia com `firebase deploy --project contatos-6c266 --only storage`. A Console do Firebase pode pedir autorização para as regras do Storage verificarem os vínculos no Firestore. Se o banco já contiver índices personalizados, preserve-os ao aplicar as configurações de `firestore.indexes.json`.

A etapa de regras não compila o APK. Para o primeiro teste em dois celulares, confira login por e-mail, convite familiar, fotos e vídeos no status e a abertura de uma chamada Jitsi a partir do chat.

## Gerar o APK pelo GitHub Actions

1. No repositório, abra **Settings → Secrets and variables → Actions → Variables**. Cadastre `CONECTA_ANDROID_API_KEY` e `CONECTA_ANDROID_APP_ID` com os valores do app Android do Firebase. Quando houver uma instância Jitsi, adicione `CONECTA_CALL_BASE_URL` com a URL HTTPS.
2. Para manter as mesmas impressões digitais entre compilações, adicione a chave de **teste** `debug.keystore`, codificada em base64, ao secret `CONECTA_DEBUG_KEYSTORE_BASE64`. Use o alias padrão `androiddebugkey` e a senha padrão de debug `android`. Sem esse secret, o runner gera uma assinatura de teste própria.
3. Um commit na branch `feat/conecta-familia-android` inicia o workflow **IsaMig Mensagens Android**. Em **Actions**, abra a execução e baixe **conecta-familia-apk-teste**. Após o workflow estar na branch padrão, também é possível usar **Run workflow**.
4. O arquivo `app-debug.apk` é para instalação de teste. `assinatura.txt` identifica o certificado desse APK.

Sem as duas variáveis do Firebase, o APK abre na tela de configuração. As variáveis Android são configuração de cliente e ficam incorporadas ao APK. Guarde a chave de assinatura apenas como secret.

## Executar na Web

1. Instale o Flutter e execute `flutter doctor`.
2. Clone este repositório.
3. Na raiz, execute `flutter create --platforms=web .` para gerar a estrutura Web.
4. Execute `flutter pub get`.
5. Execute `flutter run -d chrome` (ou selecione um dispositivo).

## Grupos, pré-cadastros e compartilhamento

1. Em **Grupos e conversas**, crie um grupo (até 50 participantes) ou uma conversa individual (até dois participantes).
2. Abra a conversa e entre em **Convites e pré-cadastros**. Copie o convite e envie à pessoa. O convite expira em sete dias.
3. A pessoa abre o IsaMig Mensagens, confirma o e-mail e cola o convite em **Grupos e conversas**. Ela informa o nome e envia o pré-cadastro.
4. O criador aprova a solicitação. A conversa aparece para o novo membro, que passa a ter acesso às mensagens do grupo. O criador pode remover membros na mesma tela.

Use o botão **+** em uma conversa para compartilhar pontualmente a localização do próprio aparelho. O Android pede autorização e a mensagem mostra a data e a hora do envio. No mesmo menu, é possível selecionar e enviar arquivos de até 25 MB pelo Cloud Storage. O destinatário escolhe onde salvar. Anexos antigos continuam disponíveis. O Cloud Storage requer o plano Blaze no Firebase.

## Responsável familiar

Após verificar o e-mail, é possível continuar sem vínculo, receber pedidos como responsável ou informar o e-mail de um responsável. A aba **Família** reúne os pedidos enviados e recebidos. O responsável indicado precisa aceitar o pedido na própria conta.

Nos vínculos aceitos por e-mail, o ícone de localização ao lado do familiar abre o painel. A pessoa vinculada confirma cada envio da posição no próprio aparelho e pode removê-la. O responsável vê a última posição compartilhada por até uma hora, com data e horário. O mapa abre no Google Maps mediante toque.

No mesmo painel, **Tempo de uso** permite revisar um resumo estimado dos apps mais usados no dia. O Android pede que o familiar habilite **Acesso ao uso**. A pessoa escolhe quais tempos enviar ao responsável, pode remover o resumo e o acesso expira em 24 horas.

## Perfil, presença e status

- O Android restaura a sessão do Firebase ao reabrir o app. Use **Sair** para encerrar a sessão.
- Em **Meu perfil**, é possível adicionar ou remover a foto e alterar nome e celular. A foto é privada e o e-mail exibido identifica a conta de login.
- Familiares vinculados podem ver **Online** enquanto o app está em primeiro plano. Quando o app fecha abruptamente ou perde a conexão, o último sinal expira em até 90 segundos.
- Em **Status de foto e vídeo**, selecione um familiar para compartilhar uma foto ou um vídeo MP4 de até 25 MB. A publicação fica visível por 24 horas. É possível removê-la antes disso.

## Chamadas de voz e vídeo

Para hospedar o Jitsi, prepare um servidor Linux com Docker Compose, um IPv4 público e um subdomínio que aponte para ele. Libere 80 e 443 TCP para HTTPS e 10000 UDP para mídia. O script usa o Docker Compose oficial, gera os segredos locais e configura HTTPS e contas individuais.

```sh
bash scripts/preparar-jitsi.sh meet.seu-dominio.com IP_PUBLICO seu-email@dominio.com ./jitsi-conecta
cd ./jitsi-conecta
docker compose up -d
```

Crie uma conta por participante na instância. Este comando pede a senha de forma interativa:

```sh
docker compose exec prosody prosodyctl --config /config/prosody.cfg.lua adduser participante@meet.jitsi
```

Após confirmar que a instância abre por HTTPS, inclua `--dart-define=CONECTA_CALL_BASE_URL=https://meet.seu-dominio.com` ao compilar o Android. O menu da conversa passa a oferecer chamadas de voz e vídeo. O login do Jitsi é separado do login do IsaMig Mensagens neste primeiro teste.

O IsaMig Mensagens cria um convite de sala na conversa. No Android 8.0 ou superior, o SDK do Jitsi abre a chamada em uma tela do próprio app. Na Web, o convite abre no navegador. O convidado toca para entrar. O modo voz começa com a câmera desligada, e cada participante concede as permissões de microfone e câmera no próprio aparelho. O convite aparece como expirado no IsaMig Mensagens após 30 minutos. A instância do Jitsi controla a autenticação, a entrada na sala e a duração da sessão. A chegada de um convite depende de abrir a conversa, pois ainda não há toque de chamada ou notificação push.

**Segurança:** nunca envie credenciais administrativas, chaves privadas, arquivos .env ou dados reais de usuários ao repositório.

O nome de exibição é IsaMig Mensagens. O identificador Android permanece `com.washingtonof.conecta_messenger` para usar o mesmo cadastro do Firebase.

### Limpeza de dados temporários

Os novos compartilhamentos do painel e os status incluem `expiresAt`. A configuração do Firestore declara TTL para `sharedLocation`, `sharedUsage` e `statuses`. Inclua esses campos ao aplicar os índices no projeto de teste. As regras de acesso continuam usando o horário do servidor. A exclusão por TTL é assíncrona, pode levar cerca de 24 horas após o prazo de limpeza e não cobre documentos antigos sem `expiresAt`.

O arquivo `storage-status-lifecycle.json` define a exclusão dos objetos sob `statuses/` após dois dias. Antes de aplicá-lo, confira a política de ciclo de vida atual do bucket e combine as regras existentes com esta regra. A atualização de ciclo de vida substitui a configuração anterior e pode alcançar objetos antigos de status. A política de exclusão reversível do bucket pode manter cópias recuperáveis por um período adicional. O prefixo `attachments/` fica fora dessa regra.

Para conferir os registros antigos, use `python3 scripts/migrar-expiracao.py --project ID_DO_PROJETO` com uma conta administrativa autenticada pelo Google Cloud CLI. O comando mostra contagens por coleção. Depois de validar no projeto de teste, o modo `--apply` grava o prazo calculado a partir da data original. Com o TTL ativo, registros cujo prazo já passou ficam elegíveis para exclusão. O script preserva datas de expiração existentes e ignora alterações concorrentes, que podem ser reavaliadas em outra execução.

### Compilação isolada do login Google (IsaMig Família)

A branch `feat/isamig-familia-google-login` contém um workflow manual em `.github/workflows/isamig-familia-google-login.yml`.

Configurações necessárias em **Settings > Secrets and variables > Actions**:
- **Secret** `CONECTA_DEBUG_KEYSTORE_BASE64`: conteúdo Base64 do certificado Android de teste persistente (nunca commitar ou divulgar).
- **Variables** `CONECTA_ANDROID_API_KEY`, `CONECTA_ANDROID_APP_ID`: configuração do app Firebase Android.
- **Variable** `GOOGLE_WEB_CLIENT_ID`: ID de cliente OAuth **Web application** associado ao projeto Firebase/Google Cloud, usado como `serverClientId` no Android. Não é o App ID do Firebase.

Após adicionar o certificado ao secret, cadastre seu SHA-1 e SHA-256 no app Android do Firebase. Execute o workflow manualmente na branch de desenvolvimento. O job falha sem os valores necessários em vez de gerar APK com assinatura diferente. O certificado fornecido é **somente para testes**; para distribuição na Play Store, configure uma chave de release separada.
