#!/bin/bash
# @file deploy/scripts/generate-certs.sh
# @brief Генерация самоподписанных TLS-сертификатов для локальной разработки
# @author Кочиев Георгий Джамболатович (kochiev@sfedu.ru)
# @date 2026-05-25
# @version 1.0.0

set -euo pipefail

CERT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../certs" && pwd)"
mkdir -p "${CERT_DIR}"

echo "[INFO] Генерация ECDSA-сертификатов (prime256v1) в ${CERT_DIR}/..."
openssl req -x509 -nodes -days 365 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
  -keyout "${CERT_DIR}/server.key" \
  -out "${CERT_DIR}/server.crt" \
  -subj "/CN=localhost/O=Dev/C=RU" 2>/dev/null

chmod 600 "${CERT_DIR}/server.key"
echo "[INFO] Готово. Файлы: server.crt, server.key"
echo "[INFO] Теперь можно запускать: cd deploy && docker compose up -d"

