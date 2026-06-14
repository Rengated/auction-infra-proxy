#!/bin/sh
# Генерирует самоподписанный серт (если нет) и запускает stunnel.
set -e
CERT=/etc/stunnel/stunnel.pem
if [ ! -f "$CERT" ]; then
  echo "==> Генерирую самоподписанный сертификат для stunnel..."
  openssl req -new -x509 -days 3650 -nodes \
    -subj "/CN=proxy" \
    -keyout /tmp/key.pem -out /tmp/crt.pem 2>/dev/null
  cat /tmp/crt.pem /tmp/key.pem > "$CERT"
  rm -f /tmp/key.pem /tmp/crt.pem
fi
exec stunnel /etc/stunnel/stunnel.conf
