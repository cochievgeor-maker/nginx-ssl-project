#!/bin/bash
# @file deploy/bootstrap.sh
# @brief Скрипт первичной подготовки чистой ОС Linux перед развертыванием инфраструктуры
# @author Кочиев Георгий Джамболатович (kochiev@sfedu.ru)
# @date 2026-05-25
# @version 1.0.0
#
# @details
# Данный сценарий автоматизирует выполнение следующих этапов:
# 1. Валидация прав суперпользователя (root) и версии дистрибутива.
# 2. Обновление системных пакетов и подключение официальных репозиториев Docker.
# 3. Установка пакетов автоматизации (docker-ce, docker-compose-plugin).
# 4. Настройка межсетевого экрана UFW по принципу "deny all, allow explicit".
# 5. Применение hardening-параметров ядра через sysctl.d.
#
# @license MIT <https://opensource.org/licenses/MIT>
# This program is free software: you can redistribute it and/or modify
# it under the terms of the MIT License.

# ==============================================================================
# РЕЖИМ БЕЗОПАСНОГО ВЫПОЛНЕНИЯ (Defensive Bash Programming)
# ==============================================================================
set -euo pipefail  # Exit on error, undefined var, pipe failure

# ==============================================================================
# ГЛОБАЛЬНЫЕ КОНСТАНТЫ (UPPERCASE)
# ==============================================================================
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly LOG_FILE="/var/log/bootstrap-${SCRIPT_NAME%.sh}.log"

# Цвета для вывода (отключаем, если не TTY)
if [[ -t 1 ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly NC='\033[0m' # No Color
else
    readonly RED='' GREEN='' YELLOW='' NC=''
fi

# ==============================================================================
# ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ (lowercase_with_underscores)
# ==============================================================================

# @brief Логирование сообщений с уровнем и временной меткой
# @description Выводит сообщение в stdout и дублирует в лог-файл
# @param 1 level  Строка: "INFO", "WARN", "ERROR"
# @param 2 message Сообщение для логирования
# @example log_msg "INFO" "Starting bootstrap..."
log_msg() {
    local level="${1:-INFO}"
    local message="${2:-}"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    
    # Пишем в лог-файл (требует прав, но не прерываем скрипт при ошибке)
    echo "[${timestamp}] [${level}] ${message}" >> "${LOG_FILE}" 2>/dev/null || true
    
    # Вывод в терминал с цветом
    case "${level}" in
        ERROR) echo -e "${RED}[${level}]${NC} ${message}" >&2 ;;
        WARN)  echo -e "${YELLOW}[${level}]${NC} ${message}" ;;
        *)     echo -e "${GREEN}[${level}]${NC} ${message}" ;;
    esac
}

# @brief Проверка наличия прав sudo/root
# @return 0 если есть привилегии, 1 если нет
# @example check_sudo_rights || exit 1
check_sudo_rights() {
    if [[ "${EUID}" -ne 0 ]]; then
        log_msg "ERROR" "Скрипт должен выполняться от имени root или через sudo"
        return 1
    fi
    return 0
}

# @brief Проверка версии дистрибутива (только LTS Ubuntu)
# @description Валидирует, что ОС — Ubuntu 22.04 LTS или 24.04 LTS
# @return 0 если проверка пройдена, 1 если нет
check_distro() {
    if [[ ! -f /etc/os-release ]]; then
        log_msg "ERROR" "Файл /etc/os-release не найден. Неподдерживаемая ОС?"
        return 1
    fi
    
    # Источник переменных из os-release
    # shellcheck source=/dev/null
    source /etc/os-release
    
    if [[ "${ID}" != "ubuntu" ]]; then
        log_msg "WARN" "Дистрибутив '${ID}' не является официальным. Продолжаем на свой риск."
        return 0  # Не прерываем, но предупреждаем
    fi
    
    # Проверка версии: только 22.04 (jammy) или 24.04 (noble)
    if [[ "${VERSION_CODENAME}" != "jammy" && "${VERSION_CODENAME}" != "noble" ]]; then
        log_msg "ERROR" "Требуется Ubuntu LTS (22.04/24.04). Обнаружено: ${VERSION}"
        return 1
    fi
    
    log_msg "INFO" "Проверка дистрибутива: ${PRETTY_NAME} ✓"
    return 0
}

# @brief Настройка межсетевого экрана UFW
# @description Применяет политику "deny incoming, allow outgoing", открывает порты 80/443/22
setup_ufw() {
    log_msg "INFO" "Настройка межсетевого экрана UFW..."
    
    # Установка ufw если отсутствует
    if ! command -v ufw &>/dev/null; then
        apt-get update -qq && apt-get install -y -qq ufw
    fi
    
    # Сброс правил (для идемпотентности)
    ufw --force reset >/dev/null 2>&1 || true
    
    # Политика по умолчанию: запрет входящих, разрешение исходящих
    ufw default deny incoming
    ufw default allow outgoing
    
    # Разрешаем критичные порты
    ufw allow 22/tcp comment "SSH access"        # Удалённое управление
    ufw allow 80/tcp comment "HTTP redirect"     # Редирект на HTTPS
    ufw allow 443/tcp comment "HTTPS service"    # Основной веб-трафик
    
    # Включаем firewall (без интерактивного подтверждения)
    echo "y" | ufw enable
    
    log_msg "INFO" "UFW настроен: разрешены порты 22, 80, 443 ✓"
}

# @brief Применение hardening-параметров ядра
# @description Создаёт /etc/sysctl.d/99-hardening.conf с безопасными настройками сетевой стека
apply_sysctl_hardening() {
    log_msg "INFO" "Применение параметров ядра (sysctl hardening)..."
    
    local sysctl_file="/etc/sysctl.d/99-hardening.conf"
    
    # Создаём файл с комментариями-обоснованиями
    cat > "${sysctl_file}" << 'EOF'
# @file 99-hardening.conf
# @brief Hardening-параметры ядра Linux для веб-сервера
# @author Кочиев Георгий Джамболатович (kochiev@sfedu.ru)
# @date 2026-05-25
# @license MIT

# ==============================================================================
# СЕТЕВАЯ БЕЗОПАСНОСТЬ (Network Stack Hardening)
# ==============================================================================

# Защита от IP-spoofing: игнорировать пакеты с неверным исходным адресом
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Запрет ICMP-redirect (защита от атак на таблицу маршрутизации)
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Игнорировать широковещательные ICMP-запросы (защита от Smurf-атак)
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Логирование "подозрительных" пакетов (martians)
net.ipv4.conf.all.log_martians = 1

# ==============================================================================
# TCP/IP ОПТИМИЗАЦИЯ (Performance)
# ==============================================================================

# Увеличение очереди входящих соединений (для высокой нагрузки)
net.core.somaxconn = 4096

# Увеличение буферов TCP (auto-tuning)
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

# Включение TCP Fast Open (уменьшает latency при повторных соединениях)
net.ipv4.tcp_fastopen = 3

# ==============================================================================
# ЗАЩИТА ОТ ПЕРЕГРУЗОК (DoS Mitigation)
# ==============================================================================

# Ограничение частоты новых соединений (базовая защита от SYN-flood)
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_synack_retries = 2
EOF

    # Применяем настройки немедленно
    sysctl -p "${sysctl_file}"
    
    log_msg "INFO" "Параметры ядра применены: ${sysctl_file} ✓"
}

# @brief Установка Docker Engine (если отсутствует)
# @description Подключает официальный репозиторий Docker и устанавливает пакеты
install_docker() {
    log_msg "INFO" "Проверка наличия Docker Engine..."
    
    # Если docker уже установлен — пропускаем
    if command -v docker &>/dev/null && docker compose version &>/dev/null; then
        log_msg "INFO" "Docker Engine уже установлен. Пропускаем установку."
        return 0
    fi
    
    log_msg "INFO" "Установка Docker Engine (официальный репозиторий)..."
    
    # Установка зависимостей для работы с репозиториями по HTTPS
    apt-get update -qq
    apt-get install -y -qq \
        ca-certificates \
        curl \
        gnupg \
        lsb
