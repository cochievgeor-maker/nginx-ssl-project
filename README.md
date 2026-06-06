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
# 1. Клонируй репозиторий
git clone git@github.com:cochievgeor-maker/nginx-ssl-project.git
cd nginx-ssl-project

# 2. Сгенерируй сертификаты (для локальной разработки)
bash deploy/scripts/generate-certs.sh

# 3. Запусти инфраструктуру
cd deploy
docker compose up -d --build

# 4. Проверь работоспособность
curl -k -I https://localhost
bash scripts/tests/run_all_tests.sh
