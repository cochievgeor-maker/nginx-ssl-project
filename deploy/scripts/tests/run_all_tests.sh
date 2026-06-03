#!/bin/bash
# @file deploy/scripts/tests/run_all_tests.sh
# @brief Агрегатор интеграционных тестов для инфраструктуры
# @author Кочиев Георгий Джамболатович (kochiev@sfedu.ru)
# @date 2026-05-25
# @version 1.0.0
# @license MIT
#
# @details
# Запускает все тестовые скрипты в каталоге tests/ и агрегирует результаты.
# Возвращает код выхода 0 только если ВСЕ тесты прошли успешно.
# Предназначен для использования в CI/CD и ручной валидации.

set -euo pipefail

# ==============================================================================
# КОНСТАНТЫ
# ==============================================================================
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TEST_PREFIX="test_"
readonly LOG_FILE="/tmp/test-run-$(date +%Y%m%d-%H%M%S).log"

# ==============================================================================
# ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
# ==============================================================================

log_msg() {
    local level="${1:-INFO}"
    local message="${2}"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[${timestamp}] [${level}] ${message}" >> "${LOG_FILE}"
    
    case "${level}" in
        ERROR) echo -e "\033[0;31m[${level}]\033[0m ${message}" >&2 ;;
        WARN)  echo -e "\033[1;33m[${level}]\033[0m ${message}" ;;
        *)     echo -e "\033[0;32m[${level}]\033[0m ${message}" ;;
    esac
}

# ==============================================================================
# ОСНОВНАЯ ЛОГИКА
# ==============================================================================
main() {
    log_msg "INFO" "=== Запуск агрегатора тестов (run_all_tests.sh v1.0.0) ==="
    log_msg "INFO" "Каталог тестов: ${SCRIPT_DIR}"
    log_msg "INFO" "Лог-файл: ${LOG_FILE}"
    echo ""
    
    local total_tests=0
    local passed_tests=0
    local failed_tests=0
    
    # Поиск и запуск всех тестовых скриптов с префиксом test_
    for test_script in "${SCRIPT_DIR}"/${TEST_PREFIX}*.sh; do
        # Пропускаем, если файлы не найдены (glob не сработал)
        [[ -e "${test_script}" ]] || continue
        # Пропускаем сам агрегатор
        [[ "$(basename "${test_script}")" != "run_all_tests.sh" ]] || continue
        
        total_tests=$((total_tests + 1))
        local test_name
        test_name="$(basename "${test_script}")"
        
        log_msg "INFO" "Запуск: ${test_name}"
        echo "─────────────────────────────────"
        
        # Запуск теста и перехват кода выхода
        if bash "${test_script}"; then
            passed_tests=$((passed_tests + 1))
            log_msg "INFO" "✓ ${test_name} — PASSED"
        else
            failed_tests=$((failed_tests + 1))
            log_msg "ERROR" "✗ ${test_name} — FAILED"
        fi
        echo ""
    done
    
    # Итоговый отчёт
    echo "═══════════════════════════════════"
    log_msg "INFO" "Итоги: всего=${total_tests}, пройдено=${passed_tests}, провалено=${failed_tests}"
    
    if [[ "${failed_tests}" -eq 0 && "${total_tests}" -gt 0 ]]; then
        log_msg "INFO" "✓ ВСЕ ТЕСТЫ ПРОЙДЕНЫ"
        return 0
    elif [[ "${total_tests}" -eq 0 ]]; then
        log_msg "WARN" "⚠ Тестовые скрипты не найдены (ожидался префикс '${TEST_PREFIX}')"
        return 1
    else
        log_msg "ERROR" "✗ ПРОВАЛЕНО ТЕСТОВ: ${failed_tests}"
        return 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
