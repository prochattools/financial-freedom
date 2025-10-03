FROM composer:2 AS vendor
WORKDIR /app
COPY . .   # 👈 copies full Laravel project
RUN composer install --no-dev --no-interaction --optimize-autoloader

FROM node:20 AS frontend
WORKDIR /app
COPY . .
RUN npm install && npm run build || echo "⚠️ Frontend build failed, continuing..."

FROM php:8.3-fpm AS app
WORKDIR /var/www/html

# system deps
RUN apt-get update && apt-get install -y \
    git unzip curl libpq-dev libonig-dev libzip-dev nginx supervisor \
    && docker-php-ext-install pdo pdo_mysql pdo_pgsql zip \
    && rm -rf /var/lib/apt/lists/*

COPY --from=vendor /app /var/www/html
COPY --from=frontend /app/public /var/www/html/public
COPY docker/nginx.conf /etc/nginx/nginx.conf
COPY docker/supervisord.conf /etc/supervisord.conf

RUN mkdir -p /var/www/html/storage /var/www/html/bootstrap/cache \
    && chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache \
    && chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache

EXPOSE 80
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
