# Развёртывание прокси-сервера (MTProto + SOCKS5) одной командой.
#   make install   — настроить и поднять (идемпотентно)
#   make link      — показать ссылку MTProto и строку TELEGRAM_PROXY для бота
#   make logs / down / restart / update

SHELL := /bin/bash
MTG_IMAGE := nineseconds/mtg:2

.DEFAULT_GOAL := help

.PHONY: help
help:
	@echo "Hermes proxy-deploy — команды:"
	@echo "  make install   установить Docker (если нет), сгенерировать секреты и поднять прокси"
	@echo "  make link      показать MTProto-ссылку (для @MTProxybot) и TELEGRAM_PROXY для бота"
	@echo "  make logs      логи сервисов"
	@echo "  make restart   перезапуск"
	@echo "  make down      остановить"
	@echo "  make update    обновить образы и перезапустить"

# ── Установка Docker при отсутствии ───────────────────────────────────────
.PHONY: docker
docker:
	@if ! command -v docker >/dev/null 2>&1; then \
		echo "==> Устанавливаю Docker..."; \
		curl -fsSL https://get.docker.com | sh; \
	else echo "==> Docker уже установлен"; fi

# ── .env из примера ───────────────────────────────────────────────────────
.env:
	@cp .env.example .env
	@echo "==> Создан .env из .env.example"

# ── Генерация секретов (идемпотентно: пустые поля заполняются) ─────────────
.PHONY: secrets
secrets: .env
	@set -a; source ./.env; set +a; \
	if [ -z "$$MTG_SECRET" ]; then \
		echo "==> Генерирую MTProto-секрет (fake-TLS под $$FRONT_DOMAIN)..."; \
		docker pull -q $(MTG_IMAGE) >/dev/null; \
		SECRET=$$(docker run --rm $(MTG_IMAGE) generate-secret "$$FRONT_DOMAIN"); \
		sed -i "s|^MTG_SECRET=.*|MTG_SECRET=$$SECRET|" .env; \
		echo "    secret: $$SECRET"; \
	else echo "==> MTG_SECRET уже задан"; fi; \
	if [ -z "$$SOCKS_PASS" ]; then \
		echo "==> Генерирую пароль SOCKS5..."; \
		PASS=$$(head -c 18 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 20); \
		sed -i "s|^SOCKS_PASS=.*|SOCKS_PASS=$$PASS|" .env; \
		echo "    socks: $$SOCKS_USER / $$PASS"; \
	else echo "==> SOCKS_PASS уже задан"; fi

# ── Рендер конфигов из шаблонов ───────────────────────────────────────────
.PHONY: render
render: secrets
	@set -a; source ./.env; set +a; \
	if [ -n "$$MTG_ADTAG" ]; then ADTAG_LINE="adtag = \"$$MTG_ADTAG\""; \
	else ADTAG_LINE=""; fi; \
	sed -e "s|__SECRET__|$$MTG_SECRET|g" -e "s|__ADTAG__|$$ADTAG_LINE|g" \
		mtg.toml.template > mtg.toml; \
	sed -e "s|__SOCKS_USER__|$$SOCKS_USER|g" -e "s|__SOCKS_PASS__|$$SOCKS_PASS|g" \
		3proxy.cfg.template > 3proxy.cfg; \
	if [ -n "$$MTG_ADTAG" ]; then echo "==> Конфиги сгенерированы (спонсорский канал включён)"; \
	else echo "==> Конфиги сгенерированы (без спонсорского канала — задайте MTG_ADTAG)"; fi

# ── Полная установка ──────────────────────────────────────────────────────
.PHONY: install
install: docker render
	@docker compose up -d
	@echo ""
	@echo "════════════════════════════════════════════════════════════════"
	@echo " Прокси подняты. Дальше:"
	@echo "  1) make link  — получить ссылки"
	@echo "  2) откройте порты MTG_PORT и SOCKS_PORT в фаерволе/у хостера"
	@echo "════════════════════════════════════════════════════════════════"
	@$(MAKE) --no-print-directory link

# ── Ссылки ────────────────────────────────────────────────────────────────
.PHONY: link
link:
	@set -a; source ./.env; set +a; \
	IP=$$(curl -fsS --max-time 5 https://api.ipify.org || echo "<IP-СЕРВЕРА>"); \
	echo ""; \
	echo "── MTProto (раздавать клиентам) ──"; \
	echo "  tg://proxy?server=$$IP&port=$$MTG_PORT&secret=$$MTG_SECRET"; \
	echo "  https://t.me/proxy?server=$$IP&port=$$MTG_PORT&secret=$$MTG_SECRET"; \
	echo ""; \
	if [ -n "$$MTG_ADTAG" ]; then \
		echo "  Спонсорский канал: ВКЛЮЧЁН (adtag задан)."; \
	else \
		CORE=$$(echo "$$MTG_SECRET" | tr '_-' '/+' | base64 -d 2>/dev/null | od -An -tx1 | tr -d ' \n' | sed 's/^ee//' | head -c 32); \
		echo "  Спонсорский канал: пока выключен. Чтобы включить —"; \
		echo "    1) @MTProxybot → /newproxy → server: $$IP  port: $$MTG_PORT"; \
		echo "       secret для бота (32 hex, НЕ fake-TLS): $$CORE"; \
		echo "    2) /setpromo → выберите канал → бот выдаст adtag (32 hex)"; \
		echo "    3) впишите adtag в .env: MTG_ADTAG=<тег>  →  make render && make restart"; \
		echo "    (боту даём короткий hex-секрет — fake-TLS он не принимает;"; \
		echo "     на сервере остаётся fake-TLS, канал привязан через adtag)"; \
	fi; \
	echo ""; \
	echo "── SOCKS5 для бота (в .env прода Hermes Trade) ──"; \
	echo "  TELEGRAM_PROXY=socks5://$$SOCKS_USER:$$SOCKS_PASS@$$IP:$$SOCKS_PORT"; \
	echo ""

.PHONY: logs
logs:
	@docker compose logs -f

.PHONY: restart
restart:
	@docker compose restart

.PHONY: down
down:
	@docker compose down

.PHONY: update
update:
	@docker compose pull && docker compose up -d
