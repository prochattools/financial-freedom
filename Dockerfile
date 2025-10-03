# 1. Frontend build stage
FROM node:20 AS frontend
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .

# Copy vendor (needed for Ziggy)
COPY --from=vendor /app/vendor ./vendor

RUN npm run build


# 2. Composer vendor stage
FROM composer:2 AS vendor
WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-interaction --optimize-autoloader


# 3. PHP base stage
FROM php:8.3-fpm AS base
WORKDIR /var/www/html
RUN apt-get update && apt-get install -y \
    git unzip curl libpq-dev libonig-dev libzip-dev nginx supervisor \
    && docker-php-ext-install pdo pdo_mysql pdo_pgsql zip \
    && rm -rf /var/lib/apt/lists/*

# Copy application code
COPY . .

# Copy vendor from composer stage
COPY --from=vendor /app/vendor ./vendor

# Copy frontend build from node stage
COPY --from=frontend /app/public/build ./public/build

# Set correct permissions
RUN mkdir -p storage bootstrap/cache \
  && chown -R www-data:www-data storage bootstrap/cache \
  && chmod -R 775 storage bootstrap/cache

# Copy configs
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

EXPOSE 80
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
