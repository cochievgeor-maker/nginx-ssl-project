# @file deploy/docker/nginx/Dockerfile
# @brief Multi-stage build for Nginx with non-root user and Alpine base
# @author Кочиев Георгий Джамболатович (kochiev@sfedu.ru)
# @date 2026-05-25
# @version 1.0.0
# @license MIT

# === ЭТАП 1: Валидация конфигов перед сборкой ===
FROM nginx:1.26-alpine AS builder
COPY config/nginx/ /etc/nginx/conf.d/
COPY config/nginx/nginx.conf /etc/nginx/nginx.conf
RUN nginx -t -c /etc/nginx/nginx.conf

# === ЭТАП 2: Минимальный runtime ===
FROM nginx:1.26-alpine AS runtime

# Установка curl для healthcheck + очистка кэша в одном RUN
RUN apk add --no-cache curl && \
    rm -rf /var/cache/apk/*

# Копируем только проверенные конфиги с правами пользователя nginx
COPY --chown=nginx:nginx --from=builder /etc/nginx/conf.d/ /etc/nginx/conf.d/
COPY --chown=nginx:nginx --from=builder /etc/nginx/nginx.conf /etc/nginx/nginx.conf

# Создаём директорию статики и задаём права
RUN mkdir -p /usr/share/nginx/html && \
    chown -R nginx:nginx /usr/share/nginx/html && \
    chmod -R 755 /usr/share/nginx/html

# Запрет работы от root (принцип наименьших привилегий)
USER nginx

EXPOSE 80 443
CMD ["nginx", "-g", "daemon off;"]
