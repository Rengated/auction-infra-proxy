# proxy-deploy — прокси-сервер для Hermes Trade

Разворачивается на **зарубежном** сервере (вне зоны блокировок Telegram). Поднимает:

- **MTProto-прокси** (`telemt` — активный Rust-форк) с fake-TLS-маскировкой под российский домен и привязкой **спонсорского канала** (промо-канал показывается всем, кто подключился через прокси).
- **SOCKS5** (`3proxy`) — для нашего бота: API Hermes Trade ходит через него в `api.telegram.org`, если у прод-сервера нет прямого доступа.

> MTProto и SOCKS5 — это **разные** прокси. MTProto нельзя использовать для бота (он для клиентов), SOCKS5 нельзя «спонсировать каналом». Поэтому здесь оба.

## Установка (одна команда)

На чистом зарубежном сервере (Ubuntu/Debian):

```bash
git clone <этот-репозиторий> /opt/proxy && cd /opt/proxy
make install
```

`make install` сам: поставит Docker (если нет) → создаст `.env` → сгенерирует MTProto-секрет (32 hex) и пароль SOCKS5 → отрендерит конфиги → поднимет оба сервиса → покажет ссылки.

В конце выведется:
- **MTProto-ссылка** (`tg://proxy?...` и `https://t.me/proxy?...`) — её раздаёшь людям;
- **строка `TELEGRAM_PROXY=socks5://...`** — её вставляешь в `.env` прод-сервера Hermes Trade.

Повторно показать ссылки: `make link`.

## После установки

1. **Открой порты** у хостера/в фаерволе: `MTG_PORT` (8443) и `SOCKS_PORT` (1080).
   ```bash
   ufw allow 8443/tcp && ufw allow 1080/tcp
   ```
   Если хостер фильтрует порты на своём уровне (Security Group) — открой их и там.
2. **Спонсорский канал** для MTProto:
   - `make link` покажет **secret для бота (32 hex)** — это тот же секрет, что в ссылке (telemt использует обычный hex, без fake-TLS кодирования — домен задаётся отдельно).
   - Напиши **@MTProxybot** → `/newproxy` → server `IP`, port `8443`, secret — этот 32-hex.
   - `/setpromo` → выбери свой канал → бот выдаст **ad_tag** (32 hex).
   - Впиши его в `.env`: `MTG_ADTAG=<тег>`, затем `make render && make restart`.
   - Теперь у всех, кто подключился через прокси, сверху закреплён твой канал.
3. **Подключи бота** Hermes Trade: на прод-сервере в `.env` добавь строку `TELEGRAM_PROXY=socks5://...` (из `make link`) и пересобери api:
   ```bash
   docker compose -f docker-compose.prod.yml up -d --build api
   ```

## Настройки (`.env`)

| Переменная | Назначение |
|---|---|
| `MTG_PORT` | внешний порт MTProto (по умолч. 8443) |
| `FRONT_DOMAIN` | домен маскировки fake-TLS (по умолч. `ya.ru` — российский, TLS 1.3) |
| `MTG_SECRET` | секрет (32 hex) — генерируется автоматически |
| `MTG_ADTAG` | ad_tag спонсорского канала от @MTProxybot — пусто = без промо |
| `SOCKS_PORT` | внешний порт SOCKS5 (по умолч. 1080) |
| `SOCKS_USER` / `SOCKS_PASS` | логин/пароль SOCKS5 — пароль генерируется автоматически |

## Сменить домен маскировки

```bash
# в .env: FRONT_DOMAIN=ya.ru (или другой российский сайт с TLS 1.3)
make render && make restart
make link      # ссылка обновится — раздавай новую
```

Подходящие домены (TLS 1.3, не блокируются в РФ): `ya.ru`, `dzen.ru`, `vk.com`, `gosuslugi.ru`, `sberbank.ru`, `avito.ru`.

## Команды

```bash
make install   # установить и поднять (идемпотентно)
make link      # показать ссылки MTProto и TELEGRAM_PROXY
make logs      # логи
make restart   # перезапуск
make down      # остановить
make update    # обновить образы и перезапустить
```

## Безопасность

- SOCKS5 закрыт логином/паролем (генерируется случайно). При желании дополнительно ограничь порт по IP прод-сервера в фаерволе.
- MTProto-движок — сторонний образ `whn0thacked/telemt-docker` (форк [telemt/telemt](https://github.com/telemt/telemt)), запускается с `network_mode: host`. Образ обновляется через `make update`.
- `.env`, `3proxy.cfg`, `telemt-config/` в `.gitignore` — секреты в репозиторий не попадают.
