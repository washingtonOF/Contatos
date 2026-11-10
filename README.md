# Conecta Messenger

Protótipo Flutter do mensageiro Conecta (Android, iOS e Web).

**Estado:** desenvolvimento. Esta versão apresenta apenas a tela inicial. Não há login, Firebase ou troca de mensagens.

## Executar

1. Instale o Flutter e execute `flutter doctor`.
2. Clone este repositório.
3. Na raiz, execute `flutter create --platforms=android,ios,web .` para gerar os diretórios nativos ainda ausentes.
4. Execute `flutter pub get`.
5. Execute `flutter run -d chrome` (ou selecione um dispositivo).

Para compilar iOS, use um ambiente macOS com Xcode.

## Próximos passos

- Criar projeto Firebase de desenvolvimento.
- Configurar FlutterFire para cada plataforma.
- Implementar autenticação, perfis e conversas.
- Implementar regras de segurança, testes e proteção contra abuso antes do beta.

**Segurança:** nunca envie credenciais administrativas, chaves privadas, arquivos .env ou dados reais de usuários ao repositório.

O nome Conecta e o identificador do aplicativo são provisórios até análise de disponibilidade de marca.
