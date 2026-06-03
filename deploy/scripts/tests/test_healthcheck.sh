#!/bin/bash
# @file deploy/scripts/tests/test_healthcheck.sh
# @brief Проверка статуса healthcheck для Docker-контейнеров
# @author Кочиев Георгий Джамболатович (kochiev@sfedu.ru)
# @date 2026-05-25
# @version 1.1.0
# @license MIT
#
# @details
# Валидирует, что ключевые сервисы проходят проверки жизнеспособности:
# 1. Контейнер запущен (status = running)
# 2. Healthcheck возвращает статус "healthy"

set -euo pipefail

# ==============================================================================
# КОНСТАНТЫ
# ==============================================================================
readonly CONTAINER_NAME="secure-nginx"

# ==============================================================================
# ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
# ==============================================================================

print_result() {
    local test_name="${1}"
    local status="${2}"
    local message="${3:-}"
    
    if [[ "${status}" == "PASS" ]]; then
        echo -e "\033[0;32m✓ PASS\033[0m: ${test_name}"
    else
        echo -e "\033[0;31m✗ FAIL\033[0m: ${test_name}"
        [[ -n "${message}" ]] && echo -e "  └─ ${message}" >&2
        return 1
    fi
}

# ==============================================================================
# ТЕСТОВЫЕ ФУНКЦИИ
# ==============================================================================

# @brief Проверка, что контейнер существует и запущен
# @return 0 если контейнер в статусе "running", 1 иначе
test_container_running() {
    local status
    status=$(docker inspect -f '{{.State.Status}}' "${CONTAINER_NAME}" 2>/dev/null || echo "not_found")
    
    if [[ "${status}" == "running" ]]; then
        print_result "Container '${CONTAINER_NAME}' is running" "PASS"
        return 0
    else
        print_result "Container '${CONTAINER_NAME}' is running" "FAIL" "Status: ${status}"
        return 1
    fi
}

# @brief Проверка статуса healthcheck (healthy/unhealthy)
# @return 0 если статус "healthy", 1 иначе
test_healthcheck_status() {
    local health
    health=$(docker inspect -f '{{.State.Health.Status}}' "${CONTAINER_NAME}" 2>/dev/null || echo "no_healthcheck")
    
    if [[ "${health}" == "healthy" ]]; then
        print_result "Healthcheck status is 'healthy'" "PASS"
        return 0
    else
        print_result "Healthcheck status is 'healthy'" "FAIL" "Status: ${health}"
        return 1
    fi
}

# @brief Проверка, что healthcheck хотя бы раз успешно прошёл (упрощённая версия)
# @return 0 если статус "healthy" (подтверждает работоспособность), 1 иначе
test_healthcheck_freshness() {
    local health
    health=$(docker inspect -f '{{.State.Health.Status}}' "${CONTAINER_NAME}" 2>/dev/null || echo "no_healthcheck")
    
    if [[ "${health}" == "healthy" ]]; then
        print_result "Healthcheck has passed at least once" "PASS"
        return 0
    else
        print_result "Healthcheck has passed at least once" "FAIL" "Status: ${health}"
        return 1
    fi
}

# ==============================================================================
# ОСНОВНАЯ ТОЧКА ВХОДА
# ==============================================================================
main() {
    echo "=== Запуск тестов Healthcheck (test_healthcheck.sh v1.1.0) ==="
    echo "Container: ${CONTAINER_NAME}"
    echo ""
    
    local failed=0
    
    test_container_running || failed=$((failed + 1))
    test_healthcheck_status || failed=$((failed + 1))
    test_healthcheck_freshness || failed=$((failed + 1))
    
    echo ""
    if [[ "${failed}" -eq 0 ]]; then
        echo -e "\033[0;32m✓ Все тесты пройдены успешно (${BASH_SOURCE[0]})\033[0m"
        return 0
    else
        echo -e "\033[0;31m✗ Провалено тестов: ${failed}\033[0m"
        return 1
    fi
}

# Запуск main(), если скрипт выполняется напрямую
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
