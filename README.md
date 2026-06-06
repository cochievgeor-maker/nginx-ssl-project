# Nginx SSL/TLS Project (DevOps Infrastructure)

## Описание проекта

Контейнеризованный веб-сервер Nginx с поддержкой:
- **TLSv1.3** и **HTTP/2**
- Автоматический редирект **HTTP → HTTPS** (301)
- Заголовки безопасности (**HSTS**, **CSP**, **X-Frame-Options**)
- **Docker Secrets** для управления ключами
- **Read-only** файловая система + **tmpfs**

Инфраструктура описана как код (IaC), разворачивается одной командой.

## 👥 Команда и распределение ролей

| ФИО | Роль | Зона ответственности | Ветка |
|-----|------|---------------------|-------|
| Кочиев Г.Д. | DevOps / IaC Engineer | Dockerfile, docker-compose, bootstrap.sh, CI/CD | `main` |
| Нестеров Г.А. | SysAdmin / SRE | Конфиги Nginx, логи, healthcheck, тесты | `feat/sysadmin-nginx-configs` |
| Тарасов С.Н. | Security / Observability | .gitignore, документация, матрица ролей, схемы | `feat/security-docs-headers` |

## Быстрый старт

### Требования
- Ubuntu 22.04/24.04 LTS (или WSL2)
- Docker Engine 24+
- Docker Compose Plugin

### Развёртывание

```bash
## Быстрый старт

> **Важно:** TLS-ключи намеренно исключены из репозитория (`.gitignore`). 
> Перед первым запуском необходимо сгенерировать их локально. Это стандарт DevOps (Secrets Management).

Выполните следующие команды в корне проекта:

```bash
# 1. Создайте папку и сгенерируйте самоподписанные сертификаты (ECDSA)
mkdir -p certs
openssl ecparam -genkey -name prime256v1 -noout -out certs/server.key
openssl req -new -x509 -sha256 -key certs/server.key -out certs/server.crt -days 365 -subj "/CN=localhost/O=DevOps/C=RU"

# 2. Настройте права (необходимо для корректного монтирования в Docker на WSL2/Linux)
chmod 644 certs/server.key certs/server.crt

# 3. Соберите и запустите контейнеры
cd deploy
docker compose up -d --build

# 4. Дождитесь инициализации healthcheck и запустите интеграционные тесты
sleep 15
bash scripts/tests/run_all_tests.sh
