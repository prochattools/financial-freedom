# Stage 1: Backend dependencies (Composer)
FROM composer:2 AS vendor
WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --no-interaction --prefer-dist
COPY . .
RUN composer install --no-dev --optimize-autoloader --no-interaction

# Stage 2: Frontend build
FROM node:20 AS frontend
WORKDIR /app
COPY package*.json ./
RUN npm install
# Copy everything including vendor folder (needed for Ziggy)
COPY . .
COPY --from=vendor /app/vendor ./vendor
RUN npm run build

# Stage 3: Backend runtime (Laravel + PHP)
FROM php:8.2-fpm AS backend

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git unzip libpq-dev libonig-dev libzip-dev \
    && docker-php-ext-install pdo pdo_mysql pdo_pgsql zip

WORKDIR /var/www/html

# Copy app code and dependencies
COPY . .
COPY --from=vendor /app/vendor ./vendor
COPY --from=frontend /app/public/js ./public/js
COPY --from=frontend /app/public/css ./public/css

# Optimize Laravel
RUN php artisan config:clear && php artisan cache:clear && php artisan route:clear

CMD ["php-fpm"]
