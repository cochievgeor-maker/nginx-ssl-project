#!/bin/bash
# @file deploy/scripts/tests/test_nginx.sh
# @brief Интеграционные тесты для Nginx: HTTPS, заголовки безопасности, редирект
# @author Кочиев Георгий Джамболатович (kochiev@sfedu.ru)
# @date 2026-05-25
# @version 1.0.0
# @license MIT
#
# @details
# Набор тестов для валидации работы веб-сервера:
# 1. Проверка доступности HTTPS-эндпоинта (код 200)
# 2. Валидация заголовков безопасности (HSTS, CSP, X-Frame-Options)
# 3. Проверка редиректа HTTP → HTTPS (код 301)
# 4. Проверка версии протокола (HTTP/2)

set -euo pipefail

# ==============================================================================
# КОНСТАНТЫ ТЕСТОВ
# ==============================================================================
readonly BASE_URL="https://localhost"
readonly HTTP_URL="http://localhost"
readonly TIMEOUT_SEC=10
readonly EXPECTED_HTTPS_CODE=200
readonly EXPECTED_REDIRECT_CODE=301

# ==============================================================================
# ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
# ==============================================================================

# @brief Вывод результата теста с цветом
# @param 1 test_name Название теста
# @param 2 status Статус: "PASS" или "FAIL"
# @param 3 message Дополнительное сообщение (опционально)
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
# ТЕСТОВЫЕ ФУНКЦИИ (BATS-совместимый стиль)
# ==============================================================================

# @brief Проверка доступности HTTPS с кодом ответа 200
# @return 0 если сервис доступен и вернул 200, 1 иначе
test_nginx_https_available() {
    local http_code
    http_code=$(curl -k -s -o /dev/null -w "%{http_code}" --connect-timeout "${TIMEOUT_SEC}" "${BASE_URL}/")
    
    if [[ "${http_code}" -eq "${EXPECTED_HTTPS_CODE}" ]]; then
        print_result "HTTPS availability (code ${EXPECTED_HTTPS_CODE})" "PASS"
        return 0
    else
        print_result "HTTPS availability (expected ${EXPECTED_HTTPS_CODE})" "FAIL" "Got HTTP ${http_code}"
        return 1
    fi
}

# @brief Проверка наличия заголовка Strict-Transport-Security (HSTS)
# @return 0 если заголовок присутствует, 1 иначе
test_nginx_hsts_header() {
    local hsts_header
    hsts_header=$(curl -k -s -I --connect-timeout "${TIMEOUT_SEC}" "${BASE_URL}/" | grep -i "^strict-transport-security:" || true)
    
    if [[ -n "${hsts_header}" ]]; then
        print_result "HSTS header present" "PASS"
        return 0
    else
        print_result "HSTS header present" "FAIL" "Header not found in response"
        return 1
    fi
}

# @brief Проверка наличия заголовка Content-Security-Policy
# @return 0 если заголовок присутствует, 1 иначе
test_nginx_csp_header() {
    local csp_header
    csp_header=$(curl -k -s -I --connect-timeout "${TIMEOUT_SEC}" "${BASE_URL}/" | grep -i "^content-security-policy:" || true)
    
    if [[ -n "${csp_header}" ]]; then
        print_result "CSP header present" "PASS"
        return 0
    else
        print_result "CSP header present" "FAIL" "Header not found in response"
        return 1
    fi
}

# @brief Проверка наличия заголовка X-Frame-Options: DENY
# @return 0 если заголовок присутствует со значением DENY, 1 иначе
test_nginx_xframe_header() {
    local xframe_header
    xframe_header=$(curl -k -s -I --connect-timeout "${TIMEOUT_SEC}" "${BASE_URL}/" | grep -i "^x-frame-options:" || true)
    
    if [[ "${xframe_header}" =~ [Dd][Ee][Nn][Yy] ]]; then
        print_result "X-Frame-Options: DENY present" "PASS"
        return 0
    else
        print_result "X-Frame-Options: DENY present" "FAIL" "Header missing or wrong value: ${xframe_header}"
        return 1
    fi
}

# @brief Проверка редиректа HTTP → HTTPS (код 301)
# @return 0 если редирект работает, 1 иначе
test_nginx_http_redirect() {
    local http_code location
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout "${TIMEOUT_SEC}" "${HTTP_URL}/")
    location=$(curl -s -I --connect-timeout "${TIMEOUT_SEC}" "${HTTP_URL}/" | grep -i "^location:" | tr -d '\r' | awk '{print $2}' || true)
    
    if [[ "${http_code}" -eq "${EXPECTED_REDIRECT_CODE}" && "${location}" =~ ^https:// ]]; then
        print_result "HTTP→HTTPS redirect (301 to https)" "PASS"
        return 0
    else
        print_result "HTTP→HTTPS redirect (expected 301 to https)" "FAIL" "Got ${http_code}, Location: ${location:-N/A}"
        return 1
    fi
}

# @brief Проверка использования протокола HTTP/2
# @return 0 если сервер отвечает по HTTP/2, 1 иначе
test_nginx_http2_protocol() {
    local protocol
    # curl -I --http2 выводит предупреждение, если сервер не поддерживает HTTP/2
    protocol=$(curl -k -s -I --http2 --connect-timeout "${TIMEOUT_SEC}" "${BASE_URL}/" 2>&1 | head -1 || true)
    
    if [[ "${protocol}" =~ ^HTTP/2 ]]; then
        print_result "HTTP/2 protocol support" "PASS"
        return 0
    else
        print_result "HTTP/2 protocol support" "FAIL" "Response: ${protocol:-empty}"
        return 1
    fi
}

# ==============================================================================
# ОСНОВНАЯ ТОЧКА ВХОДА
# ==============================================================================
main() {
    echo "=== Запуск тестов Nginx (test_nginx.sh v1.0.0) ==="
    echo "Target: ${BASE_URL}"
    echo ""
    
    local failed=0
    
    test_nginx_https_available || ((failed++)) || true
    test_nginx_hsts_header || ((failed++)) || true
    test_nginx_csp_header || ((failed++)) || true
    test_nginx_xframe_header || ((failed++)) || true
    test_nginx_http_redirect || ((failed++)) || true
    test_nginx_http2_protocol || ((failed++)) || true
    
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
