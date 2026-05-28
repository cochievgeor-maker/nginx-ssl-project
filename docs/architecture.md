
## Компоненты

### 1. Docker (DevOps)
- **Multi-stage build** на базе Alpine Linux
- **Non-root user** (nginx:nginx)
- **Read-only FS** + tmpfs для /var/cache/nginx, /var/run, /tmp

### 2. Nginx (SysAdmin)
- **TLSv1.3** + HTTP/2
- **Security headers** (HSTS, CSP, X-Frame-Options)
- **HTTP→HTTPS redirect** (301)

### 3. Security (Observability)
- `.gitignore` (исключение секретов)
- Docker Secrets для ключей
- UFW firewall (deny-by-default)

