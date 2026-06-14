# Минимальный stunnel из официального alpine-репо (без сторонних образов).
FROM alpine:3.20
RUN apk add --no-cache stunnel openssl
# Генерируем самоподписанный сертификат на этапе сборки (для TLS-обёртки —
# валидность CA не важна, нужен только шифр). entrypoint берёт смонтированный
# конфиг и (при отсутствии) генерит cert.
COPY stunnel-entry.sh /entry.sh
RUN chmod +x /entry.sh
ENTRYPOINT ["/entry.sh"]
