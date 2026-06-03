# @file deploy/docker/nginx/Dockerfile
# @brief Multi-stage build for Nginx with non-root user and Alpine base
# @author Кочиев Георгий Джамболатович (kochiev@sfedu.ru)
# @date 2026-05-25
# @version 1.2.0
# @license MIT

# === ЭТАП 1: Валидация конфигов с фейковыми сертификатами. Иначе проблема при деплое.Частое+документирванное решение  ===
FROM nginx:1.26-alpine AS builder

# Копируем конфиги в правильные места
COPY config/nginx/main/nginx.conf /etc/nginx/nginx.conf
COPY config/nginx/conf.d/ /etc/nginx/conf.d/
# Устанавливаем openssl только для валидации (не попадет в runtime) потому что сам nginx:1.26-alpine — это минималистичный дистрибутив
RUN apk add --no-cache openssl
# Создаём фейковые сертификаты ТОЛЬКО для валидации сборки
# Они не попадут в финальный образ, т.к. мы копируем только конфиги
RUN mkdir -p /run/secrets && \
    openssl req -x509 -nodes -days 1 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
    -keyout /run/secrets/nginx_key \
    -out /run/secrets/nginx_cert \
    -subj "/CN=build-validation" 2>/dev/null

# Валидация теперь пройдёт, т.к. сертификаты существуют
RUN nginx -t -c /etc/nginx/nginx.conf

# === ЭТАП 2: Минимальный runtime ===
FROM nginx:1.26-alpine AS runtime

# Установка curl для healthcheck + очистка кэша в одном RUN
RUN apk add --no-cache curl && \
    rm -rf /var/cache/apk/*

# Копируем ТОЛЬКО проверенные конфиги с правильными правами
# Фейковые сертификаты из builder НЕ копируются — намеренно!
COPY --chown=nginx:nginx --from=builder /etc/nginx/nginx.conf /etc/nginx/nginx.conf
COPY --chown=nginx:nginx --from=builder /etc/nginx/conf.d/ /etc/nginx/conf.d/

# Создаём директорию статики и задаём права
RUN mkdir -p /usr/share/nginx/html && \
    chown -R nginx:nginx /usr/share/nginx/html && \
    chmod -R 755 /usr/share/nginx/html

# Запрет работы от root (принцип наименьших привилегий)
USER nginx

EXPOSE 80 443
CMD ["nginx", "-g", "daemon off;"]
