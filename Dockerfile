# ===========================
# Stage 1: Frontend (Vite + Node)
# ===========================
FROM node:20 AS frontend

WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build


# ===========================
# Stage 2: Vendor dependencies (Composer)
# ===========================
FROM composer:2 AS vendor

WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --no-interaction --prefer-dist


# ===========================
# Stage 3: Backend runtime (Laravel + PHP)
# ===========================
FROM php:8.3-fpm AS backend

# Install required extensions
RUN apt-get update && apt-get install -y \
    git unzip libpq-dev libonig-dev libzip-dev \
    && docker-php-ext-install pdo pdo_mysql pdo_pgsql zip

WORKDIR /var/www/html

# Copy application code and build assets
COPY . .
COPY --from=vendor /app/vendor ./vendor
COPY --from=frontend /app/public/js ./public/js
COPY --from=frontend /app/public/css ./public/css

# Laravel optimizations (clear caches on build)
RUN php artisan config:clear && php artisan cache:clear && php artisan route:clear

CMD ["php-fpm"]
