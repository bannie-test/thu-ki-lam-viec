#!/usr/bin/env bash
# Run once on YOUR computer. No secrets are committed to git or sent to chat.
set -euo pipefail
umask 077
for command in gh keytool openssl base64; do command -v "$command" >/dev/null || { echo "Missing: $command" >&2; exit 1; }; done
repo="bannie-test/thu-ki-lam-viec"
backup="${1:-$PWD/signing-backup}"
mkdir -p "$backup"
if [[ -e "$backup/nhac-viec.jks" || -e "$backup/password.txt" ]]; then
  echo 'Backup already exists. Refusing to replace your signing identity.' >&2
  exit 1
fi
export NHAC_SIGN_PASSWORD
NHAC_SIGN_PASSWORD="$(openssl rand -hex 24)"
printf '%s' "$NHAC_SIGN_PASSWORD" > "$backup/password.txt"
keytool -genkeypair -noprompt -keystore "$backup/nhac-viec.jks" -storetype PKCS12 -alias nhac-viec -keyalg RSA -keysize 3072 -validity 36500 -storepass:env NHAC_SIGN_PASSWORD -keypass:env NHAC_SIGN_PASSWORD -dname 'CN=Nhac Viec Personal'
base64 < "$backup/nhac-viec.jks" | tr -d '\n' | gh secret set ANDROID_KEYSTORE_BASE64 --repo "$repo"
printf '%s' "$NHAC_SIGN_PASSWORD" | gh secret set ANDROID_STORE_PASSWORD --repo "$repo"
printf '%s' "$NHAC_SIGN_PASSWORD" | gh secret set ANDROID_KEY_PASSWORD --repo "$repo"
printf '%s' 'nhac-viec' | gh secret set ANDROID_KEY_ALIAS --repo "$repo"
keytool -exportcert -keystore "$backup/nhac-viec.jks" -alias nhac-viec -storepass:env NHAC_SIGN_PASSWORD | openssl x509 -inform DER -noout -fingerprint -sha256 | cut -d= -f2 | tr -d ':\n' | gh secret set ANDROID_CERT_SHA256 --repo "$repo"
unset NHAC_SIGN_PASSWORD
echo "Signing secrets saved. Keep a private backup of $backup (keystore AND password)."
echo 'Do not recreate or replace this key for future updates.'
echo 'Next: gh workflow run android.yml --repo bannie-test/thu-ki-lam-viec'
