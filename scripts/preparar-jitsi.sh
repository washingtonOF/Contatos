#!/usr/bin/env bash
set -euo pipefail
umask 077

if [[ $# -ne 4 ]]; then
  echo "Uso: $0 <domínio> <IPv4 público> <e-mail para TLS> <diretório novo>" >&2
  exit 2
fi

domain=$1
address=$2
email=$3
destination=$4
release=stable-11509-1

if [[ ! $domain =~ ^[[:alnum:]]([[:alnum:]-]*[[:alnum:]])?(\.[[:alnum:]]([[:alnum:]-]*[[:alnum:]])?)+$ ||
      ! $address =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ||
      ! $email =~ ^[[:alnum:]._%+-]+@[[:alnum:].-]+\.[[:alpha:]]{2,}$ ]]; then
  echo 'Informe um domínio, um IPv4 e um e-mail válidos.' >&2
  exit 2
fi

docker compose version >/dev/null
mkdir -- "$destination"
cd -- "$destination"
archive=$(mktemp)
trap 'rm -f -- "$archive"' EXIT
curl --fail --silent --show-error --location \
  "https://codeload.github.com/jitsi/docker-jitsi-meet/tar.gz/refs/tags/$release" \
  --output "$archive"
tar -xzf "$archive" --strip-components=1
sed -e 's|^CONFIG=.*|CONFIG=./data|' \
    -e 's|^HTTP_PORT=.*|HTTP_PORT=80|' \
    -e 's|^HTTPS_PORT=.*|HTTPS_PORT=443|' \
    env.example > .env

cat >> .env <<SETTINGS

PUBLIC_URL=https://$domain
JVB_ADVERTISE_IPS=$address
ENABLE_AUTH=1
AUTH_TYPE=internal
ENABLE_GUESTS=0
XMPP_DOMAIN=meet.jitsi
ENABLE_LETSENCRYPT=1
LETSENCRYPT_ACME_SERVER=letsencrypt
LETSENCRYPT_DOMAIN=$domain
LETSENCRYPT_EMAIL=$email
ENABLE_JAAS_COMPONENTS=0
JITSI_IMAGE_VERSION=$release
SETTINGS

bash gen-passwords.sh
rm -f -- .env.bak
docker compose config --quiet
printf 'Configuração validada para https://%s.\n' "$domain"
printf 'No servidor, execute docker compose up -d dentro de %s.\n' "$PWD"
