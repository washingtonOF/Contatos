# Conecta Messenger

Conecta é um protótipo Flutter de comunicação familiar.

A versão Web oferece cadastro e login por e-mail. No Android, o fluxo familiar usa login por SMS, convite de uso único, busca por número entre familiares vinculados e conversas individuais e grupos com aprovação de entrada.

## Configurar e testar no Android

1. Instale o SDK do Android e o Flutter. Execute `flutter doctor`.
2. No projeto Firebase `contatos-6c266`, cadastre um app Android com pacote `com.washingtonof.conecta_messenger`. Adicione as assinaturas SHA-1 e SHA-256 da chave usada para assinar o APK de teste.
3. Ative o provedor **Telefone** no Firebase Authentication. Para o primeiro teste, configure dois números fictícios e seus códigos na seção de números de teste. O envio de SMS reais depende do plano de cobrança e da política de regiões do Firebase.
4. Crie um banco Firestore e ative o Cloud Storage no mesmo projeto. Aplique `firestore.rules`, `firestore.indexes.json` e `storage.rules` ao ambiente de teste. Se já houver regras ou índices, combine as configurações antes de publicar. Habilite na Console do Firebase a permissão do Storage para consultar as regras de acesso no Firestore quando solicitada.
5. Rode com a chave de API e o App ID fornecidos pelo Firebase para o app Android:

   ```sh
   flutter pub get
   flutter run -d "<dispositivo>" \
     --dart-define=CONECTA_ANDROID_API_KEY="<chave>" \
     --dart-define=CONECTA_ANDROID_APP_ID="<app-id>"
   ```

6. Em dois aparelhos ou emuladores, entre com números de teste diferentes. Gere um convite no aparelho do responsável, cole no outro e aceite. Abra o familiar pelo painel, envie mensagens nos dois sentidos e verifique que desfazer o vínculo encerra o acesso à conversa.


## Gerar o APK pelo GitHub Actions

1. No repositório, abra **Settings → Secrets and variables → Actions → Variables**. Cadastre `CONECTA_ANDROID_API_KEY` e `CONECTA_ANDROID_APP_ID` com os valores do app Android do Firebase. Quando houver uma instância Jitsi, adicione `CONECTA_CALL_BASE_URL` com a URL HTTPS.
2. Para manter as mesmas impressões digitais entre compilações, adicione a chave de **teste** `debug.keystore`, codificada em base64, ao secret `CONECTA_DEBUG_KEYSTORE_BASE64`. Use o alias padrão `androiddebugkey` e a senha padrão de debug `android`. Sem esse secret, o runner gera uma assinatura de teste própria.
3. Um commit na branch `feat/conecta-familia-android` inicia o workflow **Conecta Família Android**. Em **Actions**, abra a execução e baixe **conecta-familia-apk-teste**. Após o workflow estar na branch padrão, também é possível usar **Run workflow**.
4. Registre no Firebase o SHA-1 e o SHA-256 listados em `assinatura.txt` antes de testar o SMS. O arquivo `app-debug.apk` é para instalação de teste.

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
3. A pessoa abre o Conecta Família, confirma o número por SMS e cola o convite em **Grupos e conversas**. Ela informa o nome e envia o pré-cadastro.
4. O criador aprova a solicitação. A conversa aparece para o novo membro, que passa a ter acesso às mensagens do grupo. O criador pode remover membros na mesma tela.

Use o botão **+** em uma conversa para compartilhar pontualmente a localização do próprio aparelho. O Android pede autorização e a mensagem mostra a data e a hora do envio. No mesmo menu, é possível selecionar e enviar arquivos de até 25 MB pelo Cloud Storage. O destinatário escolhe onde salvar. Anexos antigos continuam disponíveis. O Cloud Storage requer o plano Blaze no Firebase.

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

Após confirmar que a instância abre por HTTPS, inclua `--dart-define=CONECTA_CALL_BASE_URL=https://meet.seu-dominio.com` ao compilar o Android. O menu da conversa passa a oferecer chamadas de voz e vídeo. O login do Jitsi é separado do SMS do Conecta neste primeiro teste.

O Conecta cria um convite de sala na conversa e abre o Jitsi no navegador ou app compatível. O convidado toca para entrar. O modo voz começa com a câmera desligada e a permissão de câmera e microfone é pedida pelo serviço. O convite aparece como expirado no Conecta após 30 minutos. A instância do Jitsi controla a autenticação, a entrada na sala e a duração da sessão. A chegada de um convite depende de abrir a conversa, pois ainda não há toque de chamada ou notificação push.

**Segurança:** nunca envie credenciais administrativas, chaves privadas, arquivos .env ou dados reais de usuários ao repositório.

O nome Conecta e o identificador do aplicativo são provisórios até análise de disponibilidade de marca.
